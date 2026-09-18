import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart';

// Semua turunan logo dibuat dari satu berkas: assets/icon/logo_source.jpeg.
//
// Yang dihasilkan:
//
// - app_icon.png            ikon aplikasi, kotak penuh, tanpa alpha (iOS
//                           menolak ikon beralpha). Dipakai juga untuk ikon
//                           Android lawas dan favicon web.
// - app_icon_foreground.png lapisan depan adaptive icon Android. Android
//                           memotong ikon jadi lingkaran/squircle dan hanya
//                           ~66% bagian tengah yang pasti terlihat, jadi
//                           logonya dikecilkan supaya panahnya tidak kepotong.
// - app_logo_badge.png      logo di atas kotak putih membulat. Dipakai di
//                           dalam aplikasi (splash screen, header), di layar
//                           pembuka bawaan Android/iOS, dan di widget iOS.
// - BrandMark.swift         badge yang sama, ditanam sebagai base64 di dalam
//                           kode widget iOS. Widget extension belum punya
//                           asset catalog sendiri, dan menambahkannya berarti
//                           menyunting project.pbxproj dengan tangan.
//
// Jalankan: dart run tool/generate_icons.dart
//           dart run flutter_launcher_icons

const _source = 'assets/icon/logo_source.jpeg';
const _iconSize = 1024;
const _logoSize = 512;

/// Bagian lebar yang diisi logo di adaptive icon Android.
const _adaptiveScale = 0.62;

/// Bagian lebar yang diisi logo di dalam badge.
const _badgeLogoScale = 0.66;

/// Kelengkungan sudut badge, terhadap lebarnya.
const _badgeRadius = 0.23;

/// Ukuran badge yang ditanam di widget iOS (24pt @3x).
const _swiftBadgeSize = 72;

void main() {
  final source = decodeImage(File(_source).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Gagal membaca $_source');
    exit(1);
  }

  // --- ikon aplikasi -------------------------------------------------------
  _write(
    'assets/icon/app_icon.png',
    copyResize(
      source,
      width: _iconSize,
      height: _iconSize,
      interpolation: Interpolation.cubic,
    ),
  );

  final logo = trim(_cutWhiteBackground(source), mode: TrimMode.transparent);

  _write(
    'assets/icon/app_icon_foreground.png',
    _centered(logo, size: _iconSize, scale: _adaptiveScale),
  );

  // --- logo untuk di dalam aplikasi ---------------------------------------
  final badge = _badge(logo, _logoSize);
  _write('assets/icon/app_logo_badge.png', badge);

  // --- layar pembuka bawaan ------------------------------------------------
  // Android: ditaruh di tengah latar navy oleh launch_background.xml.
  for (final (folder, size) in const [
    ('mdpi', 96),
    ('hdpi', 144),
    ('xhdpi', 192),
    ('xxhdpi', 288),
    ('xxxhdpi', 384),
  ]) {
    _write(
      'android/app/src/main/res/drawable-$folder/launch_image.png',
      _badge(logo, size),
    );
  }

  // iOS: LaunchScreen.storyboard menaruh LaunchImage di tengah.
  for (final (name, size) in const [
    ('LaunchImage.png', 96),
    ('LaunchImage@2x.png', 192),
    ('LaunchImage@3x.png', 288),
  ]) {
    _write(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/$name',
      _badge(logo, size),
    );
  }

  // --- widget iOS ----------------------------------------------------------
  _writeSwiftBrandMark(_badge(logo, _swiftBadgeSize));

  stdout.writeln('Ikon, logo, dan layar pembuka dibuat ulang dari $_source.');
}

/// Latar putih logo dijadikan transparan.
///
/// Logonya biru di atas putih, jadi seberapa "putih" sebuah piksel diukur dari
/// channel terkecilnya: putih murni -> hilang, biru tua -> pekat. Warnanya
/// lalu dikembalikan seolah tidak pernah dicampur putih, supaya tepiannya
/// tidak menyisakan halo terang.
Image _cutWhiteBackground(Image source) {
  final result = source.convert(numChannels: 4);
  for (final pixel in result) {
    final alpha = 255 - min(pixel.r, min(pixel.g, pixel.b));
    if (alpha <= 6) {
      pixel.setRgba(0, 0, 0, 0);
      continue;
    }
    final opacity = alpha / 255;
    pixel.setRgba(
      _unblend(pixel.r, opacity),
      _unblend(pixel.g, opacity),
      _unblend(pixel.b, opacity),
      alpha,
    );
  }
  return result;
}

