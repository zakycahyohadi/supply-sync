import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/data/auth_repository.dart';
import 'package:supply_sync/data/notifications.dart';
import 'package:supply_sync/data/sales_repository.dart';
import 'package:supply_sync/data/sales_analytics.dart';
import 'package:supply_sync/data/sample_sales_data.dart';
import 'package:supply_sync/models/sales_upload.dart';
import 'package:supply_sync/widgets/dashboard/month_dropdown.dart';
import 'package:supply_sync/data/user_directory.dart';
import 'package:supply_sync/main.dart';
import 'package:supply_sync/screens/shipments/shipment_request_screen.dart';
import 'package:supply_sync/screens/upload_detail_screen.dart';
import 'package:supply_sync/utils/currency.dart';
import 'package:supply_sync/utils/date_format.dart';
import 'package:supply_sync/widgets/dashboard/stock_level_tile.dart';
import 'package:supply_sync/widgets/dashboard/upload_list_tile.dart';

import 'support/fake_auth_repository.dart';

const _phoneSizes = {'HP normal': Size(390, 844), 'HP kecil': Size(360, 640)};

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Buka app (lewat splash) sampai halaman publik tampil.
Future<void> _openApp(WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String email, String password) async {
  await tester.tap(find.text('Dashboard'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextField, 'Password'), password);
  await tester.tap(find.widgetWithText(FilledButton, 'LOGIN'));
  await tester.pumpAndSettle();
}

Future<void> _logout(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Akun'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Keluar'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Keluar'));
  await tester.pumpAndSettle();
}

