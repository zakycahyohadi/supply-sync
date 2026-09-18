import 'package:flutter/material.dart';

import '../../data/insights_engine.dart';
import '../../data/notifications.dart';
import '../../data/sales_analytics.dart';
import '../../data/sales_repository.dart';
import '../../models/app_user.dart';
import '../../models/sales_upload.dart';
import '../../models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/dashboard/dashboard_app_bar.dart';
import '../../widgets/dashboard/insight_list.dart';
import '../../widgets/dashboard/notification_sheet.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/dashboard/stock_level_tile.dart';
import '../../widgets/dashboard/upload_list_tile.dart';
import '../../widgets/shipment/shipment_tile.dart';
import '../../widgets/upload/xlsx_upload_card.dart';
import '../shipments/shipment_detail_screen.dart';
import '../upload_detail_screen.dart';
import '../../widgets/dashboard/spotlight.dart';

/// Halaman admin toko: pengiriman masuk, upload data penjualan (.xlsx),
/// stok tokonya, dan riwayat upload.
class StoreAdminHomeScreen extends StatefulWidget {
  const StoreAdminHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<StoreAdminHomeScreen> createState() => _StoreAdminHomeScreenState();
}

class _StoreAdminHomeScreenState extends State<StoreAdminHomeScreen> {
  late final Stream<List<SalesUpload>> _uploads;
  late final Stream<List<Shipment>> _shipments;
  final _shipmentsKey = GlobalKey();

  String get _storeName => widget.user.storeName ?? '';

  @override
  void initState() {
    super.initState();
    final repository = SalesRepository.instance;
    final now = DateTime.now();
    // 4 bulan: cukup untuk membandingkan bulan ini dengan 2 bulan sebelumnya.
    _uploads = repository.watchUploads(
      storeName: _storeName,
      since: DateTime(now.year, now.month - 3),
    );
    _shipments = repository.watchShipments(
      storeName: _storeName,
      since: DateTime(now.year, now.month, now.day - 90),
    );
    // Badge lonceng ikut mati begitu panel notifikasi dibuka.
    NotificationReadStore.instance.addListener(_onReadStoreChanged);
  }

  @override
  void dispose() {
    NotificationReadStore.instance.removeListener(_onReadStoreChanged);
    super.dispose();
  }

