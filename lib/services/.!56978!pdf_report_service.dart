import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sale_record.dart';
import '../models/expense_record.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Transaction Data Transfer Object
// ──────────────────────────────────────────────────────────────────────────────

/// Lightweight DTO that flattens a [SaleRecord] or [ExpenseRecord] into a
/// single row for the PDF transaction table.
class _TransactionRow {
  final DateTime date;
  final String type; // 'Sale' or 'Expense'
  final String description;
  final double amount;

  const _TransactionRow({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
  });
}

// ──────────────────────────────────────────────────────────────────────────────
// PDF Report Service
// ──────────────────────────────────────────────────────────────────────────────

/// Generates a clean, printable monthly financial report as a PDF and triggers
/// the native share / print dialog via the `printing` package.
///
/// ### Features
/// - **Header** with business name, report title, and date range.
/// - **Summary block** showing Total Sales, Total Expenses, and Net Profit.
/// - **Transaction table** listing every sale and expense with automatic
///   multi-page breaks via [pw.MultiPage].
/// - **Footer** with page numbers and branding watermark.
///
/// ### Usage
/// ```dart
/// await PdfReportService.generateAndShareMonthlyReport(
///   businessName: profile.businessName,
///   totalSales: dashProv.totalMonthlySales,
///   totalExpenses: dashProv.totalMonthlyExpenses,
///   sales: salesProv.saleRecords,
///   expenses: expenseProv.expenses,
/// );
/// ```
class PdfReportService {
  PdfReportService._();

  // ── Brand Colour (mirrors AppTheme.primary) ────────────────────────────
  static const PdfColor _brandPurple = PdfColor.fromInt(0xFF5A51C4);
  static const PdfColor _brandPurpleLight = PdfColor.fromInt(0xFFEDE9FF);

  // ── Formatters ─────────────────────────────────────────────────────────
  static final _currencyFmt =
      NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _monthYearFmt = DateFormat('MMMM yyyy');

  // ════════════════════════════════════════════════════════════════════════
  // Public API
  // ════════════════════════════════════════════════════════════════════════

  /// Builds a financial report PDF for a specific period and opens the native share / print sheet.
  ///
  /// [businessName] – The display name shown in the report header.
  /// [totalSales]   – Pre-aggregated sales total for the period.
  /// [totalExpenses] – Pre-aggregated expenses total for the period.
  /// [sales]        – Full list of [SaleRecord]s (filtered internally).
  /// [expenses]     – Full list of [ExpenseRecord]s (filtered internally).
  /// [startDate]    – Start of the period. Defaults to start of current month if null.
  /// [endDate]      – End of the period. Defaults to end of current month if null.
  static Future<void> generateAndShareReport({
    required String businessName,
    required double totalSales,
    required double totalExpenses,
    List<SaleRecord> sales = const [],
    List<ExpenseRecord> expenses = const [],
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    // Default to current month if no range provided
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ??
        DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(seconds: 1));

    final netProfit = totalSales - totalExpenses;

    // ── Flatten transactions into table rows ──────────────────────────────
    final rows = _buildTransactionRows(
      sales: sales,
      expenses: expenses,
      startDate: start,
      endDate: end,
    );

    // ── Load Fonts (Fixes apostrophe rendering) ───────────────────────────
    final fontRegular = await PdfGoogleFonts.interRegular();
    final fontBold = await PdfGoogleFonts.interBold();

    // ── Load App Logo (best-effort) ───────────────────────────────────────
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData =
          await rootBundle.load('assets/App Logo.jpeg');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (e) {
      debugPrint('PdfReportService: Logo not found – $e');
    }

    // ── Build PDF Document ────────────────────────────────────────────────
    final pdf = pw.Document(
      title: 'Financial Report – $businessName',
      author: 'MyRekod FinHealth',
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (pw.Context ctx) => _buildPageHeader(
          businessName: businessName,
          startDate: start,
          endDate: end,
          logoImage: logoImage,
        ),
        footer: (pw.Context ctx) => _buildPageFooter(ctx),
        build: (pw.Context ctx) => [
          // ── Summary Block ────────────────────────────────────────────
          _buildSummaryBlock(
            totalSales: totalSales,
            totalExpenses: totalExpenses,
            netProfit: netProfit,
          ),
          pw.SizedBox(height: 24),

          // ── Transaction Table ────────────────────────────────────────
          _buildTransactionTable(rows),
        ],
      ),
    );

    // ── Trigger native share / print dialog ───────────────────────────────
    final fileName =
        'MyRekod_Report_${DateFormat('yyyyMMdd').format(start)}_to_${DateFormat('yyyyMMdd').format(end)}.pdf';

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: fileName,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Page Header
  // ════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildPageHeader({
    required String businessName,
    required DateTime startDate,
    required DateTime endDate,
    pw.MemoryImage? logoImage,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _brandPurple, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Left: Logo + Business name
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage != null) ...[
                pw.Image(logoImage, height: 36),
                pw.SizedBox(width: 12),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandPurple,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Monthly Financial Report',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Right: Report period
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                startDate.year == endDate.year && startDate.month == endDate.month
                    ? _monthYearFmt.format(startDate)
                    : '${_dateFmt.format(startDate)} - ${_dateFmt.format(endDate)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated: ${_dateFmt.format(DateTime.now())}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  // Page Footer
  // ════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildPageFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MyRekod FinHealth – Empowering Micro-SMEs',
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey400,
            ),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

