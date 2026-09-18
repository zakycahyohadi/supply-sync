// Membuat file XLSX untuk admin toko dari katalog di templates/produk.json:
//   templates/template_penjualan.xlsx     semua produk katalog, qty & stok kosong
//   templates/contoh_upload_toko1.xlsx    contoh data Senin s/d kemarin, siap upload
//   templates/contoh_upload_toko2.xlsx    sama, untuk Toko 2
//
// Jalankan: dart run tool/generate_xlsx.dart
import 'dart:io';
import 'dart:math';

import 'package:supply_sync/data/product_json.dart';
import 'package:supply_sync/data/xlsx/sales_template.dart';
import 'package:supply_sync/models/catalog_product.dart';
import 'package:supply_sync/models/sales_record.dart';

/// Rentang stok awal & penjualan harian per kategori. Stok awal dibuat cukup
/// untuk lebih dari 14 hari penjualan, jadi statusnya aman kecuali produk di
/// [_endingStock].
const _profile = {
  'iPhone': (minStart: 30, maxStart: 45, maxDaily: 2),
  'MacBook': (minStart: 18, maxStart: 28, maxDaily: 1),
  'Apple Watch': (minStart: 30, maxStart: 40, maxDaily: 2),
  'Audio': (minStart: 60, maxStart: 90, maxDaily: 4),
  'Accessories': (minStart: 75, maxStart: 110, maxDaily: 5),
};

/// Produk yang sengaja dibuat habis / menipis di akhir file, supaya
/// peringatan stok terlihat setelah upload.
const _endingStock = {
  // Habis, menipis (≤ stok minimum), hampir menipis (≤ 2× minimum).
  'Toko 1': {'IP18PM': 0, 'APP2': 4, 'M5P16': 5},
  'Toko 2': {'MK': 0, 'IP17PM': 3, 'AWU3': 5},
};

void main() {
  final parsed = parseProductJson(
    File('templates/produk.json').readAsStringSync(),
    existing: const [],
  );
  if (!parsed.canSave) {
    stderr.writeln('templates/produk.json tidak valid:');
    parsed.issues.forEach(stderr.writeln);
    exit(1);
  }
  final catalog = [
    for (final item in parsed.products)
      if (item.product.isActive) item.product,
  ];

  File(
    'templates/template_penjualan.xlsx',
  ).writeAsBytesSync(buildSalesTemplate(catalog));

  final today = dateOnly(DateTime.now());
  final thisMonday = weekStart(today);
  // Senin s/d kemarin; kalau hari ini Senin, pakai 7 hari terakhir.
  final firstDay = today == thisMonday
      ? DateTime(today.year, today.month, today.day - 7)
      : thisMonday;
  final days = [
    for (
      var date = firstDay;
      date.isBefore(today);
      date = DateTime(date.year, date.month, date.day + 1)
    )
      date,
  ];

  for (final (index, store) in ['Toko 1', 'Toko 2'].indexed) {
    final rows = _rowsFor(store, catalog, days, Random(20 + index));
    final file =
        'templates/contoh_upload_${store.toLowerCase().replaceAll(' ', '')}.xlsx';
    File(
      file,
    ).writeAsBytesSync(buildSalesWorkbook(rows: rows, catalog: catalog));
    stdout.writeln(
      '$file: ${rows.length} baris, ${catalog.length} produk × ${days.length} hari '
      '(${formatIsoDate(days.first)} s/d ${formatIsoDate(days.last)})',
    );
  }
}

List<TemplateRow> _rowsFor(
  String store,
  List<CatalogProduct> catalog,
  List<DateTime> days,
  Random random,
) {
  final rows = <TemplateRow>[];
  for (final product in catalog) {
    final profile = _profile[product.category]!;
    final sales = [for (final _ in days) random.nextInt(profile.maxDaily + 1)];
    final target = _endingStock[store]?[product.code];
    int stock = target == null
        ? profile.minStart +
              random.nextInt(profile.maxStart - profile.minStart + 1)
        : target + sales.fold<int>(0, (sum, qty) => sum + qty);

    for (final (i, date) in days.indexed) {
      final int quantity = min(sales[i], stock);
      stock -= quantity;
      rows.add((
        date: date,
        code: product.code,
        name: product.name,
        category: product.category,
        quantity: quantity,
        unitPrice: product.price,
        stockEnd: stock,
        minStock: product.minStock,
      ));
    }
  }
  // Urut per tanggal, lalu mengikuti urutan katalog.
  final order = {for (final (i, p) in catalog.indexed) p.code: i};
  rows.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : order[a.code]!.compareTo(order[b.code]!);
  });
  return rows;
}
