import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/sale_record.dart';
import 'firestore_service.dart';
import 'lhdn_serializer.dart';

class ConsolidationResult {
  final bool success;
  final String? masterInvoiceNumber;
  final double totalAmount;
  final String? error;

  ConsolidationResult({
    required this.success,
    this.masterInvoiceNumber,
    this.totalAmount = 0.0,
    this.error,
  });
}

class ConsolidationService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<ConsolidationResult> submitConsolidatedInvoice(List<SaleRecord> selectedSales) async {
    if (selectedSales.isEmpty) return ConsolidationResult(success: false, error: "No sales selected");
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ConsolidationResult(success: false, error: "User not authenticated");

    try {
      final profile = await _firestoreService.getBusinessProfile(user.uid);
      if (profile == null) throw Exception("Business profile not found");

      // 1. Generate Master Invoice Number (e.g. INV-C-123456)
      final masterInvoiceNumber =
          "INV-C-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

      // 2. Generate JSON Payload (Method A - Line items = receipts)
      final payloadMap = LhdnPayloadBuilder.buildConsolidatedPayload(
        masterInvoiceNumber: masterInvoiceNumber,
        selectedSales: selectedSales,
        sellerProfile: profile,
      );
      final payloadJson = jsonEncode(payloadMap);
      debugPrint("Consolidated Payload Generated: $masterInvoiceNumber");

      // 3. Mock LHDN Response
      final mockUuid =
          'LHDN-C-${math.Random().nextInt(999999).toString().padLeft(6, '0')}';

      // 4. Firestore Batch Update (Link children to Master)
      final batch = FirebaseFirestore.instance.batch();
      double masterTotalPayable = 0.0;

      for (var sale in selectedSales) {
        masterTotalPayable += sale.totalPayable;
        final docRef = FirebaseFirestore.instance
            .collection('business_profiles')
            .doc(user.uid)
            .collection('sale_records')
            .doc(sale.id);

        batch.update(docRef, {
          'complianceStatus': ComplianceStatus.valid.firestoreValue,
          'consolidatedInvoiceRef': masterInvoiceNumber,
          'lhdnUuid': mockUuid,
          'lhdnValidatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Save the Master Payload to Firestore
      final masterDocRef = FirebaseFirestore.instance
          .collection('business_profiles')
          .doc(user.uid)
          .collection('consolidated_invoices')
          .doc(masterInvoiceNumber);

      batch.set(masterDocRef, {
        'invoiceNumber': masterInvoiceNumber,
        'payload': payloadJson, // The raw JSON string
        'createdAt': FieldValue.serverTimestamp(),
        'totalAmount': masterTotalPayable,
        'recordCount': selectedSales.length,
        'lhdnUuid': mockUuid,
      });

      await batch.commit();
      return ConsolidationResult(
        success: true,
        masterInvoiceNumber: masterInvoiceNumber,
        totalAmount: masterTotalPayable,
      );
    } catch (e) {
      debugPrint("Consolidation error: $e");
      return ConsolidationResult(success: false, error: e.toString());
    }
  }
}
