import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/widgets/app_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('logo terdaftar sebagai aset dan ikut dibundel', () async {
    // Kalau pubspec.yaml lupa mendaftarkan assets/icon/, ini yang gagal
    // duluan — bukan layar yang mendadak kosong di perangkat.
    final bytes = await rootBundle.load(AppLogo.asset);
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
