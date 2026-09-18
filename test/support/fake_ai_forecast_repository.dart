import 'package:supply_sync/data/ai/ai_forecast_repository.dart';
import 'package:supply_sync/models/ai_forecast.dart';

/// Versi [AiForecastRepository] untuk test: tidak memanggil Gemini.
class FakeAiForecastRepository extends AiForecastRepository {
  FakeAiForecastRepository({this.result, this.error});

  /// Hasil yang dikembalikan; kalau null dan [error] juga null, dipakai
  /// [sampleForecast].
  final AiForecast? result;

  /// Kalau diisi, panggilan selalu gagal dengan pesan ini.
  final String? error;

  /// Payload yang diterima panggilan terakhir, untuk diperiksa test.
  Map<String, Object?>? lastPayload;
  final calledKeys = <String>[];

  @override
  Future<AiForecast> forecast({
    required Map<String, Object?> payload,
    required String cacheKey,
  }) async {
    lastPayload = payload;
    calledKeys.add(cacheKey);
    final error = this.error;
    if (error != null) throw AiForecastException(error);
    return result ?? sampleForecast;
  }
}

/// Balasan Gemini yang khas, dipakai beberapa test.
final sampleForecast = AiForecast.fromJson({
  'ringkasan': 'Omzet bulan ini sedikit di atas bulan lalu, ditarik iPhone.',
  'tren': [
    {
      'arah': 'turun',
      'judul': 'MacBook Air M4 turun 40%',
      'alasan': 'Hanya terjual 3 unit, dari 5 unit di periode yang sama.',
    },
    {
      'arah': 'naik',
      'judul': 'iPhone 17 Pro Max naik 71%',
      'alasan': 'Permintaan naik sejak awal bulan.',
    },
  ],
  'forecast_bulan_depan': {
    'omzet_perkiraan': 268000000,
    'unit_perkiraan': 95,
    'keyakinan': 'sedang',
    'dasar_perhitungan': 'Rata-rata dua bulan terakhir, diprorata 30 hari.',
  },
  'produk_perlu_dikirim': [
    {
      'produk': 'iPhone 17 Pro Max',
      'toko': 'Toko 1',
      'jumlah_saran': 12,
      'alasan': 'Stok habis dan rata-rata terjual 0,9 unit per hari.',
    },
  ],
  'rekomendasi': ['Kirim iPhone 17 Pro Max ke Toko 1 minggu ini.'],
  'model': 'gemini-3.8-flash',
});
