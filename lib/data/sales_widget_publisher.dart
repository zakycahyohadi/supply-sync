import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../home_widget_sync.dart';
import '../models/sales_record.dart';
import 'sales_analytics.dart';
import '../utils/date_format.dart';
import 'widget_sales_summary.dart';

/// Mengirim ringkasan penjualan ke widget iOS "Supply Sync".
class SalesWidgetPublisher {
  SalesWidgetPublisher._();

  /// Sama dengan `kind` widget di ios/SupplySyncWidget.
  static const iOSWidgetKind = 'SupplySyncWidget';

  /// Key di UserDefaults App Group yang dibaca widget.
  static const summaryKey = 'sales_summary';

  static String? _lastSummary;

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Kirim ringkasan setelah frame selesai digambar. Aman dipanggil dari
  /// `build`: kalau datanya sama dengan kiriman terakhir, tidak ada apa-apa.
  static void publishLater(
    List<SalesRecord> records, {
    List<StockLevel> stockLevels = const [],
  }) {
    if (!_isSupported) return;
    final summary = jsonEncode(
      buildWidgetSalesSummary(records, stockLevels: stockLevels),
    );
    if (summary == _lastSummary) return;
    _lastSummary = summary;
    SchedulerBinding.instance.addPostFrameCallback((_) => _save(summary));
  }

  /// Hapus data dari widget (dipakai saat logout).
  static Future<void> clear() async {
    if (!_isSupported) return;
    _lastSummary = null;
    await _write(null);
  }

  static Future<void> _save(String summary) async {
    final data = jsonDecode(summary) as Map<String, Object?>;
    final now = DateTime.now();
    // Singkat supaya muat di widget, contoh "18 Sep, 10.30".
    data['updated'] =
        '${formatDayMonth(now)}, '
        '${now.hour.toString().padLeft(2, '0')}.'
        '${now.minute.toString().padLeft(2, '0')}';
    await _write(jsonEncode(data));
  }

  static Future<void> _write(String? value) async {
    try {
      await HomeWidget.setAppGroupId(HomeWidgetSync.appGroupId);
      await HomeWidget.saveWidgetData<String>(summaryKey, value);
      await HomeWidget.updateWidget(iOSName: iOSWidgetKind);
    } on MissingPluginException {
      // Tanpa plugin native (misalnya saat test).
    } on PlatformException {
      // Widget belum dipasang di home screen; tidak perlu diperbarui.
    }
  }
}
