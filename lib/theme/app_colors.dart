import 'package:flutter/material.dart';

/// Palet warna Supply Sync.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0B1F3A);
  static const navyLight = Color(0xFF1C3A63);
  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE3E7EE);
  static const placeholder = Color(0xFFE5E7EB);
  static const placeholderIcon = Color(0xFF9CA3AF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF8A8F98);
  static const whatsapp = Color(0xFF25D366);
  static const trending = Color(0xFFEA580C);
  static const danger = Color(0xFFDC2626);

  // Grafik: garis bantu tipis dan baseline.
  static const chartGrid = Color(0xFFEDEFF3);
  static const chartBaseline = Color(0xFFD5D9E0);

  /// Warna kategori untuk grafik, urutannya tetap (sudah dicek aman untuk
  /// buta warna). Tambah toko ke-4 dst. perlu dicek ulang.
  static const series = [
    Color(0xFF2A78D6),
    Color(0xFFEB6834),
    Color(0xFF1BAF7A),
  ];

  // Warna status: selalu dipasangkan dengan ikon + label, jangan dipakai
  // sebagai warna seri grafik.
  static const statusGood = Color(0xFF0CA30C);
  static const statusWarning = Color(0xFFFAB219);
  static const statusSerious = Color(0xFFEC835A);
  static const statusCritical = Color(0xFFD03B3B);
  static const deltaUp = Color(0xFF006300);
  static const deltaDown = Color(0xFFD03B3B);
}
