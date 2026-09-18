import 'dart:math';

import '../models/sales_record.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import 'sales_analytics.dart';

// Aturan-aturan (if-else) untuk membaca data penjualan: tren naik/turun,
// perkiraan kebutuhan bulan depan, peringatan stok, barang nganggur, dan
// rekomendasi pindah barang antar toko. Tidak memakai AI, jadi hasilnya
// selalu sama untuk data yang sama dan bisa dijelaskan.

/// Minimal unit terjual supaya tren produk dihitung (biar 1–2 unit tidak
/// terbaca "naik 100%").
const kInsightMinUnits = 3;

/// Batas persen perubahan.
const kSpikeGrowth = 0.5;
const kUpGrowth = 0.2;
const kSharpDrop = 0.5;
const kDrop = 0.2;

/// Batas tren total per toko.
const kStoreTrend = 0.15;

/// Barang dianggap mengendap kalau tidak terjual sekian hari.
const kIdleDays = 14;

/// Stok minimal yang dianggap "numpuk" untuk direkomendasikan dipindah.
const kTransferMinStock = 4;

enum InsightKind {
  stockOut,
  stockLow,
  transfer,
  trendDown,
  trendUp,
  demand,
  idle,
  forecast,
}

enum InsightTone { positive, negative, warning, info }

/// Satu baris insight yang tampil di app & widget.
class Insight {
  const Insight({
    required this.kind,
    required this.emoji,
    required this.title,
    required this.detail,
    required this.tone,
    required this.priority,
    this.storeName,
    this.productCode,
    this.shortText,
  });

  final InsightKind kind;
  final String emoji;
  final String title;
  final String detail;
  final InsightTone tone;

  /// Makin kecil makin penting.
  final int priority;
  final String? storeName;
  final String? productCode;

  /// Versi pendek untuk widget home screen.
  final String? shortText;

  String get widgetText => shortText ?? title;
}

/// Ringkasan satu produk di satu toko, dipakai semua aturan.
class _ProductStat {
  _ProductStat({
    required this.storeName,
    required this.productCode,
    required this.productName,
  });

  final String storeName;
  final String productCode;
  final String productName;

  int unitsThisMonth = 0;

  /// Bulan lalu, seluruh bulan (untuk perkiraan kebutuhan).
  int unitsLastMonth = 0;

  /// Bulan lalu, hanya sampai tanggal yang sama dengan data bulan ini
  /// (untuk perbandingan naik/turun yang adil).
  int unitsLastMonthSameRange = 0;
  int unitsTwoMonthsAgo = 0;
  int revenueThisMonth = 0;
  int revenueLastMonth = 0;
  DateTime? lastSoldAt;

  StockLevel? stock;

  int get stockNow => stock?.stock ?? 0;
  int get minStock => stock?.minStock ?? 0;
  int get incoming => stock?.incoming ?? 0;
}

