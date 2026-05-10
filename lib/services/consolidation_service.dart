import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../models/sale_record.dart';
import 'firestore_service.dart';
import 'lhdn_serializer.dart';

class ConsolidationService {
  final FirestoreService _firestoreService = FirestoreService();

  Future<bool> submitConsolidatedInvoice(List<SaleRecord> selectedSales) async {
    if (selectedSales.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

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

      for (var sale in selectedSales) {
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

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Consolidation error: $e");
      return false;
    }
  }
}
