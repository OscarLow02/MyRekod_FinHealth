import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer.dart';

// ── Status Enums ─────────────────────────────────────────────────────────────

/// Tracks the payment lifecycle of a sale.
enum CommercialStatus {
  pendingPayment,
  paid;

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case CommercialStatus.pendingPayment:
        return 'Pending Payment';
      case CommercialStatus.paid:
        return 'Paid';
    }
  }

  /// Serializes to Firestore string.
  String get firestoreValue => name;

  /// Deserializes from Firestore string.
  static CommercialStatus fromString(String? value) {
    if (value == 'paid') return CommercialStatus.paid;
    return CommercialStatus.pendingPayment;
  }
}

/// Tracks the LHDN e-Invoice compliance lifecycle.
enum ComplianceStatus {
  pendingSubmission,
  valid,
  invalid,
  pendingConsolidation;

  /// Human-readable label for UI display.
  String get label {
    switch (this) {
      case ComplianceStatus.pendingSubmission:
        return 'Pending Submission';
      case ComplianceStatus.valid:
        return 'Valid';
      case ComplianceStatus.invalid:
        return 'Invalid';
      case ComplianceStatus.pendingConsolidation:
        return 'Pending Consolidation';
    }
  }

  /// Serializes to Firestore string.
  String get firestoreValue => name;

  /// Deserializes from Firestore string.
  static ComplianceStatus fromString(String? value) {
    switch (value) {
      case 'valid':
        return ComplianceStatus.valid;
      case 'invalid':
        return ComplianceStatus.invalid;
      case 'pendingConsolidation':
        return ComplianceStatus.pendingConsolidation;
      default:
        return ComplianceStatus.pendingSubmission;
    }
  }
}

// ── SaleRecord Model ─────────────────────────────────────────────────────────

/// DTO model for the Firestore `sale_records` subcollection.
///
/// Firestore path: `business_profiles/{uid}/sale_records/{saleId}`
///
/// Stores a completed sale transaction including:
/// - The buyer (Customer reference or embedded snapshot)
/// - Line item details (from SaleItem catalog)
/// - Pricing breakdown (subtotal, tax, discounts, total)
/// - Running invoice ID (Field 20, e.g., "INV-0001")
/// - Dual status tracking (commercial + LHDN compliance)
class SaleRecord {
  final String id;

  /// Running invoice number (Field 20), e.g., "INV-0001"
  final String invoiceNumber;

  /// Date and time of the sale.
  final DateTime saleDate;

  // ── Customer Snapshot ──────────────────────────────────────────────────
  // Embedded to avoid broken references if customer is later edited/deleted.

  final String customerId;
  final String customerName;
  final CustomerType customerType;
  final String customerTin;
  final String customerIdNumber;
  final String customerIdScheme;

  // ── Item Details ───────────────────────────────────────────────────────

  final String itemId;
  final String itemName;
  final String measurementUnit; // LHDN unit code, e.g. 'C62'
  final String classificationCode; // LHDN classification, e.g. '022'
  final double unitPrice;
  final double quantity;

  // ── Pricing Breakdown ──────────────────────────────────────────────────

  /// subtotal = unitPrice × quantity (before tax & discount)
  final double subtotal;

  /// Discount amount applied (absolute, not percentage).
  final double discountAmount;

  /// Discount description (optional, for LHDN payload).
  final String discountDescription;

  /// Tax type code from LhdnConstants.taxTypes (e.g., '06' = Not Applicable).
  final String taxType;

  /// Tax rate as percentage (e.g., 6.0 for 6%).
  final double taxRate;

  /// Calculated tax amount.
  final double taxAmount;

  /// Final total payable = subtotal - discountAmount + taxAmount
  /// Rounded to nearest 5 sen per Malaysian rounding rules.
  final double totalPayable;

  /// Rounding adjustment amount (e.g., -0.01, +0.02).
  final double roundingAmount;

  // ── Payment ────────────────────────────────────────────────────────────

  /// Payment mode code from LhdnConstants.paymentModes.
  final String paymentMode;

  // ── Status Tracking ────────────────────────────────────────────────────

  final CommercialStatus commercialStatus;
  final ComplianceStatus complianceStatus;

  // ── LHDN Response Fields (populated after submission) ──────────────────

  /// UUID returned by LHDN upon successful validation.
  final String? lhdnUuid;

  /// Long ID returned by LHDN for the submission.
  final String? lhdnLongId;

  /// ISO 8601 timestamp of LHDN validation.
  final DateTime? lhdnValidatedAt;

  // ── Notes ──────────────────────────────────────────────────────────────

  final String notes;