/// Semua insight untuk [month], diurutkan dari yang paling penting.
///
/// [records] sebaiknya berisi minimal 3 bulan data supaya perkiraan kebutuhan
/// lebih stabil. [storeName] null = semua toko.
List<Insight> buildInsights({
  required List<SalesRecord> records,
  required List<StockLevel> stockLevels,
  required DateTime month,
  String? storeName,
}) {
  if (records.isEmpty) return const [];

  final monthStart = DateTime(month.year, month.month);
  final lastMonthStart = DateTime(month.year, month.month - 1);
  final twoMonthsAgoStart = DateTime(month.year, month.month - 2);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

  // Tanggal data terakhir di bulan ini, untuk menghitung "baru berjalan
  // berapa hari" dan barang nganggur.
  DateTime? latestDate;
  for (final record in records) {
    if (record.date.year == monthStart.year &&
        record.date.month == monthStart.month &&
        (latestDate == null || record.date.isAfter(latestDate))) {
      latestDate = record.date;
    }
  }
  if (latestDate == null) return const [];
  final elapsedDays = latestDate.day;

  final stats = <String, _ProductStat>{};
  _ProductStat statFor(String store, String code, String name) =>
      stats.putIfAbsent(
        '$store|$code',
        () => _ProductStat(
          storeName: store,
          productCode: code,
          productName: name,
        ),
      );

  bool sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  for (final record in records) {
    final stat = statFor(
      record.storeName,
      record.productCode,
      record.productName,
    );
    if (sameMonth(record.date, monthStart)) {
      stat.unitsThisMonth += record.quantity;
      stat.revenueThisMonth += record.revenue;
    } else if (sameMonth(record.date, lastMonthStart)) {
      stat.unitsLastMonth += record.quantity;
      stat.revenueLastMonth += record.revenue;
      if (record.date.day <= elapsedDays) {
        stat.unitsLastMonthSameRange += record.quantity;
      }
    } else if (sameMonth(record.date, twoMonthsAgoStart)) {
      stat.unitsTwoMonthsAgo += record.quantity;
    }
    if (record.quantity > 0 &&
        (stat.lastSoldAt == null || record.date.isAfter(stat.lastSoldAt!))) {
      stat.lastSoldAt = record.date;
    }
  }
  for (final level in stockLevels) {
    stats['${level.storeName}|${level.productCode}']?.stock = level;
  }

  final selected = [
    for (final stat in stats.values)
      if (storeName == null || stat.storeName == storeName) stat,
  ];
  final insights = <Insight>[
    ..._stockInsights(selected, latestDate),
    ..._transferInsights(
      stats.values.toList(),
      storeName: storeName,
      elapsedDays: elapsedDays,
      daysInMonth: daysInMonth,
      latestDate: latestDate,
    ),
    ..._trendInsights(selected, lastMonthStart),
    ..._idleInsights(selected, latestDate),
    ..._forecastInsights(
      selected,
      month: monthStart,
      elapsedDays: elapsedDays,
      daysInMonth: daysInMonth,
    ),
    ..._storeDemandInsights(selected, lastMonthStart, storeName: storeName),
  ];

  insights.sort((a, b) => a.priority.compareTo(b.priority));
  return insights;
}

/// Stok habis / menipis.
List<Insight> _stockInsights(List<_ProductStat> stats, DateTime latestDate) {
  final insights = <Insight>[];
  for (final stat in stats) {
    final level = stat.stock;
    if (level == null) continue;

    final incoming = level.incoming > 0
        ? ' ${level.incoming} unit sedang dikirim.'
        : ' Saran kirim ${level.suggestedRestock} unit.';

    if (level.status == StockStatus.out) {
      insights.add(
        Insight(
          kind: InsightKind.stockOut,
          emoji: '🛑',
          title: '${stat.productName} habis di ${stat.storeName}',
          detail:
              'Stok 0 sejak ${formatDayMonth(level.asOf)}. Bulan ini sudah '
              'terjual ${stat.unitsThisMonth} unit, jadi jangan sampai kosong '
              'lama.$incoming',
          tone: InsightTone.negative,
          priority: 0,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} habis · ${stat.storeName}',
        ),
      );
    } else if (level.status == StockStatus.low) {
      final daysLeft = level.daysLeft;
      insights.add(
        Insight(
          kind: InsightKind.stockLow,
          emoji: '⚠️',
          title: '${stat.productName} menipis di ${stat.storeName}',
          detail:
              'Sisa ${level.stock} unit'
              '${level.minStock == null ? '' : ' (min ${level.minStock})'}'
              '${daysLeft == null ? '' : ', kira-kira habis ${daysLeft.floor()} hari lagi'}'
              '.$incoming',
          tone: InsightTone.warning,
          priority: 2,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText:
              '${stat.productName} tinggal ${level.stock} · ${stat.storeName}',
        ),
      );
    }
  }
  return insights;
}

