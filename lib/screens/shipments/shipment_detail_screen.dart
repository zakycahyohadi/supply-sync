import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/sales_repository.dart';
import '../../models/app_user.dart';
import '../../models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_format.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/shipment/shipment_tile.dart';
import '../../widgets/app_header.dart';
import '../../widgets/dashboard/spotlight.dart';

/// Detail pengiriman. Admin toko bisa mengonfirmasi barang sudah diterima.
class ShipmentDetailScreen extends StatefulWidget {
  const ShipmentDetailScreen({
    super.key,
    required this.user,
    required this.shipment,
  });

  final AppUser user;
  final Shipment shipment;

  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  late Shipment _shipment = widget.shipment;
  bool _isConfirming = false;

  bool get _canConfirm =>
      widget.user.role == UserRole.storeAdmin &&
      widget.user.storeName == _shipment.storeName &&
      _shipment.status == ShipmentStatus.inTransit;

  Future<void> _confirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Barang sudah diterima?'),
        content: Text(
          'Pastikan ${_shipment.items.length} produk (${_shipment.totalUnits} unit) '
          'sudah sampai dan jumlahnya sesuai. Stok toko akan langsung diperbarui.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ya, sesuai'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isConfirming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      await SalesRepository.instance.confirmShipment(
        user: widget.user,
        shipment: _shipment,
      );
      if (!mounted) return;
      setState(() {
        _shipment = _shipment.markReceived(
          by: widget.user.name,
          byEmail: widget.user.email,
          at: now,
        );
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengiriman dikonfirmasi. Stok sudah diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal konfirmasi. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shipment = _shipment;
    final textTheme = Theme.of(context).textTheme;
    final note = shipment.note;
    final receivedAt = shipment.receivedAt;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Detail Pengiriman',
        subtitle: 'Ke ${_shipment.storeName}',
        showBackButton: true,
      ),
      body: PageBody(
        maxWidth: 720,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: spotlightDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ke ${shipment.storeName}',
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${shipment.items.length} produk · ${shipment.totalUnits} unit',
                  style: textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                _Info(
                  icon: Icons.send_outlined,
                  text:
                      'Diajukan ${shipment.createdBy} · ${formatDateTime(shipment.createdAt)}',
                ),
                if (receivedAt != null) ...[
                  const SizedBox(height: 6),
                  _Info(
                    icon: Icons.task_alt_rounded,
                    text:
                        'Diterima ${shipment.receivedBy} · ${formatDateTime(receivedAt)}',
                  ),
                ],
                const SizedBox(height: 14),
                ShipmentStatusChip(status: shipment.status),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Catatan',
              icon: Icons.sticky_note_2_outlined,
              child: Text(note),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Barang dikirim',
            icon: Icons.inventory_2_outlined,
            child: Column(
              children: [
                for (final item in shipment.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Stok saat diajukan: ${item.stockBefore} unit',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${item.quantity} unit',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_canConfirm) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isConfirming ? null : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isConfirming
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.task_alt_rounded, size: 20),
                label: const Text('Konfirmasi barang diterima'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Buka detail pengiriman.
void openShipmentDetail(BuildContext context, AppUser user, Shipment shipment) {
  unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ShipmentDetailScreen(user: user, shipment: shipment),
      ),
    ),
  );
}
