import 'package:flutter/foundation.dart';

import '../models/shipment.dart';

// Notifikasi admin toko dibaca dari data yang sudah ada (pengiriman dari
// pusat), bukan koleksi terpisah. Jadi begitu admin pusat menekan "kirim",
// lonceng di header admin toko langsung berubah tanpa perlu push notification.

/// Jenis notifikasi yang tampil di lonceng header.
enum AppNotificationKind {
  /// Pusat mengirim barang, menunggu dikonfirmasi admin toko.
  shipmentIncoming,

  /// Pengiriman sudah dikonfirmasi diterima.
  shipmentReceived,
}

/// Satu baris notifikasi.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.time,
    required this.shipment,
  });

  /// Tetap sama selama isinya tidak berubah, jadi bisa ditandai sudah dibaca.
  /// Status pengiriman ikut di dalam id: begitu barang dikonfirmasi, id-nya
  /// berganti dan notifikasinya dihitung sebagai yang baru.
  final String id;
  final AppNotificationKind kind;
  final String title;
  final String message;
  final DateTime time;
  final Shipment shipment;

  /// Masih menunggu tindakan admin toko. Hanya yang begini yang dihitung di
  /// badge lonceng; sisanya cuma riwayat.
  bool get needsAction => kind == AppNotificationKind.shipmentIncoming;
}

/// Notifikasi admin toko dari [shipments] tokonya, terbaru dulu.
List<AppNotification> buildStoreNotifications(List<Shipment> shipments) {
  final notifications = <AppNotification>[];
  for (final shipment in shipments) {
    final size =
        '${shipment.items.length} produk (${shipment.totalUnits} unit)';
    final receivedBy = shipment.receivedBy;
    notifications.add(switch (shipment.status) {
      ShipmentStatus.inTransit => AppNotification(
        id: 'shipment:${shipment.id}:${shipment.status.value}',
        kind: AppNotificationKind.shipmentIncoming,
        title: 'Pengiriman baru dari pusat',
        message:
            '$size sedang dikirim. Konfirmasi setelah barang sampai dan '
            'jumlahnya sesuai.',
        time: shipment.createdAt,
        shipment: shipment,
      ),
      ShipmentStatus.received => AppNotification(
        id: 'shipment:${shipment.id}:${shipment.status.value}',
        kind: AppNotificationKind.shipmentReceived,
        title: 'Pengiriman sudah diterima',
        message:
            '$size dikonfirmasi${receivedBy == null ? '' : ' $receivedBy'}. '
            'Stok toko sudah bertambah.',
        time: shipment.receivedAt ?? shipment.createdAt,
        shipment: shipment,
      ),
    });
  }
  return notifications..sort((a, b) => b.time.compareTo(a.time));
}

/// Catatan notifikasi yang sudah dibuka, per pengguna.
///
/// Hanya disimpan di memori: hilang kalau aplikasi ditutup. Cukup untuk
/// mematikan badge selama dipakai, dan pengiriman yang belum dikonfirmasi
/// tetap kelihatan di banner + bagian "Pengiriman dari pusat".
class NotificationReadStore extends ChangeNotifier {
  NotificationReadStore._();

  static final instance = NotificationReadStore._();

  final _seenByUser = <String, Set<String>>{};

  /// Notifikasi yang perlu tindakan dan belum pernah dibuka [userId].
  List<AppNotification> unread(
    String userId,
    List<AppNotification> notifications,
  ) {
    final seen = _seenByUser[userId] ?? const <String>{};
    return [
      for (final notification in notifications)
        if (notification.needsAction && !seen.contains(notification.id))
          notification,
    ];
  }

  /// Tandai [notifications] sudah dibaca [userId].
  void markRead(String userId, Iterable<AppNotification> notifications) {
    final seen = _seenByUser.putIfAbsent(userId, () => <String>{});
    final before = seen.length;
    seen.addAll(notifications.map((notification) => notification.id));
    if (seen.length != before) notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _seenByUser.clear();
    notifyListeners();
  }
}
