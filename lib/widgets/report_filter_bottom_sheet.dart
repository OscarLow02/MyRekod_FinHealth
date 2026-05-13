import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';

class ReportFilterBottomSheet extends StatefulWidget {
  final String title;

  const ReportFilterBottomSheet({
    super.key,
    this.title = 'Generate Financial Report',
  });

  @override
  State<ReportFilterBottomSheet> createState() => _ReportFilterBottomSheetState();

  static Future<Map<String, DateTime>?> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportFilterBottomSheet(title: title ?? 'Generate Financial Report'),
    );
  }
}

class _ReportFilterBottomSheetState extends State<ReportFilterBottomSheet> {
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
        // Keep existing or set to null
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
        builder: (context, child) => _buildThemePicker(context, child!),
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
        builder: (context, child) => _buildThemePicker(context, child!),
      );
      if (selected != null) {
        setState(() {
          startDate = DateTime(selected.start.year, selected.start.month, selected.start.day);
          endDate = DateTime(selected.end.year, selected.end.month, selected.end.day, 23, 59, 59);
        });
      }
    }
  }

  Widget _buildThemePicker(BuildContext context, Widget child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          onPrimary: Colors.white,
        ),
      ),
      child: child,
    );
  }

  void _onConfirm() {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range')),
      );
      return;
    }
    Navigator.pop(context, {
      'start': startDate!,
      'end': endDate!,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Filter Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _filters.map((filter) {
                final isSelected = selectedFilter == filter;
                return ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        selectedFilter = filter;
                        _updateDatesForPreset(filter);
                      });
                    }
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Date Picker Trigger
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        startDate != null && endDate != null
                            ? (selectedFilter == 'Day'
                                ? DateFormat('dd MMM yyyy').format(startDate!)
                                : "${DateFormat('dd MMM yyyy').format(startDate!)} - ${DateFormat('dd MMM yyyy').format(endDate!)}")
                            : 'Select Date Range',
                        style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: theme.colorScheme.onSurfaceVariant, size: 18),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Button
            ElevatedButton(
              onPressed: _onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Generate PDF Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
