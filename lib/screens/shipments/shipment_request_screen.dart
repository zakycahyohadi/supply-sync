import 'package:flutter/material.dart';

import '../../data/sales_analytics.dart';
import '../../data/sales_repository.dart';
import '../../data/stores.dart';
import '../../models/app_user.dart';
import '../../models/shipment.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/page_body.dart';
import '../../widgets/dashboard/section_card.dart';
import '../../widgets/dashboard/stock_status_chip.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_header.dart';

/// Form admin pusat untuk mengirim barang ke toko yang stoknya habis,
/// menipis, atau hampir menipis.
class ShipmentRequestScreen extends StatefulWidget {
  const ShipmentRequestScreen({
    super.key,
    required this.user,
    required this.stockLevels,
    this.initialStore,
  });

  final AppUser user;

  /// Stok semua toko saat form dibuka.
  final List<StockLevel> stockLevels;
  final String? initialStore;

  @override
  State<ShipmentRequestScreen> createState() => _ShipmentRequestScreenState();
}

class _ShipmentRequestScreenState extends State<ShipmentRequestScreen> {
  late String _store;
  bool _isPickerOpen = true;
  bool _isSubmitting = false;
  final _noteController = TextEditingController();

  /// Kode produk → jumlah kirim. Urutan = urutan dipilih.
  final _quantities = <String, int>{};

