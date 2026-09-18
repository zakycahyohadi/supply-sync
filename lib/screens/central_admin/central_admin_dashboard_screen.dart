import 'package:flutter/material.dart';

import 'package:flutter/scheduler.dart';

import '../../data/ai/ai_forecast_repository.dart';
import '../../data/ai/forecast_payload.dart';
import '../../data/ai/forecast_widget_insights.dart';
import '../../data/insights_engine.dart';
import '../../data/sales_analytics.dart';
import '../../data/sales_repository.dart';
import '../../data/sales_widget_publisher.dart';
import '../../models/ai_forecast.dart';
import '../../models/app_user.dart';
import '../../models/catalog_product.dart';
import '../../models/sales_upload.dart';
import '../../models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../theme/store_colors.dart';
import '../../utils/currency.dart';
import '../../utils/date_format.dart';
import '../../widgets/charts/ranked_bars.dart';
import '../../widgets/charts/store_trend_chart.dart';
import '../../widgets/dashboard/ai_forecast_card.dart';
import '../../widgets/dashboard/dashboard_app_bar.dart';
import '../../widgets/dashboard/insight_list.dart';
import '../../widgets/dashboard/month_dropdown.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/product_movers.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/dashboard/stat_tile.dart';
import '../../widgets/dashboard/stock_level_tile.dart';
import '../../widgets/dashboard/store_filter_chips.dart';
import '../../widgets/dashboard/upload_list_tile.dart';
import '../../widgets/shipment/shipment_tile.dart';
import '../products/products_tab.dart';
import '../shipments/shipment_detail_screen.dart';
import '../shipments/shipment_request_screen.dart';
import '../upload_detail_screen.dart';

/// Rentang data yang dibaca dashboard: bulan ini + 11 bulan sebelumnya.
const kDashboardMonths = 12;
const kDashboardShipmentDays = 90;

/// Dashboard admin pusat: ringkasan penjualan, stok & pengiriman, dan data
/// yang di-upload semua toko.
class CentralAdminDashboardScreen extends StatefulWidget {
  const CentralAdminDashboardScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CentralAdminDashboardScreen> createState() =>
      _CentralAdminDashboardScreenState();
}

