import '../../models/ai_forecast.dart';

/// Analisis & perkiraan dari AI.
///
/// `main.dart` memakai versi Gemini; test dan mode tanpa AI memakai versi
/// lain. Polanya sama dengan [SalesRepository] supaya gampang ditukar.
abstract class AiForecastRepository {
  static AiForecastRepository instance = UnavailableAiForecastRepository();

  /// Analisis [payload] (hasil `buildForecastPayload`).
  ///
  /// [cacheKey] adalah sidik jari payload: selama datanya belum berubah,
  /// hasil lama dipakai ulang dan model tidak dipanggil lagi.
  Future<AiForecast> forecast({
    required Map<String, Object?> payload,
    required String cacheKey,
  });
}

/// Gagal menganalisis. Dashboard menangkap ini dan kembali menampilkan
/// catatan otomatis biasa, jadi tidak ada halaman yang kosong.
class AiForecastException implements Exception {
  const AiForecastException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Dipakai kalau AI belum diaktifkan (default, dan saat test).
class UnavailableAiForecastRepository extends AiForecastRepository {
  @override
  Future<AiForecast> forecast({
    required Map<String, Object?> payload,
    required String cacheKey,
  }) async => throw const AiForecastException('Analisis AI belum diaktifkan.');
}
