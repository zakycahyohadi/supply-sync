import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Simulasi perangkat untuk build web (GitHub Pages): aplikasi tampil di dalam
// bingkai HP, bukan memenuhi seluruh jendela browser.
//
// device_preview 3 dikendalikan lewat Flutter DevTools, dan di halaman web
// yang sudah di-deploy DevTools tidak ada. Jadi perangkatnya dipilih lewat
// query URL, misalnya:
//
//   .../supply_sync/?device=google-pixel-9
//   .../supply_sync/?device=apple-ipad-mini&orientation=landscape
//
// Daftar id ada di DevicePresets.all.

/// Dinyalakan build web lewat `--dart-define=DEVICE_PREVIEW=true`.
///
/// Tanpa flag ini perilakunya seperti bawaan paket: aktif saat debug &
/// profile, mati total di release — jadi APK/IPA rilis tidak terpengaruh.
const kDevicePreviewForced = bool.fromEnvironment('DEVICE_PREVIEW');

/// Perangkat yang dipakai kalau URL tidak menyebut apa-apa.
const kDefaultPreviewDevice = 'apple-iphone-17-pro';

/// Pasang binding device_preview. Harus dipanggil paling awal di `main()`,
/// sebelum binding lain dibuat.
WidgetsBinding initDevicePreview() => DevicePreview.enable(
  enabled: kDevicePreviewForced || !kReleaseMode,
  padding: const EdgeInsets.all(24),
);

/// Terapkan perangkat dari query URL. Aman dipanggil walau simulasi mati.
Future<void> applyPreviewDeviceFromUrl() async {
  final controller = DevicePreview.maybeController;
  if (controller == null || !kDevicePreviewForced) return;

  final query = Uri.base.queryParameters;
  final preset = previewPresetById(query['device'] ?? kDefaultPreviewDevice);
  if (preset == null) return;

  await controller.applyPreset(
    preset,
    orientation: query['orientation'] == 'landscape'
        ? Orientation.landscape
        : Orientation.portrait,
  );
}

/// Preset dengan [id] ini, atau null kalau tidak ada.
DevicePreset? previewPresetById(String id) {
  for (final preset in DevicePresets.all) {
    if (preset.id == id) return preset;
  }
  return null;
}
