import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../models/sale_item.dart';
import '../../services/firestore_service.dart';
import '../../providers/expense_provider.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/custom_widgets.dart';
import 'widgets/add_item_bottom_sheet.dart';

/// Item Settings screen.
/// Section: Item Catalog with add/edit capabilities.
class ItemSettingsScreen extends StatefulWidget {
  const ItemSettingsScreen({super.key});

  @override
  State<ItemSettingsScreen> createState() => _ItemSettingsScreenState();
}

class _ItemSettingsScreenState extends State<ItemSettingsScreen> {
  // ── Firebase ──
  final _fs = FirestoreService();
  String? _userId;

  // ── Loading state ──
  bool _isLoading = true;

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
      final items = await _fs.watchSaleItems(_userId!).first;
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
    bool confirmed = false;
    await AppDialogs.showActionModal(
      context,
      title: 'Delete Item',
      body: 'Remove "${item.name}" from your catalog?',
      primaryButtonText: 'Delete',
      onPrimaryPressed: () => confirmed = true,
      secondaryButtonText: 'Cancel',
      onSecondaryPressed: () => confirmed = false,
      icon: Icons.delete_outline_rounded,
      iconColor: Colors.redAccent,
      primaryButtonColor: Colors.redAccent,
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
        title: const Text('Item Settings'),
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
                    'Item Settings',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your item catalog for faster sales checkout.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),

                  // ═══════════════════════════════
                  // Item Catalog
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
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
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 22,
                      ),
                      label: const Text('Add New Sale Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMedium,
                          ),
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
                    ..._items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildItemTile(theme, item),
                      ),
                    ),

                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildEmptyCatalogHint(theme),
                  ],

                  const SizedBox(height: 32),
                  _buildExpenseCategoriesSection(context),
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
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCategoriesSection(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final allCats = provider.categories;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    theme,
                    icon: Icons.category_outlined,
                    title: 'EXPENSE CATEGORIES',
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppTheme.primary,
                  ),
                  onPressed: () {
                    final controller = TextEditingController();
                    AppDialogs.showFormModal(
                      context,
                      title: 'Add Category',
                      formBody: AppTextField(
                        controller: controller,
                        hintText: 'e.g. Travel, Marketing',
                        textCapitalization: TextCapitalization.words,
                      ),
                      primaryButtonText: 'Add',
                      secondaryButtonText: 'Cancel',
                      onPrimaryPressed: () async {
                        final val = controller.text.trim();
                        if (val.isNotEmpty) {
                          await provider.addCategory(val);
                          return true;
                        }
                        return false;
                      },
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (allCats.isEmpty)
              Text(
                'No categories available. Add one using the button above.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),

            // Generate a list tile for every category
            ...allCats.map(
              (cat) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.folder_outlined,
                  color: theme.colorScheme.onSurface,
                ),
                title: Text(cat, style: theme.textTheme.bodyLarge),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        final controller = TextEditingController(text: cat);
                        AppDialogs.showFormModal(
                          context,
                          title: 'Edit Category',
                          formBody: AppTextField(
                            controller: controller,
                            hintText: 'Category Name',
                            textCapitalization: TextCapitalization.words,
                          ),
                          primaryButtonText: 'Update',
                          secondaryButtonText: 'Cancel',
                          onPrimaryPressed: () async {
                            final newVal = controller.text.trim();
                            if (newVal.isNotEmpty && newVal != cat) {
                              await provider.updateCategory(cat, newVal);
                              return true;
                            }
                            return false;
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () {
                        AppDialogs.showActionModal(
                          context,
                          title: 'Delete Category',
                          body:
                              'Are you sure you want to delete "$cat"? This will not affect existing records.',
                          primaryButtonText: 'Delete',
                          primaryButtonColor: Colors.redAccent,
                          secondaryButtonText: 'Cancel',
                          icon: Icons.warning_rounded,
                          iconColor: Colors.redAccent,
                          onPrimaryPressed: () {
                            provider.deleteCategory(cat);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
