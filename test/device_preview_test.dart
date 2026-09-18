import 'dart:io';

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

  test('perangkat bawaan ada di katalog', () {
    expect(previewPresetById(kDefaultPreviewDevice), isNotNull);
  });

  test('semua pilihan di pemilih perangkat web ada di katalog', () {
    // Daftar perangkat ditulis dua kali: di web/index.html (untuk dropdown)
    // dan di DevicePresets (untuk simulasinya). Test ini yang menjaga supaya
    // tidak ada pilihan yang menunjuk id tidak ada — gejalanya halus:
    // dropdown-nya kelihatan normal, tapi dipilih pun tidak terjadi apa-apa.
    final html = File('web/index.html').readAsStringSync();
    final ids = RegExp(
      r'<option value="([a-z0-9-]+)"',
    ).allMatches(html).map((match) => match.group(1)!).toList();

    expect(ids, hasLength(greaterThan(5)), reason: 'pilihan tidak terbaca');
    for (final id in ids) {
      expect(
        previewPresetById(id),
        isNotNull,
        reason: '"$id" ada di web/index.html tapi tidak ada di DevicePresets',
      );
    }
  });
}
