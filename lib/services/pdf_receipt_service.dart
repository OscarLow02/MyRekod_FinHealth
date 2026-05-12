import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, RenderBox, Offset;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/sale_record.dart';
import '../models/business_profile.dart';
import '../core/lhdn_constants.dart';

/// Service to generate professional PDF receipts and share them via native share sheet.
class PdfReceiptService {
  static Future<void> generateAndShareReceipt(
    SaleRecord sale,
    BusinessProfile profile,
    BuildContext context,
  ) async {
    final pdf = pw.Document();

    // Load App Logo
    pw.MemoryImage? logoImage;
    try {
      final ByteData logoData = await rootBundle.load('assets/App Logo.jpeg');
      final Uint8List logoBytes = logoData.buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
    } catch (e) {
      debugPrint('Error loading logo: $e');
    }

    final currencyFormat = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    // Get Payment Method full name from constants
    final String paymentModeCode = sale.paymentMode ?? '08'; // Default to 'Others' if null
    final String paymentMethodName = LhdnConstants.paymentModes[paymentModeCode] ?? 'Others';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header - Business Profile
              pw.Center(
                child: pw.Column(
                  children: [
                    if (logoImage != null)
                      pw.Image(logoImage, height: 60),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      profile.businessName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(profile.addressLine1, style: const pw.TextStyle(fontSize: 10)),
                    if (profile.addressLine2.isNotEmpty)
                      pw.Text(profile.addressLine2, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('${profile.postalCode} ${profile.city}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Tel: ${profile.phoneNumber}', style: const pw.TextStyle(fontSize: 10)),
                    if (profile.email.isNotEmpty)
                      pw.Text('Email: ${profile.email}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Title
              pw.Center(
                child: pw.Text(
                  sale.lhdnValidationUrl != null ? 'TAX INVOICE' : 'RECEIPT',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),

              // Transaction Info & Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Sale Details
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Invoice No:', sale.invoiceNumber),
                      _buildInfoRow('Date:', dateFormat.format(sale.saleDate)),
                      _buildInfoRow('Payment:', paymentMethodName),
                    ],
                  ),
                  // Customer Details
                  if (sale.customerName.isNotEmpty && sale.customerName != 'Walk-in Customer')
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('BILL TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(sale.customerName, style: const pw.TextStyle(fontSize: 10)),
                        if (sale.customerTin.isNotEmpty)
                          pw.Text('TIN: ${sale.customerTin}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table
              pw.Table(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4), // Item Name
                  1: const pw.FixedColumnWidth(40), // Qty
                  2: const pw.FixedColumnWidth(70), // Unit Price
                  3: const pw.FixedColumnWidth(50), // Tax
                  4: const pw.FixedColumnWidth(70), // Total
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _buildTableCell('ITEM DESCRIPTION', isHeader: true),
                      _buildTableCell('QTY', isHeader: true, align: pw.TextAlign.center),
                      _buildTableCell('PRICE', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('TAX', isHeader: true, align: pw.TextAlign.right),
                      _buildTableCell('TOTAL', isHeader: true, align: pw.TextAlign.right),
                    ],
                  ),
                  // Table Rows
                  ...sale.lineItems.map((lineItem) => pw.TableRow(
                    children: [
                      _buildTableCell(lineItem.item.name),
                      _buildTableCell(lineItem.quantity.toStringAsFixed(0), align: pw.TextAlign.center),
                      _buildTableCell(currencyFormat.format(lineItem.unitPrice), align: pw.TextAlign.right),
                      _buildTableCell(sale.taxRate > 0 ? '${sale.taxRate}%' : '0%', align: pw.TextAlign.right),
                      _buildTableCell(currencyFormat.format(lineItem.subtotal), align: pw.TextAlign.right),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 15),

              // Financial Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalRow('Subtotal:', currencyFormat.format(sale.subtotal)),
                      if (sale.discountAmount != null && sale.discountAmount! > 0)
                        _buildTotalRow('Discount:', '- ${currencyFormat.format(sale.discountAmount)}'),
                      if (sale.taxAmount > 0)
                        _buildTotalRow('Tax (${sale.taxRate}%):', currencyFormat.format(sale.taxAmount)),
                      if (sale.roundingAmount != 0)
                        _buildTotalRow('Rounding:', currencyFormat.format(sale.roundingAmount)),
                      pw.SizedBox(height: 5),
                      pw.Container(width: 150, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 5),
                      pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'TOTAL PAYABLE:',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(width: 20),
                          pw.Text(
                            currencyFormat.format(sale.totalPayable),
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer: QR & Thank You
              pw.Center(
                child: pw.Column(
                  children: [
                    if (sale.lhdnValidationUrl != null) ...[
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: sale.lhdnValidationUrl!,
                        width: 80,
                        height: 80,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Scan to verify e-Invoice', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                      pw.SizedBox(height: 20),
                    ],
                    pw.Text('Thank you for your purchase!', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 11)),
                    pw.SizedBox(height: 15),
                    pw.Divider(thickness: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Generated by MyRekod FinHealth - Empowering Micro-SMEs',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/Receipt_${sale.invoiceNumber}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Share via share_plus
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null 
        ? box.localToGlobal(Offset.zero) & box.size 
        : null;

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Receipt - ${sale.invoiceNumber}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.black : PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(width: 20),
          pw.SizedBox(
            width: 80,
            child: pw.Text(value, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}
