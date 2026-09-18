import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../models/catalog_product.dart';
import '../../models/sales_record.dart';
import '../../utils/date_format.dart';
import 'sales_sheet_format.dart';

/// Masalah di satu baris file.
class SheetIssue {
  const SheetIssue(this.rowNumber, this.message);

  /// Nomor baris seperti di Excel (mulai dari 1).
  final int rowNumber;
  final String message;

  @override
  String toString() => 'Baris $rowNumber: $message';
}

/// File tidak bisa diproses sama sekali (bukan XLSX, kolom tidak lengkap, dst).
class SalesSheetException implements Exception {
  const SalesSheetException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParsedSalesSheet {
  const ParsedSalesSheet({
    required this.sheetName,
    required this.records,
    required this.issues,
  });

  final String sheetName;
  final List<SalesRecord> records;
  final List<SheetIssue> issues;

  bool get canSubmit => issues.isEmpty && records.isNotEmpty;
}

/// Input untuk [parseSalesSheetInBackground].
typedef SalesSheetInput = ({
  Uint8List bytes,
  String storeName,
  DateTime today,
  List<CatalogProduct> catalog,
  DateTime? month,
});

/// Versi top-level untuk dijalankan di isolate lain lewat `compute`, supaya
/// file besar tidak membuat layar patah-patah.
ParsedSalesSheet parseSalesSheetInBackground(SalesSheetInput input) =>
    parseSalesSheet(
      input.bytes,
      storeName: input.storeName,
      today: input.today,
      catalog: input.catalog,
      month: input.month,
    );

/// Membaca file XLSX penjualan menjadi daftar [SalesRecord].
///
/// Setiap baris harus memakai kode produk yang ada di [catalog], dengan nama
/// (dan kategori, kalau diisi) yang sama persis. Nama & kategori yang disimpan
/// selalu diambil dari katalog, jadi datanya seragam di semua toko.
///
/// Kalau [month] diisi, semua tanggal harus di bulan itu.
///
/// Melempar [SalesSheetException] kalau file tidak bisa dibaca atau kolom
/// wajib tidak ada. Kesalahan per baris dikumpulkan di
/// [ParsedSalesSheet.issues].
ParsedSalesSheet parseSalesSheet(
  Uint8List bytes, {
  required String storeName,
  required DateTime today,
  required List<CatalogProduct> catalog,
  DateTime? month,
}) {
  if (catalog.isEmpty) {
    throw const SalesSheetException(
      'Katalog produk masih kosong. Minta admin pusat menambahkan produk dulu.',
    );
  }
  final productsByCode = {
    for (final product in catalog) product.code.toUpperCase(): product,
  };

  final Excel excel;
  try {
    excel = Excel.decodeBytes(bytes);
  } catch (_) {
    throw const SalesSheetException(
      'File tidak bisa dibaca. Pastikan formatnya .xlsx (bukan .xls atau .csv).',
    );
  }

  final located = _locateTable(excel);
  if (located == null) {
    final required = SalesColumn.values
        .where((column) => column.isRequired)
        .map((column) => column.header)
        .join(', ');
    throw SalesSheetException(
      'Judul kolom tidak ditemukan. Baris judul harus berisi: $required.',
    );
  }

  final (:sheetName, :rows, :headerRow, :columns) = located;
  final records = <SalesRecord>[];
  final issues = <SheetIssue>[];
  final seenKeys = <String, int>{};
  final lastDate = dateOnly(today);

  for (var index = headerRow + 1; index < rows.length; index++) {
    final row = rows[index];
    final rowNumber = index + 1;
    CellValue? cell(SalesColumn column) {
      final columnIndex = columns[column];
      if (columnIndex == null || columnIndex >= row.length) return null;
      return row[columnIndex]?.value;
    }

    if (columns.values.every(
      (i) => _isBlank(i < row.length ? row[i]?.value : null),
    )) {
      continue;
    }

    if (records.length + issues.length >= kMaxSalesRows) {
      throw const SalesSheetException(
        'File terlalu besar. Maksimal $kMaxSalesRows baris per upload.',
      );
    }

    final rowIssues = <String>[];

    final date = _readDate(cell(SalesColumn.date));
    if (date == null) {
      rowIssues.add('tanggal kosong atau formatnya salah');
    } else if (date.isAfter(lastDate)) {
      rowIssues.add('tanggal ${formatIsoDate(date)} belum terjadi');
    } else if (month != null &&
        (date.year != month.year || date.month != month.month)) {
      rowIssues.add(
        'tanggal ${formatIsoDate(date)} bukan bulan ${formatMonthYear(month)}',
      );
    }

    final rawCode = _readText(cell(SalesColumn.productCode));
    final name = _readText(cell(SalesColumn.productName));
    final category = _readText(cell(SalesColumn.category));
    final product = rawCode == null
        ? null
        : productsByCode[rawCode.toUpperCase()];
    final code = product?.code;

    if (rawCode == null) {
      rowIssues.add('kode_produk kosong');
    } else if (product == null) {
      rowIssues.add('kode_produk "$rawCode" tidak ada di katalog');
    } else if (!product.isActive) {
      rowIssues.add('produk ${product.code} sudah tidak aktif di katalog');
    }

    if (name == null) {
      rowIssues.add('nama_produk kosong');
    } else if (product != null &&
        normalizeProductName(name) != normalizeProductName(product.name)) {
      rowIssues.add(
        'nama_produk untuk ${product.code} harus "${product.name}"',
      );
    }

    if (category != null &&
        product != null &&
        normalizeProductName(category) !=
            normalizeProductName(product.category)) {
      rowIssues.add(
        'kategori untuk ${product.code} harus "${product.category}"',
      );
    }

    int? readCount(SalesColumn column, {required bool required}) {
      final value = cell(column);
      if (_isBlank(value)) {
        if (required) rowIssues.add('${column.header} kosong');
        return null;
      }
      final number = _readWholeNumber(value);
      if (number == null || number < 0) {
        rowIssues.add('${column.header} harus angka bulat ≥ 0');
        return null;
      }
      return number;
    }

    final quantity = readCount(SalesColumn.quantity, required: true);
    final unitPrice = readCount(SalesColumn.unitPrice, required: true);
    final stockEnd = readCount(SalesColumn.stockEnd, required: true);
    final minStock = readCount(SalesColumn.minStock, required: false);

    if (date != null && code != null) {
      final key = '${formatIsoDate(date)}_$code';
      final firstRow = seenKeys[key];
      if (firstRow != null) {
        rowIssues.add(
          'produk $code tanggal ${formatIsoDate(date)} sudah ada di baris $firstRow',
        );
      } else {
        seenKeys[key] = rowNumber;
      }
    }

    if (rowIssues.isNotEmpty) {
      issues.add(SheetIssue(rowNumber, rowIssues.join('; ')));
      continue;
    }

    records.add(
      SalesRecord(
        storeName: storeName,
        date: date!,
        productCode: product!.code,
        productName: product.name,
        category: product.category,
        quantity: quantity!,
        unitPrice: unitPrice!,
        stockEnd: stockEnd!,
        minStock: minStock ?? product.minStock,
      ),
    );
  }

  if (records.isEmpty && issues.isEmpty) {
    throw const SalesSheetException(
      'File tidak berisi data di bawah baris judul.',
    );
  }

  return ParsedSalesSheet(
    sheetName: sheetName,
    records: records,
    issues: issues,
  );
}

typedef _LocatedTable = ({
  String sheetName,
  List<List<Data?>> rows,
  int headerRow,
  Map<SalesColumn, int> columns,
});

_LocatedTable? _locateTable(Excel excel) {
  final sheetNames = excel.tables.keys.toList()
    ..sort((a, b) {
      // Sheet "Penjualan" dicek lebih dulu.
      final aPreferred = normalizeHeader(a) == normalizeHeader(kSalesSheetName);
      final bPreferred = normalizeHeader(b) == normalizeHeader(kSalesSheetName);
      return aPreferred == bPreferred ? 0 : (aPreferred ? -1 : 1);
    });

  for (final sheetName in sheetNames) {
    final rows = excel.tables[sheetName]!.rows;
    // Baris judul dicari di 10 baris pertama.
    for (
      var rowIndex = 0;
      rowIndex < rows.length && rowIndex < 10;
      rowIndex++
    ) {
      final columns = <SalesColumn, int>{};
      final row = rows[rowIndex];
      for (var columnIndex = 0; columnIndex < row.length; columnIndex++) {
        final text = _readText(row[columnIndex]?.value);
        if (text == null) continue;
        final normalized = normalizeHeader(text);
        for (final column in SalesColumn.values) {
          if (!columns.containsKey(column) && column.matches(normalized)) {
            columns[column] = columnIndex;
          }
        }
      }
      final hasRequired = SalesColumn.values
          .where((column) => column.isRequired)
          .every(columns.containsKey);
      if (hasRequired) {
        return (
          sheetName: sheetName,
          rows: rows,
          headerRow: rowIndex,
          columns: columns,
        );
      }
    }
  }
  return null;
}

bool _isBlank(CellValue? value) => switch (value) {
  null => true,
  TextCellValue() => value.value.toString().trim().isEmpty,
  _ => false,
};

String? _readText(CellValue? value) {
  final text = switch (value) {
    null => null,
    TextCellValue() => value.value.toString(),
    IntCellValue() => '${value.value}',
    DoubleCellValue() =>
      value.value == value.value.roundToDouble()
          ? '${value.value.toInt()}'
          : '${value.value}',
    BoolCellValue() => '${value.value}',
    DateCellValue() => formatIsoDate(
      DateTime(value.year, value.month, value.day),
    ),
    DateTimeCellValue() => formatIsoDate(
      DateTime(value.year, value.month, value.day),
    ),
    TimeCellValue() || FormulaCellValue() => null,
  }?.trim();
  return text == null || text.isEmpty ? null : text;
}

final _isoDate = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
final _dayFirstDate = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$');

DateTime? _readDate(CellValue? value) {
  switch (value) {
    case DateCellValue():
      return DateTime(value.year, value.month, value.day);
    case DateTimeCellValue():
      return DateTime(value.year, value.month, value.day);
    case IntCellValue():
      return _fromExcelSerial(value.value.toDouble());
    case DoubleCellValue():
      return _fromExcelSerial(value.value);
    case TextCellValue():
      final text = value.value.toString().trim();
      final iso = _isoDate.firstMatch(text);
      if (iso != null) {
        return _validDate(
          int.parse(iso[1]!),
          int.parse(iso[2]!),
          int.parse(iso[3]!),
        );
      }
      final dayFirst = _dayFirstDate.firstMatch(text);
      if (dayFirst != null) {
        return _validDate(
          int.parse(dayFirst[3]!),
          int.parse(dayFirst[2]!),
          int.parse(dayFirst[1]!),
        );
      }
      return null;
    default:
      return null;
  }
}

/// Excel menyimpan tanggal sebagai jumlah hari sejak 30 Des 1899.
DateTime? _fromExcelSerial(double serial) {
  if (serial < 20000 || serial > 80000) return null;
  final date = DateTime(1899, 12, 30 + serial.floor());
  return DateTime(date.year, date.month, date.day);
}

DateTime? _validDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  // DateTime menggeser tanggal yang tidak ada (31 Feb -> 3 Mar); tolak itu.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

final _thousandsDots = RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$');
final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');

int? _readWholeNumber(CellValue? value) {
  switch (value) {
    case IntCellValue():
      return value.value;
    case DoubleCellValue():
      final number = value.value;
      return number == number.roundToDouble() ? number.toInt() : null;
    case TextCellValue():
      var text = value.value
          .toString()
          .trim()
          .replaceFirst(RegExp(r'^rp\.?', caseSensitive: false), '')
          .replaceAll(' ', '');
      if (_thousandsDots.hasMatch(text)) {
        // Format Indonesia: 20.000.000 atau 20.000.000,00
        text = text.split(',').first.replaceAll('.', '');
        return int.parse(text);
      }
      if (_plainNumber.hasMatch(text)) {
        final number = double.parse(text.replaceAll(',', '.'));
        return number == number.roundToDouble() ? number.toInt() : null;
      }
      return null;
    default:
      return null;
  }
}
