import 'package:flutter/material.dart';

import '../../models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';

/// Status pengiriman: ikon + label.
class ShipmentStatusChip extends StatelessWidget {
  const ShipmentStatusChip({super.key, required this.status});

  final ShipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ShipmentStatus.inTransit => (
        AppColors.navy,
        Icons.local_shipping_rounded,
      ),
      ShipmentStatus.received => (
        AppColors.statusGood,
        Icons.check_circle_rounded,
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu baris pengiriman di daftar.
class ShipmentTile extends StatelessWidget {
  const ShipmentTile({
    super.key,
    required this.shipment,
    this.showStore = true,
    this.onTap,
  });

  final Shipment shipment;
  final bool showStore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final productNames = shipment.items.map((i) => i.productName).join(', ');
    final receivedAt = shipment.receivedAt;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: shipment.status == ShipmentStatus.inTransit
                  ? AppColors.navy.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: AppColors.navy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showStore
                          ? 'Ke ${shipment.storeName}'
                          : '${shipment.items.length} produk · ${shipment.totalUnits} unit',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showStore
                          ? '${shipment.items.length} produk · ${shipment.totalUnits} unit · $productNames'
                          : productNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      receivedAt == null
                          ? 'Diajukan ${formatDateTime(shipment.createdAt)}'
                          : 'Diterima ${formatDateTime(receivedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ShipmentStatusChip(status: shipment.status),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar pengiriman; yang masih dalam perjalanan di atas.
class ShipmentList extends StatelessWidget {
  const ShipmentList({
    super.key,
    required this.shipments,
    required this.onOpen,
    this.showStore = true,
    this.emptyMessage = 'Belum ada pengiriman.',
  });

  final List<Shipment> shipments;
  final ValueChanged<Shipment> onOpen;
  final bool showStore;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (shipments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final sorted = [...shipments]
      ..sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        return byStatus != 0 ? byStatus : b.createdAt.compareTo(a.createdAt);
      });

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ShipmentTile(
            shipment: sorted[i],
            showStore: showStore,
            onTap: () => onOpen(sorted[i]),
          ),
        ],
      ],
    );
  }
}