  void _onReadStoreChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToShipments() {
    final shipmentsContext = _shipmentsKey.currentContext;
    if (shipmentsContext == null) return;
    Scrollable.ensureVisible(
      shipmentsContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// Buka panel notifikasi, lalu tandai semuanya sudah dibaca supaya badge
  /// lonceng mati. Titik merah per baris tetap dipakai sekali ini, jadi yang
  /// baru masih kelihatan di panel yang sedang dibuka.
  void _openNotifications(List<AppNotification> notifications) {
    final readStore = NotificationReadStore.instance;
    final unreadIds = {
      for (final notification in readStore.unread(
        widget.user.id,
        notifications,
      ))
        notification.id,
    };
    readStore.markRead(widget.user.id, notifications);
    showNotificationSheet(
      context: context,
      notifications: notifications,
      unreadIds: unreadIds,
      onOpen: (notification) =>
          openShipmentDetail(context, widget.user, notification.shipment),
      onSeeAll: _scrollToShipments,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SalesUpload>>(
      stream: _uploads,
      builder: (context, uploadsSnapshot) {
        return StreamBuilder<List<Shipment>>(
          stream: _shipments,
          builder: (context, shipmentsSnapshot) {
            final uploads = uploadsSnapshot.data ?? const <SalesUpload>[];
            final shipments = shipmentsSnapshot.data ?? const <Shipment>[];
            final pending = shipments
                .where((s) => s.status == ShipmentStatus.inTransit)
                .toList();
            final records = latestRecords(uploads);
            final stockLevels = computeStockLevels(
              records,
              shipments: shipments,
            );
            final restock = stockLevels
                .where((level) => level.status.needsRestock)
                .toList();
            final now = DateTime.now();
            final insights = buildInsights(
              records: records,
              stockLevels: stockLevels,
              month: DateTime(now.year, now.month),
              storeName: _storeName,
            );
            final notifications = buildStoreNotifications(shipments);
            final unread = NotificationReadStore.instance.unread(
              widget.user.id,
              notifications,
            );

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: DashboardAppBar(
                user: widget.user,
                notificationCount: unread.length,
                onNotificationsTap: () => _openNotifications(notifications),
              ),
              body: PageBody(
                maxWidth: 720,
                children: [
                  _WelcomeCard(
                    user: widget.user,
                    uploadCount: uploads.length,
                    restockCount: restock.length,
                  ),
                  if (pending.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _IncomingShipmentsBanner(
                      shipments: pending,
                      onOpen: (shipment) =>
                          openShipmentDetail(context, widget.user, shipment),
                    ),
                  ],
                  const SizedBox(height: 16),
                  XlsxUploadCard(user: widget.user),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Stok perlu perhatian',
                    subtitle: 'Habis, menipis, atau hampir menipis',
                    icon: Icons.notifications_active_outlined,
                    child: StockLevelList(levels: restock, showStore: false),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Insight & perkiraan',
                    subtitle: 'Catatan otomatis dari data $_storeName',
                    icon: Icons.lightbulb_outline_rounded,
                    child: InsightList(
                      insights: insights,
                      maxItems: 5,
                      emptyMessage:
                          'Belum ada catatan. Upload data penjualan dulu.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    key: _shipmentsKey,
                    title: 'Pengiriman dari pusat',
                    subtitle: pending.isEmpty
                        ? 'Tidak ada yang menunggu konfirmasi'
                        : '${pending.length} menunggu konfirmasi',
                    icon: Icons.local_shipping_outlined,
                    child: ShipmentList(
                      shipments: shipments,
                      showStore: false,
                      onOpen: (shipment) =>
                          openShipmentDetail(context, widget.user, shipment),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionCard(
                    title: 'Riwayat upload',
                    subtitle: '${uploads.length} kali upload',
                    icon: Icons.history_rounded,
                    child: uploads.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text('Belum ada data yang di-upload.'),
                          )
                        : _UploadHistory(uploads: uploads),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Notifikasi pengiriman yang perlu dikonfirmasi.
class _IncomingShipmentsBanner extends StatelessWidget {
  const _IncomingShipmentsBanner({
    required this.shipments,
    required this.onOpen,
  });

  final List<Shipment> shipments;
  final ValueChanged<Shipment> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final first = shipments.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  shipments.length == 1
                      ? 'Ada pengiriman dari pusat'
                      : '${shipments.length} pengiriman dari pusat',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${first.items.length} produk (${first.totalUnits} unit) sedang '
            'dikirim. Konfirmasi setelah barang sampai dan jumlahnya sesuai.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () => onOpen(first),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Lihat & konfirmasi'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.user,
    required this.uploadCount,
    required this.restockCount,
  });

  final AppUser user;
  final int uploadCount;
  final int restockCount;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: spotlightDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, ${user.name}',
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Upload data penjualan ${user.storeName} dalam format .xlsx. '
            'Data langsung masuk ke dashboard admin pusat.',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SpotlightStat(
                  label: 'Kali upload',
                  value: '$uploadCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SpotlightStat(
                  label: 'Stok perlu dicek',
                  value: '$restockCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Riwayat upload dikelompokkan per bulan laporan, bulan terbaru dulu.
class _UploadHistory extends StatelessWidget {
  const _UploadHistory({required this.uploads});

  final List<SalesUpload> uploads;

  @override
  Widget build(BuildContext context) {
    final byMonth = <DateTime, List<SalesUpload>>{};
    for (final upload in uploads) {
      byMonth.putIfAbsent(upload.reportMonth, () => []).add(upload);
    }
    final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, month) in months.indexed) ...[
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 16, bottom: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: AppColors.navy,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: formatMonthYear(month),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      children: [
                        TextSpan(
                          text: '  ·  ${byMonth[month]!.length} upload',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final (i, upload) in byMonth[month]!.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            UploadListTile(
              upload: upload,
              showStore: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => UploadDetailScreen(upload: upload),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