/// Barang numpuk di satu toko, tapi laris & tipis di toko lain → sarankan
/// dipindah.
List<Insight> _transferInsights(
  List<_ProductStat> allStats, {
  required String? storeName,
  required int elapsedDays,
  required int daysInMonth,
  required DateTime latestDate,
}) {
  final byProduct = <String, List<_ProductStat>>{};
  for (final stat in allStats) {
    byProduct.putIfAbsent(stat.productCode, () => []).add(stat);
  }

  final insights = <Insight>[];
  for (final group in byProduct.values) {
    if (group.length < 2) continue;

    for (final source in group) {
      // Calon asal: stok menumpuk dan tidak ada penjualan bulan ini.
      final idleDays = source.lastSoldAt == null
          ? null
          : latestDate.difference(source.lastSoldAt!).inDays;
      final isIdle =
          source.unitsThisMonth == 0 &&
          source.stockNow >= max(kTransferMinStock, source.minStock * 2) &&
          (idleDays == null || idleDays >= kIdleDays);
      if (!isIdle) continue;

      for (final target in group) {
        if (target.storeName == source.storeName) continue;
        // Calon tujuan: laris tapi stoknya tipis/habis.
        final needsStock =
            target.unitsThisMonth > 0 &&
            (target.stock?.status == StockStatus.out ||
                target.stock?.status == StockStatus.low);
        if (!needsStock) continue;

        final projected = _projectNextMonth(target, elapsedDays, daysInMonth);
        final need = max(
          projected + target.minStock - target.stockNow - target.incoming,
          1,
        );
        final surplus = source.stockNow - source.minStock;
        final quantity = min(surplus, need);
        if (quantity < 1) continue;

        // Kalau sedang difilter per toko, tampilkan yang menyangkut toko itu.
        if (storeName != null &&
            storeName != source.storeName &&
            storeName != target.storeName) {
          continue;
        }

        insights.add(
          Insight(
            kind: InsightKind.transfer,
            emoji: '🔁',
            title:
                'Pindahkan $quantity ${source.productName} '
                '${source.storeName} → ${target.storeName}',
            detail:
                '${source.storeName} punya ${source.stockNow} unit tapi belum '
                'terjual bulan ini'
                '${idleDays == null ? '' : ' ($idleDays hari nganggur)'}'
                '. ${target.storeName} sudah laku ${target.unitsThisMonth} unit '
                'dan stoknya ${target.stockNow}. Daripada mengendap, geser saja.',
            tone: InsightTone.info,
            priority: 1,
            storeName: target.storeName,
            productCode: source.productCode,
            shortText:
                'Pindah $quantity ${source.productName} ke ${target.storeName}',
          ),
        );
      }
    }
  }
  return insights;
}

/// Naik / turun dibanding bulan lalu.
List<Insight> _trendInsights(List<_ProductStat> stats, DateTime lastMonth) {
  final lastMonthLabel = formatMonthYear(lastMonth);
  final insights = <Insight>[];

  for (final stat in stats) {
    final now = stat.unitsThisMonth;
    final before = stat.unitsLastMonthSameRange;
    final revenueNow = formatCompactRupiah(stat.revenueThisMonth);

    // Aturan: butuh volume yang cukup supaya persennya berarti.
    if (before == 0 && now >= kInsightMinUnits) {
      insights.add(
        Insight(
          kind: InsightKind.trendUp,
          emoji: '🌱',
          title: '${stat.productName} mulai laku di ${stat.storeName}',
          detail:
              'Bulan lalu belum ada yang terjual, sekarang sudah $now unit '
              '($revenueNow). Pantau stoknya.',
          tone: InsightTone.positive,
          priority: 7,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} mulai laku',
        ),
      );
      continue;
    }
    if (now == 0 && before >= kInsightMinUnits) {
      insights.add(
        Insight(
          kind: InsightKind.trendDown,
          emoji: '🥶',
          title: '${stat.productName} berhenti laku di ${stat.storeName}',
          detail:
              'Bulan lalu $before unit, bulan ini belum ada yang terjual. '
              'Cek harga, display, atau stoknya.',
          tone: InsightTone.negative,
          priority: 4,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} berhenti laku',
        ),
      );
      continue;
    }
    if (before < kInsightMinUnits || now < 1) continue;

    final change = (now - before) / before;
    final percent = formatPercent(change.abs() * 100);
    if (change >= kSpikeGrowth) {
      insights.add(
        Insight(
          kind: InsightKind.trendUp,
          emoji: '🚀',
          title: '${stat.productName} melesat $percent',
          detail:
              '${stat.storeName} · $before → $now unit dibanding $lastMonthLabel '
              '($revenueNow). Tambah stok biar nggak kehabisan.',
          tone: InsightTone.positive,
          priority: 6,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} +$percent',
        ),
      );
    } else if (change >= kUpGrowth) {
      insights.add(
        Insight(
          kind: InsightKind.trendUp,
          emoji: '📈',
          title: '${stat.productName} naik $percent',
          detail:
              '${stat.storeName} · $before → $now unit dibanding $lastMonthLabel '
              '($revenueNow).',
          tone: InsightTone.positive,
          priority: 8,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} +$percent',
        ),
      );
    } else if (change <= -kSharpDrop) {
      insights.add(
        Insight(
          kind: InsightKind.trendDown,
          emoji: '📉',
          title: '${stat.productName} turun tajam $percent',
          detail:
              '${stat.storeName} · $before → $now unit dibanding $lastMonthLabel. '
              'Perlu dicek: stok kosong, harga, atau memang sepi?',
          tone: InsightTone.negative,
          priority: 3,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} −$percent',
        ),
      );
    } else if (change <= -kDrop) {
      insights.add(
        Insight(
          kind: InsightKind.trendDown,
          emoji: '🔻',
          title: '${stat.productName} turun $percent',
          detail:
              '${stat.storeName} · $before → $now unit dibanding $lastMonthLabel.',
          tone: InsightTone.negative,
          priority: 5,
          storeName: stat.storeName,
          productCode: stat.productCode,
          shortText: '${stat.productName} −$percent',
        ),
      );
    }
  }
  return insights;
}

