import 'package:flutter/material.dart';

import '../models/catalog_product.dart';
import '../theme/app_colors.dart';
import '../utils/currency.dart';

/// Ikon per kategori produk.
IconData productCategoryIcon(String? category) =>
    switch (category?.toLowerCase()) {
      'iphone' => Icons.phone_iphone_rounded,
      'macbook' => Icons.laptop_mac_rounded,
      'apple watch' => Icons.watch_rounded,
      'audio' => Icons.headphones_rounded,
      'accessories' => Icons.cable_rounded,
      _ => Icons.inventory_2_outlined,
    };

/// Foto produk dari link; kalau kosong atau gagal dimuat, tampil ikon
/// kategori.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.category,
    this.iconSize = 44,
  });

  final String? imageUrl;
  final String? category;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: AppColors.navy.withValues(alpha: 0.04),
      child: Center(
        child: Icon(
          productCategoryIcon(category),
          size: iconSize,
          color: AppColors.navy.withValues(alpha: 0.25),
        ),
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return placeholder;

    return ColoredBox(
      color: Colors.white,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

/// Card produk di homepage: foto, nama, harga, stok, dan toko yang punya
/// stok. Data dari katalog di database.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final totalStock = product.totalStock;
    final stores = product.storesInStock;
    final badge = totalStock <= 0
        ? (label: 'Stok habis', color: AppColors.textSecondary)
        : totalStock <= product.minStock * 2
        ? (label: 'Stok terbatas', color: AppColors.trending)
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gambar mengisi sisa tinggi card, jadi teks di bawahnya selalu muat.
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageUrl: product.imageUrl,
                      category: product.category,
                    ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _StockBadge(
                          label: badge.label,
                          color: badge.color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatRupiah(product.price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    text: totalStock <= 0
                        ? 'Stok habis'
                        : 'Stok: $totalStock unit',
                    color: totalStock <= 0
                        ? AppColors.danger
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: stores.isEmpty
                        ? 'Belum tersedia di toko'
                        : stores.join(', '),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