class _CentralAdminDashboardScreenState
    extends State<CentralAdminDashboardScreen> {
  static const _overviewTab = 0;
  static const _stockTab = 1;

  late final Stream<List<SalesUpload>> _uploads;
  late final Stream<List<Shipment>> _shipments;
  late final Stream<List<CatalogProduct>> _products;
  int _tabIndex = _overviewTab;

  /// Null = semua toko.
  String? _selectedStore;

  /// Null = bulan terbaru yang punya data.
  DateTime? _selectedMonth;

  /// Analisis AI untuk data yang sedang ditampilkan.
  ///
  /// [_forecastKey] adalah sidik jari data yang sedang/sudah dianalisis.
  /// Selama sidik jarinya sama, Gemini tidak dipanggil lagi — termasuk saat
  /// pindah tab atau ganti filter toko.
  String? _forecastKey;
  AiForecast? _forecast;
  String? _forecastError;
  bool _forecastLoading = false;

  @override
  void initState() {
    super.initState();
    final repository = SalesRepository.instance;
    final now = DateTime.now();
    _uploads = repository.watchUploads(
      since: DateTime(now.year, now.month - (kDashboardMonths - 1)),
    );
    _products = repository.watchProducts();
    _shipments = repository.watchShipments(
      since: DateTime(now.year, now.month, now.day - kDashboardShipmentDays),
    );
  }

  /// Mulai analisis kalau datanya berubah. Aman dipanggil dari `build`:
  /// panggilan sebenarnya dijadwalkan setelah frame selesai, pola yang sama
  /// dengan [SalesWidgetPublisher.publishLater].
  void _loadForecastLater(Map<String, Object?> payload) {
    final key = forecastFingerprint(payload);
    if (key == _forecastKey) return;
    _forecastKey = key;
    _forecast = null;
    _forecastError = null;
    _forecastLoading = true;
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      try {
        final forecast = await AiForecastRepository.instance.forecast(
          payload: payload,
          cacheKey: key,
        );
        // Data bisa berubah lagi selagi menunggu; hasil yang basi dibuang.
        if (!mounted || _forecastKey != key) return;
        setState(() {
          _forecast = forecast;
          _forecastLoading = false;
        });
      } on Object catch (error) {
        if (!mounted || _forecastKey != key) return;
        setState(() {
          _forecastError = error is AiForecastException
              ? error.message
              : 'Analisis AI gagal. Periksa koneksi internet.';
          _forecastLoading = false;
        });
      }
    });
  }

  void _retryForecast() {
    setState(() => _forecastKey = null);
  }

  void _selectStore(String? store) => setState(() => _selectedStore = store);

  void _selectMonth(DateTime month) => setState(() => _selectedMonth = month);

  void _openShipmentRequest(List<StockLevel> allLevels) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShipmentRequestScreen(
          user: widget.user,
          stockLevels: allLevels,
          initialStore: _selectedStore,
        ),
      ),
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
            final uploads = uploadsSnapshot.data;
            final shipments = shipmentsSnapshot.data;
            final hasError =
                uploadsSnapshot.hasError || shipmentsSnapshot.hasError;

            if (uploads == null || shipments == null) {
              return Scaffold(
                backgroundColor: AppColors.background,
                appBar: DashboardAppBar(user: widget.user),
                body: Center(
                  child: hasError
                      ? const Text(
                          'Gagal memuat data. Periksa koneksi internet.',
                        )
                      : const CircularProgressIndicator(),
                ),
              );
            }

            final records = latestRecords(uploads);
            final now = DateTime.now();
            final months = availableMonths(records);
            final month = months.contains(_selectedMonth)
                ? _selectedMonth!
                : months.isNotEmpty
                ? months.first
                : DateTime(now.year, now.month);
            final allStores = SalesAnalytics.from(
              records,
              month: month,
              shipments: shipments,
            );
            final analytics = _selectedStore == null
                ? allStores
                : SalesAnalytics.from(
                    records,
                    month: month,
                    storeName: _selectedStore,
                    shipments: shipments,
                  );
            final alertCount = allStores.stockAlerts.length;
            // Catatan otomatis (aturan if-else, bukan AI).
            final insights = buildInsights(
              records: records,
              stockLevels: allStores.stockLevels,
              month: month,
              storeName: _selectedStore,
            );
            // Analisis AI selalu memakai data semua toko, bukan filter yang
            // sedang aktif, supaya hasilnya sama untuk semua tampilan.
            if (allStores.hasData) {
              _loadForecastLater(
                buildForecastPayload(
                  analytics: allStores,
                  ruleInsights: buildInsights(
                    records: records,
                    stockLevels: allStores.stockLevels,
                    month: month,
                  ),
                ),
              );
            }
            final forecast = _forecast;

            // Widget home screen selalu memakai data terbaru semua toko.
            // Hasil AI ditaruh paling atas; sisanya catatan otomatis.
            SalesWidgetPublisher.publishLater(
              records,
              stockLevels: allStores.stockLevels,
              aiInsights: forecast == null
                  ? const []
                  : aiWidgetInsights(forecast),
            );

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: DashboardAppBar(user: widget.user),
              body: IndexedStack(
                index: _tabIndex,
                children: [
                  _OverviewTab(
                    user: widget.user,
                    analytics: analytics,
                    insights: insights,
                    forecast: forecast,
                    forecastLoading: _forecastLoading,
                    forecastError: _forecastError,
                    onRetryForecast: _retryForecast,
                    months: months,
                    onMonthChanged: _selectMonth,
                    selectedStore: _selectedStore,
                    onStoreChanged: _selectStore,
                    onSeeAllStock: () => setState(() => _tabIndex = _stockTab),
                    onRequestShipment: () =>
                        _openShipmentRequest(allStores.stockLevels),
                  ),
                  _StockTab(
                    user: widget.user,
                    analytics: analytics,
                    shipments: shipments,
                    selectedStore: _selectedStore,
                    onStoreChanged: _selectStore,
                    onRequestShipment: () =>
                        _openShipmentRequest(allStores.stockLevels),
                  ),
                  _UploadsTab(
                    uploads: uploads,
                    month: month,
                    months: months,
                    onMonthChanged: _selectMonth,
                    selectedStore: _selectedStore,
                    onStoreChanged: _selectStore,
                  ),
                  StreamBuilder<List<CatalogProduct>>(
                    stream: _products,
                    builder: (context, snapshot) {
                      final products = snapshot.data;
                      if (products == null) {
                        return Center(
                          child: snapshot.hasError
                              ? const Text('Gagal memuat katalog.')
                              : const CircularProgressIndicator(),
                        );
                      }
                      return ProductsTab(user: widget.user, products: products);
                    },
                  ),
                ],
              ),
              bottomNavigationBar: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: const Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.navy.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: NavigationBar(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (index) =>
                      setState(() => _tabIndex = index),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Ringkasan',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: alertCount > 0,
                        label: Text('$alertCount'),
                        child: const Icon(Icons.inventory_2_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: alertCount > 0,
                        label: Text('$alertCount'),
                        child: const Icon(Icons.inventory_2_rounded),
                      ),
                      label: 'Stok',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.table_chart_outlined),
                      selectedIcon: Icon(Icons.table_chart_rounded),
                      label: 'Upload',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.sell_outlined),
                      selectedIcon: Icon(Icons.sell_rounded),
                      label: 'Produk',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _RequestShipmentButton extends StatelessWidget {
  const _RequestShipmentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.local_shipping_outlined, size: 20),
        label: const Text('Ajukan pengiriman'),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.user,
    required this.analytics,
    required this.insights,
    required this.forecast,
    required this.forecastLoading,
    required this.forecastError,
    required this.onRetryForecast,
    required this.months,
    required this.onMonthChanged,
    required this.selectedStore,
    required this.onStoreChanged,
    required this.onSeeAllStock,
    required this.onRequestShipment,
  });

  final AppUser user;
  final SalesAnalytics analytics;
  final List<Insight> insights;
  final AiForecast? forecast;
  final bool forecastLoading;
  final String? forecastError;
  final VoidCallback onRetryForecast;
  final List<DateTime> months;
  final ValueChanged<DateTime> onMonthChanged;
  final String? selectedStore;
  final ValueChanged<String?> onStoreChanged;
  final VoidCallback onSeeAllStock;
  final VoidCallback onRequestShipment;

  static const _maxAlerts = 4;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = analytics.current;
    final previous = analytics.previous;
    final alerts = analytics.stockAlerts;
    final outCount = alerts.where((a) => a.status == StockStatus.out).length;

    return PageBody(
      children: [
        _PageHeader(
          title: 'Halo, ${user.name}',
          subtitle: months.isEmpty
              ? 'Belum ada data penjualan yang di-upload.'
              : 'Laporan penjualan bulanan Toko 1 & Toko 2.',
        ),
        const SizedBox(height: 16),
        if (months.isNotEmpty) ...[
          MonthDropdown(
            months: months,
            selected: analytics.month,
            onChanged: onMonthChanged,
          ),
          const SizedBox(height: 12),
        ],
        StoreFilterChips(
          selectedStore: selectedStore,
          onChanged: onStoreChanged,
        ),
        const SizedBox(height: 16),
        if (current == null)
          SectionCard(
            title: 'Belum ada data',
            icon: Icons.insights_outlined,
            child: Text(
              months.isEmpty
                  ? 'Ringkasan muncul setelah admin toko meng-upload data penjualan.'
                  : 'Belum ada data ${selectedStore ?? 'penjualan'} di '
                        '${formatMonthYear(analytics.month)}.',
            ),
          )
        else ...[
          Text(
            '${formatMonthYear(analytics.month)} · data ${formatPeriod(current.start, current.end)}'
            '${previous != null ? ' · dibanding ${formatPeriod(previous.start, previous.end)}' : ''}',
            style: textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          StatTileGrid(
            children: [
              StatTile(
                label: 'Omzet',
                value: formatCompactRupiah(current.revenue),
                icon: Icons.payments_outlined,
                deltaPercent: _change(current.revenue, previous?.revenue),
              ),
              StatTile(
                label: 'Unit terjual',
                value: formatThousands(current.quantity),
                icon: Icons.shopping_bag_outlined,
                deltaPercent: _change(current.quantity, previous?.quantity),
              ),
              StatTile(
                label: 'Stok habis',
                value: '$outCount produk',
                icon: Icons.remove_shopping_cart_outlined,
              ),
              StatTile(
                label: 'Stok menipis',
                value: '${alerts.length - outCount} produk',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          AiForecastCard(
            forecast: forecast,
            isLoading: forecastLoading,
            errorMessage: forecastError,
            onRetry: onRetryForecast,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Peringatan stok',
            subtitle:
                'Stok saat ini: habis, di bawah minimum, atau perkiraan habis < $kLowStockDays hari',
            icon: Icons.notifications_active_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StockLevelList(levels: alerts.take(_maxAlerts).toList()),
                if (alerts.length > _maxAlerts)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: onSeeAllStock,
                      child: Text(
                        'Lihat semua stok (${alerts.length} peringatan)',
                      ),
                    ),
                  ),
                if (analytics.restockCandidates.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _RequestShipmentButton(onPressed: onRequestShipment),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Insight penjualan',
            subtitle: 'Naik, turun, dan barang yang mengendap bulan ini',
            icon: Icons.lightbulb_outline_rounded,
            child: InsightList(
              insights: insights
                  .where(
                    (i) =>
                        i.kind == InsightKind.trendUp ||
                        i.kind == InsightKind.trendDown ||
                        i.kind == InsightKind.demand ||
                        i.kind == InsightKind.idle,
                  )
                  .toList(),
              maxItems: 5,
              emptyMessage: 'Penjualan bulan ini relatif stabil.',
            ),
          ),
          if (insights.any((i) => i.kind == InsightKind.transfer)) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Rekomendasi pindah barang',
              subtitle: 'Mengendap di satu toko, laris di toko lain',
              icon: Icons.swap_horiz_rounded,
              child: InsightList(
                insights: insights
                    .where((i) => i.kind == InsightKind.transfer)
                    .toList(),
                maxItems: 4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title:
                'Perkiraan kebutuhan '
                '${formatMonthYear(DateTime(analytics.month.year, analytics.month.month + 1))}',
            subtitle: 'Dari rata-rata 3 bulan terakhir dan arah trennya',
            icon: Icons.auto_graph_rounded,
            child: InsightList(
              insights: insights
                  .where((i) => i.kind == InsightKind.forecast)
                  .toList(),
              maxItems: 5,
              emptyMessage: 'Belum cukup data untuk memperkirakan kebutuhan.',
            ),
          ),
          SectionCard(
            title: 'Omzet harian',
            subtitle: selectedStore == null
                ? 'Per toko, ${formatMonthYear(analytics.month)} (Rp)'
                : '$selectedStore, ${formatMonthYear(analytics.month)} (Rp)',
            icon: Icons.show_chart_rounded,
            child: StoreTrendChart(
              days: analytics.days,
              revenueByStore: analytics.revenueByStoreDay,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Naik & turun',
            subtitle: 'Omzet produk dibanding periode sama bulan lalu',
            icon: Icons.swap_vert_rounded,
            child: ProductMovers(
              risers: analytics.risers,
              fallers: analytics.fallers,
            ),
          ),
          // Perbandingan antar toko hanya berguna kalau lebih dari satu toko.
          if (analytics.revenueByStore.length > 1) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Omzet per toko',
              subtitle: formatMonthYear(analytics.month),
              icon: Icons.storefront_outlined,
              child: RankedBars(
                items: [
                  for (final entry in analytics.revenueByStore)
                    RankedBarItem(
                      label: entry.key,
                      value: entry.value,
                      valueLabel: formatCompactRupiah(entry.value),
                      color: storeColor(entry.key),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Produk terlaris',
            subtitle: '${formatMonthYear(analytics.month)}, berdasarkan omzet',
            icon: Icons.local_fire_department_outlined,
            child: RankedBars(
              items: [
                for (final product in analytics.topProducts)
                  RankedBarItem(
                    label: product.productName,
                    detail: '${product.quantity} unit',
                    value: product.revenue,
                    valueLabel: formatCompactRupiah(product.revenue),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static double? _change(int current, int? previous) {
    if (previous == null || previous == 0) return null;
    return (current - previous) / previous * 100;
  }
}

class _StockTab extends StatelessWidget {
  const _StockTab({
    required this.user,
    required this.analytics,
    required this.shipments,
    required this.selectedStore,
    required this.onStoreChanged,
    required this.onRequestShipment,
  });

  final AppUser user;
  final SalesAnalytics analytics;
  final List<Shipment> shipments;
  final String? selectedStore;
  final ValueChanged<String?> onStoreChanged;
  final VoidCallback onRequestShipment;

  @override
  Widget build(BuildContext context) {
    final levels = analytics.stockLevels;
    final needsRestock = analytics.restockCandidates.length;
    final store = selectedStore;
    final storeShipments = store == null
        ? shipments
        : shipments.where((s) => s.storeName == store).toList();
    final inTransit = storeShipments
        .where((s) => s.status == ShipmentStatus.inTransit)
        .length;

    return PageBody(
      children: [
        const _PageHeader(
          title: 'Stok produk',
          subtitle:
              'Stok terakhir tiap toko (data upload + pengiriman yang sudah '
              'diterima). Yang paling mendesak di atas.',
        ),
        const SizedBox(height: 16),
        StoreFilterChips(
          selectedStore: selectedStore,
          onChanged: onStoreChanged,
        ),
        const SizedBox(height: 16),
        _RequestShipmentButton(onPressed: onRequestShipment),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Pengiriman',
          subtitle: inTransit == 0
              ? 'Tidak ada yang sedang dikirim'
              : '$inTransit menunggu konfirmasi toko',
          icon: Icons.local_shipping_outlined,
          child: ShipmentList(
            shipments: storeShipments,
            showStore: store == null,
            onOpen: (shipment) => openShipmentDetail(context, user, shipment),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '${levels.length} produk',
          subtitle: needsRestock == 0
              ? 'Semua stok aman'
              : '$needsRestock perlu dikirim',
          icon: Icons.inventory_2_outlined,
          child: StockLevelList(
            levels: levels,
            showStore: store == null,
            emptyMessage: 'Belum ada data stok.',
          ),
        ),
      ],
    );
  }
}

class _UploadsTab extends StatelessWidget {
  const _UploadsTab({
    required this.uploads,
    required this.month,
    required this.months,
    required this.onMonthChanged,
    required this.selectedStore,
    required this.onStoreChanged,
  });

  final List<SalesUpload> uploads;
  final DateTime month;
  final List<DateTime> months;
  final ValueChanged<DateTime> onMonthChanged;
  final String? selectedStore;
  final ValueChanged<String?> onStoreChanged;

  @override
  Widget build(BuildContext context) {
    final store = selectedStore;
    // Laporan untuk bulan terpilih (bulan yang dipilih admin toko saat upload).
    final filtered = uploads
        .where(
          (u) =>
              (store == null || u.storeName == store) && u.reportMonth == month,
        )
        .toList();

    return PageBody(
      children: [
        const _PageHeader(
          title: 'Data masuk',
          subtitle: 'File XLSX yang di-upload admin toko.',
        ),
        const SizedBox(height: 16),
        if (months.isNotEmpty) ...[
          MonthDropdown(
            months: months,
            selected: month,
            onChanged: onMonthChanged,
          ),
          const SizedBox(height: 12),
        ],
        StoreFilterChips(
          selectedStore: selectedStore,
          onChanged: onStoreChanged,
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Belum ada upload di bulan ini.')),
          )
        else
          for (final upload in filtered) ...[
            UploadListTile(
              upload: upload,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => UploadDetailScreen(upload: upload),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}
