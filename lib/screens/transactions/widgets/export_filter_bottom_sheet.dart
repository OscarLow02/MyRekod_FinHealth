import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/sales_provider.dart';
import '../../../services/csv_export_service.dart';

class ExportFilterBottomSheet extends StatefulWidget {
  const ExportFilterBottomSheet({super.key});

  @override
  State<ExportFilterBottomSheet> createState() => _ExportFilterBottomSheetState();
}

class _ExportFilterBottomSheetState extends State<ExportFilterBottomSheet> {
  String selectedFilter = 'Month';
  DateTime? startDate;
  DateTime? endDate;

  final List<String> _filters = ['Day', 'Week', 'Month', 'Year', 'Custom'];

  @override
  void initState() {
    super.initState();
    _updateDatesForPreset(selectedFilter);
  }

  void _updateDatesForPreset(String filter) {
    final now = DateTime.now();
    switch (filter) {
      case 'Day':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'Week':
        final diff = now.weekday - 1;
        final startOfWeek = now.subtract(Duration(days: diff));
        startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        endDate = startDate!.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'Month':
        startDate = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        endDate = nextMonth.subtract(const Duration(seconds: 1));
        break;
      case 'Year':
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
      case 'Custom':
        startDate = null;
        endDate = null;
        break;
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    if (selectedFilter == 'Day') {
      final selected = await showDatePicker(
        context: context,
        initialDate: startDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (selected != null) {
        setState(() {
          startDate = DateTime(selected.year, selected.month, selected.day);
          endDate = DateTime(selected.year, selected.month, selected.day, 23, 59, 59);
        });
      }
    } else {
      final selected = await showDateRangePicker(
        context: context,
        initialDateRange: startDate != null && endDate != null
            ? DateTimeRange(start: startDate!, end: endDate!)
            : null,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (selected != null) {
        setState(() {
          startDate = DateTime(selected.start.year, selected.start.month, selected.start.day);
          endDate = DateTime(selected.end.year, selected.end.month, selected.end.day, 23, 59, 59);
        });
      }
    }
  }

  Future<void> _applyAndDownload() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }

    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final allSales = salesProvider.saleRecords;

    final filteredSales = allSales.where((s) => s.saleDate.isAfter(startDate!) && s.saleDate.isBefore(endDate!)).toList();

    if (filteredSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sales found for this period.')),
      );
      return;
    }

    String reportSuffix;
    if (selectedFilter == 'Day') {
      reportSuffix = DateFormat('yyyy_MM_dd').format(startDate!);
    } else if (selectedFilter == 'Month') {
      reportSuffix = DateFormat('MMM_yyyy').format(startDate!);
    } else if (selectedFilter == 'Year') {
      reportSuffix = DateFormat('yyyy').format(startDate!);
    } else {
      reportSuffix = "${DateFormat('yyyyMMdd').format(startDate!)}_to_${DateFormat('yyyyMMdd').format(endDate!)}";
    }

    await CsvExportService.exportBulkSalesToCSV(context, filteredSales, reportSuffix);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Export Sales Ledger',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _filters.map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: selectedFilter == filter,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedFilter = filter;
                        _updateDatesForPreset(filter);
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(
                startDate != null && endDate != null
                    ? (selectedFilter == 'Day'
                        ? DateFormat('dd MMM yyyy').format(startDate!)
                        : "${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}")
                    : 'Select Date Range',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _applyAndDownload,
              child: const Text('Apply and Download', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