  @override
  void initState() {
    super.initState();
    _store = widget.initialStore ?? _storeWithMostNeeds();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _storeWithMostNeeds() {
    var best = kStores.first;
    var bestCount = -1;
    for (final store in kStores) {
      final count = _candidatesFor(store).length;
      if (count > bestCount) {
        best = store;
        bestCount = count;
      }
    }
    return best;
  }

  /// Produk yang bisa dipilih: habis, menipis, dan hampir menipis.
  List<StockLevel> _candidatesFor(String store) => widget.stockLevels
      .where((level) => level.storeName == store && level.status.needsRestock)
      .toList();

  List<StockLevel> get _candidates => _candidatesFor(_store);

  void _changeStore(String? store) {
    if (store == null || store == _store) return;
    setState(() {
      _store = store;
      _quantities.clear();
      _isPickerOpen = true;
    });
  }

  void _toggle(StockLevel level, bool selected) {
    setState(() {
      if (selected) {
        _quantities[level.productCode] = level.suggestedRestock;
      } else {
        _quantities.remove(level.productCode);
      }
    });
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      _quantities.clear();
      if (selectAll) {
        for (final level in _candidates) {
          _quantities[level.productCode] = level.suggestedRestock;
        }
      }
    });
  }

  void _changeQuantity(String productCode, int delta) {
    setState(() {
      final next = (_quantities[productCode] ?? 0) + delta;
      _quantities[productCode] = next.clamp(1, 999);
    });
  }

  Future<void> _submit() async {
    final levels = {for (final level in _candidates) level.productCode: level};
    final items = [
      for (final entry in _quantities.entries)
        ShipmentItem(
          productCode: entry.key,
          productName: levels[entry.key]!.productName,
          quantity: entry.value,
          stockBefore: levels[entry.key]!.stock,
        ),
    ];
    if (items.isEmpty) return;

    setState(() => _isSubmitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final shipment = await SalesRepository.instance.createShipment(
        user: widget.user,
        storeName: _store,
        items: items,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Pengiriman ke ${shipment.storeName} diajukan '
              '(${shipment.items.length} produk, ${shipment.totalUnits} unit). '
              'Admin toko sudah diberi tahu.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal mengajukan pengiriman. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    final selected = [
      for (final code in _quantities.keys)
        candidates.firstWhere((level) => level.productCode == code),
    ];
    final totalUnits = _quantities.values.fold(0, (sum, qty) => sum + qty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Ajukan Pengiriman',
        subtitle: 'Kirim stok dari pusat ke toko',
        showBackButton: true,
      ),
      body: PageBody(
        maxWidth: 720,
        children: [
          SectionCard(
            title: 'Toko tujuan',
            icon: Icons.storefront_outlined,
            child: DropdownButtonFormField<String>(
              initialValue: _store,
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                for (final store in kStores)
                  DropdownMenuItem(
                    value: store,
                    child: Text(
                      '$store · ${_candidatesFor(store).length} produk perlu dikirim',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _isSubmitting ? null : _changeStore,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Pilih produk',
            subtitle: 'Status habis, menipis, atau hampir menipis',
            icon: Icons.checklist_rounded,
            child: candidates.isEmpty
                ? const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.statusGood,
                      ),
                      SizedBox(width: 8),
                      Expanded(child: Text('Semua stok di toko ini aman.')),
                    ],
                  )
                : _ProductPicker(
                    candidates: candidates,
                    selectedCodes: _quantities.keys.toSet(),
                    isOpen: _isPickerOpen,
                    enabled: !_isSubmitting,
                    onOpenChanged: (open) =>
                        setState(() => _isPickerOpen = open),
                    onToggle: _toggle,
                    onToggleAll: _toggleAll,
                  ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: 'Jumlah kirim',
              subtitle: 'Sudah diisi saran supaya stok kembali aman',
              icon: Icons.inventory_outlined,
              child: Column(
                children: [
                  for (var i = 0; i < selected.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _SelectedProductCard(
                      level: selected[i],
                      quantity: _quantities[selected[i].productCode]!,
                      enabled: !_isSubmitting,
                      onChanged: (delta) =>
                          _changeQuantity(selected[i].productCode, delta),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              enabled: !_isSubmitting,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Catatan untuk toko (opsional)',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: selected.isEmpty || _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                selected.isEmpty
                    ? 'Pilih produk dulu'
                    : 'Submit · ${selected.length} produk, $totalUnits unit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown berisi checkbox produk.
class _ProductPicker extends StatelessWidget {
  const _ProductPicker({
    required this.candidates,
    required this.selectedCodes,
    required this.isOpen,
    required this.enabled,
    required this.onOpenChanged,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<StockLevel> candidates;
  final Set<String> selectedCodes;
  final bool isOpen;
  final bool enabled;
  final ValueChanged<bool> onOpenChanged;
  final void Function(StockLevel level, bool selected) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedCodes.length;
    final allSelected = selectedCount == candidates.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOpen ? AppColors.navy : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: enabled ? () => onOpenChanged(!isOpen) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: AppColors.navy,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selectedCount == 0
                          ? 'Pilih produk (${candidates.length} tersedia)'
                          : '$selectedCount dari ${candidates.length} produk dipilih',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: !isOpen
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      CheckboxListTile(
                        value: allSelected
                            ? true
                            : selectedCount == 0
                            ? false
                            : null,
                        tristate: true,
                        onChanged: enabled
                            ? (_) => onToggleAll(!allSelected)
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.navy,
                        title: const Text(
                          'Pilih semua',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      for (final level in candidates)
                        CheckboxListTile(
                          value: selectedCodes.contains(level.productCode),
                          onChanged: enabled
                              ? (value) => onToggle(level, value ?? false)
                              : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.navy,
                          title: Text(
                            level.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                StockStatusChip(status: level.status),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Sisa ${level.stock} unit'
                                    '${level.incoming > 0 ? ' · ${level.incoming} dikirim' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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

/// Kartu produk yang dipilih: nama, keterangan, dan tombol tambah/kurang.
class _SelectedProductCard extends StatelessWidget {
  const _SelectedProductCard({
    required this.level,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final StockLevel level;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final (statusColor, _) = stockStatusStyle(level.status);
    final minStock = level.minStock;

    // Garis warna status di kiri. Border dengan warna berbeda per sisi tidak
    // bisa digabung dengan sudut membulat, jadi garisnya ditumpuk di Stack.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: statusColor),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(
                  productCategoryIcon(level.category),
                  color: AppColors.navy,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${level.status.label} · sisa ${level.stock} unit'
                        '${minStock == null ? '' : ' (min $minStock)'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Saran kirim ${level.suggestedRestock} unit',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _QuantityStepper(
                  productName: level.productName,
                  quantity: quantity,
                  enabled: enabled,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.productName,
    required this.quantity,
    required this.enabled,
    required this.onChanged,
  });

  final String productName;
  final int quantity;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi $productName',
            onPressed: enabled && quantity > 1 ? () => onChanged(-1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tambah $productName',
            onPressed: enabled ? () => onChanged(1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
