import 'dart:math';

import '../models/sales_record.dart';
import '../models/sales_upload.dart';
import '../models/shipment.dart';
import 'apple_catalog.dart';
import 'stores.dart';

// Data contoh 6 minggu untuk 2 toko, dipakai test & mode offline.

/// Maksimal unit terjual per hari dan jumlah sekali restock, per produk.
const _demand = {
  'IP17PM': (maxDaily: 2, restock: 12),
  'IP17P': (maxDaily: 2, restock: 12),
  'IP17': (maxDaily: 3, restock: 14),
  'IP16': (maxDaily: 1, restock: 8),
  'MBA13M4': (maxDaily: 1, restock: 8),
  'MBP14M5': (maxDaily: 1, restock: 6),
  'AWS11': (maxDaily: 2, restock: 10),
  'AWU3': (maxDaily: 1, restock: 6),
};

const _storeScale = [1.0, 0.8];

/// Toko + produk yang tidak di-restock 3 hari terakhir: stok menipis tapi
/// belum habis.
const _runningLowPairs = {('Toko 2', 'IP17')};

/// Toko + produk yang sengaja tidak di-restock di akhir periode, supaya ada
/// contoh stok habis.
const _lowStockPairs = {('Toko 1', 'IP17PM'), ('Toko 2', 'AWS11')};

({List<SalesUpload> uploads, List<Shipment> shipments}) buildSampleSalesData(
  DateTime now, {
  int weeks = 6,
}) {
  final thisMonday = weekStart(now);
  final firstDay = DateTime(
    thisMonday.year,
    thisMonday.month,
    thisMonday.day - 7 * weeks,
  );
  final totalDays = 7 * weeks;
  final uploads = <SalesUpload>[];

  for (var storeIndex = 0; storeIndex < kStores.length; storeIndex++) {
    final storeName = kStores[storeIndex];
    final random = Random(1000 + storeIndex);
    final stock = {
      for (final product in appleCatalog)
        product.code:
            _demand[product.code]!.restock +
            random.nextInt(_demand[product.code]!.restock),
    };

    for (var week = 0; week < weeks; week++) {
      final weekRecords = <SalesRecord>[];

      for (var day = 0; day < 7; day++) {
        final dayIndex = week * 7 + day;
        final date = DateTime(
          firstDay.year,
          firstDay.month,
          firstDay.day + dayIndex,
        );
        final daysToEnd = totalDays - 1 - dayIndex;
        final growth = 0.85 + dayIndex / totalDays * 0.35;

        for (final product in appleCatalog) {
          final demand = _demand[product.code]!;
          final keepLow = _lowStockPairs.contains((storeName, product.code));
          if (keepLow && daysToEnd == 12) {
            stock[product.code] = min(
              stock[product.code]!,
              product.minStock + 3,
            );
          }

          final runningLow = _runningLowPairs.contains((
            storeName,
            product.code,
          ));
          if (runningLow && daysToEnd == 2) {
            stock[product.code] = product.minStock + demand.maxDaily * 2;
          }

          final weekendBoost = date.weekday >= 6 && random.nextBool() ? 1 : 0;
          final wanted =
              ((random.nextInt(demand.maxDaily + 1) + weekendBoost) *
                      _storeScale[storeIndex] *
                      growth)
                  .round();
          final quantity = min(wanted, stock[product.code]!);
          var remaining = stock[product.code]! - quantity;

          final canRestock =
              !(keepLow && daysToEnd <= 12) && !(runningLow && daysToEnd <= 2);
          if (canRestock &&
              remaining <= product.minStock + demand.maxDaily * 5 &&
              random.nextDouble() < 0.7) {
            remaining += demand.restock;
          }
          stock[product.code] = remaining;

          weekRecords.add(
            SalesRecord(
              storeName: storeName,
              date: date,
              productCode: product.code,
              productName: product.name,
              category: product.category.label,
              quantity: quantity,
              unitPrice: product.price,
              stockEnd: remaining,
              minStock: product.minStock,
            ),
          );
        }
      }

      final weekFirstDay = weekRecords.first.date;
      uploads.add(
        SalesUpload.fromRecords(
          id: 'sample-$storeIndex-$week',
          storeName: storeName,
          uploadedBy: 'Admin $storeName',
          uploadedByEmail:
              '${storeName.toLowerCase().replaceAll(' ', '')}@supply.id',
          uploadedAt: DateTime(
            weekFirstDay.year,
            weekFirstDay.month,
            weekFirstDay.day + 7,
            9 + storeIndex,
            15 * storeIndex,
          ),
          fileName:
              'penjualan_${storeName.toLowerCase().replaceAll(' ', '')}_'
              '${formatIsoDate(weekFirstDay)}.xlsx',
          records: weekRecords,
        ),
      );
    }
  }

  return (uploads: uploads, shipments: const <Shipment>[]);
}
