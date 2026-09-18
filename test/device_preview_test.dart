import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/device_preview_boot.dart';

void main() {
  Uri url(String query) => Uri.parse('https://contoh.test/supply-sync/$query');

  test('tanpa query: pakai perangkat bawaan, tegak', () {
    final simulation = previewSimulationFromUrl(url(''));

    expect(simulation, isNotNull);
    expect(simulation!.presetId, kDefaultPreviewDevice);
    final size = simulation.screenSize!;
    expect(size.height, greaterThan(size.width), reason: 'tegak');
  });

  test('?device= memilih perangkat lain', () {
    final simulation = previewSimulationFromUrl(url('?device=google-pixel-9'));

    expect(simulation!.presetId, 'google-pixel-9');
  });

  test('?orientation=landscape memutar layarnya', () {
    final simulation = previewSimulationFromUrl(
      url('?device=apple-ipad-mini&orientation=landscape'),
    );

    final size = simulation!.screenSize!;
    expect(size.width, greaterThan(size.height), reason: 'mendatar');
  });

  test('id yang tidak dikenal: tanpa simulasi, bukan crash', () {
    expect(previewSimulationFromUrl(url('?device=nokia-3310')), isNull);
  });

  test('semua id di daftar preset bisa dipakai', () {
    for (final id in [
      'apple-iphone-17-pro',
      'apple-iphone-se-3',
      'google-pixel-9',
      'samsung-galaxy-s25',
      'apple-ipad-mini',
      'desktop-small',
    ]) {
      expect(previewPresetById(id), isNotNull, reason: id);
    }
  });
}
