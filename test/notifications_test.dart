import 'package:flutter_test/flutter_test.dart';

import 'package:supply_sync/data/notifications.dart';
import 'package:supply_sync/models/shipment.dart';
import 'package:supply_sync/utils/date_format.dart';

Shipment _shipment({
  required String id,
  required ShipmentStatus status,
  required DateTime createdAt,
  DateTime? receivedAt,
}) => Shipment(
  id: id,
  storeName: 'Toko 1',
  status: status,
  items: const [
    ShipmentItem(
      productCode: 'IP17PM',
      productName: 'iPhone 17 Pro Max',
      quantity: 5,
      stockBefore: 0,
    ),
    ShipmentItem(
      productCode: 'IPAD11',
      productName: 'iPad 11',
      quantity: 3,
      stockBefore: 2,
    ),
  ],
  createdBy: 'Admin Pusat',
  createdByEmail: 'pusat@supply.id',
  createdAt: createdAt,
  receivedBy: receivedAt == null ? null : 'Admin Toko 1',
  receivedByEmail: receivedAt == null ? null : 'toko1@supply.id',
  receivedAt: receivedAt,
);

void main() {
  setUp(NotificationReadStore.instance.reset);

  group('buildStoreNotifications', () {
    test('pengiriman dalam perjalanan perlu tindakan', () {
      final notifications = buildStoreNotifications([
        _shipment(
          id: 'a',
          status: ShipmentStatus.inTransit,
          createdAt: DateTime(2026, 9, 18, 9),
        ),
      ]);

      expect(notifications, hasLength(1));
      final first = notifications.single;
      expect(first.kind, AppNotificationKind.shipmentIncoming);
      expect(first.title, 'Pengiriman baru dari pusat');
      expect(first.message, contains('2 produk (8 unit)'));
      expect(first.time, DateTime(2026, 9, 18, 9));
      expect(first.needsAction, isTrue);
    });

    test('pengiriman yang sudah diterima cuma riwayat', () {
      final notifications = buildStoreNotifications([
        _shipment(
          id: 'a',
          status: ShipmentStatus.received,
          createdAt: DateTime(2026, 9, 18, 9),
          receivedAt: DateTime(2026, 9, 18, 14),
        ),
      ]);

      final first = notifications.single;
      expect(first.kind, AppNotificationKind.shipmentReceived);
      expect(first.message, contains('Admin Toko 1'));
      // Waktunya ikut saat dikonfirmasi, bukan saat diajukan.
      expect(first.time, DateTime(2026, 9, 18, 14));
      expect(first.needsAction, isFalse);
    });

    test('id memuat status, jadi catatan "sudah dibaca" tidak nyangkut', () {
      final shipment = _shipment(
        id: 'a',
        status: ShipmentStatus.inTransit,
        createdAt: DateTime(2026, 9, 18, 9),
      );
      final received = shipment.markReceived(
        by: 'Admin Toko 1',
        byEmail: 'toko1@supply.id',
        at: DateTime(2026, 9, 18, 14),
      );

      expect(
        buildStoreNotifications([shipment]).single.id,
        'shipment:a:in_transit',
      );
      expect(
        buildStoreNotifications([received]).single.id,
        'shipment:a:received',
      );
    });

    test('urut dari yang terbaru', () {
      final notifications = buildStoreNotifications([
        _shipment(
          id: 'lama',
          status: ShipmentStatus.inTransit,
          createdAt: DateTime(2026, 9, 10),
        ),
        _shipment(
          id: 'baru',
          status: ShipmentStatus.inTransit,
          createdAt: DateTime(2026, 9, 17),
        ),
      ]);

      expect(notifications.map((n) => n.shipment.id), ['baru', 'lama']);
    });
  });

  group('NotificationReadStore', () {
    final notifications = buildStoreNotifications([
      _shipment(
        id: 'a',
        status: ShipmentStatus.inTransit,
        createdAt: DateTime(2026, 9, 17),
      ),
      _shipment(
        id: 'b',
        status: ShipmentStatus.received,
        createdAt: DateTime(2026, 9, 10),
        receivedAt: DateTime(2026, 9, 11),
      ),
    ]);

    test('yang belum dibaca hanya yang perlu tindakan', () {
      final unread = NotificationReadStore.instance.unread(
        'user-1',
        notifications,
      );
      expect(unread.map((n) => n.shipment.id), ['a']);
    });

    test('setelah ditandai dibaca, badge kosong', () {
      final store = NotificationReadStore.instance;
      store.markRead('user-1', notifications);

      expect(store.unread('user-1', notifications), isEmpty);
      // Pengguna lain tidak ikut terbaca.
      expect(store.unread('user-2', notifications), hasLength(1));
    });

    test('pengiriman baru muncul lagi walau yang lama sudah dibaca', () {
      final store = NotificationReadStore.instance;
      store.markRead('user-1', notifications);

      final withNewOne = buildStoreNotifications([
        ...notifications.map((n) => n.shipment),
        _shipment(
          id: 'c',
          status: ShipmentStatus.inTransit,
          createdAt: DateTime(2026, 9, 18),
        ),
      ]);
      expect(store.unread('user-1', withNewOne).map((n) => n.shipment.id), [
        'c',
      ]);
    });
  });

  group('formatRelativeTime', () {
    final now = DateTime(2026, 9, 18, 12);

    test('pilihan kata per rentang waktu', () {
      expect(formatRelativeTime(now, now: now), 'Baru saja');
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 menit lalu',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 jam lalu',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 1)), now: now),
        'Kemarin',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 3)), now: now),
        '3 hari lalu',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 30)), now: now),
        '19 Agu 2026',
      );
    });

    test('waktu di masa depan tidak jadi angka negatif', () {
      expect(
        formatRelativeTime(now.add(const Duration(minutes: 5)), now: now),
        'Baru saja',
      );
    });
  });
}
