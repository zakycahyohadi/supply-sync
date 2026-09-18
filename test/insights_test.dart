import 'package:flutter_test/flutter_test.dart';
import 'package:supply_sync/data/insights_engine.dart';
import 'package:supply_sync/data/sales_analytics.dart';
import 'package:supply_sync/data/widget_sales_summary.dart';
import 'package:supply_sync/models/sales_record.dart';

/// Baris penjualan harian sebuah produk di satu toko selama [days] hari
/// pertama bulan [month], masing-masing [perDay] unit.
List<SalesRecord> rows({
  required String store,
  required String code,
  required DateTime month,
  required int days,
  required int perDay,
  required int stock,
  int price = 1000000,
  int minStock = 3,
  String category = 'iPhone',
}) {
  return [
    for (var day = 1; day <= days; day++)
      SalesRecord(
        storeName: store,
        date: DateTime(month.year, month.month, day),
        productCode: code,
        productName: code,
        category: category,
        quantity: perDay,
        unitPrice: price,
        stockEnd: stock,
        minStock: minStock,
      ),
  ];
}

final _september = DateTime(2026, 9);
final _august = DateTime(2026, 8);
final _july = DateTime(2026, 7);

List<Insight> insightsFor(List<SalesRecord> records, {String? storeName}) =>
    buildInsights(
      records: records,
      stockLevels: computeStockLevels(records),
      month: _september,
      storeName: storeName,
    );

Insight? firstOfKind(List<Insight> insights, InsightKind kind, [String? code]) {
  for (final insight in insights) {
    if (insight.kind == kind && (code == null || insight.productCode == code)) {
      return insight;
    }
  }
  return null;
}

