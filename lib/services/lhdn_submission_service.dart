import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sale_record.dart';
import '../models/business_profile.dart';
import '../services/firestore_service.dart';
import '../services/lhdn_serializer.dart';

/// Result of an LHDN e-Invoice submission attempt.
class LhdnSubmissionResult {
  final bool success;
  final String? uuid;
  final String? longId;
  final DateTime? validatedAt;
  final String? errorMessage;
  final Map<String, dynamic>? payload;

  const LhdnSubmissionResult({
    required this.success,
    this.uuid,
    this.longId,
    this.validatedAt,
    this.errorMessage,
    this.payload,
  });
}

/// Service for submitting e-Invoices to LHDN.
///
/// Currently implements a **mock submission** that:
/// 1. Serializes the [SaleRecord] + [BusinessProfile] into UBL 2.1 JSON
/// 2. Simulates an API delay (1–2 seconds)
/// 3. Returns a mock UUID + Long ID on success
/// 4. Updates the [SaleRecord] in Firestore with LHDN response fields
///
/// When the LHDN production API is available, replace the mock
/// logic in [_mockApiCall] with a real HTTP POST to the LHDN endpoint.
class LhdnSubmissionService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Submits a sale record as an e-Invoice to LHDN.
  ///
  /// Flow:
  /// 1. Serialize → UBL 2.1 JSON
  /// 2. Submit → LHDN API (currently mocked)
  /// 3. Update → Firestore with response (UUID, LongID, status)
  ///
  /// Returns [LhdnSubmissionResult] with success/failure details.
  Future<LhdnSubmissionResult> submitInvoice({
    required SaleRecord record,
    required BusinessProfile sellerProfile,
  }) async {
    try {
      // Step 1: Build the full payload
      final payload = LhdnPayloadBuilder.buildInvoicePayload(
        record: record,
        sellerProfile: sellerProfile,
      );

      // Debug: Print the payload in development
      debugPrint('═══ LHDN Payload ═══');
      debugPrint(const JsonEncoder.withIndent('  ').convert(payload));
      debugPrint('═══ End Payload ═══');

      // Step 2: Submit to LHDN API (mocked)
      final result = await _mockApiCall(payload);

      // Step 3: Update Firestore record with LHDN response
      if (result.success) {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          final updatedRecord = record.copyWith(
            lhdnUuid: result.uuid,
            lhdnLongId: result.longId,
            lhdnValidatedAt: result.validatedAt,
            complianceStatus: ComplianceStatus.valid,
          );
          _firestoreService.updateSaleRecord(userId, updatedRecord);
        }
      }

      return result;
    } catch (e) {
      debugPrint('LHDN submission error: $e');
      return LhdnSubmissionResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Generates a preview of the UBL 2.1 JSON payload without submitting.
  ///
  /// Useful for debugging or showing the user what will be sent.
  Map<String, dynamic> generatePreview({
    required SaleRecord record,
    required BusinessProfile sellerProfile,
  }) {
    return LhdnPayloadBuilder.buildInvoicePayload(
      record: record,
      sellerProfile: sellerProfile,
    );
  }

  /// Returns the payload as a formatted JSON string.
  String generatePreviewString({
    required SaleRecord record,
    required BusinessProfile sellerProfile,
  }) {
    final payload = generatePreview(
      record: record,
      sellerProfile: sellerProfile,
    );
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  MOCK API CALL
  // ══════════════════════════════════════════════════════════════════════════

  /// Simulates an LHDN API submission with:
  /// - 1–2 second network delay
  /// - 90% success rate (for testing error handling)
  /// - Mock UUID and Long ID generation
  ///
  /// TODO: Replace with real HTTP POST when LHDN API is available:
  /// ```dart
  /// final response = await http.post(
  ///   Uri.parse('https://preprod-api.myinvois.hasil.gov.my/api/v1.0/documentsubmissions'),
  ///   headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
  ///   body: jsonEncode(payload),
  /// );
  /// ```
  Future<LhdnSubmissionResult> _mockApiCall(
    Map<String, dynamic> payload,
  ) async {
    // Simulate network latency
    final delayMs = 1000 + Random().nextInt(1500);
    await Future.delayed(Duration(milliseconds: delayMs));

    // 90% success rate for realistic testing
    final isSuccess = Random().nextInt(10) < 9;

    if (isSuccess) {
      final now = DateTime.now();
      final uuid = _generateMockUuid();
      final longId = _generateMockLongId();

      return LhdnSubmissionResult(
        success: true,
        uuid: uuid,
        longId: longId,
        validatedAt: now,
        payload: payload,
      );
    } else {
      return const LhdnSubmissionResult(
        success: false,
        errorMessage: 'LHDN API Error: Document validation failed. '
            'Please verify supplier TIN and BRN numbers. (Mock Error)',
      );
    }
  }

  /// Generates a mock UUID v4 (matching LHDN response format).
  static String _generateMockUuid() {
    final random = Random();
    final bytes = List.generate(16, (_) => random.nextInt(256));

    // Set version (4) and variant bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  /// Generates a mock Long ID (matching LHDN's alphanumeric format).
  static String _generateMockLongId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final id = List.generate(
      26,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return id;
  }
}
