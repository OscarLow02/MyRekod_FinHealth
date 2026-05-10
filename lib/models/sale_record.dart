import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer.dart';
import 'sale_item.dart';
import 'sale_line_item.dart';

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
  final String customerSstRegistrationNumber;
  final String customerTourismTaxNumber;

  // ── Item Details ───────────────────────────────────────────────────────

  final List<SaleLineItem> lineItems;

  // ── Pricing Breakdown ──────────────────────────────────────────────────

  /// subtotal = unitPrice × quantity (before tax & discount)
  final double subtotal;

  /// Discount amount applied (absolute, not percentage).
  final double? discountAmount;

  /// Discount rate applied (if any).
  final double? discountRate;

  /// Fee/Charge amount applied (absolute, not percentage).
  final double? feeAmount;

  /// Fee/Charge rate applied (if any).
  final double? feeRate;

  /// Discount description (optional, for LHDN payload).
  final String? discountDescription;

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
  final String? paymentMode;

  /// Payment terms (optional, e.g. "Net 30").
  final String? paymentTerms;

  /// Supplier's bank account number (optional override for this sale).
  final String? supplierBankAccount;

  // ── Prepayment Details ──────────────────────────────────────────────────

  final double? prepaymentAmount;
  final DateTime? prepaymentDate;
  final String? prepaymentReference;

  // ── Billing & Exemption ────────────────────────────────────────────────

  /// Internal reference for the bill (optional).
  final String? billReference;

  /// Billing frequency (e.g., 'Daily', 'Weekly', 'Monthly').
  final String? billingFrequency;

  /// Tax exemption amount applied (optional).
  final double? taxExemptionAmount;

  /// Billing period start date (optional).
  final DateTime? billingStartDate;

  /// Billing period end date (optional).
  final DateTime? billingEndDate;

  /// Tax exemption reason (optional, for LHDN payload).
  final String? taxExemptionReason;

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

  /// The raw LHDN JSON payload generated for this record.
  final String? lastGeneratedPayload;

  /// If this record was rolled into a master invoice, this holds the master ID.
  final String? consolidatedInvoiceRef;

  // ── Notes ──────────────────────────────────────────────────────────────

  final String notes;

  // ── Timestamps ─────────────────────────────────────────────────────────

  final DateTime? createdAt;
  final DateTime? updatedAt;

  // --- Mandatory LHDN Fields ---
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
    this.customerSstRegistrationNumber = 'NA',
    this.customerTourismTaxNumber = 'NA',
    // Item
    required this.lineItems,
    // Pricing
    required this.subtotal,
    this.discountAmount,
    this.discountRate,
    this.feeAmount,
    this.feeRate,
    this.discountDescription,
    this.taxType = '06',
    this.taxRate = 0.0,
    this.taxAmount = 0.0,
    required this.totalPayable,
    this.roundingAmount = 0.0,
    // Payment
    this.paymentMode,
    this.paymentTerms,
    this.supplierBankAccount,
    // Prepayment
    this.prepaymentAmount,
    this.prepaymentDate,
    this.prepaymentReference,
    // Billing
    this.billReference,
    this.billingFrequency,
    this.taxExemptionAmount,
    this.billingStartDate,
    this.billingEndDate,
    this.taxExemptionReason,
    // Status
    this.commercialStatus = CommercialStatus.pendingPayment,
    this.complianceStatus = ComplianceStatus.pendingConsolidation,
    // LHDN
    this.lhdnUuid,
    this.lhdnLongId,
    this.lhdnValidatedAt,
    this.lastGeneratedPayload,
    this.consolidatedInvoiceRef,
    // Notes
    this.notes = '',
    // Timestamps
    this.createdAt,
    this.updatedAt,
  });

  /// Converts to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'invoiceNumber': invoiceNumber,
      'saleDate': Timestamp.fromDate(saleDate),
      // Customer snapshot
      'customerId': customerId,
      'customerName': customerName,
      'customerType': customerType.name,
      'customerTin': customerTin,
      'customerIdNumber': customerIdNumber,
      'customerIdScheme': customerIdScheme,
      'customerSstRegistrationNumber': customerSstRegistrationNumber.isEmpty
          ? 'NA'
          : customerSstRegistrationNumber,
      'customerTourismTaxNumber': customerTourismTaxNumber.isEmpty
          ? 'NA'
          : customerTourismTaxNumber,
      // Items
      'lineItems': lineItems
          .map(
            (l) => {
              'itemId': l.item.id,
              'itemName': l.item.name,
              'unitPrice': l.unitPrice,
              'quantity': l.quantity,
              'measurementUnit': l.item.measurementUnit,
              'classificationCode': l.item.classificationCode,
            },
          )
          .toList(),
      // Pricing
      'subtotal': subtotal,
      'taxType': taxType,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'totalPayable': totalPayable,
      'roundingAmount': roundingAmount,
      // Status
      'commercialStatus': commercialStatus.firestoreValue,
      'complianceStatus': complianceStatus.firestoreValue,
      // Notes
      'notes': notes,
    };

    // Optional Fields - Exclude if null per requirement
    if (discountAmount != null) data['discountAmount'] = discountAmount;
    if (discountRate != null) data['discountRate'] = discountRate;
    if (feeAmount != null) data['feeAmount'] = feeAmount;
    if (feeRate != null) data['feeRate'] = feeRate;
    if (discountDescription != null)
      data['discountDescription'] = discountDescription;

    if (paymentMode != null) data['paymentMode'] = paymentMode;
    if (paymentTerms != null) data['paymentTerms'] = paymentTerms;
    if (supplierBankAccount != null)
      data['supplierBankAccount'] = supplierBankAccount;

    if (prepaymentAmount != null) data['prepaymentAmount'] = prepaymentAmount;
    if (prepaymentDate != null)
      data['prepaymentDate'] = Timestamp.fromDate(prepaymentDate!);
    if (prepaymentReference != null)
      data['prepaymentReference'] = prepaymentReference;

    if (billReference != null) data['billReference'] = billReference;
    if (billingFrequency != null) data['billingFrequency'] = billingFrequency;
    if (taxExemptionAmount != null)
      data['taxExemptionAmount'] = taxExemptionAmount;
    if (billingStartDate != null)
      data['billingStartDate'] = Timestamp.fromDate(billingStartDate!);
    if (billingEndDate != null)
      data['billingEndDate'] = Timestamp.fromDate(billingEndDate!);
    if (taxExemptionReason != null)
      data['taxExemptionReason'] = taxExemptionReason;

    if (lhdnUuid != null) data['lhdnUuid'] = lhdnUuid;
    if (lhdnLongId != null) data['lhdnLongId'] = lhdnLongId;
    if (lhdnValidatedAt != null)
      data['lhdnValidatedAt'] = Timestamp.fromDate(lhdnValidatedAt!);
    if (lastGeneratedPayload != null)
      data['lastGeneratedPayload'] = lastGeneratedPayload;
    if (consolidatedInvoiceRef != null)
      data['consolidatedInvoiceRef'] = consolidatedInvoiceRef;

    if (createdAt != null) {
      data['createdAt'] = Timestamp.fromDate(createdAt!);
    } else {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = FieldValue.serverTimestamp();

    return data;
  }

  /// Constructs a [SaleRecord] from a Firestore document snapshot.
  factory SaleRecord.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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
      customerSstRegistrationNumber:
          data['customerSstRegistrationNumber'] as String? ?? '',
      // Items
      lineItems: (data['lineItems'] as List? ?? []).map((l) {
        final itemMap = l as Map<String, dynamic>;
        return SaleLineItem(
          item: SaleItem(
            id: itemMap['itemId'] ?? '',
            name: itemMap['itemName'] ?? '',
            unitPrice: (itemMap['unitPrice'] as num?)?.toDouble() ?? 0.0,
            measurementUnit: itemMap['measurementUnit'] ?? 'C62',
            classificationCode: itemMap['classificationCode'] ?? '022',
          ),
          quantity: (itemMap['quantity'] as num?)?.toDouble() ?? 1.0,
          customPrice: null,
        );
      }).toList(),
      // Pricing
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (data['discountAmount'] as num?)?.toDouble(),
      discountRate: (data['discountRate'] as num?)?.toDouble(),
      feeAmount: (data['feeAmount'] as num?)?.toDouble(),
      feeRate: (data['feeRate'] as num?)?.toDouble(),
      discountDescription: data['discountDescription'] as String?,
      taxType: data['taxType'] as String? ?? '06',
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (data['taxAmount'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (data['totalPayable'] as num?)?.toDouble() ?? 0.0,
      roundingAmount: (data['roundingAmount'] as num?)?.toDouble() ?? 0.0,
      // Payment
      paymentMode: data['paymentMode'] as String?,
      paymentTerms: data['paymentTerms'] as String?,
      supplierBankAccount: data['supplierBankAccount'] as String?,
      // Prepayment
      prepaymentAmount: (data['prepaymentAmount'] as num?)?.toDouble(),
      prepaymentDate: (data['prepaymentDate'] as Timestamp?)?.toDate(),
      prepaymentReference: data['prepaymentReference'] as String?,
      // Billing
      billReference: data['billReference'] as String?,
      billingFrequency: data['billingFrequency'] as String?,
      taxExemptionAmount: (data['taxExemptionAmount'] as num?)?.toDouble(),
      billingStartDate: (data['billingStartDate'] as Timestamp?)?.toDate(),
      billingEndDate: (data['billingEndDate'] as Timestamp?)?.toDate(),
      taxExemptionReason: data['taxExemptionReason'] as String?,
      // Status
      commercialStatus: CommercialStatus.fromString(
        data['commercialStatus'] as String?,
      ),
      complianceStatus: ComplianceStatus.fromString(
        data['complianceStatus'] as String?,
      ),
      // LHDN
      lhdnUuid: data['lhdnUuid'] as String?,
      lhdnLongId: data['lhdnLongId'] as String?,
      lhdnValidatedAt: (data['lhdnValidatedAt'] as Timestamp?)?.toDate(),
      lastGeneratedPayload: data['lastGeneratedPayload'] as String?,
      consolidatedInvoiceRef: data['consolidatedInvoiceRef'] as String?,
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
    String? customerSstRegistrationNumber,
    List<SaleLineItem>? lineItems,
    double? subtotal,
    double? discountAmount,
    double? discountRate,
    double? feeAmount,
    double? feeRate,
    String? discountDescription,
    String? taxType,
    double? taxRate,
    double? taxAmount,
    double? totalPayable,
    double? roundingAmount,
    String? paymentMode,
    String? paymentTerms,
    String? supplierBankAccount,
    double? prepaymentAmount,
    DateTime? prepaymentDate,
    String? prepaymentReference,
    String? billReference,
    String? billingFrequency,
    double? taxExemptionAmount,
    DateTime? billingStartDate,
    DateTime? billingEndDate,
    String? taxExemptionReason,
    CommercialStatus? commercialStatus,
    ComplianceStatus? complianceStatus,
    String? lhdnUuid,
    String? lhdnLongId,
    DateTime? lhdnValidatedAt,
    String? lastGeneratedPayload,
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
      customerSstRegistrationNumber:
          customerSstRegistrationNumber ?? this.customerSstRegistrationNumber,
      lineItems: lineItems ?? this.lineItems,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountRate: discountRate ?? this.discountRate,
      feeAmount: feeAmount ?? this.feeAmount,
      feeRate: feeRate ?? this.feeRate,
      discountDescription: discountDescription ?? this.discountDescription,
      taxType: taxType ?? this.taxType,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      totalPayable: totalPayable ?? this.totalPayable,
      roundingAmount: roundingAmount ?? this.roundingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      supplierBankAccount: supplierBankAccount ?? this.supplierBankAccount,
      prepaymentAmount: prepaymentAmount ?? this.prepaymentAmount,
      prepaymentDate: prepaymentDate ?? this.prepaymentDate,
      prepaymentReference: prepaymentReference ?? this.prepaymentReference,
      billReference: billReference ?? this.billReference,
      billingFrequency: billingFrequency ?? this.billingFrequency,
      taxExemptionAmount: taxExemptionAmount ?? this.taxExemptionAmount,
      billingStartDate: billingStartDate ?? this.billingStartDate,
      billingEndDate: billingEndDate ?? this.billingEndDate,
      taxExemptionReason: taxExemptionReason ?? this.taxExemptionReason,
      commercialStatus: commercialStatus ?? this.commercialStatus,
      complianceStatus: complianceStatus ?? this.complianceStatus,
      lhdnUuid: lhdnUuid ?? this.lhdnUuid,
      lhdnLongId: lhdnLongId ?? this.lhdnLongId,
      lhdnValidatedAt: lhdnValidatedAt ?? this.lhdnValidatedAt,
      lastGeneratedPayload: lastGeneratedPayload ?? this.lastGeneratedPayload,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
