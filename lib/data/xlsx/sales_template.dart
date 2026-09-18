import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../models/catalog_product.dart';
import 'sales_sheet_format.dart';

/// Contoh isi yang ditaruh di template.
typedef TemplateRow = ({
  DateTime date,
  String code,
  String name,
  String? category,
  int? quantity,
  int unitPrice,
  int? stockEnd,
  int? minStock,
});

/// Membuat file XLSX: sheet "Penjualan" (judul kolom + [rows]), sheet
/// "Produk" (katalog resmi, kalau [catalog] diisi), dan sheet "Petunjuk".
Uint8List buildSalesWorkbook({
  List<TemplateRow> rows = const [],
  List<CatalogProduct> catalog = const [],
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet()!;
  excel.rename(defaultSheet, kSalesSheetName);
  final sheet = excel[kSalesSheetName];

  final headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#0B1F3A'),
  );
  sheet.appendRow([
    for (final column in SalesColumn.values) TextCellValue(column.header),
  ]);
  for (var i = 0; i < SalesColumn.values.length; i++) {
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle =
        headerStyle;
    sheet.setColumnWidth(i, i == 2 ? 24 : 16);
  }

  for (final row in rows) {
    sheet.appendRow([
      DateCellValue(
        year: row.date.year,
        month: row.date.month,
        day: row.date.day,
      ),
      TextCellValue(row.code),
      TextCellValue(row.name),
      row.category == null ? null : TextCellValue(row.category!),
      row.quantity == null ? null : IntCellValue(row.quantity!),
      IntCellValue(row.unitPrice),
      row.stockEnd == null ? null : IntCellValue(row.stockEnd!),
      row.minStock == null ? null : IntCellValue(row.minStock!),
    ]);
  }

  if (catalog.isNotEmpty) {
    final products = excel['Produk'];
    const headers = [
      'kode_produk',
      'nama_produk',
      'kategori',
      'harga_satuan',
      'stok_minimum',
    ];
    products.appendRow([for (final header in headers) TextCellValue(header)]);
    for (var i = 0; i < headers.length; i++) {
      products
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .cellStyle =
          headerStyle;
      products.setColumnWidth(i, i == 1 ? 26 : 16);
    }
    for (final product in catalog) {
      products.appendRow([
        TextCellValue(product.code),
        TextCellValue(product.name),
        TextCellValue(product.category),
        IntCellValue(product.price),
        IntCellValue(product.minStock),
      ]);
    }
  }

  final guide = excel['Petunjuk'];
  guide.appendRow([
    TextCellValue('Kolom'),
    TextCellValue('Wajib?'),
    TextCellValue('Keterangan'),
  ]);
  for (var i = 0; i < 3; i++) {
    guide
            .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .cellStyle =
        headerStyle;
  }
  for (final column in SalesColumn.values) {
    guide.appendRow([
      TextCellValue(column.header),
      TextCellValue(column.isRequired ? 'Wajib' : 'Opsional'),
      TextCellValue(column.description),
    ]);
  }
  guide.appendRow([]);
  guide.appendRow([
    TextCellValue('Catatan'),
    null,
    TextCellValue(
      'Satu baris = satu produk per hari. kode_produk & nama_produk harus '
      'sama persis dengan sheet "Produk". Omzet dihitung otomatis '
      '(qty_terjual x harga_satuan). Upload ulang tanggal yang sama akan '
      'menimpa data lama.',
    ),
  ]);
  guide.setColumnWidth(0, 16);
  guide.setColumnWidth(1, 10);
  guide.setColumnWidth(2, 70);

  excel.setDefaultSheet(kSalesSheetName);
  return Uint8List.fromList(excel.encode()!);
}

/// Template untuk admin toko: satu baris per produk aktif di katalog pada
/// tanggal [date]. Default: kemarin, atau hari terakhir [month] kalau bulan
/// itu sudah lewat. Kode, nama, kategori, harga, dan stok minimum sudah
/// terisi; admin toko tinggal mengisi qty_terjual & stok_akhir.
Uint8List buildSalesTemplate(
  List<CatalogProduct> catalog, {
  DateTime? date,
  DateTime? month,
}) {
  final rowDate = date ?? defaultTemplateDate(DateTime.now(), month: month);
  final active = catalog.where((product) => product.isActive).toList();
  return buildSalesWorkbook(
    catalog: active,
    rows: [
      for (final product in active)
        (
          date: rowDate,
          code: product.code,
          name: product.name,
          category: product.category,
          quantity: null,
          unitPrice: product.price,
          stockEnd: null,
          minStock: product.minStock,
        ),
    ],
  );
}

/// Tanggal contoh di template: kemarin (atau hari ini kalau tanggal 1) untuk
/// bulan berjalan, hari terakhir bulan untuk bulan yang sudah lewat.
DateTime defaultTemplateDate(DateTime now, {DateTime? month}) {
  final today = DateTime(now.year, now.month, now.day);
  final target = month ?? today;
  if (target.year == today.year && target.month == today.month) {
    return today.day > 1
        ? DateTime(today.year, today.month, today.day - 1)
        : today;
  }
  return DateTime(target.year, target.month + 1, 0);
}
