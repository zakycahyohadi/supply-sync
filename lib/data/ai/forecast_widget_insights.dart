import '../../models/ai_forecast.dart';
import '../../utils/currency.dart';

/// Lebar widget home screen sempit; lebih dari ini dipotong.
const kWidgetInsightMaxLength = 48;

/// Hasil AI diubah jadi baris-baris untuk widget home screen.
///
/// Bentuknya sama dengan catatan otomatis biasa (`{emoji, text, tone}`), jadi
/// kode Swift di `ios/SupplySyncWidget` tidak perlu diubah sama sekali.
///
/// Urutannya sengaja: yang **turun** dulu (itu yang perlu ditindak), lalu
/// barang yang **perlu disiapkan** bulan depan, baru perkiraan omzet dan yang
/// naik.
List<Map<String, Object?>> aiWidgetInsights(
  AiForecast forecast, {
  int max = 4,
}) {
  final lines = <Map<String, Object?>>[];

  void add(String emoji, String text, String tone) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || lines.length >= max) return;
    lines.add({'emoji': emoji, 'text': _shorten(trimmed), 'tone': tone});
  }

  for (final trend in forecast.downTrends) {
    add('📉', trend.title, 'negative');
  }
  for (final restock in forecast.restocks) {
    add(
      '📦',
      'Siapkan ${restock.quantity} ${restock.productName} · ${restock.storeName}',
      'warning',
    );
  }
  if (forecast.outlook.revenue > 0) {
    add(
      '🔮',
      'Bulan depan ± ${formatCompactRupiah(forecast.outlook.revenue)}',
      'info',
    );
  }
  for (final trend in forecast.upTrends) {
    add('📈', trend.title, 'positive');
  }

  return lines;
}

String _shorten(String text) => text.length <= kWidgetInsightMaxLength
    ? text
    : '${text.substring(0, kWidgetInsightMaxLength - 1).trimRight()}…';
