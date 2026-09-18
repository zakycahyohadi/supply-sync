import 'package:device_preview/device_preview.dart';
import 'package:device_preview/presets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'device_preview_marker_stub.dart'
    if (dart.library.js_interop) 'device_preview_marker_web.dart';

// Simulasi perangkat: aplikasi tampil di dalam bingkai HP, bukan memenuhi
// seluruh jendela browser.
//
// device_preview 3 biasanya dikendalikan lewat Flutter DevTools, dan halaman
// web yang sudah di-deploy tidak punya DevTools. Jadi khusus di web,
// perangkatnya dipasang sendiri sebelum frame pertama dan dipilih lewat query
// URL:
//
//   .../supply-sync/?device=google-pixel-9
//   .../supply-sync/?device=apple-ipad-mini&orientation=landscape
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
WidgetsBinding initDevicePreview() {
  final enabled = kDevicePreviewForced || !kReleaseMode;

  // Hanya di web. Di HP, aplikasinya sudah berjalan di perangkat sungguhan —
  // menirukan perangkat lain di dalamnya tidak ada gunanya.
  if (enabled && kIsWeb) {
    final simulation = previewSimulationFromUrl();
    // Dipasang lewat latch, bukan lewat controller setelah binding jadi:
    // dengan begini perangkatnya sudah aktif di frame pertama, jadi tidak ada
    // kedipan tampilan layar penuh sebelum bingkainya muncul.
    DevicePreviewBindingMixin.latchConfiguration(initialSimulation: simulation);
    // Pemilih perangkat di halaman baru muncul setelah ini.
    markDevicePreviewActive(simulation?.presetId ?? '');
  }

  // enable() menyetel ulang enabled/padding/latar, tapi membiarkan simulasi
  // yang sudah di-latch di atas.
  return DevicePreview.enable(
    enabled: enabled,
    // Ruang di atas disisakan untuk pemilih perangkat di halaman, supaya
    // tidak menutupi status bar perangkat yang disimulasikan.
    padding: const EdgeInsets.fromLTRB(24, 76, 24, 24),
  );
}

/// Perangkat yang diminta lewat query URL, atau [kDefaultPreviewDevice].
/// Null kalau id-nya tidak dikenal.
DeviceSimulation? previewSimulationFromUrl([Uri? url]) {
  final query = (url ?? Uri.base).queryParameters;
  final preset = previewPresetById(query['device'] ?? kDefaultPreviewDevice);
  return preset?.resolve(
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
