import 'dart:io';

import 'package:image/image.dart';

// Menyiapkan dua PNG dari logo asli untuk flutter_launcher_icons:
//
// - app_icon.png            : kotak penuh, tanpa transparansi (iOS menolak
//                             ikon yang punya alpha), dipakai juga untuk
//                             ikon Android lawas dan favicon web.
// - app_icon_foreground.png : lapisan depan adaptive icon Android. Android
//                             memotong ikon jadi lingkaran/squircle dan hanya
//                             ~66% bagian tengah yang dijamin terlihat, jadi
//                             logonya dikecilkan dulu supaya panahnya tidak
//                             kepotong.
//
// Jalankan: dart run tool/generate_icons.dart
//           dart run flutter_launcher_icons

const _source = 'assets/icon/logo_source.jpeg';
const _size = 1024;

/// Bagian lebar ikon yang diisi logo di adaptive icon.
const _foregroundScale = 0.62;

void main() {
  final source = decodeImage(File(_source).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Gagal membaca $_source');
    exit(1);
  }

  final square = copyResize(
    source,
    width: _size,
    height: _size,
    interpolation: Interpolation.cubic,
  );
  File('assets/icon/app_icon.png').writeAsBytesSync(encodePng(square));

  // Latar transparan; logo ditaruh di tengah dengan ukuran lebih kecil.
  final inner = (_size * _foregroundScale).round();
  final foreground = Image(width: _size, height: _size, numChannels: 4);
  compositeImage(
    foreground,
    copyResize(
      source,
      width: inner,
      height: inner,
      interpolation: Interpolation.cubic,
    ),
    dstX: (_size - inner) ~/ 2,
    dstY: (_size - inner) ~/ 2,
  );
  File(
    'assets/icon/app_icon_foreground.png',
  ).writeAsBytesSync(encodePng(foreground));

  stdout.writeln('app_icon.png & app_icon_foreground.png dibuat ($_size px).');
}