num _unblend(num channel, double opacity) =>
    ((channel - 255 * (1 - opacity)) / opacity).clamp(0, 255);

/// [logo] ditaruh di tengah kanvas persegi transparan, rasionya dijaga.
Image _centered(Image logo, {required int size, required double scale}) {
  final box = (size * scale).round();
  final width = logo.width >= logo.height
      ? box
      : (box * logo.width / logo.height).round();
  final height = logo.height >= logo.width
      ? box
      : (box * logo.height / logo.width).round();

  final canvas = Image(width: size, height: size, numChannels: 4);
  compositeImage(
    canvas,
    copyResize(
      logo,
      width: width,
      height: height,
      interpolation: Interpolation.cubic,
    ),
    dstX: (size - width) ~/ 2,
    dstY: (size - height) ~/ 2,
  );
  return canvas;
}

/// Kotak putih membulat dengan logo di tengahnya; di luar kotak transparan.
///
/// Kotaknya digambar manual, bukan pakai `fillRect(radius: ...)`: fungsi itu
/// hanya mencampur R/G/B dan tidak pernah mengisi alpha, jadi di atas kanvas
/// transparan hasilnya tidak kelihatan sama sekali.
Image _badge(Image logo, int size) {
  final radius = size * _badgeRadius;
  final canvas = Image(width: size, height: size, numChannels: 4);
  for (final pixel in canvas) {
    final coverage = _roundedRectCoverage(
      pixel.x + 0.5,
      pixel.y + 0.5,
      size,
      radius,
    );
    pixel.setRgba(255, 255, 255, (coverage * 255).round());
  }
  compositeImage(canvas, _centered(logo, size: size, scale: _badgeLogoScale));
  return canvas;
}

/// Seberapa besar piksel di ([x], [y]) tertutup kotak membulat selebar [size]
/// dengan sudut [radius]. 1 = penuh, 0 = di luar; nilai di antaranya membuat
/// tepinya halus, tidak bergerigi.
double _roundedRectCoverage(double x, double y, int size, double radius) {
  final dx = max(max(radius - x, x - (size - radius)), 0.0);
  final dy = max(max(radius - y, y - (size - radius)), 0.0);
  if (dx == 0 || dy == 0) return 1;
  final distance = sqrt(dx * dx + dy * dy);
  return (radius + 0.5 - distance).clamp(0.0, 1.0);
}

void _writeSwiftBrandMark(Image badge) {
  final base64Png = base64Encode(encodePng(badge));
  final buffer = StringBuffer()
    ..writeln('import SwiftUI')
    ..writeln()
    ..writeln('// DIBUAT OTOMATIS oleh tool/generate_icons.dart. Jangan diedit')
    ..writeln('// tangan; ubah assets/icon/logo_source.jpeg lalu jalankan:')
    ..writeln('//   dart run tool/generate_icons.dart')
    ..writeln('//')
    ..writeln('// Logonya ditanam sebagai base64, bukan taruh di asset')
    ..writeln('// catalog, karena target widget extension belum punya asset')
    ..writeln('// catalog sendiri.')
    ..writeln('enum BrandMark {')
    ..writeln('  static let image: Image? = {')
    ..writeln('    guard let data = Data(base64Encoded: png),')
    ..writeln('          let uiImage = UIImage(data: data)')
    ..writeln('    else { return nil }')
    ..writeln('    return Image(uiImage: uiImage)')
    ..writeln('  }()')
    ..writeln()
    ..writeln('  private static let png = """');
  // Dipotong supaya barisnya tidak kepanjangan.
  for (var start = 0; start < base64Png.length; start += 76) {
    buffer.writeln(
      base64Png.substring(start, min(start + 76, base64Png.length)),
    );
  }
  buffer
    ..writeln('"""')
    ..writeln('}');

  File('ios/SupplySyncWidget/BrandMark.swift').writeAsStringSync('$buffer');
}

void _write(String path, Image image) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(encodePng(image));
}
