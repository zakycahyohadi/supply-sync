import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sales_repository.dart';
import '../data/stores.dart';
import '../models/catalog_product.dart';
import '../theme/app_colors.dart';
import '../widgets/login_dialog.dart';
import '../widgets/product_card.dart';
import 'app_navigation.dart';
import '../widgets/app_header.dart';
import '../widgets/chat/chat_sheet.dart';
import '../widgets/dashboard/spotlight.dart';

/// Halaman utama untuk customer/public, bisa diakses tanpa login.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  late Stream<List<CatalogProduct>> _products;

  /// Null = semua kategori.
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _products = SalesRepository.instance.watchProducts();
  }

  void _reloadProducts() {
    setState(() {
      _products = SalesRepository.instance.watchProducts();
    });
  }

  Future<void> _openLogin() async {
    final user = await LoginDialog.show(context);
    if (user == null || !mounted) return;
    openHomeForUser(context, user);
  }

  void _openChat() => unawaited(showChatSheet(context));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Supply Sync',
        subtitle: 'Katalog produk',
        actions: [_DashboardButton(onPressed: _openLogin)],
      ),
      body: StreamBuilder<List<CatalogProduct>>(
        stream: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Gagal memuat produk.'),
                  TextButton(
                    onPressed: _reloadProducts,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducts = data.where((p) => p.isActive).toList();
          final categories = {
            for (final product in allProducts) product.category,
          }.toList();
          final category = _selectedCategory;
          final products = category == null
              ? allProducts
              : allProducts.where((p) => p.category == category).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverList.list(
                      children: [
                        _HeroCard(products: allProducts),
                        const SizedBox(height: 24),
                        const _SectionHeader(),
                        const SizedBox(height: 12),
                        _CategoryChips(
                          categories: categories,
                          selected: _selectedCategory,
                          onChanged: (value) =>
                              setState(() => _selectedCategory = value),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  if (products.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            category == null
                                ? 'Belum ada produk di katalog.'
                                : 'Belum ada produk $category.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      // Padding bawah memberi ruang supaya card terakhir
                      // tidak tertutup tombol WhatsApp.
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;
                          final columns = width >= 900
                              ? 4
                              : width >= 600
                              ? 3
                              : 2;
                          return SliverGrid.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  mainAxisExtent: 280,
                                ),
                            itemCount: products.length,
                            itemBuilder: (context, index) =>
                                ProductCard(product: products[index]),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openChat,
        tooltip: 'Chat dengan kami',
        backgroundColor: AppColors.whatsapp,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.chat),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.products});

  final List<CatalogProduct> products;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final availableCount = products.where((p) => p.totalStock > 0).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: spotlightDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gadget Apple terbaru',
            style: textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'iPhone, MacBook, dan Apple Watch. Cek harga & stok di semua toko kami.',
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
                  value: '${products.length}',
                  label: 'Produk',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SpotlightStat(value: '${kStores.length}', label: 'Toko'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SpotlightStat(
                  value: '$availableCount',
                  label: 'Tersedia',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            size: 20,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Katalog Produk',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Stok diperbarui dari data setiap toko',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final category in <String?>[null, ...categories]) ...[
            ChoiceChip(
              label: Text(category ?? 'Semua'),
              selected: selected == category,
              onSelected: (_) => onChanged(category),
              showCheckmark: false,
              avatar: category == null
                  ? null
                  : Icon(
                      productCategoryIcon(category),
                      size: 16,
                      color: selected == category
                          ? Colors.white
                          : AppColors.navy,
                    ),
              selectedColor: AppColors.navy,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: selected == category
                    ? Colors.white
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected == category ? AppColors.navy : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// Tombol masuk ke dashboard: pill putih supaya menonjol di header navy.
class _DashboardButton extends StatelessWidget {
  const _DashboardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      icon: const Icon(Icons.space_dashboard_rounded, size: 18),
      label: const Text('Dashboard'),
    );
  }
}
