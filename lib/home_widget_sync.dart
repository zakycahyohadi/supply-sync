import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Keeps the counter in sync with the home screen widget.
///
/// The value lives in the storage shared with the native widget
/// (SharedPreferences on Android, App Group UserDefaults on iOS), so the "+"
/// button on the widget and the button in the app update the same number.
class HomeWidgetSync {
  HomeWidgetSync._();

  /// Must match the App Group enabled for Runner and the widget extension.
  static const appGroupId = 'group.com.retailinsight.app';

  /// Must match the class name of the Android AppWidgetProvider.
  static const androidProvider = 'CounterWidgetProvider';

  /// Must match the `kind` of the iOS widget.
  static const iOSWidgetKind = 'CounterWidget';

  static const counterKey = 'counter';
  static const updatedAtKey = 'updated_at';

  static bool get _isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> init() async {
    if (!_isSupported) return;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } on MissingPluginException {
      // Running without the native plugin (e.g. widget tests).
    }
  }

  static Future<int> loadCounter() async {
    if (!_isSupported) return 0;
    try {
      final value = await HomeWidget.getWidgetData<num>(counterKey);
      return value?.toInt() ?? 0;
    } on MissingPluginException {
      return 0;
    } on PlatformException {
      return 0;
    }
  }

  static Future<void> saveCounter(int counter) async {
    if (!_isSupported) return;
    try {
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}';
      await HomeWidget.saveWidgetData<int>(counterKey, counter);
      await HomeWidget.saveWidgetData<String>(updatedAtKey, time);
      await HomeWidget.updateWidget(
        androidName: androidProvider,
        iOSName: iOSWidgetKind,
      );
    } on MissingPluginException {
      // Running without the native plugin (e.g. widget tests).
    } on PlatformException {
      // No widget placed on the home screen yet; nothing to refresh.
    }
  }
}
