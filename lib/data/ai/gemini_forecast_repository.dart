import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';

import '../../models/ai_forecast.dart';
import 'ai_forecast_repository.dart';
import 'forecast_prompt.dart';

/// Model yang dipakai. Kelas Flash: cukup pintar untuk membaca ringkasan
/// angka, dan di Firebase AI Logic masih masuk kuota gratis.
const kForecastModel = 'gemini-3.8-flash';

/// Analisis lewat Gemini (Firebase AI Logic), dengan cache di Firestore.
///
/// API key tidak pernah ada di aplikasi: `FirebaseAI.googleAI()` menembak
/// backend Gemini Developer API lewat project Firebase, dan Firebase App Check
/// yang memastikan hanya app asli yang boleh memanggil.
///
/// Hasilnya disimpan di koleksi `ai_forecasts` dengan id = sidik jari data.
/// Selama belum ada upload baru, semua admin membaca hasil yang sama dan
/// Gemini hanya dipanggil sekali.
class GeminiForecastRepository extends AiForecastRepository {
  GeminiForecastRepository({
    GenerativeModel? model,
    FirebaseFirestore? firestore,
  }) : _model = model,
       _db = firestore ?? FirebaseFirestore.instance;

  /// Dibuat saat pertama dipakai, bukan di konstruktor: `FirebaseAI` baru bisa
  /// dipanggil setelah `Firebase.initializeApp()` selesai.
  GenerativeModel? _model;
  final FirebaseFirestore _db;

  /// Cache sesi ini, supaya pindah tab tidak menembak Firestore lagi.
  final _memory = <String, AiForecast>{};

  GenerativeModel get _generativeModel =>
      _model ??= FirebaseAI.googleAI().generativeModel(
        model: kForecastModel,
        systemInstruction: Content.system(kForecastSystemInstruction),
        generationConfig: GenerationConfig(
          // Dua baris ini yang memaksa balasannya JSON sesuai bentuk yang
          // kita mau, bukan paragraf bebas.
          responseMimeType: 'application/json',
          responseSchema: kForecastSchema,
          // Rendah: untuk analisis angka kita mau jawaban yang konsisten,
          // bukan yang kreatif.
          temperature: 0.2,
        ),
      );

  CollectionReference<Map<String, dynamic>> get _cache =>
      _db.collection('ai_forecasts');

  @override
  Future<AiForecast> forecast({
    required Map<String, Object?> payload,
    required String cacheKey,
  }) async {
    final remembered = _memory[cacheKey];
    if (remembered != null) return remembered;

    final cached = await _readCache(cacheKey);
    if (cached != null) return _memory[cacheKey] = cached;

    final forecast = await _generate(payload);
    _memory[cacheKey] = forecast;
    // Gagal menyimpan cache bukan alasan untuk gagal menampilkan hasil.
    unawaited(_writeCache(cacheKey, forecast));
    return forecast;
  }

  Future<AiForecast?> _readCache(String cacheKey) async {
    try {
      final data = (await _cache.doc(cacheKey).get()).data();
      if (data == null) return null;
      final forecast = AiForecast.fromJson(data);
      return forecast.isEmpty ? null : forecast;
    } on FirebaseException {
      return null;
    }
  }

  Future<void> _writeCache(String cacheKey, AiForecast forecast) async {
    try {
      await _cache.doc(cacheKey).set(forecast.toJson());
    } on FirebaseException {
      // Aturan Firestore menolak atau sedang offline; abaikan.
    }
  }

  Future<AiForecast> _generate(Map<String, Object?> payload) async {
    final GenerateContentResponse response;
    try {
      response = await _generativeModel.generateContent([
        Content.text(jsonEncode(payload)),
      ]);
    } on ServiceApiNotEnabled {
      throw const AiForecastException(
        'Firebase AI Logic belum diaktifkan. Buka Firebase Console → AI Logic '
        '→ Get started, lalu coba lagi.',
      );
    } on QuotaExceeded {
      throw const AiForecastException(
        'Kuota AI hari ini sudah habis. Analisis akan tersedia lagi besok.',
      );
    } on FirebaseAIException catch (error) {
      throw AiForecastException(
        'Gemini tidak bisa dihubungi: ${error.message}',
      );
    }

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const AiForecastException('Balasan AI kosong.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const AiForecastException('Balasan AI bukan JSON yang valid.');
    }
    if (decoded is! Map) {
      throw const AiForecastException('Bentuk balasan AI tidak dikenali.');
    }

    final forecast = AiForecast.fromJson(
      Map<String, Object?>.from(decoded),
    ).copyWith(generatedAt: DateTime.now(), model: kForecastModel);
    if (forecast.isEmpty) {
      throw const AiForecastException('Balasan AI tidak berisi analisis.');
    }
    return forecast;
  }
}
