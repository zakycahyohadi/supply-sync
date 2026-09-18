import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/data/ai/forecast_payload.dart';
import 'package:supply_sync/data/ai/forecast_widget_insights.dart';
import 'package:supply_sync/data/insights_engine.dart';
import 'package:supply_sync/data/sales_analytics.dart';
import 'package:supply_sync/data/sample_sales_data.dart';
import 'package:supply_sync/data/widget_sales_summary.dart';
import 'package:supply_sync/models/ai_forecast.dart';
import 'package:supply_sync/models/sales_upload.dart';

import 'support/fake_ai_forecast_repository.dart';

void main() {
  final now = DateTime(2026, 9, 18);
  final sample = buildSampleSalesData(now);
  final records = latestRecords(sample.uploads);
  final month = availableMonths(records).first;
  final analytics = SalesAnalytics.from(
    records,
    month: month,
    shipments: sample.shipments,
  );
  final ruleInsights = buildInsights(
    records: records,
    stockLevels: analytics.stockLevels,
    month: month,
  );

  group('buildForecastPayload', () {
    final payload = buildForecastPayload(
      analytics: analytics,
      ruleInsights: ruleInsights,
    );

    test('berisi angka yang sudah dihitung aplikasi, bukan baris mentah', () {
      expect(payload['bulan'], isA<String>());
      expect(payload['bulan_ini'], isA<Map<String, Object?>>());
      expect(payload['data_sampai_tanggal'], analytics.latestDate?.day);
      expect(payload['hari_dalam_bulan'], 30);
      expect(payload['omzet_per_toko'], isNotEmpty);
      // Tidak ada baris penjualan satu per satu di payload.
      expect(payload.keys, isNot(contains('rows')));
      expect(payload.keys, isNot(contains('records')));
    });

    test('tetap ringkas walau datanya banyak', () {
      expect(records.length, greaterThan(100));
      expect(
        (payload['produk_terlaris']! as List).length,
        lessThanOrEqualTo(kPayloadListLimit),
      );
      expect(
        (payload['stok_perlu_perhatian']! as List).length,
        lessThanOrEqualTo(kPayloadListLimit),
      );
      expect(
        (payload['catatan_aplikasi']! as List).length,
        lessThanOrEqualTo(8),
      );
    });
  });

  group('forecastFingerprint', () {
    test('payload yang sama menghasilkan sidik jari yang sama', () {
      final a = buildForecastPayload(
        analytics: analytics,
        ruleInsights: ruleInsights,
      );
      final b = buildForecastPayload(
        analytics: analytics,
        ruleInsights: ruleInsights,
      );
      expect(forecastFingerprint(a), forecastFingerprint(b));
      expect(forecastFingerprint(a), hasLength(16));
    });

    test('data berubah, sidik jari berubah', () {
      final a = buildForecastPayload(
        analytics: analytics,
        ruleInsights: ruleInsights,
      );
      final b = buildForecastPayload(
        analytics: analytics,
        ruleInsights: ruleInsights,
        storeName: 'Toko 1',
      );
      expect(forecastFingerprint(a), isNot(forecastFingerprint(b)));
    });
  });

  group('AiForecast.fromJson', () {
    test('membaca balasan yang lengkap', () {
      expect(sampleForecast.summary, startsWith('Omzet bulan ini'));
      expect(
        sampleForecast.downTrends.single.title,
        'MacBook Air M4 turun 40%',
      );
      expect(sampleForecast.upTrends.single.direction, AiTrendDirection.up);
      expect(sampleForecast.outlook.revenue, 268000000);
      expect(sampleForecast.outlook.confidence, AiConfidence.medium);
      expect(sampleForecast.restocks.single.quantity, 12);
      expect(sampleForecast.recommendations, hasLength(1));
      expect(sampleForecast.isEmpty, isFalse);
    });

    test('balasan rusak tidak bikin crash', () {
      final forecast = AiForecast.fromJson({
        'ringkasan': 'Ada data.',
        'tren': 'bukan list',
        'forecast_bulan_depan': {
          'omzet_perkiraan': '123',
          'keyakinan': 'ngawur',
        },
        'produk_perlu_dikirim': [
          {'produk': 'iPhone', 'jumlah_saran': 3.7},
          'bukan objek',
        ],
        'rekomendasi': ['  ', 'Kirim barang.', 42],
      });

      expect(forecast.trends, isEmpty);
      expect(forecast.outlook.revenue, 123);
      // Nilai enum yang tidak dikenal jatuh ke yang paling aman.
      expect(forecast.outlook.confidence, AiConfidence.low);
      expect(forecast.restocks.single.quantity, 4);
      expect(forecast.recommendations, ['Kirim barang.']);
    });

    test('balasan kosong ditandai isEmpty', () {
      expect(AiForecast.fromJson(const {}).isEmpty, isTrue);
    });

    test('bolak-balik lewat JSON tidak kehilangan isi (untuk cache)', () {
      final restored = AiForecast.fromJson(sampleForecast.toJson());
      expect(restored.summary, sampleForecast.summary);
      expect(restored.trends.length, sampleForecast.trends.length);
      expect(restored.outlook.revenue, sampleForecast.outlook.revenue);
      expect(restored.model, 'gemini-3.8-flash');
      expect(
        restored.generatedAt.toIso8601String(),
        sampleForecast.generatedAt.toIso8601String(),
      );
    });
  });

  group('aiWidgetInsights', () {
    test('yang turun dulu, lalu yang perlu disiapkan', () {
      final lines = aiWidgetInsights(sampleForecast);

      expect(lines.map((line) => line['emoji']), ['📉', '📦', '🔮', '📈']);
      expect(lines.first['text'], 'MacBook Air M4 turun 40%');
      expect(lines.first['tone'], 'negative');
      expect(lines[1]['text'], 'Siapkan 12 iPhone 17 Pro Max · Toko 1');
    });

    test('teks panjang dipotong supaya muat di widget', () {
      final forecast = AiForecast.fromJson({
        'tren': [
          {
            'arah': 'turun',
            'judul':
                'MacBook Air M4 dan MacBook Pro 14 inci sama-sama turun tajam',
            'alasan': '',
          },
        ],
      });

      final text = aiWidgetInsights(forecast).single['text']! as String;
      expect(text.length, lessThanOrEqualTo(kWidgetInsightMaxLength));
      expect(text, endsWith('…'));
    });

    test('dibatasi jumlah maksimum', () {
      expect(aiWidgetInsights(sampleForecast, max: 2), hasLength(2));
    });
  });

  group('buildWidgetSalesSummary dengan AI', () {
    List<Object?> insightsOf(Map<String, Object?> summary, int storeIndex) =>
        ((summary['stores']! as List)[storeIndex] as Map)['insights'] as List;

    test('baris AI ditaruh paling atas di "Semua"', () {
      final summary = buildWidgetSalesSummary(
        records,
        stockLevels: analytics.stockLevels,
        aiInsights: aiWidgetInsights(sampleForecast),
      );

      final all = insightsOf(summary, 0);
      expect(all, hasLength(4));
      expect((all.first! as Map)['text'], 'MacBook Air M4 turun 40%');
    });

    test('per toko tetap catatan otomatis', () {
      final summary = buildWidgetSalesSummary(
        records,
        stockLevels: analytics.stockLevels,
        aiInsights: aiWidgetInsights(sampleForecast),
      );

      final toko1 = insightsOf(summary, 1);
      expect(
        toko1.map((i) => (i! as Map)['text']),
        isNot(contains('MacBook Air M4 turun 40%')),
      );
    });

    test('tanpa AI, isinya persis seperti sebelumnya', () {
      final withAi = buildWidgetSalesSummary(
        records,
        stockLevels: analytics.stockLevels,
      );
      expect(insightsOf(withAi, 0), isNotEmpty);
    });
  });
}
