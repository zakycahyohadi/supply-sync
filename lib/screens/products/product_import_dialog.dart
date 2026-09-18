import 'package:flutter/material.dart';

import '../../data/product_json.dart';
import '../../theme/app_colors.dart';
import '../../utils/currency.dart';

/// Ringkasan isi file JSON sebelum disimpan. Mengembalikan true kalau admin
/// menekan Simpan.
Future<bool?> showProductImportDialog(
  BuildContext context, {
  required String fileName,
  required ParsedProductJson parsed,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _ProductImportDialog(fileName: fileName, parsed: parsed),
  );
}

class _ProductImportDialog extends StatelessWidget {
  const _ProductImportDialog({required this.fileName, required this.parsed});

  final String fileName;
  final ParsedProductJson parsed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasIssues = parsed.issues.isNotEmpty;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Import produk'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              if (hasIssues)
                _Box(
                  color: AppColors.danger,
                  icon: Icons.error_outline_rounded,
                  title: '${parsed.issues.length} masalah, perbaiki file dulu',
                  lines: parsed.issues,
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: _Count(
                        value: parsed.newCount,
                        label: 'Produk baru',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Count(
                        value: parsed.updateCount,
                        label: 'Diperbarui',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final item in parsed.products)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${item.product.code} · ${item.product.category} · '
                                '${formatRupiah(item.product.price)}'
                                '${item.product.isActive ? '' : ' · nonaktif'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Tag(isNew: item.isNew),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: parsed.canSave
              ? () => Navigator.of(context).pop(true)
              : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          child: Text(
            parsed.canSave
                ? 'Simpan ${parsed.products.length} produk'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.isNew});

  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final color = isNew ? AppColors.statusGood : AppColors.navy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isNew ? 'Baru' : 'Update',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.color,
    required this.icon,
    required this.title,
    required this.lines,
  });

  final Color color;
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
