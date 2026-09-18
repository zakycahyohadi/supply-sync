import '../models/sales_record.dart';
import '../models/shipment.dart';
import 'stores.dart';

/// Stok "menipis" kalau perkiraan habis kurang dari sekian hari.
const kLowStockDays = 7;

/// Stok "hampir menipis" kalau perkiraan habis kurang dari sekian hari.
const kNearLowStockDays = 14;

/// Rata-rata penjualan harian dihitung dari sekian hari terakhir.
const kSalesVelocityDays = 14;

/// Saran jumlah kirim: cukup untuk sekian hari penjualan.
const kRestockTargetDays = 21;

/// Urutan = tingkat urgensi (paling mendesak dulu).
enum StockStatus {
  out('Habis'),
  low('Menipis'),
  nearLow('Hampir menipis'),
  ok('Aman');

  const StockStatus(this.label);

  final String label;

  bool get needsRestock => this != ok;
}

/// Stok terakhir satu produk di satu toko.
class StockLevel {
  const StockLevel({
    required this.storeName,
    required this.productCode,
    required this.productName,
    required this.stock,
    required this.asOf,
    required this.averageDailySales,
    required this.status,
    this.category,
    this.minStock,
    this.receivedSinceUpload = 0,
    this.incoming = 0,
  });

  final String storeName;
  final String productCode;
  final String productName;
  final String? category;

  /// Stok akhir dari data upload + pengiriman yang diterima setelahnya.
  final int stock;
  final int? minStock;

  /// Tanggal data upload terakhir.
  final DateTime asOf;
  final double averageDailySales;
  final StockStatus status;

  /// Unit dari pengiriman yang sudah dikonfirmasi setelah upload terakhir.
  final int receivedSinceUpload;

  /// Unit yang sedang dikirim (belum dikonfirmasi toko).
  final int incoming;

  /// Perkiraan stok habis dalam sekian hari; null kalau tidak ada penjualan.
  double? get daysLeft =>
      averageDailySales > 0 ? stock / averageDailySales : null;

  /// Saran jumlah kirim supaya statusnya kembali aman.
  int get suggestedRestock {
    final min = minStock ?? 0;
    final target = [
      min * 2 + 1,
      (averageDailySales * kRestockTargetDays).ceil(),
      1,
    ].reduce((a, b) => a > b ? a : b);
    final needed = target - stock - incoming;
    return needed < 1 ? 1 : needed;
  }
}

class ProductPerformance {
  const ProductPerformance({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.revenue,
  });

  final String productCode;
  final String productName;
  final int quantity;
  final int revenue;
}

/// Perubahan omzet produk dibanding periode yang sama sebelumnya.
class ProductChange {
  const ProductChange({
    required this.productCode,
    required this.productName,
    required this.currentRevenue,
    required this.previousRevenue,
    required this.currentQuantity,
  });

  final String productCode;
  final String productName;
  final int currentRevenue;
  final int previousRevenue;
  final int currentQuantity;

  double get changePercent =>
      (currentRevenue - previousRevenue) / previousRevenue * 100;
}

class PeriodTotals {
  const PeriodTotals({
    required this.start,
    required this.end,
    required this.revenue,
    required this.quantity,
  });

  final DateTime start;
  final DateTime end;
  final int revenue;
  final int quantity;
}

/// Bulan (tanggal 1) yang punya data penjualan, terbaru dulu.
List<DateTime> availableMonths(Iterable<SalesRecord> records) {
  final months = {
    for (final record in records) DateTime(record.date.year, record.date.month),
  }.toList()..sort((a, b) => b.compareTo(a));
  return months;
}

/// Semua angka dashboard untuk satu bulan, dihitung dari baris penjualan.
///
/// Pembanding bulan lalu memakai rentang tanggal yang sama (misalnya 1–16 Sep
/// dibanding 1–16 Agu), supaya bulan yang belum selesai tidak terlihat turun
/// drastis. Stok selalu stok terakhir (bukan per bulan), karena dipakai untuk
/// mengajukan pengiriman.
class SalesAnalytics {
  SalesAnalytics._({
    required this.month,
    required this.latestDate,
    required this.days,
    required this.revenueByStoreDay,
    required this.current,
    required this.previous,
    required this.revenueByStore,
    required this.topProducts,
    required this.risers,
    required this.fallers,
    required this.stockLevels,
  });

