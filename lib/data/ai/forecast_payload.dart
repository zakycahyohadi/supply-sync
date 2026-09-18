import 'dart:convert';

import '../../utils/date_format.dart';
import '../insights_engine.dart';
import '../sales_analytics.dart';

// Yang dikirim ke Gemini adalah RINGKASAN yang sudah dihitung aplikasi, bukan
// baris-baris penjualan mentah. Dua alasannya:
//
// 1. Model bahasa buruk dalam berhitung. Omzet, persen naik/turun, dan sisa
//    stok harus tetap keluar dari sales_analytics.dart supaya angkanya bisa
//    dipertanggungjawabkan.
// 2. Data mentah bisa ribuan baris; ringkasan ini ±3 KB, jadi panggilannya
//    cepat dan hemat kuota.
//
// Gemini bertugas menafsirkan, bukan menghitung ulang.

/// Berapa produk per daftar yang ikut dikirim. Cukup untuk menyimpulkan,
/// tanpa bikin payload membengkak.
const kPayloadListLimit = 5;

/// Ringkasan untuk dikirim ke Gemini. [ruleInsights] adalah hasil
/// `buildInsights()` (aturan if-else yang sudah ada) — dipakai sebagai bahan
/// mentah, bukan digantikan.
Map<String, Object?> buildForecastPayload({
  required SalesAnalytics analytics,
  required List<Insight> ruleInsights,
  String? storeName,
}) {
  final month = analytics.month;
  final current = analytics.current;
  final previous = analytics.previous;
  final alerts = analytics.restockCandidates.take(kPayloadListLimit);

  return {
    'toko': storeName ?? 'Semua toko',
    'bulan': formatMonthYear(month),
    // Bulan berjalan hampir selalu belum lengkap. Dua angka ini yang dipakai
    // model untuk memprorata sebelum membandingkan dengan bulan lalu.
    'data_sampai_tanggal': analytics.latestDate?.day,
    'hari_dalam_bulan': DateTime(month.year, month.month + 1, 0).day,
    if (current != null)
      'bulan_ini': {'omzet': current.revenue, 'unit': current.quantity},
    if (previous != null)
      'bulan_lalu_periode_sama': {
        'omzet': previous.revenue,
        'unit': previous.quantity,
      },
    'omzet_per_toko': {
      for (final entry in analytics.revenueByStore) entry.key: entry.value,
    },
    'produk_terlaris': [
      for (final product in analytics.topProducts.take(kPayloadListLimit))
        {
          'produk': product.productName,
          'unit': product.quantity,
          'omzet': product.revenue,
        },
    ],
    'naik': [
      for (final change in analytics.risers)
        {
          'produk': change.productName,
          'unit': change.currentQuantity,
          'perubahan_persen': change.changePercent.round(),
        },
    ],
    'turun': [
      for (final change in analytics.fallers)
        {
          'produk': change.productName,
          'unit': change.currentQuantity,
          'perubahan_persen': change.changePercent.round(),
        },
    ],
    'stok_perlu_perhatian': [
      for (final level in alerts)
        {
          'produk': level.productName,
          'toko': level.storeName,
          'sisa': level.stock,
          'min': level.minStock ?? 0,
          'status': level.status.label,
          'rata_rata_jual_harian': double.parse(
            level.averageDailySales.toStringAsFixed(2),
          ),
          'perkiraan_habis_hari': level.daysLeft?.round(),
          'dalam_pengiriman': level.incoming,
          'saran_kirim_aplikasi': level.suggestedRestock,
        },
    ],
    // Hasil aturan if-else yang sudah ada. Model boleh mempertajam atau
    // menggabungkannya, tapi tidak boleh bertentangan tanpa alasan.
    'catatan_aplikasi': [
      for (final insight in ruleInsights.take(8))
        '${insight.title} — ${insight.detail}',
    ],
  };
}

/// Sidik jari isi payload. Dipakai sebagai id dokumen cache: selama datanya
/// belum berubah, hasil analisis dipakai ulang dan Gemini tidak dipanggil lagi.
///
/// Dihitung sendiri, bukan `hashCode`, karena `String.hashCode` tidak dijamin
/// sama antar proses/perangkat — padahal cache-nya dipakai bersama.
String forecastFingerprint(Map<String, Object?> payload) {
  final bytes = utf8.encode(jsonEncode(payload));
  // Dua hash dengan titik awal berbeda digabung jadi 16 karakter hex, supaya
  // dua data berbeda tidak gampang dapat id yang sama.
  return _hash(bytes, 0).toRadixString(16).padLeft(8, '0') +
      _hash(bytes, 0x5bf03635).toRadixString(16).padLeft(8, '0');
}

/// Jenkins one-at-a-time, sengaja dijaga di 29 bit.
///
/// Di web `int` itu bilangan pecahan JavaScript, jadi hash 64-bit tidak bisa
/// dipakai: `flutter build web` langsung menolak angkanya. Batas 29 bit
/// membuat hasilnya identik di HP maupun browser.
int _hash(List<int> bytes, int seed) {
  var hash = seed;
  for (final byte in bytes) {
    hash = 0x1fffffff & (hash + byte);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    hash ^= hash >> 6;
  }
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash ^= hash >> 11;
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
