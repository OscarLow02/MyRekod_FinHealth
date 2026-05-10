import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sale_record.dart';
import '../../providers/sales_provider.dart';
import '../../services/consolidation_service.dart';
import '../../core/app_theme.dart';
import '../../widgets/app_dialogs.dart';

class ConsolidationScreen extends StatefulWidget {
  const ConsolidationScreen({super.key});

  @override
  State<ConsolidationScreen> createState() => _ConsolidationScreenState();
}

class _ConsolidationScreenState extends State<ConsolidationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedSaleIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide Select All button
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salesProvider = context.watch<SalesProvider>();
    final pendingRecords = salesProvider.pendingConsolidationRecords;
    final historyRecords = salesProvider.consolidatedHistoryRecords;

    // Calculate total for selected items
    double selectedTotal = 0.0;
    for (var record in pendingRecords) {
      if (_selectedSaleIds.contains(record.id)) {
        selectedTotal += record.totalPayable;
      }
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Consolidation Dashboard'),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'History'),
              ],
            ),
            actions: [
              if (_tabController.index == 0 && pendingRecords.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedSaleIds.length == pendingRecords.length) {
                        _selectedSaleIds.clear();
                      } else {
                        _selectedSaleIds.addAll(pendingRecords.map((r) => r.id));
                      }
                    });
                  },
                  child: Text(_selectedSaleIds.length == pendingRecords.length ? 'Deselect All' : 'Select All'),
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Pending ──────────────────────────────────────────
              pendingRecords.isEmpty
                  ? _buildEmptyState(theme, 'All caught up!', 'No sales are pending consolidation.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pendingRecords.length,
                      itemBuilder: (context, index) {
                        final sale = pendingRecords[index];
                        final isSelected = _selectedSaleIds.contains(sale.id);
                        final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(sale.saleDate);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedSaleIds.add(sale.id);
                              } else {
                                _selectedSaleIds.remove(sale.id);
                              }
                            });
                          },
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sale.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                'RM ${sale.totalPayable.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('$dateStr\n${sale.customerName}'),
                          isThreeLine: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
                          checkColor: Colors.white,
                          activeColor: AppTheme.primary,
                        );
                      },
                    ),

              // ── Tab 2: History ──────────────────────────────────────────
              historyRecords.isEmpty
                  ? _buildEmptyState(theme, 'No History', 'Past consolidations will appear here.')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: historyRecords.length,
                      itemBuilder: (context, index) {
                        final sale = historyRecords[index];
                        final dateStr = DateFormat('MMM dd, yyyy • HH:mm').format(sale.saleDate);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(sale.invoiceNumber, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    Text(
                                      'RM ${sale.totalPayable.toStringAsFixed(2)}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.neonGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$dateStr • ${sale.customerName}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const Divider(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.link_rounded, size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Rolled into ${sale.consolidatedInvoiceRef}',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
          bottomNavigationBar: _tabController.index == 0 
              ? _buildBottomBar(context, theme, selectedTotal, pendingRecords)
              : null,
        ),
        if (_isSubmitting)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_edu_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ThemeData theme, double total, List<SaleRecord> allPending) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedSaleIds.length} Selected',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Total: RM ${total.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedSaleIds.isEmpty ? null : () => _submitConsolidation(context, allPending),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
              ),
              child: const Text('Submit Consolidated E-Invoice', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitConsolidation(BuildContext context, List<SaleRecord> allPending) async {
    setState(() => _isSubmitting = true);

    try {
      final selectedRecords = allPending.where((r) => _selectedSaleIds.contains(r.id)).toList();
      final success = await ConsolidationService().submitConsolidatedInvoice(selectedRecords);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        await AppDialogs.showSystemAlert(
          context,
          title: 'Success',
          body: 'Consolidated e-invoice has been submitted successfully.',
        );
        _selectedSaleIds.clear(); // Clear selection after success
        // Auto switch to history tab? Maybe not, keep them here or pop.
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit consolidated invoice. Please try again.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