/// Area scroll vertikal yang sedang terlihat (bukan chip filter horizontal).
Finder get _verticalScrollable => find
    .byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    )
    .hitTestable()
    .first;

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, [
  double delta = 300,
]) => tester.scrollUntilVisible(finder, delta, scrollable: _verticalScrollable);

Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  // Kolom teks yang masih fokus akan menggulir layar kembali ke dirinya.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _scrollTo(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthRepository.instance = FakeAuthRepository();
    SalesRepository.instance = InMemorySalesRepository();
    NotificationReadStore.instance.reset();
  });

  group('format', () {
    test('Rupiah', () {
      expect(formatRupiah(20000000), 'Rp20.000.000');
      expect(formatRupiah(450000), 'Rp450.000');
      expect(formatRupiah(0), 'Rp0');
      expect(formatCompactRupiah(245300000), 'Rp245,3 jt');
      expect(formatCompactRupiah(2500000), 'Rp2,5 jt');
      expect(formatCompactRupiah(19960000), 'Rp20 jt');
      expect(formatCompactRupiah(1250000000), 'Rp1,3 M');
      expect(formatPercent(8.43), '8,4%');
    });

    test('tanggal', () {
      expect(
        formatDateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 7)),
        '1–7 Sep 2026',
      );
      expect(
        formatDateRange(DateTime(2026, 9, 29), DateTime(2026, 10, 5)),
        '29 Sep – 5 Okt 2026',
      );
      expect(formatMonthYear(DateTime(2026, 8)), 'Agustus 2026');
    });
  });

  testWidgets('splash: tanpa sesi login ke halaman publik', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('SUPPLY SYNC'), findsOneWidget);
    expect(find.text('Dashboard'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('Katalog Produk'), findsOneWidget);
  });

  testWidgets('splash: sesi login tersimpan langsung ke dashboard', (
    tester,
  ) async {
    AuthRepository.instance = FakeAuthRepository(
      signedIn: appUserForEmail(id: 'p', email: 'pusat@supply.id'),
    );
    await _openApp(tester);

    expect(find.text('Halo, Admin Pusat'), findsOneWidget);
  });

  testWidgets('admin toko 2 hanya melihat data Toko 2', (tester) async {
    await _openApp(tester);
    await _login(tester, 'toko2@supply.id', '123456');

    expect(find.text('Halo, Admin Toko 2'), findsOneWidget);
    expect(find.text('Admin Toko · Toko 2'), findsOneWidget);
    await _scrollTo(tester, find.text('Riwayat upload'));
    expect(find.text('6 kali upload'), findsOneWidget);
  });

  testWidgets('password salah menampilkan pesan error', (tester) async {
    await _openApp(tester);
    await _login(tester, 'pusat@supply.id', 'salah');

    expect(find.text('Email atau password salah.'), findsOneWidget);
    expect(AuthRepository.instance.currentUser, isNull);
  });

  for (final MapEntry(key: name, value: size) in _phoneSizes.entries) {
    testWidgets('halaman publik tampil rapi ($name)', (tester) async {
      _setScreenSize(tester, size);
      await _openApp(tester);

      expect(find.text('Supply Sync'), findsOneWidget);
      expect(find.text('Katalog Produk'), findsOneWidget);
      // Produk dari katalog, lengkap dengan harga & stok per toko.
      await _scrollTo(tester, find.text('iPhone 17 Pro Max'), 200);
      expect(find.text('Rp24.999.000'), findsOneWidget);
      expect(find.textContaining('Stok: '), findsWidgets);

      // Filter kategori.
      await _scrollTo(tester, find.widgetWithText(ChoiceChip, 'MacBook'), -200);
      await tester.tap(find.widgetWithText(ChoiceChip, 'MacBook'));
      await tester.pumpAndSettle();
      expect(find.text('iPhone 17 Pro Max'), findsNothing);
      await _scrollTo(tester, find.text('MacBook Pro 14 M5'), 200);
    });

    testWidgets('admin pusat: ringkasan, stok, upload & detail ($name)', (
      tester,
    ) async {
      _setScreenSize(tester, size);
      await _openApp(tester);
      await _login(tester, 'pusat@supply.id', 'pusat123');

      expect(find.text('Halo, Admin Pusat'), findsOneWidget);
      expect(find.text('Omzet'), findsOneWidget);
      expect(find.text('Stok habis'), findsOneWidget);

      for (final section in [
        'Peringatan stok',
        'Ajukan pengiriman',
        'Omzet harian',
        'Naik & turun',
        'Omzet per toko',
        'Produk terlaris',
      ]) {
        await _scrollTo(tester, find.text(section));
      }

      // Filter satu toko: kartu perbandingan antar toko disembunyikan.
      await _scrollTo(tester, find.widgetWithText(ChoiceChip, 'Toko 2'), -300);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Toko 2'));
      await tester.pumpAndSettle();
      expect(find.text('Omzet per toko'), findsNothing);

      await tester.tap(find.text('Stok').last);
      await tester.pumpAndSettle();
      expect(find.text('Stok produk'), findsOneWidget);
      await _scrollTo(tester, find.text('8 produk'));

      await tester.tap(find.text('Upload').last);
      await tester.pumpAndSettle();
      expect(find.text('Data masuk'), findsOneWidget);

      await tester.tap(find.byType(UploadListTile).first);
      await tester.pumpAndSettle();
      expect(find.text('Detail Upload'), findsOneWidget);
      expect(find.text('Toko 2'), findsWidgets, reason: 'header & kartu');

      await tester.scrollUntilVisible(
        find.text('Lihat tabel'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(UploadDetailScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat tabel'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Senin, '), findsOneWidget);
    });

    testWidgets('admin toko: form upload xlsx, stok & riwayat ($name)', (
      tester,
    ) async {
      _setScreenSize(tester, size);
      await _openApp(tester);
      await _login(tester, 'toko1@supply.id', 'toko123');

      expect(find.text('Halo, Admin Toko 1'), findsOneWidget);
      expect(find.text('Upload data penjualan'), findsOneWidget);

      // Periode laporan: default bulan ini, bisa pilih bulan sebelumnya.
      final now = DateTime.now();
      final thisMonth = formatMonthYear(DateTime(now.year, now.month));
      final lastMonth = formatMonthYear(DateTime(now.year, now.month - 1));
      await _scrollTo(tester, find.text('Periode laporan'));
      await _scrollAndTap(tester, find.text(thisMonth));
      await tester.tap(find.text(lastMonth).last);
      await tester.pumpAndSettle();
      expect(find.text(lastMonth), findsWidgets);
      expect(
        find.textContaining('Semua tanggal di file harus di 1–'),
        findsOneWidget,
      );

      await _scrollTo(tester, find.text('Pilih file .xlsx'));
      await _scrollAndTap(tester, find.text('Kolom yang dibutuhkan'));
      await _scrollTo(tester, find.text('qty_terjual'), 200);

      await _scrollTo(tester, find.text('Stok perlu perhatian'));
      await _scrollTo(tester, find.text('Pengiriman dari pusat'));
      await _scrollTo(tester, find.text('Riwayat upload'));
      expect(find.text('6 kali upload'), findsOneWidget);
      await _scrollTo(tester, find.textContaining('Laporan ').first);
    });
  }

  testWidgets(
    'pengiriman: pusat ajukan → toko konfirmasi → stok kembali aman',
    (tester) async {
      _setScreenSize(tester, const Size(390, 844));
      await _openApp(tester);

      // 1. Admin pusat mengajukan pengiriman iPhone 17 Pro Max ke Toko 1.
      await _login(tester, 'pusat@supply.id', 'pusat123');
      await tester.tap(find.text('Stok').last);
      await tester.pumpAndSettle();
      await _scrollAndTap(tester, find.text('Ajukan pengiriman'));
      expect(find.text('Ajukan Pengiriman'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Toko 1 · ').last);
      await tester.pumpAndSettle();

      // Dropdown checkbox: habis, menipis, dan hampir menipis.
      expect(find.text('Pilih semua'), findsOneWidget);
      expect(find.text('Habis'), findsWidgets);
      expect(find.text('Hampir menipis'), findsWidgets);
      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'iPhone 17 Pro Max'),
      );
      await tester.pumpAndSettle();

      // Kartu produk muncul dengan tombol tambah/kurang.
      final addButton = find.byTooltip('Tambah iPhone 17 Pro Max');
      await _scrollAndTap(tester, addButton);
      await tester.tap(find.byTooltip('Kurangi iPhone 17 Pro Max'));
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.textContaining('Submit · 1 produk'));
      expect(find.byType(ShipmentRequestScreen), findsNothing);
      expect(
        find.textContaining('Pengiriman ke Toko 1 diajukan'),
        findsOneWidget,
      );
      await _scrollTo(tester, find.text('Dalam pengiriman'), 200);
      await _scrollTo(tester, find.text('Toko 1 · Sisa 0 unit (min 4)'));
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Toko 1 · Sisa 0 unit (min 4)'),
            matching: find.byType(StockLevelTile),
          ),
          matching: find.textContaining('sedang dikirim'),
        ),
        findsOneWidget,
      );
      await tester.drag(_verticalScrollable, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await _logout(tester);

      // 2. Admin toko melihat notifikasi lalu mengonfirmasi.
      await _login(tester, 'toko1@supply.id', 'toko123');
      expect(find.text('Ada pengiriman dari pusat'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byTooltip('Notifikasi'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      // Lonceng membuka panel notifikasi; dari situ langsung ke detail.
      await tester.tap(find.byTooltip('Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Pengiriman baru dari pusat'), findsOneWidget);
      await tester.tap(find.text('Pengiriman baru dari pusat'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Pengiriman'), findsOneWidget);
      await _scrollAndTap(tester, find.text('Konfirmasi barang diterima'));
      await tester.tap(find.text('Ya, sesuai'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi barang diterima'), findsNothing);
      expect(find.text('Diterima'), findsOneWidget);

      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Ada pengiriman dari pusat'), findsNothing);
      // Badge mati setelah panel dibuka, notifikasinya tinggal jadi riwayat.
      expect(
        find.descendant(
          of: find.byTooltip('Notifikasi'),
          matching: find.text('1'),
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Notifikasi'));
      await tester.pumpAndSettle();
      expect(find.text('Pengiriman sudah diterima'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      await _logout(tester);

      // 3. Admin pusat: stok iPhone 17 Pro Max Toko 1 sudah aman.
      await _login(tester, 'pusat@supply.id', 'pusat123');
      await tester.tap(find.text('Stok').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Toko 1'));
      await tester.pumpAndSettle();
      final tile = find.ancestor(
        of: find.text('iPhone 17 Pro Max'),
        matching: find.byType(StockLevelTile),
      );
      await _scrollTo(tester, tile);
      expect(
        find.descendant(of: tile, matching: find.text('Aman')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.textContaining('Sisa 12 unit'),
        ),
        findsOneWidget,
        reason: 'saran 12 unit, +1 lalu -1',
      );
    },
  );

  testWidgets('admin pusat memilih periode per bulan', (tester) async {
    _setScreenSize(tester, const Size(390, 844));
    final months = availableMonths(
      latestRecords(buildSampleSalesData(DateTime.now()).uploads),
    );
    expect(months.length, greaterThanOrEqualTo(2));
    final latest = formatMonthYear(months[0]);
    final older = formatMonthYear(months[1]);

    await _openApp(tester);
    await _login(tester, 'pusat@supply.id', 'pusat123');

    // Default: bulan terbaru.
    expect(find.text(latest), findsOneWidget);
    await _scrollTo(tester, find.text('Per toko, $latest (Rp)'));

    await _scrollTo(tester, find.byType(MonthDropdown), -300);
    await tester.tap(find.byType(MonthDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(older).last);
    await tester.pumpAndSettle();

    expect(find.text(older), findsOneWidget);
    await _scrollTo(tester, find.text('Per toko, $older (Rp)'));
    await _scrollTo(tester, find.text('$older, berdasarkan omzet'));

    // Tab Upload memakai bulan yang sama.
    await tester.tap(find.text('Upload').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MonthDropdown).hitTestable(),
        matching: find.text(older),
      ),
      findsOneWidget,
    );
  });

  testWidgets('admin pusat menambah produk → tampil di homepage', (
    tester,
  ) async {
    _setScreenSize(tester, const Size(390, 844));
    await _openApp(tester);
    await _login(tester, 'pusat@supply.id', 'pusat123');

    await tester.tap(find.text('Produk').last);
    await tester.pumpAndSettle();
    expect(find.text('Katalog produk'), findsOneWidget);
    expect(find.text('8 produk'), findsOneWidget);

    await tester.tap(find.text('Tambah produk'));
    await tester.pumpAndSettle();

    // Kode & nama yang sudah dipakai ditolak.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kode produk'),
      'ip17pm',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama produk'),
      'iphone 17 pro max',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Harga (Rp)'),
      '19999000',
    );
    // Tombol simpan di form (teks "Tambah produk" juga ada di halaman
    // belakangnya, jadi dicari lewat ikonnya).
    await _scrollAndTap(tester, find.byIcon(Icons.save_outlined));
    await _scrollTo(tester, find.text('Kode IP17PM sudah dipakai'), -300);
    expect(find.text('Nama ini sudah dipakai produk lain'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kode produk'),
      'ipair',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama produk'),
      'iPhone Air',
    );
    // Tombol simpan di form (teks "Tambah produk" juga ada di halaman
    // belakangnya, jadi dicari lewat ikonnya).
    await _scrollAndTap(tester, find.byIcon(Icons.save_outlined));
    expect(find.text('iPhone Air ditambahkan ke katalog.'), findsOneWidget);
    expect(find.text('9 produk'), findsOneWidget);

    await _logout(tester);
    await _scrollTo(tester, find.text('iPhone Air'), 200);
    expect(find.text('Rp19.999.000'), findsOneWidget);
    expect(find.text('Belum tersedia di toko'), findsWidgets);
  });

  testWidgets('logout kembali ke halaman publik', (tester) async {
    await _openApp(tester);
    await _login(tester, 'toko1@supply.id', 'toko123');
    await _logout(tester);

    expect(find.text('Katalog Produk'), findsOneWidget);
    expect(AuthRepository.instance.currentUser, isNull);
  });
}
