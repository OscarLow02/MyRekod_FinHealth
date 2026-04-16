import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../models/sale_item.dart';
import '../../../core/lhdn_constants.dart';
import '../../../widgets/custom_dropdown.dart';

/// Modal bottom sheet for adding or editing a Sale Item.
/// Triggered from the Item Catalog section in ItemTaxSettingsScreen.
class AddItemBottomSheet extends StatefulWidget {
  /// If provided, sheet opens in "edit" mode with pre-filled data.
  final SaleItem? existingItem;

  const AddItemBottomSheet({super.key, this.existingItem});

  @override
  State<AddItemBottomSheet> createState() => _AddItemBottomSheetState();
}

class _AddItemBottomSheetState extends State<AddItemBottomSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late String _measurementUnit;
  late String _classificationCode;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.existingItem?.name ?? '',
    );
    _priceCtrl = TextEditingController(
      text: widget.existingItem != null
          ? widget.existingItem!.unitPrice.toStringAsFixed(2)
          : '',
    );
    _measurementUnit = widget.existingItem?.measurementUnit ?? 'C62';
    _classificationCode = widget.existingItem?.classificationCode ?? '022';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0.0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name.')),
      );
      return;
    }

    final item = SaleItem(
      id: widget.existingItem?.id ??
          'item_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      unitPrice: price,
      measurementUnit: _measurementUnit,
      classificationCode: _classificationCode,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXLarge),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag Handle ──
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),

          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Icon(
                  _isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Item' : 'Add New Item',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Provide item details for compliance',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  minimumSize: const Size(AppTheme.minTouchTarget, AppTheme.minTouchTarget),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Content ──
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Item Name ──
                  _buildFieldLabel(theme, 'ITEM NAME'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.shopping_bag_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      hintText: 'e.g., Burger Ayam',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Default Unit Price ──
                  _buildFieldLabel(theme, 'DEFAULT UNIT PRICE (RM)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.payments_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      hintText: '0.00',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  CustomPremiumDropdown<String>(
                    label: 'MEASUREMENT UNIT',
                    items: CustomDropdownBuilder.fromMap(LhdnConstants.unitOfMeasurement, icon: Icons.straighten_rounded),
                    value: _measurementUnit,
                    onChanged: (val) {
                      if (val != null) setState(() => _measurementUnit = val);
                    },
                    isSearchable: true,
                    hint: 'Select Unit',
                  ),
                  const SizedBox(height: 20),

                  CustomPremiumDropdown<String>(
                    label: 'LHDN CODE',
                    items: CustomDropdownBuilder.fromMap(LhdnConstants.classificationCodes, icon: Icons.policy_outlined),
                    value: _classificationCode,
                    onChanged: (val) {
                      if (val != null) setState(() => _classificationCode = val);
                    },
                    isSearchable: true,
                    hint: 'Select LHDN Code',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Save Button ──
          SizedBox(
            width: double.infinity,
            height: AppTheme.minTouchTarget + 8,
            child: ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: Text(_isEditing ? 'UPDATE ITEM' : 'SAVE ITEM'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Cancel Button ──
          SizedBox(
            width: double.infinity,
            height: AppTheme.minTouchTarget,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'CANCEL',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.primary,
      ),
    );
  }
}
