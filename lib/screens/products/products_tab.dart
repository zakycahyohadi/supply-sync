import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/product_json.dart';
import '../../data/sales_repository.dart';
import '../../models/app_user.dart';
import '../../models/catalog_product.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/product_card.dart';
import 'product_form_screen.dart';
import 'product_import_dialog.dart';

/// Tab katalog produk untuk admin pusat.
class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key, required this.user, required this.products});

  final AppUser user;
  final List<CatalogProduct> products;

  void _openForm(BuildContext context, [CatalogProduct? product]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProductFormScreen(
          user: user,
          product: product,
          existingProducts: products,
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Future<void> _importJson(BuildContext context) async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
    } catch (_) {
      if (context.mounted) _showMessage(context, 'File tidak bisa dibuka.');
      return;
    }
    if (file == null || !context.mounted) return;

    final String text;
    try {
      text = utf8.decode(await file.readAsBytes());
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'File harus berupa teks JSON (UTF-8).');
      }
      return;
    }
    if (!context.mounted) return;

    final parsed = parseProductJson(text, existing: products);
    final confirmed = await showProductImportDialog(
      context,
      fileName: file.name,
      parsed: parsed,
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await SalesRepository.instance.saveProducts(
        user: user,
        products: [for (final item in parsed.products) item.product],
      );
      if (context.mounted) {
        _showMessage(
          context,
          'Import selesai: ${parsed.newCount} produk baru, '
          '${parsed.updateCount} diperbarui.',
        );
      }
    } catch (_) {
      if (context.mounted) _showMessage(context, 'Gagal menyimpan. Coba lagi.');
    }
  }

  Future<void> _downloadJson(BuildContext context) async {
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'produk.json',
        bytes: Uint8List.fromList(utf8.encode(encodeProductJson(products))),
        mimeType: 'application/json',
      );
      if (uri != null && context.mounted) {
        _showMessage(context, 'produk.json tersimpan.');
      }
    } catch (_) {
      if (context.mounted) _showMessage(context, 'File gagal disimpan.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final activeCount = products.where((p) => p.isActive).length;

    return PageBody(
      children: [
        Text(
          'Katalog produk',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Kode & nama di sini wajib sama dengan file XLSX admin toko, dan '
          'produk aktif tampil di homepage.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: () => _openForm(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Tambah produk'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _OutlineAction(
                icon: Icons.upload_file_rounded,
                label: 'Import JSON',
                onPressed: () => _importJson(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OutlineAction(
                icon: Icons.download_rounded,
                label: 'Unduh JSON',
                onPressed: products.isEmpty
                    ? null
                    : () => _downloadJson(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: '${products.length} produk',
          subtitle: '$activeCount aktif',
          icon: Icons.inventory_2_outlined,
          child: products.isEmpty
              ? const Text('Katalog masih kosong.')
              : Column(
                  children: [
                    for (var i = 0; i < products.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _ProductTile(
                        product: products[i],
                        onTap: () => _openForm(context, products[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: ProductImage(
                    imageUrl: product.imageUrl,
                    category: product.category,
                    iconSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: product.isActive
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '${product.code} · ${product.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${formatRupiah(product.price)} · min ${product.minStock}'
                      '${product.isActive ? '' : ' · Nonaktif'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_outlined, size: 20, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