  factory SalesAnalytics.from(
    List<SalesRecord> allRecords, {
    required DateTime month,
    String? storeName,
    List<Shipment> shipments = const [],
  }) {
    final records = storeName == null
        ? allRecords
        : allRecords.where((r) => r.storeName == storeName).toList();
    final monthStart = DateTime(month.year, month.month);
    final stockLevels = computeStockLevels(records, shipments: shipments);

    bool inRange(DateTime date, DateTime start, DateTime end) =>
        !date.isBefore(start) && !date.isAfter(end);

    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final monthRecords = records
        .where((r) => inRange(r.date, monthStart, monthEnd))
        .toList();

    if (monthRecords.isEmpty) {
      return SalesAnalytics._(
        month: monthStart,
        latestDate: null,
        days: const [],
        revenueByStoreDay: const {},
        current: null,
        previous: null,
        revenueByStore: const [],
        topProducts: const [],
        risers: const [],
        fallers: const [],
        stockLevels: stockLevels,
      );
    }

    final latestDate = monthRecords
        .map((r) => r.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final days = [
      for (var day = 1; day <= latestDate.day; day++)
        DateTime(month.year, month.month, day),
    ];

    // Omzet per toko per hari.
    final byStoreDay = <String, Map<DateTime, int>>{};
    for (final record in monthRecords) {
      byStoreDay
          .putIfAbsent(record.storeName, () => {})
          .update(
            record.date,
            (v) => v + record.revenue,
            ifAbsent: () => record.revenue,
          );
    }

    // Bulan lalu, tanggal 1 sampai tanggal yang sama (dibatasi akhir bulan).
    final previousStart = DateTime(month.year, month.month - 1);
    final previousMonthEnd = DateTime(month.year, month.month, 0);
    final previousEnd = DateTime(
      previousStart.year,
      previousStart.month,
      latestDate.day < previousMonthEnd.day
          ? latestDate.day
          : previousMonthEnd.day,
    );
    final previousRecords = records
        .where((r) => inRange(r.date, previousStart, previousEnd))
        .toList();

    PeriodTotals totals(List<SalesRecord> rows, DateTime start, DateTime end) =>
        PeriodTotals(
          start: start,
          end: end,
          revenue: rows.fold(0, (sum, r) => sum + r.revenue),
          quantity: rows.fold(0, (sum, r) => sum + r.quantity),
        );

    final revenueByStore = <String, int>{};
    for (final record in monthRecords) {
      revenueByStore.update(
        record.storeName,
        (v) => v + record.revenue,
        ifAbsent: () => record.revenue,
      );
    }

    final currentProducts = _groupByProduct(monthRecords);
    final previousProducts = _groupByProduct(previousRecords);
    final changes = [
      for (final product in currentProducts.values)
        if ((previousProducts[product.productCode]?.revenue ?? 0) > 0)
          ProductChange(
            productCode: product.productCode,
            productName: product.productName,
            currentRevenue: product.revenue,
            previousRevenue: previousProducts[product.productCode]!.revenue,
            currentQuantity: product.quantity,
          ),
    ];

    return SalesAnalytics._(
      month: monthStart,
      latestDate: latestDate,
      days: days,
      revenueByStoreDay: {
        for (final store in kStores)
          if (byStoreDay.containsKey(store)) store: byStoreDay[store]!,
      },
      current: totals(monthRecords, monthStart, latestDate),
      previous: previousRecords.isEmpty
          ? null
          : totals(previousRecords, previousStart, previousEnd),
      revenueByStore: revenueByStore.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
      topProducts:
          (currentProducts.values.toList()
                ..sort((a, b) => b.revenue.compareTo(a.revenue)))
              .take(5)
              .toList(),
      risers:
          (changes.where((c) => c.changePercent > 0).toList()
                ..sort((a, b) => b.changePercent.compareTo(a.changePercent)))
              .take(3)
              .toList(),
      fallers:
          (changes.where((c) => c.changePercent < 0).toList()
                ..sort((a, b) => a.changePercent.compareTo(b.changePercent)))
              .take(3)
              .toList(),
      stockLevels: stockLevels,
    );
  }

  /// Bulan yang dianalisis (tanggal 1).
  final DateTime month;

  /// Tanggal data paling baru di bulan ini; null kalau belum ada data.
  final DateTime? latestDate;

  /// Tanggal 1 sampai [latestDate].
  final List<DateTime> days;

  /// Omzet per toko per hari, urutan toko mengikuti [kStores].
  final Map<String, Map<DateTime, int>> revenueByStoreDay;

  final PeriodTotals? current;
  final PeriodTotals? previous;

  /// Omzet tiap toko di bulan ini, terbesar dulu.
  final List<MapEntry<String, int>> revenueByStore;

  final List<ProductPerformance> topProducts;
  final List<ProductChange> risers;
  final List<ProductChange> fallers;

  /// Semua stok terakhir, yang paling mendesak dulu.
  final List<StockLevel> stockLevels;

  bool get hasData => latestDate != null;

  /// Stok habis & menipis (perlu segera dikirim).
  List<StockLevel> get stockAlerts => stockLevels
      .where((l) => l.status == StockStatus.out || l.status == StockStatus.low)
      .toList();

  /// Semua yang bukan "Aman", termasuk hampir menipis.
  List<StockLevel> get restockCandidates =>
      stockLevels.where((l) => l.status.needsRestock).toList();

  static Map<String, ProductPerformance> _groupByProduct(
    List<SalesRecord> records,
  ) {
    final result = <String, ProductPerformance>{};
    for (final record in records) {
      final current = result[record.productCode];
      result[record.productCode] = ProductPerformance(
        productCode: record.productCode,
        productName: record.productName,
        quantity: (current?.quantity ?? 0) + record.quantity,
        revenue: (current?.revenue ?? 0) + record.revenue,
      );
    }
    return result;
  }
}

/// Stok terakhir tiap produk per toko, diurutkan dari yang paling mendesak.
///
/// Stok = `stok_akhir` dari upload terakhir + pengiriman yang dikonfirmasi
/// SETELAH upload itu. Pengiriman yang diterima sebelum upload dianggap sudah
/// termasuk di `stok_akhir`, jadi tidak dihitung dua kali.
List<StockLevel> computeStockLevels(
  List<SalesRecord> records, {
  List<Shipment> shipments = const [],
}) {
  final byItem = <(String, String), List<SalesRecord>>{};
  for (final record in records) {
    byItem
        .putIfAbsent((record.storeName, record.productCode), () => [])
        .add(record);
  }

  final levels = <StockLevel>[];
  for (final rows in byItem.values) {
    final latest = rows.reduce((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate > 0 ? a : b;
      final aTime = a.uploadedAt ?? DateTime(0);
      final bTime = b.uploadedAt ?? DateTime(0);
      return aTime.isAfter(bTime) ? a : b;
    });
    final windowStart = DateTime(
      latest.date.year,
      latest.date.month,
      latest.date.day - (kSalesVelocityDays - 1),
    );
    final window = rows.where((r) => !r.date.isBefore(windowStart)).toList();
    final firstDate = window
        .map((r) => r.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final days = latest.date.difference(firstDate).inDays + 1;
    final average = window.fold(0, (sum, r) => sum + r.quantity) / days;

    var received = 0;
    var incoming = 0;
    for (final shipment in shipments) {
      if (shipment.storeName != latest.storeName) continue;
      final units = shipment.items
          .where((item) => item.productCode == latest.productCode)
          .fold(0, (sum, item) => sum + item.quantity);
      if (units == 0) continue;
      final receivedAt = shipment.receivedAt;
      if (shipment.status == ShipmentStatus.inTransit) {
        incoming += units;
      } else if (receivedAt != null &&
          (latest.uploadedAt == null ||
              receivedAt.isAfter(latest.uploadedAt!))) {
        received += units;
      }
    }

    final stock = latest.stockEnd + received;
    final minStock = latest.minStock;
    final daysLeft = average > 0 ? stock / average : null;
    final status = stock <= 0
        ? StockStatus.out
        : (minStock != null && stock <= minStock) ||
              (daysLeft != null && daysLeft < kLowStockDays)
        ? StockStatus.low
        : (minStock != null && stock <= minStock * 2) ||
              (daysLeft != null && daysLeft < kNearLowStockDays)
        ? StockStatus.nearLow
        : StockStatus.ok;

    levels.add(
      StockLevel(
        storeName: latest.storeName,
        productCode: latest.productCode,
        productName: latest.productName,
        category: latest.category,
        stock: stock,
        minStock: minStock,
        asOf: latest.date,
        averageDailySales: average,
        status: status,
        receivedSinceUpload: received,
        incoming: incoming,
      ),
    );
  }

  levels.sort((a, b) {
    final byStatus = a.status.index.compareTo(b.status.index);
    if (byStatus != 0) return byStatus;
    final aDays = a.daysLeft ?? double.infinity;
    final bDays = b.daysLeft ?? double.infinity;
    final byDays = aDays.compareTo(bDays);
    if (byDays != 0) return byDays;
    final byStore = kStores
        .indexOf(a.storeName)
        .compareTo(kStores.indexOf(b.storeName));
    return byStore != 0 ? byStore : a.productName.compareTo(b.productName);
  });
  return levels;
}
