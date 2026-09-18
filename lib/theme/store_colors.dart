import 'package:flutter/material.dart';

import '../data/stores.dart';
import 'app_colors.dart';

/// Warna tetap per toko, jadi Toko 1 selalu biru walau filter berubah.
Color storeColor(String storeName) {
  final index = kStores.indexOf(storeName);
  if (index < 0) return AppColors.textMuted;
  return AppColors.series[index % AppColors.series.length];
}