/// Stok nganggur: ada barang, tapi lama tidak terjual.
List<Insight> _idleInsights(List<_ProductStat> stats, DateTime latestDate) {
  final insights = <Insight>[];
  for (final stat in stats) {
    if (stat.stockNow < kTransferMinStock || stat.unitsThisMonth > 0) continue;
    final lastSold = stat.lastSoldAt;
    final idleDays = lastSold == null
        ? null
        : latestDate.difference(lastSold).inDays;
    if (idleDays != null && idleDays < kIdleDays) continue;

    insights.add(
      Insight(
        kind: InsightKind.idle,
        emoji: '😴',
        title: '${stat.productName} mengendap di ${stat.storeName}',
        detail: lastSold == null
            ? 'Stok ${stat.stockNow} unit dan belum pernah tercatat terjual.'
            : 'Stok ${stat.stockNow} unit, terakhir laku '
                  '${formatDayMonth(lastSold)} ($idleDays hari lalu).',
        tone: InsightTone.warning,
        priority: 9,
        storeName: stat.storeName,
        productCode: stat.productCode,
        shortText: '${stat.productName} nganggur ${stat.stockNow} unit',
      ),
    );
  }
  return insights;
}

/// Perkiraan kebutuhan bulan depan (rata-rata 3 bulan + arah tren).
List<Insight> _forecastInsights(
  List<_ProductStat> stats, {
  required DateTime month,
  required int elapsedDays,
  required int daysInMonth,
}) {
  final nextMonthLabel = formatMonthYear(DateTime(month.year, month.month + 1));
  final insights = <Insight>[];

  final monthLabel = formatMonthYear(month);
  final isPartialMonth = elapsedDays < daysInMonth;

  for (final stat in stats) {
    final projected = _projectNextMonth(stat, elapsedDays, daysInMonth);
    if (projected < 1) continue;

    final need = projected + stat.minStock - stat.stockNow - stat.incoming;
    final history = [
      if (stat.unitsTwoMonthsAgo > 0) '${stat.unitsTwoMonthsAgo}',
      if (stat.unitsLastMonth > 0) '${stat.unitsLastMonth}',
      '${stat.unitsThisMonth}',
    ].join(' → ');
    final partialNote = isPartialMonth
        ? ' ($monthLabel baru $elapsedDays hari)'
        : '';

    insights.add(
      Insight(
        kind: InsightKind.forecast,
        emoji: '🔮',
        title:
            '$nextMonthLabel: ±$projected ${stat.productName} '
            'di ${stat.storeName}',
        detail: need > 0
            ? 'Riwayat $history unit$partialNote. '
                  'Stok sekarang ${stat.stockNow}'
                  '${stat.incoming > 0 ? ' (+${stat.incoming} dikirim)' : ''}, '
                  'siapkan ±$need unit lagi.'
            : 'Riwayat $history unit$partialNote. '
                  'Stok sekarang ${stat.stockNow}, sudah cukup.',
        tone: need > 0 ? InsightTone.warning : InsightTone.info,
        priority: need > 0 ? 10 : 12,
        storeName: stat.storeName,
        productCode: stat.productCode,
        shortText: need > 0
            ? 'Siapkan $need ${stat.productName} · ${stat.storeName}'
            : '${stat.productName} stok cukup',
      ),
    );
  }
  return insights;
}

