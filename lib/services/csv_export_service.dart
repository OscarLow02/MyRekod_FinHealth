import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sale_record.dart';
import '../models/expense_record.dart';
import '../services/firestore_service.dart';

class CsvExportService {
  // ──────────────────────────────────────────────────────────────────────────
  // 1. Expense - Export to CSV (Single)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> exportSingleExpenseToCSV(
    BuildContext context,
    ExpenseRecord expense,
  ) async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(expense.date);
      final rows = [
        ['ID', 'Date', 'Vendor', 'Category', 'Amount', 'Notes', 'Receipt Path'],
        [
          expense.id,
          dateStr,
          expense.vendor,
          expense.category,
          expense.amount.toStringAsFixed(2),
          expense.notes ?? '',
          expense.imagePath ?? 'No Receipt',
        ],
      ];

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final fileName = 'Expense_${expense.vendor}_$dateStr.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvData);

      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MyRekod Expense - ${expense.vendor}',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Expense - Export to CSV (Bulk)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> exportBulkExpensesToCSV(
    BuildContext context,
    List<ExpenseRecord> expenses,
    String reportSuffix,
  ) async {
    try {
      final rows = [
        ['ID', 'Date', 'Vendor', 'Category', 'Amount', 'Notes', 'Receipt Path'],
      ];

      for (var expense in expenses) {
        final dateStr = DateFormat('yyyy-MM-dd').format(expense.date);
        rows.add([
          expense.id,
          dateStr,
          expense.vendor,
          expense.category,
          expense.amount.toStringAsFixed(2),
          expense.notes ?? '',
          expense.imagePath ?? 'No Receipt',
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final fileName = 'Expense_Report_$reportSuffix.csv';
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csvData);

      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(path)],
        text: 'MyRekod Expense Report ($reportSuffix)',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Sale - Export to CSV (Single)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> exportSingleSaleToCSV(
    BuildContext context,
    SaleRecord sale,
  ) async {
    try {
      // 1. Fetch Business Profile for Supplier Data
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final profile = await FirestoreService().getBusinessProfile(userId);

      if (profile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Business profile not found. Please complete onboarding.',
              ),
            ),
          );
        }
        return;
      }

      // 2. Define the exact 55 Headers matching LHDN Specs
      List<List<dynamic>> rows = [];
      rows.add([
        "Supplier's Name",
        "Buyer's Name",
        "Supplier's TIN",
        "Supplier's Reg/ID",
        "Supplier's SST",
        "Supplier's Tourism Tax",
        "Supplier's Email",
        "Supplier's MSIC",
        "Supplier's Business Activity",
        "Buyer's TIN",
        "Buyer's Reg/ID",
        "Buyer's SST",
        "Buyer's Email",
        "Supplier's Address",
        "Buyer's Address",
        "Supplier's Contact Number",
        "Buyer's Contact Number",
        "e-Invoice Version",
        "e-Invoice Type",
        "e-Invoice Code/Number",
        "Original e-Invoice Ref",
        "e-Invoice Date & Time",
        "Issuer's Digital Signature",
        "Invoice Currency Code",
        "Currency Exchange Rate",
        "Frequency of Billing",
        "Billing Period",
        "Classification",
        "Description of Product/Service",
        "Unit Price",
        "Tax Type",
        "Tax Rate",
        "Tax Amount",
        "Details of Tax Exemption",
        "Amount Exempted from Tax",
        "Subtotal",
        "Total Excluding Tax",
        "Total Including Tax",
        "Total Net Amount",
        "Total Payable Amount",
        "Rounding Amount",
        "Total Taxable Amount Per Tax Type",
        "Quantity",
        "Measurement",
        "Discount Rate",
        "Discount Amount",
        "Fee/Charge Rate",
        "Fee/Charge Amount",
        "Payment Mode",
        "Supplier's Bank Account Number",
        "Payment Terms",
        "Prepayment Amount",
        "Prepayment Date",
        "Prepayment Ref Number",
        "Bill Ref Number",
      ]);

      // 3. Formatting Helpers
      String formatDateTime(DateTime? dt) =>
          dt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dt) : 'NA';
      String formatDate(DateTime? dt) =>
          dt != null ? DateFormat('yyyy-MM-dd').format(dt) : 'NA';

      // 4. Smart Defaults for B2C Consolidated (Walk-In)
      final isConsolidated =
          sale.customerId == 'walk-in' || sale.customerName == 'General Public';
      final buyerName = isConsolidated ? 'General Public' : sale.customerName;
      final buyerTIN = isConsolidated
          ? 'EI00000000010'
          : (sale.customerTin.isNotEmpty ? sale.customerTin : 'NA');
      final buyerReg = isConsolidated
          ? 'NA'
          : (sale.customerIdNumber.isNotEmpty ? sale.customerIdNumber : 'NA');
      final buyerSST = isConsolidated
          ? 'NA'
          : (sale.customerSstRegistrationNumber.isNotEmpty
                ? sale.customerSstRegistrationNumber
                : 'NA');
      final buyerEmail = 'NA';
      final buyerAddress = 'NA';
      final buyerContact = 'NA';

      final supplierAddress =
          "${profile.addressLine1} ${profile.city} ${profile.postalCode} ${profile.stateCode}"
              .trim();
      final billingPeriod =
          (sale.billingStartDate != null && sale.billingEndDate != null)
          ? "${formatDate(sale.billingStartDate)} to ${formatDate(sale.billingEndDate)}"
          : 'NA';

      // 5. Map each Line Item to the 55 Columns
      for (var line in sale.lineItems) {
        rows.add([
          // Parties (1-2)
          profile.businessName,
          buyerName,

          // Details (3-13)
          profile.tinNumber,
          profile.brnNumber,
          profile.sstNumber,
          profile.tourismTaxNumber,
          profile.email,
          profile.msicCode,
          profile.businessActivityDescription,
          buyerTIN,
          buyerReg,
          buyerSST,
          buyerEmail,

          // Address (14-15)
          supplierAddress,
          buyerAddress,

          // Contact Number (16-17)
          profile.phoneNumber,
          buyerContact,

          // Invoice Details (18-27)
          "1.0", // 18. Version
          "01", // 19. Type
          sale.invoiceNumber, // 20. Code
          "", // 21. Original Ref
          formatDateTime(sale.saleDate), // 22. Date Time
          "", // 23. Digital Signature (Blank for raw data)
          "MYR", // 24. Currency
          "", // 25. Exchange Rate
          sale.billingFrequency ?? 'NA', // 26. Frequency
          billingPeriod, // 27. Period
          // Products / Services (28-48)
          line.item.classificationCode, // 28. Classification
          line.item.name, // 29. Description
          line.unitPrice.toStringAsFixed(2), // 30. Unit Price
          sale.taxType, // 31. Tax Type
          sale.taxType == 'E'
              ? '0.00'
              : sale.taxRate.toStringAsFixed(2), // 32. Tax Rate
          sale.taxAmount.toStringAsFixed(2), // 33. Tax Amount
          sale.taxExemptionReason ?? 'NA', // 34. Exemption Reason
          sale.taxType == 'E'
              ? sale.subtotal.toStringAsFixed(2)
              : '0.00', // 35. Exempted Amt
          sale.subtotal.toStringAsFixed(2), // 36. Subtotal
          sale.subtotal.toStringAsFixed(2), // 37. Total Excluding Tax
          sale.totalPayable.toStringAsFixed(2), // 38. Total Including Tax
          sale.subtotal.toStringAsFixed(2), // 39. Total Net Amount
          sale.totalPayable.toStringAsFixed(2), // 40. Total Payable
          sale.roundingAmount.toStringAsFixed(2), // 41. Rounding
          sale.subtotal.toStringAsFixed(2), // 42. Taxable Amount Per Tax
          line.quantity.toStringAsFixed(2), // 43. Quantity
          "C62", // 44. Measurement
          sale.discountRate?.toStringAsFixed(2) ?? '0.00', // 45
          sale.discountAmount?.toStringAsFixed(2) ?? '0.00', // 46
          sale.feeRate?.toStringAsFixed(2) ?? '0.00', // 47
          sale.feeAmount?.toStringAsFixed(2) ?? '0.00', // 48
          // Payment Info (49-55)
          sale.paymentMode ?? '01',
          profile.bankAccountNumber ?? 'NA',
          sale.paymentTerms ?? 'NA',
          sale.prepaymentAmount?.toStringAsFixed(2) ?? '0.00',
          formatDate(sale.prepaymentDate),
          sale.prepaymentReference ?? 'NA',
          sale.billReference ?? 'NA',
        ]);
      }

      // 6. Convert & Save
      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      final safeInvoiceNum = sale.invoiceNumber.replaceAll('/', '-');
      final path = "${directory.path}/LHDN_Invoice_$safeInvoiceNum.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // 7. Trigger the Share Sheet
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(path)],
        text: 'LHDN e-Invoice Data for $safeInvoiceNum',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV Export Failed: $e')));
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Sale - Export to CSV (Bulk)
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> exportBulkSalesToCSV(
    BuildContext context,
    List<SaleRecord> sales,
    String reportSuffix,
  ) async {
    try {
      // 1. Fetch Business Profile for Supplier Data
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final profile = await FirestoreService().getBusinessProfile(userId);

      if (profile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Business profile not found. Please complete onboarding.',
              ),
            ),
          );
        }
        return;
      }

      // 2. Define the exact 55 Headers matching LHDN Specs
      List<List<dynamic>> rows = [];
      rows.add([
        "Supplier's Name",
        "Buyer's Name",
        "Supplier's TIN",
        "Supplier's Reg/ID",
        "Supplier's SST",
        "Supplier's Tourism Tax",
        "Supplier's Email",
        "Supplier's MSIC",
        "Supplier's Business Activity",
        "Buyer's TIN",
        "Buyer's Reg/ID",
        "Buyer's SST",
        "Buyer's Email",
        "Supplier's Address",
        "Buyer's Address",
        "Supplier's Contact Number",
        "Buyer's Contact Number",
        "e-Invoice Version",
        "e-Invoice Type",
        "e-Invoice Code/Number",
        "Original e-Invoice Ref",
        "e-Invoice Date & Time",
        "Issuer's Digital Signature",
        "Invoice Currency Code",
        "Currency Exchange Rate",
        "Frequency of Billing",
        "Billing Period",
        "Classification",
        "Description of Product/Service",
        "Unit Price",
        "Tax Type",
        "Tax Rate",
        "Tax Amount",
        "Details of Tax Exemption",
        "Amount Exempted from Tax",
        "Subtotal",
        "Total Excluding Tax",
        "Total Including Tax",
        "Total Net Amount",
        "Total Payable Amount",
        "Rounding Amount",
        "Total Taxable Amount Per Tax Type",
        "Quantity",
        "Measurement",
        "Discount Rate",
        "Discount Amount",
        "Fee/Charge Rate",
        "Fee/Charge Amount",
        "Payment Mode",
        "Supplier's Bank Account Number",
        "Payment Terms",
        "Prepayment Amount",
        "Prepayment Date",
        "Prepayment Ref Number",
        "Bill Ref Number",
      ]);

      // Formatting Helpers
      String formatDateTime(DateTime? dt) =>
          dt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dt) : 'NA';
      String formatDate(DateTime? dt) =>
          dt != null ? DateFormat('yyyy-MM-dd').format(dt) : 'NA';

      // 3. Outer loop
      for (var sale in sales) {
        // 4. Smart Defaults for B2C Consolidated (Walk-In)
        final isConsolidated =
            sale.customerId == 'walk-in' || sale.customerName == 'General Public';
        final buyerName = isConsolidated ? 'General Public' : sale.customerName;
        final buyerTIN = isConsolidated
            ? 'EI00000000010'
            : (sale.customerTin.isNotEmpty ? sale.customerTin : 'NA');
        final buyerReg = isConsolidated
            ? 'NA'
            : (sale.customerIdNumber.isNotEmpty ? sale.customerIdNumber : 'NA');
        final buyerSST = isConsolidated
            ? 'NA'
            : (sale.customerSstRegistrationNumber.isNotEmpty
                  ? sale.customerSstRegistrationNumber
                  : 'NA');
        final buyerEmail = 'NA';
        final buyerAddress = 'NA';
        final buyerContact = 'NA';

        final supplierAddress =
            "${profile.addressLine1} ${profile.city} ${profile.postalCode} ${profile.stateCode}"
                .trim();
        final billingPeriod =
            (sale.billingStartDate != null && sale.billingEndDate != null)
            ? "${formatDate(sale.billingStartDate)} to ${formatDate(sale.billingEndDate)}"
            : 'NA';

        // 5. Map each Line Item to the 55 Columns
        for (var line in sale.lineItems) {
          rows.add([
            // Parties (1-2)
            profile.businessName,
            buyerName,

            // Details (3-13)
            profile.tinNumber,
            profile.brnNumber,
            profile.sstNumber,
            profile.tourismTaxNumber,
            profile.email,
            profile.msicCode,
            profile.businessActivityDescription,
            buyerTIN,
            buyerReg,
            buyerSST,
            buyerEmail,

            // Address (14-15)
            supplierAddress,
            buyerAddress,

            // Contact Number (16-17)
            profile.phoneNumber,
            buyerContact,

            // Invoice Details (18-27)
            "1.0", // 18. Version
            "01", // 19. Type
            sale.invoiceNumber, // 20. Code
            "", // 21. Original Ref
            formatDateTime(sale.saleDate), // 22. Date Time
            "", // 23. Digital Signature (Blank for raw data)
            "MYR", // 24. Currency
            "", // 25. Exchange Rate
            sale.billingFrequency ?? 'NA', // 26. Frequency
            billingPeriod, // 27. Period
            // Products / Services (28-48)
            line.item.classificationCode, // 28. Classification
            line.item.name, // 29. Description
            line.unitPrice.toStringAsFixed(2), // 30. Unit Price
            sale.taxType, // 31. Tax Type
            sale.taxType == 'E'
                ? '0.00'
                : sale.taxRate.toStringAsFixed(2), // 32. Tax Rate
            sale.taxAmount.toStringAsFixed(2), // 33. Tax Amount
            sale.taxExemptionReason ?? 'NA', // 34. Exemption Reason
            sale.taxType == 'E'
                ? sale.subtotal.toStringAsFixed(2)
                : '0.00', // 35. Exempted Amt
            sale.subtotal.toStringAsFixed(2), // 36. Subtotal
            sale.subtotal.toStringAsFixed(2), // 37. Total Excluding Tax
            sale.totalPayable.toStringAsFixed(2), // 38. Total Including Tax
            sale.subtotal.toStringAsFixed(2), // 39. Total Net Amount
            sale.totalPayable.toStringAsFixed(2), // 40. Total Payable
            sale.roundingAmount.toStringAsFixed(2), // 41. Rounding
            sale.subtotal.toStringAsFixed(2), // 42. Taxable Amount Per Tax
            line.quantity.toStringAsFixed(2), // 43. Quantity
            "C62", // 44. Measurement
            sale.discountRate?.toStringAsFixed(2) ?? '0.00', // 45
            sale.discountAmount?.toStringAsFixed(2) ?? '0.00', // 46
            sale.feeRate?.toStringAsFixed(2) ?? '0.00', // 47
            sale.feeAmount?.toStringAsFixed(2) ?? '0.00', // 48
            // Payment Info (49-55)
            sale.paymentMode ?? '01',
            profile.bankAccountNumber ?? 'NA',
            sale.paymentTerms ?? 'NA',
            sale.prepaymentAmount?.toStringAsFixed(2) ?? '0.00',
            formatDate(sale.prepaymentDate),
            sale.prepaymentReference ?? 'NA',
            sale.billReference ?? 'NA',
          ]);
        }
      }

      // 6. Convert & Save
      String csvData = const ListToCsvConverter().convert(rows);

      final directory = await getTemporaryDirectory();
      // 7. Name the file
      final fileName = 'LHDN_Sales_Report_$reportSuffix.csv';
      final path = "${directory.path}/$fileName";
      final file = File(path);
      await file.writeAsString(csvData);

      // 8. Trigger the Share Sheet
      final box = context.findRenderObject() as RenderBox?;

      await Share.shareXFiles(
        [XFile(path)],
        text: 'LHDN Sales Report ($reportSuffix)',
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV Export Failed: $e')));
      }
    }
  }
}