void main() {
  group('tren naik & turun', () {
    test('melesat, naik, turun tajam, turun, mulai laku, berhenti laku', () {
      final records = [
        // MELESAT: 30 → 60 unit (+100%).
        ...rows(
          store: 'Toko 1',
          code: 'MELESAT',
          month: _august,
          days: 30,
          perDay: 1,
          stock: 40,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'MELESAT',
          month: _september,
          days: 30,
          perDay: 2,
          stock: 40,
        ),
        // NAIK: 30 → 39 unit (+30%).
        ...rows(
          store: 'Toko 1',
          code: 'NAIK',
          month: _august,
          days: 30,
          perDay: 1,
          stock: 60,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'NAIK',
          month: _september,
          days: 13,
          perDay: 3,
          stock: 60,
        ),
        // JATUH: 60 → 15 unit (−75%).
        ...rows(
          store: 'Toko 1',
          code: 'JATUH',
          month: _august,
          days: 30,
          perDay: 2,
          stock: 80,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'JATUH',
          month: _september,
          days: 15,
          perDay: 1,
          stock: 80,
        ),
        // TURUN: 30 → 21 unit (−30%).
        ...rows(
          store: 'Toko 1',
          code: 'TURUN',
          month: _august,
          days: 30,
          perDay: 1,
          stock: 70,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'TURUN',
          month: _september,
          days: 21,
          perDay: 1,
          stock: 70,
        ),
        // BARU: belum ada di Agustus.
        ...rows(
          store: 'Toko 1',
          code: 'BARU',
          month: _september,
          days: 10,
          perDay: 1,
          stock: 50,
        ),
        // MANDEK: laku di Agustus, 0 di September.
        ...rows(
          store: 'Toko 1',
          code: 'MANDEK',
          month: _august,
          days: 20,
          perDay: 1,
          stock: 30,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'MANDEK',
          month: _september,
          days: 30,
          perDay: 0,
          stock: 30,
        ),
      ];
      final insights = insightsFor(records);

      final melesat = firstOfKind(insights, InsightKind.trendUp, 'MELESAT')!;
      expect(melesat.emoji, '🚀');
      expect(melesat.title, 'MELESAT melesat 100%');
      expect(melesat.detail, contains('30 → 60 unit dibanding Agustus 2026'));
      expect(melesat.tone, InsightTone.positive);

      final naik = firstOfKind(insights, InsightKind.trendUp, 'NAIK')!;
      expect(naik.emoji, '📈');
      expect(naik.title, 'NAIK naik 30%');

      final jatuh = firstOfKind(insights, InsightKind.trendDown, 'JATUH')!;
      expect(jatuh.emoji, '📉');
      expect(jatuh.title, 'JATUH turun tajam 75%');
      expect(jatuh.tone, InsightTone.negative);

      final turun = firstOfKind(insights, InsightKind.trendDown, 'TURUN')!;
      expect(turun.emoji, '🔻');
      expect(turun.title, 'TURUN turun 30%');

      final baru = firstOfKind(insights, InsightKind.trendUp, 'BARU')!;
      expect(baru.emoji, '🌱');
      expect(baru.title, contains('mulai laku di Toko 1'));

      final mandek = firstOfKind(insights, InsightKind.trendDown, 'MANDEK')!;
      expect(mandek.emoji, '🥶');
      expect(mandek.title, contains('berhenti laku'));
    });

    test('bulan berjalan yang belum penuh dibanding tanggal yang sama', () {
      // Agustus 31 hari x 2 = 62 unit, September baru 13 hari x 2 = 26 unit.
      // Dibanding 1-13 Agustus (26 unit) hasilnya sama, jadi tidak ada
      // laporan naik/turun.
      final records = [
        ...rows(
          store: 'Toko 1',
          code: 'ADIL',
          month: _august,
          days: 31,
          perDay: 2,
          stock: 90,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'ADIL',
          month: _september,
          days: 13,
          perDay: 2,
          stock: 90,
        ),
      ];
      final insights = insightsFor(records);

      expect(firstOfKind(insights, InsightKind.trendDown, 'ADIL'), isNull);
      expect(firstOfKind(insights, InsightKind.trendUp, 'ADIL'), isNull);
      expect(
        insights.where((i) => i.kind == InsightKind.demand),
        isEmpty,
        reason: 'total toko juga dibandingkan dengan rentang yang sama',
      );
    });

    test('perubahan kecil & volume kecil tidak dilaporkan', () {
      final records = [
        // Cuma −10%.
        ...rows(
          store: 'Toko 1',
          code: 'STABIL',
          month: _august,
          days: 30,
          perDay: 1,
          stock: 40,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'STABIL',
          month: _september,
          days: 27,
          perDay: 1,
          stock: 40,
        ),
        // Volume kecil: 2 → 1 unit.
        ...rows(
          store: 'Toko 1',
          code: 'KECIL',
          month: _august,
          days: 2,
          perDay: 1,
          stock: 40,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'KECIL',
          month: _september,
          days: 1,
          perDay: 1,
          stock: 40,
        ),
      ];
      final insights = insightsFor(records);

      expect(firstOfKind(insights, InsightKind.trendDown, 'STABIL'), isNull);
      expect(firstOfKind(insights, InsightKind.trendDown, 'KECIL'), isNull);
      expect(firstOfKind(insights, InsightKind.trendUp, 'KECIL'), isNull);
    });
  });

  test('tren permintaan per toko: makin laris & agak sepi', () {
    final records = [
      ...rows(
        store: 'Toko 1',
        code: 'A',
        month: _august,
        days: 20,
        perDay: 1,
        stock: 40,
      ),
      ...rows(
        store: 'Toko 1',
        code: 'A',
        month: _september,
        days: 30,
        perDay: 1,
        stock: 40,
      ),
      ...rows(
        store: 'Toko 2',
        code: 'A',
        month: _august,
        days: 30,
        perDay: 1,
        stock: 40,
      ),
      ...rows(
        store: 'Toko 2',
        code: 'A',
        month: _september,
        days: 15,
        perDay: 1,
        stock: 40,
      ),
    ];
    final insights = insightsFor(records);
    final demand = insights.where((i) => i.kind == InsightKind.demand).toList();

    final toko1 = demand.firstWhere((i) => i.storeName == 'Toko 1');
    expect(toko1.emoji, '🔥');
    expect(toko1.title, 'Toko 1 makin laris 50%');
    expect(toko1.detail, contains('20 → 30 unit'));

    final toko2 = demand.firstWhere((i) => i.storeName == 'Toko 2');
    expect(toko2.emoji, '🧊');
    expect(toko2.title, 'Toko 2 agak sepi 50%');
  });

  test('peringatan stok habis & menipis, paling penting di atas', () {
    final records = [
      // Habis: stok 0.
      ...rows(
        store: 'Toko 1',
        code: 'HABIS',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 0,
      ),
      // Menipis: stok 2, di bawah minimum 3.
      ...rows(
        store: 'Toko 1',
        code: 'TIPIS',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 2,
      ),
      // Aman.
      ...rows(
        store: 'Toko 1',
        code: 'AMAN',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 90,
      ),
    ];
    final insights = insightsFor(records);

    final habis = firstOfKind(insights, InsightKind.stockOut, 'HABIS')!;
    expect(habis.emoji, '🛑');
    expect(habis.title, 'HABIS habis di Toko 1');
    expect(habis.detail, contains('Saran kirim'));
    expect(
      insights.first.kind,
      InsightKind.stockOut,
      reason: 'prioritas tertinggi',
    );

    final tipis = firstOfKind(insights, InsightKind.stockLow, 'TIPIS')!;
    expect(tipis.emoji, '⚠️');
    expect(tipis.detail, contains('Sisa 2 unit'));

    expect(firstOfKind(insights, InsightKind.stockOut, 'AMAN'), isNull);
    expect(firstOfKind(insights, InsightKind.stockLow, 'AMAN'), isNull);
  });

  group('rekomendasi pindah barang', () {
    final records = [
      // Toko 1: stok menumpuk, terakhir laku Agustus.
      ...rows(
        store: 'Toko 1',
        code: 'PINDAH',
        month: _august,
        days: 5,
        perDay: 1,
        stock: 12,
      ),
      ...rows(
        store: 'Toko 1',
        code: 'PINDAH',
        month: _september,
        days: 20,
        perDay: 0,
        stock: 12,
      ),
      // Toko 2: laris tapi stok tinggal 1.
      ...rows(
        store: 'Toko 2',
        code: 'PINDAH',
        month: _august,
        days: 20,
        perDay: 1,
        stock: 1,
      ),
      ...rows(
        store: 'Toko 2',
        code: 'PINDAH',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 1,
      ),
    ];

    test('barang mengendap di satu toko, laris di toko lain', () {
      final transfer = firstOfKind(insightsFor(records), InsightKind.transfer)!;

      expect(transfer.emoji, '🔁');
      expect(transfer.title, startsWith('Pindahkan '));
      expect(transfer.title, contains('Toko 1 → Toko 2'));
      expect(transfer.detail, contains('belum terjual bulan ini'));
      expect(transfer.storeName, 'Toko 2');
      // Maksimal sisa stok di atas minimum (12 − 3).
      final quantity = int.parse(
        RegExp(r'Pindahkan (\d+)').firstMatch(transfer.title)!.group(1)!,
      );
      expect(quantity, inInclusiveRange(1, 9));
    });

    test('tidak muncul kalau toko asal masih laku', () {
      final laku = [
        ...rows(
          store: 'Toko 1',
          code: 'PINDAH',
          month: _september,
          days: 20,
          perDay: 1,
          stock: 12,
        ),
        ...rows(
          store: 'Toko 2',
          code: 'PINDAH',
          month: _september,
          days: 20,
          perDay: 1,
          stock: 1,
        ),
      ];
      expect(firstOfKind(insightsFor(laku), InsightKind.transfer), isNull);
    });

    test('filter toko tetap menampilkan pindahan yang menyangkut toko itu', () {
      expect(
        firstOfKind(
          insightsFor(records, storeName: 'Toko 1'),
          InsightKind.transfer,
        ),
        isNotNull,
      );
      expect(
        insightsFor(records, storeName: 'Toko 1').every(
          (i) =>
              i.storeName == null ||
              i.storeName == 'Toko 1' ||
              i.kind == InsightKind.transfer,
        ),
        isTrue,
      );
    });
  });

  test('barang nganggur: ada stok, lama tidak laku', () {
    final records = [
      ...rows(
        store: 'Toko 1',
        code: 'NGANGGUR',
        month: _august,
        days: 3,
        perDay: 1,
        stock: 15,
      ),
      ...rows(
        store: 'Toko 1',
        code: 'NGANGGUR',
        month: _september,
        days: 25,
        perDay: 0,
        stock: 15,
      ),
    ];
    final idle = firstOfKind(insightsFor(records), InsightKind.idle)!;

    expect(idle.emoji, '😴');
    expect(idle.title, 'NGANGGUR mengendap di Toko 1');
    expect(idle.detail, contains('Stok 15 unit'));
    expect(idle.detail, contains('terakhir laku 3 Agu'));
  });

  group('perkiraan kebutuhan bulan depan', () {
    test('rata-rata 3 bulan + arah tren, dan sisa yang perlu disiapkan', () {
      final records = [
        ...rows(
          store: 'Toko 1',
          code: 'RAMAL',
          month: _july,
          days: 20,
          perDay: 2,
          stock: 20,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'RAMAL',
          month: _august,
          days: 25,
          perDay: 2,
          stock: 20,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'RAMAL',
          month: _september,
          days: 30,
          perDay: 2,
          stock: 20,
        ),
      ];
      final forecast = firstOfKind(insightsFor(records), InsightKind.forecast)!;

      // Juli 40, Agustus 50, September 60. Rata-rata berbobot 53, dikali
      // faktor tren 60/50 = 1,2 → perkiraan Oktober 64 unit.
      expect(forecast.emoji, '🔮');
      expect(forecast.title, 'Oktober 2026: ±64 RAMAL di Toko 1');
      expect(forecast.detail, contains('Riwayat 40 → 50 → 60 unit'));
      expect(forecast.detail, contains('siapkan ±47 unit lagi'));
      expect(forecast.tone, InsightTone.warning);
    });

    test('bulan berjalan belum penuh: disetarakan ke bulan penuh', () {
      // 10 hari × 3 unit = 30 unit dalam 10 dari 30 hari → setara 90 sebulan.
      final records = rows(
        store: 'Toko 1',
        code: 'PARSIAL',
        month: _september,
        days: 10,
        perDay: 3,
        stock: 200,
      );
      final forecast = firstOfKind(insightsFor(records), InsightKind.forecast)!;

      expect(forecast.title, 'Oktober 2026: ±90 PARSIAL di Toko 1');
      expect(forecast.detail, contains('September 2026 baru 10 hari'));
      expect(forecast.detail, contains('Stok sekarang 200, sudah cukup'));
    });

    test('stok sudah cukup: tidak menyuruh menyiapkan lagi', () {
      final records = [
        ...rows(
          store: 'Toko 1',
          code: 'CUKUP',
          month: _august,
          days: 30,
          perDay: 1,
          stock: 300,
        ),
        ...rows(
          store: 'Toko 1',
          code: 'CUKUP',
          month: _september,
          days: 30,
          perDay: 1,
          stock: 300,
        ),
      ];
      final forecast = firstOfKind(insightsFor(records), InsightKind.forecast)!;

      expect(forecast.detail, contains('sudah cukup'));
      expect(forecast.tone, InsightTone.info);
    });
  });

  test('tanpa data bulan itu: tidak ada insight', () {
    final records = rows(
      store: 'Toko 1',
      code: 'A',
      month: _august,
      days: 10,
      perDay: 1,
      stock: 10,
    );
    expect(
      buildInsights(records: records, stockLevels: const [], month: _september),
      isEmpty,
    );
    expect(
      buildInsights(
        records: const [],
        stockLevels: const [],
        month: _september,
      ),
      isEmpty,
    );
  });

  test('ringkasan widget membawa insight per toko', () {
    final records = [
      ...rows(
        store: 'Toko 1',
        code: 'HABIS',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 0,
      ),
      ...rows(
        store: 'Toko 2',
        code: 'AMAN',
        month: _september,
        days: 20,
        perDay: 1,
        stock: 90,
      ),
    ];
    final summary = buildWidgetSalesSummary(
      records,
      stockLevels: computeStockLevels(records),
    );
    final stores = (summary['stores']! as List).cast<Map<String, Object?>>();

    final semua = (stores[0]['insights']! as List).cast<Map<String, Object?>>();
    expect(semua, isNotEmpty);
    expect(semua.first['emoji'], '🛑');
    expect(semua.first['text'], 'HABIS habis · Toko 1');
    expect(semua.first['tone'], 'negative');
    expect(semua.length, lessThanOrEqualTo(4));

    final toko2 = (stores[2]['insights']! as List).cast<Map<String, Object?>>();
    expect(
      toko2.every((i) => !(i['text']! as String).contains('Toko 1')),
      isTrue,
      reason: 'insight Toko 2 tidak mencampur data Toko 1',
    );
  });
}