/// Tren total per toko: makin laris atau agak sepi.
List<Insight> _storeDemandInsights(
  List<_ProductStat> stats,
  DateTime lastMonth, {
  required String? storeName,
}) {
  final now = <String, int>{};
  final before = <String, int>{};
  for (final stat in stats) {
    now.update(
      stat.storeName,
      (v) => v + stat.unitsThisMonth,
      ifAbsent: () => stat.unitsThisMonth,
    );
    before.update(
      stat.storeName,
      (v) => v + stat.unitsLastMonthSameRange,
      ifAbsent: () => stat.unitsLastMonthSameRange,
    );
  }

  final lastMonthLabel = formatMonthYear(lastMonth);
  final insights = <Insight>[];
  for (final store in now.keys) {
    final currentUnits = now[store] ?? 0;
    final previousUnits = before[store] ?? 0;
    if (previousUnits < kInsightMinUnits) continue;

    final change = (currentUnits - previousUnits) / previousUnits;
    if (change.abs() < kStoreTrend) continue;
    final percent = formatPercent(change.abs() * 100);
    final isUp = change > 0;

    insights.add(
      Insight(
        kind: InsightKind.demand,
        emoji: isUp ? '🔥' : '🧊',
        title: isUp
            ? '$store makin laris $percent'
            : '$store agak sepi $percent',
        detail:
            'Total $previousUnits → $currentUnits unit dibanding $lastMonthLabel.'
            '${isUp ? ' Pastikan stok mengikuti.' : ' Coba cek stok & promo.'}',
        tone: isUp ? InsightTone.positive : InsightTone.negative,
        priority: isUp ? 6 : 4,
        storeName: store,
        shortText: isUp ? '$store +$percent' : '$store −$percent',
      ),
    );
  }
  return insights;
}

/// Perkiraan unit bulan depan: bulan ini (disetahunkan ke bulan penuh) 50%,
/// bulan lalu 30%, dua bulan lalu 20%. Bobot dinormalkan kalau riwayatnya
/// belum lengkap.
int _projectNextMonth(_ProductStat stat, int elapsedDays, int daysInMonth) {
  final coverage = elapsedDays <= 0 ? 1.0 : elapsedDays / daysInMonth;
  final fullMonthNow = coverage >= 1
      ? stat.unitsThisMonth.toDouble()
      : stat.unitsThisMonth / coverage;

  var weighted = fullMonthNow * 0.5;
  var weight = 0.5;
  if (stat.unitsLastMonth > 0) {
    weighted += stat.unitsLastMonth * 0.3;
    weight += 0.3;
  }
  if (stat.unitsTwoMonthsAgo > 0) {
    weighted += stat.unitsTwoMonthsAgo * 0.2;
    weight += 0.2;
  }
  final average = weighted / weight;

  // Arah tren ikut memengaruhi, tapi dibatasi 0,8–1,3 supaya tidak liar.
  var factor = 1.0;
  if (stat.unitsLastMonth > 0) {
    factor = (fullMonthNow / stat.unitsLastMonth).clamp(0.8, 1.3);
  }
  return (average * factor).round();
}
