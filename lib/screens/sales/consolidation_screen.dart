import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sale_record.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/app_dialogs.dart';
import '../../services/consolidation_service.dart';
import '../../core/app_theme.dart';

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
                  : () {
                      // Group records by their master reference
                      final Map<String, List<SaleRecord>> grouped = {};
                      for (var r in historyRecords) {
                        final ref = r.consolidatedInvoiceRef ?? 'Unknown';
                        grouped.putIfAbsent(ref, () => []).add(r);
                      }
                      final masterRefs = grouped.keys.toList();

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: masterRefs.length,
                        itemBuilder: (context, index) {
                          final masterRef = masterRefs[index];
                          final children = grouped[masterRef]!;
                          final totalAmount = children.fold(0.0, (sum, r) => sum + r.totalPayable);
                          // Use the date of the first child as a reference for the group
                          final dateStr = DateFormat('MMM dd, yyyy').format(children.first.saleDate);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 24),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Master Header
                                InkWell(
                                  onTap: () => _viewMasterPayload(context, masterRef),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.05),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.inventory_2_rounded, color: AppTheme.primary),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Master: $masterRef',
                                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '$dateStr • ${children.length} Invoices',
                                                style: theme.textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'RM ${totalAmount.toStringAsFixed(2)}',
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                            const Row(
                                              children: [
                                                Text('View JSON', style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                                SizedBox(width: 4),
                                                Icon(Icons.code_rounded, size: 14, color: AppTheme.primary),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(height: 1),
                                // Children List
                                ...children.map((sale) => ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.receipt_long_outlined, size: 18),
                                      title: Text(sale.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(sale.customerName),
                                      trailing: Text('RM ${sale.totalPayable.toStringAsFixed(2)}'),
                                    )),
                                const SizedBox(height: 8),
                              ],
                            ),
                          );
                        },
                      );
                    }(),
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
      final result = await ConsolidationService().submitConsolidatedInvoice(selectedRecords);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (result.success) {
        AppDialogs.showMockLhdnSuccessDialog(
          context,
          invoiceNumber: result.masterInvoiceNumber ?? 'N/A',
          totalAmount: result.totalAmount,
          isLhdnSubmitted: true, // Show mock LHDN QR code for consolidation
          onDone: () {
            Navigator.pop(context); // Close dialog
            _selectedSaleIds.clear(); // Clear selection after success
            if (mounted) Navigator.pop(context); // Go back to history/dashboard
          },
        );
      } else {
        AppDialogs.showSystemAlert(
          context,
          title: 'Submission Failed',
          body: result.error ?? 'Failed to submit consolidated invoice. Please try again.',
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppDialogs.showSystemAlert(
        context,
        title: 'Unexpected Error',
        body: e.toString(),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    }
  }

  Future<void> _viewMasterPayload(BuildContext context, String masterRef) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Show a quick loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 2. Fetch the Master Payload from Firestore
      final masterDoc = await FirebaseFirestore.instance
          .collection('business_profiles')
          .doc(user.uid)
          .collection('consolidated_invoices')
          .doc(masterRef)
          .get();

      // Pop the loading indicator
      if (context.mounted) Navigator.pop(context);

      if (masterDoc.exists && masterDoc.data() != null) {
        final rawPayload = masterDoc.data()!['payload'] as String;
        String formattedPayload = rawPayload;

        try {
          // Pretty print the JSON for better readability
          final dynamic jsonObject = jsonDecode(rawPayload);
          formattedPayload = const JsonEncoder.withIndent('  ').convert(jsonObject);
        } catch (e) {
          debugPrint('Error formatting JSON: $e');
        }

        // 3. Show the JSON Dialog
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Master Payload: $masterRef'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: SelectableText(
                    formattedPayload,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: formattedPayload));
                    Clipboard.setData(ClipboardData(text: formattedPayload));
                    if (context.mounted) {
                      AppDialogs.showSystemAlert(
                        context,
                        title: 'Copied',
                        body: 'Master Payload copied to clipboard.',
                        icon: Icons.copy_rounded,
                        iconColor: AppTheme.primary,
                      );
                    }
                  },
                  child: const Text('Copy'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                )
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Master payload not found in database.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching payload: $e')),
        );
      }
    }
  }
}
