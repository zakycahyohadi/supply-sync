import 'package:flutter/material.dart';

import '../../data/stores.dart';
import '../../theme/app_colors.dart';
import '../../theme/store_colors.dart';

/// Chip filter toko ("Semua toko", "Toko 1", ...). Null = semua toko.
class StoreFilterChips extends StatelessWidget {
  const StoreFilterChips({
    super.key,
    required this.selectedStore,
    required this.onChanged,
  });

  final String? selectedStore;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <String?>[null, ...kStores];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final store in options) ...[
            ChoiceChip(
              label: Text(store ?? 'Semua toko'),
              selected: selectedStore == store,
              onSelected: (_) => onChanged(store),
              showCheckmark: false,
              avatar: store == null
                  ? null
                  : CircleAvatar(backgroundColor: storeColor(store), radius: 4),
              selectedColor: AppColors.navy,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: selectedStore == store
                    ? Colors.white
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selectedStore == store
                    ? AppColors.navy
                    : AppColors.border,
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
