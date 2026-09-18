import 'dart:math';

import '../models/sales_record.dart';
import 'insights_engine.dart';
import '../utils/currency.dart';
import '../utils/date_format.dart';
import 'sales_analytics.dart';
import 'stores.dart';

/// Kategori di widget: iPhone, MacBook, dan sisanya digabung jadi "Lainnya".
const kWidgetCategories = ['iPhone', 'MacBook', 'Lainnya'];

/// Label pilihan "semua toko" di widget.
const kWidgetAllStores = 'Semua';

String widgetCategoryFor(String? category) => switch (category) {
  'iPhone' => 'iPhone',
  'MacBook' => 'MacBook',
  _ => 'Lainnya',
};

/// Ringkasan omzet per kategori untuk widget home screen, bulan terbaru yang
/// punya data. Formatnya JSON sederhana supaya mudah dibaca Swift:
///
/// ```json
/// {
///   "month": "September 2026",
///   "days": ["14", "15", "16"],
///   "stores": [
///     {"name": "Semua", "total": "Rp4 M",
///      "items": [{"category": "iPhone", "revenue": 123, "label": "Rp1,2 M", "units": 9}],
///      "series": [{"category": "iPhone", "values": [40, 55, 28]}],
///      "insights": [{"emoji": "🛑", "text": "iPhone 17 habis", "tone": "negative"}]}
///   ]
/// }
/// ```
///
/// `insights` = catatan otomatis teratas untuk toko itu (teks pendek).
/// `days` = tanggal pertama s/d terakhir yang punya data di bulan itu.
/// `series` = omzet harian per kategori, sejajar dengan `days` (untuk grafik
/// garis naik-turun). `stores` selalu berisi "Semua" lalu tiap toko di
/// [kStores]; `items` & `series` selalu berisi ketiga [kWidgetCategories].
Map<String, Object?> buildWidgetSalesSummary(
  List<SalesRecord> records, {
  List<StockLevel> stockLevels = const [],
  int maxInsights = 4,
}) {
  final months = availableMonths(records);
  if (months.isEmpty) {
    return {'month': null, 'stores': <Object?>[]};
  }
  final month = months.first;
  final monthRecords = records
      .where((r) => r.date.year == month.year && r.date.month == month.month)
      .toList();
  final firstDay = monthRecords.map((r) => r.date.day).reduce(min);
  final lastDay = monthRecords.map((r) => r.date.day).reduce(max);

  List<Map<String, Object?>> insightsFor(String? store) {
    final insights = buildInsights(
      records: records,
      stockLevels: stockLevels,
      month: month,
      storeName: store,
    );
    return [
      for (final insight in insights.take(maxInsights))
        {
          'emoji': insight.emoji,
          'text': insight.widgetText,
          'tone': insight.tone.name,
        },
    ];
  }

  Map<String, Object?> storeSummary(
    String name,
    Iterable<SalesRecord> rows, {
    String? insightStore,
  }) {
    final revenue = {for (final c in kWidgetCategories) c: 0};
    final units = {for (final c in kWidgetCategories) c: 0};
    final daily = {
      for (final c in kWidgetCategories)
        c: List.filled(lastDay - firstDay + 1, 0),
    };
    for (final row in rows) {
      final category = widgetCategoryFor(row.category);
      revenue[category] = revenue[category]! + row.revenue;
      units[category] = units[category]! + row.quantity;
      daily[category]![row.date.day - firstDay] += row.revenue;
    }
    final total = revenue.values.fold(0, (sum, v) => sum + v);
    return {
      'name': name,
      'total': formatCompactRupiah(total),
      'items': [
        for (final category in kWidgetCategories)
          {
            'category': category,
            'revenue': revenue[category],
            'label': formatCompactRupiah(revenue[category]!),
            'units': units[category],
          },
      ],
      'series': [
        for (final category in kWidgetCategories)
          {'category': category, 'values': daily[category]},
      ],
      'insights': insightsFor(insightStore),
    };
  }

  return {
    'month': formatMonthYear(month),
    'days': [for (var day = firstDay; day <= lastDay; day++) '$day'],
    'stores': [
      storeSummary(kWidgetAllStores, monthRecords),
      for (final store in kStores)
        storeSummary(
          store,
          monthRecords.where((r) => r.storeName == store),
          insightStore: store,
        ),
    ],
  };
}
