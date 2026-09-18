/// Format angka ke Rupiah, contoh: 20000000 -> "Rp20.000.000".
String formatRupiah(int amount) {
  final buffer = StringBuffer(amount < 0 ? '-Rp' : 'Rp');
  buffer.write(formatThousands(amount.abs()));
  return buffer.toString();
}

/// Pemisah ribuan dengan titik, contoh: 1250 -> "1.250".
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Rupiah ringkas untuk kartu & grafik, contoh: 245300000 -> "Rp245,3 jt".
String formatCompactRupiah(num amount) {
  final sign = amount < 0 ? '-' : '';
  return '${sign}Rp${formatCompactNumber(amount.abs())}';
}

/// Angka ringkas tanpa "Rp", contoh: 2500000 -> "2,5 jt".
String formatCompactNumber(num value) {
  final v = value.abs().toDouble();
  final sign = value < 0 ? '-' : '';
  if (v >= 1e9) return '$sign${_oneDecimal(v / 1e9)} M';
  if (v >= 1e6) return '$sign${_oneDecimal(v / 1e6)} jt';
  if (v >= 1e3) return '$sign${_oneDecimal(v / 1e3)} rb';
  return '$sign${v.toStringAsFixed(0)}';
}

/// Persen dengan koma, contoh: 8.43 -> "8,4%".
String formatPercent(double value) => '${_oneDecimal(value)}%';

String _oneDecimal(double value) {
  final text = value.toStringAsFixed(1);
  final trimmed = text.endsWith('.0')
      ? text.substring(0, text.length - 2)
      : text;
  return trimmed.replaceAll('.', ',');
}
