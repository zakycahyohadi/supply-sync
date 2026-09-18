import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/data/auth_repository.dart';
import 'package:supply_sync/data/chat_replies.dart';
import 'package:supply_sync/data/sales_repository.dart';
import 'package:supply_sync/data/stores.dart';
import 'package:supply_sync/main.dart';

import 'support/fake_auth_repository.dart';

void main() {
  setUp(() {
    AuthRepository.instance = FakeAuthRepository();
    SalesRepository.instance = InMemorySalesRepository();
  });

  group('autoReply', () {
    test('kata kunci stok', () {
      expect(autoReply('Stok iPhone 17 masih ada?'), contains('katalog'));
    });

    test('kata kunci lokasi menyebut semua toko', () {
      final reply = autoReply('tokonya di mana ya');
      for (final store in kStores) {
        expect(reply, contains(store));
      }
    });

    test('huruf besar-kecil tidak berpengaruh', () {
      expect(autoReply('GARANSI'), autoReply('garansi'));
    });

    test('pertanyaan di luar daftar tetap dijawab', () {
      final reply = autoReply('apakah kalian buka cabang di Mars');
      expect(reply, isNotEmpty);
      expect(reply, contains('katalog'));
    });

    test('tiap pertanyaan siap-pakai punya balasan yang cocok', () {
      for (final question in kChatQuickQuestions) {
        // Bukan jatuh ke balasan umum: tombolnya harus terasa dijawab.
        expect(
          autoReply(question),
          isNot(kChatFallbackReply),
          reason: question,
        );
      }
    });
  });

  testWidgets('customer: tombol chat membuka panel, pesan dibalas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Chat dengan kami'));
    await tester.pumpAndSettle();

    expect(find.text('Asisten Supply Sync'), findsOneWidget);
    expect(find.text(kChatGreeting), findsOneWidget);
    // Jelas ini balasan otomatis, bukan orang.
    expect(find.textContaining('Balasan otomatis'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stok iPhone 17 ada?');
    await tester.tap(find.bySemanticsLabel('Kirim'));
    await tester.pump();

    expect(find.text('stok iPhone 17 ada?'), findsOneWidget);
    expect(find.text('Sedang menulis…'), findsOneWidget);

    // Balasannya dijadwalkan lewat Timer; pumpAndSettle sendiri tidak
    // memajukan jam, jadi jedanya dilewati secara eksplisit.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.text('Sedang menulis…'), findsNothing);
    expect(find.text(autoReply('stok')), findsOneWidget);

    // Ditutup tanpa meninggalkan apa pun di halaman katalog.
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.text('Asisten Supply Sync'), findsNothing);
    expect(find.text('Gadget Apple terbaru'), findsOneWidget);
  });

  testWidgets('tombol pertanyaan siap-pakai langsung mengirim', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat dengan kami'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'Lokasi toko'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Lokasi toko'), findsOneWidget);
    expect(find.text(autoReply('Lokasi toko')), findsOneWidget);
    // Tombolnya hilang setelah percakapan mulai.
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('pesan kosong tidak terkirim', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chat dengan kami'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.bySemanticsLabel('Kirim'));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Sedang menulis…'), findsNothing);
    expect(find.byType(ActionChip), findsWidgets, reason: 'masih awal');
  });
}
