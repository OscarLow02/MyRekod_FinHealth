import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../models/sale_item.dart';
import '../../models/tax_config.dart';
import '../../core/lhdn_constants.dart';
import '../../services/firestore_service.dart';
import '../../widgets/custom_dropdown.dart';
import 'widgets/add_item_bottom_sheet.dart';

/// Item & Tax Settings screen.
/// Section 1: Global Tax Configuration (dropdown + fields).
/// Section 2: Item Catalog with add/edit capabilities.
class ItemTaxSettingsScreen extends StatefulWidget {
  const ItemTaxSettingsScreen({super.key});

  @override
  State<ItemTaxSettingsScreen> createState() => _ItemTaxSettingsScreenState();
}

class _ItemTaxSettingsScreenState extends State<ItemTaxSettingsScreen> {
  // ── Firebase ──
  final _fs = FirestoreService();
  String? _userId;

  // ── Loading / saving state ──
  bool _isLoading = true;
  bool _isSaving = false;

  // ── Tax Configuration State ──
  String _defaultTaxType = '06'; // '06' = Not Applicable
  final TextEditingController _taxRateCtrl = TextEditingController();
  final TextEditingController _taxExemptionCtrl = TextEditingController();

  // ── Item Catalog State (real-time via stream) ──
  List<SaleItem> _items = [];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Load tax config and items in parallel
      final results = await Future.wait([
        _fs.getTaxConfig(_userId!),
        _fs.watchSaleItems(_userId!).first,
      ]);
      final taxConfig = results[0] as TaxConfig;
      final items = results[1] as List<SaleItem>;
      if (mounted) {
        setState(() {
          _defaultTaxType = taxConfig.defaultTaxType;
          _taxRateCtrl.text = taxConfig.taxRate?.toString() ?? '';
          _taxExemptionCtrl.text = taxConfig.taxExemptionDetails ?? '';
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _taxRateCtrl.dispose();
    _taxExemptionCtrl.dispose();
    super.dispose();
  }

  bool get _isTaxEnabled => _defaultTaxType != '06';

  // ── Save tax config to Firestore ──
  Future<void> _saveTaxConfig() async {
    if (_userId == null) return;
    setState(() => _isSaving = true);
    try {
      final config = TaxConfig(
        defaultTaxType: _defaultTaxType,
        taxRate: _isTaxEnabled && _taxRateCtrl.text.isNotEmpty
            ? double.tryParse(_taxRateCtrl.text)
            : null,
        taxExemptionDetails: _taxExemptionCtrl.text.trim().isEmpty
            ? null
            : _taxExemptionCtrl.text.trim(),
      );
      await _fs.saveTaxConfig(_userId!, config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Tax settings saved!'),
              ],
            ),
            backgroundColor: AppTheme.neonGreenDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Open the Add/Edit Item sheet and persist result ──
  Future<void> _openAddItemSheet({SaleItem? existingItem}) async {
    if (_userId == null) return;
    final result = await showModalBottomSheet<SaleItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemBottomSheet(existingItem: existingItem),
    );

    if (result != null && mounted) {
      try {
        if (existingItem != null) {
          // Update existing item in Firestore
          await _fs.updateSaleItem(_userId!, result);
          setState(() {
            final idx = _items.indexWhere((e) => e.id == existingItem.id);
            if (idx != -1) _items[idx] = result;
          });
        } else {
          // Add new item to Firestore
          final saved = await _fs.addSaleItem(_userId!, result);
          setState(() => _items.add(saved));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save item: $e'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // ── Delete item from Firestore ──
  Future<void> _deleteItem(SaleItem item) async {
    if (_userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Remove "${item.name}" from your catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _fs.deleteSaleItem(_userId!, item.id);
      if (mounted) setState(() => _items.removeWhere((e) => e.id == item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppTheme.minTouchTarget,
              AppTheme.minTouchTarget,
            ),
          ),
        ),
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Page Title ──
            Text(
              'Item & Tax Settings',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure your business compliance and item catalog.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),

            // ═══════════════════════════════
            // Section 1: Tax Configuration
            // ═══════════════════════════════
            _buildSectionHeader(
              theme,
              icon: Icons.account_balance_outlined,
              title: 'GLOBAL TAX CONFIGURATION',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tax Type Dropdown
                  CustomPremiumDropdown<String>(
                    label: 'Default Tax Type',
                    items: CustomDropdownBuilder.fromMap(LhdnConstants.taxTypes, icon: Icons.percent_rounded),
                    value: _defaultTaxType,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _defaultTaxType = val;
                          if (val == '06') _taxRateCtrl.clear();
                        });
                      }
                    },
                    fillColor: theme.scaffoldBackgroundColor,
                    hint: 'Select Tax Type',
                  ),
                  const SizedBox(height: 20),

                  // Tax Rate
                  Text(
                    'Tax Rate',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Units/Rate chip
                      Expanded(
                        child: Container(
                          height: AppTheme.minTouchTarget,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isTaxEnabled
                                ? theme.scaffoldBackgroundColor
                                : theme.scaffoldBackgroundColor
                                    .withValues(alpha: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          child: TextField(
                            controller: _taxRateCtrl,
                            enabled: _isTaxEnabled,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _isTaxEnabled
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Units / Rate',
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // % Percentage chip
                      Container(
                        height: AppTheme.minTouchTarget,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isTaxEnabled
                              ? theme.scaffoldBackgroundColor
                              : theme.scaffoldBackgroundColor
                                  .withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Text(
                          '% Percentage',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            color: _isTaxEnabled
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tax Exemption Details
                  Text(
                    'Tax Exemption Details (Optional)',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _taxExemptionCtrl,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.description_outlined,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      hintText: 'e.g., Certificate Number',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Save Tax Config Button
            SizedBox(
              width: double.infinity,
              height: AppTheme.minTouchTarget + 4,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTaxConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(_isSaving ? 'SAVING…' : 'SAVE TAX SETTINGS'),
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
            const SizedBox(height: 32),

            // ═══════════════════════════════
            // Section 2: Item Catalog
            // ═══════════════════════════════
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    theme,
                    icon: Icons.inventory_2_outlined,
                    title: 'ITEM CATALOG',
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '${_items.length} ITEM${_items.length == 1 ? '' : 'S'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Add New Sale Item Button ──
            SizedBox(
              width: double.infinity,
              height: AppTheme.minTouchTarget + 8,
              child: ElevatedButton.icon(
                onPressed: () => _openAddItemSheet(),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                label: const Text('+ Add New Sale Item'),
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
            const SizedBox(height: 16),

            // ── Item List ──
            if (_items.isEmpty)
              _buildEmptyCatalog(theme)
            else
              ..._items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildItemTile(theme, item),
                  )),

            if (_items.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildEmptyCatalogHint(theme),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Section header with icon ──
  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Item tile ──
  Widget _buildItemTile(ThemeData theme, SaleItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'RM ${item.unitPrice.toStringAsFixed(2)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            onPressed: () => _openAddItemSheet(existingItem: item),
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: theme.colorScheme.onSurfaceVariant,
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AppTheme.minTouchTarget,
                AppTheme.minTouchTarget,
              ),
            ),
          ),
          // Delete button
          IconButton(
            onPressed: () => _deleteItem(item),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: Colors.redAccent.withValues(alpha: 0.7),
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AppTheme.minTouchTarget,
                AppTheme.minTouchTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty catalog placeholder ──
  Widget _buildEmptyCatalog(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to your menu to speed up\nsales checkout.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hint below item list ──
  Widget _buildEmptyCatalogHint(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.tune_rounded,
            size: 36,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 8),
          Text(
            'Add more items to your menu to speed up\nsales checkout.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 14,
              color:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
