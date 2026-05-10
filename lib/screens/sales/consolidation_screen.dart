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

class _ConsolidationScreenState extends State<ConsolidationScreen> {
  final Set<String> _selectedSaleIds = {};
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final salesProvider = context.watch<SalesProvider>();
    final pendingRecords = salesProvider.pendingConsolidationRecords;

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
            title: const Text('Consolidate Sales'),
            actions: [
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
          body: pendingRecords.isEmpty
              ? _buildEmptyState(theme)
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
          bottomNavigationBar: _buildBottomBar(context, theme, selectedTotal, pendingRecords),
        ),
        if (_isSubmitting)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'All caught up!',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'No sales are pending consolidation.',
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
