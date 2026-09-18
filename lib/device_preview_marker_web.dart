import 'package:web/web.dart' as web;

/// Memberi tahu halaman bahwa simulasi perangkat sedang aktif, sekaligus
/// perangkat mana yang dipakai.
///
/// Pemilih perangkat di `web/index.html` menyembunyikan dirinya sampai
/// atribut ini muncul, jadi build web tanpa `--dart-define=DEVICE_PREVIEW=true`
/// tidak menampilkan tombol yang tidak berfungsi.
void markDevicePreviewActive(String presetId) {
  web.document.documentElement?.setAttribute('data-device-preview', presetId);
}