  // ── Timestamps ─────────────────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SaleRecord({
    required this.id,
    required this.invoiceNumber,
    required this.saleDate,
    // Customer
    required this.customerId,
    required this.customerName,
    required this.customerType,
    this.customerTin = '',
    this.customerIdNumber = '',
    this.customerIdScheme = 'BRN',
    // Item
    required this.itemId,
    required this.itemName,
    this.measurementUnit = 'C62',
    this.classificationCode = '022',
    required this.unitPrice,
    required this.quantity,
    // Pricing
    required this.subtotal,
    this.discountAmount = 0.0,
    this.discountDescription = '',
    this.taxType = '06',
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    required this.totalPayable,
    this.roundingAmount = 0.0,
    // Payment
    this.paymentMode = '01', // Default: Cash
    // Status
    this.commercialStatus = CommercialStatus.pendingPayment,
    this.complianceStatus = ComplianceStatus.pendingConsolidation,
    // LHDN
    this.lhdnUuid,
    this.lhdnLongId,
    this.lhdnValidatedAt,
    // Notes
    this.notes = '',
    // Timestamps
    this.createdAt,
    this.updatedAt,
  });

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'invoiceNumber': invoiceNumber,
      'saleDate': Timestamp.fromDate(saleDate),
      // Customer snapshot
      'customerId': customerId,
      'customerName': customerName,
      'customerType': customerType.name,
      'customerTin': customerTin,
      'customerIdNumber': customerIdNumber,
      'customerIdScheme': customerIdScheme,
      // Item
      'itemId': itemId,
      'itemName': itemName,
      'measurementUnit': measurementUnit,
      'classificationCode': classificationCode,
      'unitPrice': unitPrice,
      'quantity': quantity,
      // Pricing
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountDescription': discountDescription,
      'taxType': taxType,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'totalPayable': totalPayable,
      'roundingAmount': roundingAmount,
      // Payment
      'paymentMode': paymentMode,
      // Status
      'commercialStatus': commercialStatus.firestoreValue,
      'complianceStatus': complianceStatus.firestoreValue,
      // LHDN
      'lhdnUuid': lhdnUuid,
      'lhdnLongId': lhdnLongId,
      'lhdnValidatedAt': lhdnValidatedAt != null
          ? Timestamp.fromDate(lhdnValidatedAt!)
          : null,
      // Notes
      'notes': notes,
      // Timestamps
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Constructs a [SaleRecord] from a Firestore document snapshot.
  factory SaleRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return SaleRecord(
      id: doc.id,
      invoiceNumber: data['invoiceNumber'] as String? ?? '',
      saleDate: (data['saleDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Customer
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerType: CustomerType.values.firstWhere(
        (e) => e.name == (data['customerType'] as String? ?? 'b2c'),
        orElse: () => CustomerType.b2c,
      ),
      customerTin: data['customerTin'] as String? ?? '',
      customerIdNumber: data['customerIdNumber'] as String? ?? '',
      customerIdScheme: data['customerIdScheme'] as String? ?? 'BRN',
      // Item
      itemId: data['itemId'] as String? ?? '',
      itemName: data['itemName'] as String? ?? '',
      measurementUnit: data['measurementUnit'] as String? ?? 'C62',
      classificationCode: data['classificationCode'] as String? ?? '022',
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0.0,
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      // Pricing
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble() ?? 0.0,
      discountDescription: data['discountDescription'] as String? ?? '',
      taxType: data['taxType'] as String? ?? '06',
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (data['totalPayable'] as num?)?.toDouble() ?? 0.0,
      roundingAmount: (data['roundingAmount'] as num?)?.toDouble() ?? 0.0,
      // Payment
      paymentMode: data['paymentMode'] as String? ?? '01',
      // Status
      commercialStatus:
          CommercialStatus.fromString(data['commercialStatus'] as String?),
      complianceStatus:
          ComplianceStatus.fromString(data['complianceStatus'] as String?),
      // LHDN
      lhdnUuid: data['lhdnUuid'] as String?,
      lhdnLongId: data['lhdnLongId'] as String?,
      lhdnValidatedAt: (data['lhdnValidatedAt'] as Timestamp?)?.toDate(),
      // Notes
      notes: data['notes'] as String? ?? '',
      // Timestamps
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Returns a copy with optionally updated fields.
  SaleRecord copyWith({
    String? id,
    String? invoiceNumber,
    DateTime? saleDate,
    String? customerId,
    String? customerName,
    CustomerType? customerType,
    String? customerTin,
    String? customerIdNumber,
    String? customerIdScheme,
    String? itemId,
    String? itemName,
    String? measurementUnit,
    String? classificationCode,
    double? unitPrice,
    double? quantity,
    double? subtotal,
    double? discountAmount,
    String? discountDescription,
    String? taxType,
    double? taxRate,
    double? taxAmount,
    double? totalPayable,
    double? roundingAmount,
    String? paymentMode,
    CommercialStatus? commercialStatus,
    ComplianceStatus? complianceStatus,
    String? lhdnUuid,
    String? lhdnLongId,
    DateTime? lhdnValidatedAt,
    String? notes,
  }) {
    return SaleRecord(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      saleDate: saleDate ?? this.saleDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerType: customerType ?? this.customerType,
      customerTin: customerTin ?? this.customerTin,
      customerIdNumber: customerIdNumber ?? this.customerIdNumber,
      customerIdScheme: customerIdScheme ?? this.customerIdScheme,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      classificationCode: classificationCode ?? this.classificationCode,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountDescription: discountDescription ?? this.discountDescription,
      taxType: taxType ?? this.taxType,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      totalPayable: totalPayable ?? this.totalPayable,
      roundingAmount: roundingAmount ?? this.roundingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      commercialStatus: commercialStatus ?? this.commercialStatus,
      complianceStatus: complianceStatus ?? this.complianceStatus,
      lhdnUuid: lhdnUuid ?? this.lhdnUuid,
      lhdnLongId: lhdnLongId ?? this.lhdnLongId,
      lhdnValidatedAt: lhdnValidatedAt ?? this.lhdnValidatedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
