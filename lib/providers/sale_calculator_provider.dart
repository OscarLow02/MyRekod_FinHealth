import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';
import '../models/sale_item.dart';
import '../models/sale_record.dart';
import '../models/tax_config.dart';
import '../models/sale_line_item.dart';
import '../models/business_profile.dart';
import '../services/firestore_service.dart';
import '../services/lhdn_serializer.dart';
import 'dart:convert';

/// The real-time calculation engine for the Record Sale form.
///
/// Responsibilities:
/// 1. Holds mutable form state (selected item, customer, quantity, etc.)
/// 2. Exposes computed getters for subtotal, tax, discount, rounding, total
/// 3. Implements strict Malaysian 5-cent rounding logic
/// 4. Loads the user's TaxConfig defaults and SaleItem/Customer catalogs
/// 5. Builds a finalized [SaleRecord] snapshot for persistence
///
/// Architecture Note: This provider is scoped to the Record Sale screen
/// lifecycle. It is NOT registered globally — it should be created via
/// ChangeNotifierProvider at the screen level.
class SaleCalculatorProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // ── Auth & Loading State ───────────────────────────────────────────────

  String? _currentUserId;
  bool _isLoading = true;
  String? _error;

  String? get currentUserId => _currentUserId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Catalog Data (loaded from Firestore) ───────────────────────────────

  List<SaleItem> _saleItems = [];
  List<Customer> _customers = [];
  TaxConfig _taxConfig = TaxConfig.empty;
  BusinessProfile? _businessProfile;
  StreamSubscription<List<SaleItem>>? _itemsSub;
  StreamSubscription<List<Customer>>? _customersSub;

  List<SaleItem> get saleItems => _saleItems;
  List<Customer> get customers => _customers;
  TaxConfig get taxConfig => _taxConfig;
  BusinessProfile? get businessProfile => _businessProfile;

  // ── Form State (mutable, drives computed getters) ──────────────────────

  final List<SaleLineItem> _lineItems = [];
  Customer? _selectedCustomer;

  bool _isDiscountRateMode = true; // true = Rate (%), false = Amount (RM)
  double _discountAmount = 0.0;
  double _discountRate = 0.0;
  double _feeAmount = 0.0;
  double _feeRate = 0.0;

  String _discountDescription = '';
  String _paymentMode = '01'; // Default: Cash
  String _notes = '';
  DateTime _saleDate = DateTime.now();
  bool _submitToLhdnNow = true;
  String? _previewInvoiceNumber;

  // --- Section Toggles ---
  bool _enableDiscountCharges = false;
  bool _enablePaymentInfo = false;
  bool _enablePrepayment = false;
  bool _enableBillingExemption = false;

  String _taxType = '06'; // Default: Not Applicable
  double _taxRate = 0.0;
  double? _numUnits; // Unit-based: number of units
  double? _ratePerUnit; // Unit-based: rate per unit

  // -- Additional LHDN Details --
  String _paymentTerms = '';
  String _supplierBankAccount = '';
  String _billReference = '';

  double _prepaymentAmount = 0.0;
  DateTime? _prepaymentDate;
  String _prepaymentReference = '';

  String _billingFrequency = ''; // e.g., Monthly, Yearly
  double _taxExemptionAmount = 0.0;
  DateTime? _billingStartDate;
  DateTime? _billingEndDate;

  // ── Form State Getters ─────────────────────────────────────────────────

  List<SaleLineItem> get lineItems => _lineItems;
  Customer? get selectedCustomer => _selectedCustomer;

  bool get isDiscountRateMode => _isDiscountRateMode;
  double get discountAmount => _discountAmount;
  double get discountRate => _discountRate;
  double get feeAmount => _feeAmount;
  double get feeRate => _feeRate;

  String get discountDescription => _discountDescription;
  String get paymentMode => _paymentMode;
  String get notes => _notes;
  DateTime get saleDate => _saleDate;
  String get taxType => _taxType;
  double get taxRate => _taxRate;
  bool get submitToLhdnNow => _submitToLhdnNow;
  String? get previewInvoiceNumber => _previewInvoiceNumber;

  // --- Section Toggles ---
  bool get enableDiscountCharges => _enableDiscountCharges;
  bool get enablePaymentInfo => _enablePaymentInfo;
  bool get enablePrepayment => _enablePrepayment;
  bool get enableBillingExemption => _enableBillingExemption;

  // -- Additional LHDN Getters --
  String get paymentTerms => _paymentTerms;
  String get supplierBankAccount => _supplierBankAccount;
  String get billReference => _billReference;

  double get prepaymentAmount => _prepaymentAmount;
  DateTime? get prepaymentDate => _prepaymentDate;
  String get prepaymentReference => _prepaymentReference;

  String get billingFrequency => _billingFrequency;
  double get taxExemptionAmount => _taxExemptionAmount;
  DateTime? get billingStartDate => _billingStartDate;
  DateTime? get billingEndDate => _billingEndDate;

  // Legacy getters for compatibility with single-item logic if needed
  SaleItem? get selectedItem =>
      _lineItems.isNotEmpty ? _lineItems.first.item : null;
  double get quantity =>
      _lineItems.isNotEmpty ? _lineItems.first.quantity : 1.0;
  double get unitPrice =>
      _lineItems.isNotEmpty ? _lineItems.first.unitPrice : 0.0;

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPUTED GETTERS — The Calculation Engine
  // ══════════════════════════════════════════════════════════════════════════

  /// Line subtotal before tax and discount.
  /// Formula: sum of (unitPrice × quantity) for all line items
  double get subtotal {
    double total = 0.0;
    for (var line in _lineItems) {
      total += line.subtotal;
    }
    return _round2dp(total);
  }

  /// Computed actual discount amount (Rate % + Fixed Amount RM).
  double get actualDiscountAmount {
    if (!_enableDiscountCharges) return 0.0;
    return _round2dp(subtotal * (_discountRate / 100.0) + _discountAmount);
  }

  /// Computed actual fee amount (Rate % + Fixed Amount RM).
  double get actualFeeAmount {
    if (!_enableDiscountCharges) return 0.0;
    return _round2dp(subtotal * (_feeRate / 100.0) + _feeAmount);
  }

  /// Net amount after discount and fees, before tax.
  /// Formula: subtotal - actualDiscountAmount + actualFeeAmount
  /// Clamped at 0 to prevent negative values.
  double get netAmount {
    final net = subtotal - actualDiscountAmount + actualFeeAmount;
    return _round2dp(math.max(0.0, net));
  }

  /// Calculated tax amount.
  /// - Total Percentage mode: netAmount × (taxRate / 100)
  /// - Unit-Based mode: (total line items quantity / numUnits) × ratePerUnit
  double get taxAmount {
    if (_taxType == 'E' || _taxType == '06') return 0.00;

    // Unit-based calculation takes priority if both units and rate are set
    if (_numUnits != null && _ratePerUnit != null && _numUnits! > 0) {
      double totalQty = 0.0;
      for (var line in _lineItems) {
        totalQty += line.quantity;
      }
      return _round2dp((totalQty / _numUnits!) * _ratePerUnit!);
    }

    // Percentage mode
    if (_taxRate > 0) {
      return _round2dp(netAmount * (_taxRate / 100.0));
    }

    return 0.0;
  }

  /// Exact total before rounding.
  /// Formula: netAmount + taxAmount
  double get totalBeforeRounding {
    return _round2dp(netAmount + taxAmount);
  }

  /// The 5-cent rounding adjustment.
  double get roundingAmount {
    // 1. Remove the taxAmount == 0.00 check so it ALWAYS calculates odd cents.
    // 2. (Optional LHDN Best Practice): BNM rounding legally only applies
    //    to Cash payments ('01'). If they pay by DuitNow/Card, exact cents are kept.
    if (enablePaymentInfo && paymentMode != '01') {
      return 0.00;
    }

    return _calculateRoundingAdjustment(totalBeforeRounding);
  }

  /// Final total payable after 5-cent rounding.
  /// This is the amount the customer actually pays.
  double get totalPayable {
    return _round2dp(totalBeforeRounding + roundingAmount);
  }

  /// Whether the form has enough data to be submitted.
  bool get canSubmit {
    return _lineItems.isNotEmpty &&
        _selectedCustomer != null &&
        totalPayable >= 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the calculator with the current user's data.
  /// Loads SaleItem catalog, Customer list, and TaxConfig defaults.
  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _error = 'No authenticated user';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _currentUserId = user.uid;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load tax config defaults
      _taxConfig = await _firestoreService.getTaxConfig(user.uid);
      _taxType = _taxConfig.defaultTaxType;
      _taxRate = _taxConfig.taxRate ?? 0.0;
      _numUnits = _taxConfig.numUnits;
      _ratePerUnit = _taxConfig.ratePerUnit;

      // Stream sale items catalog
      _itemsSub?.cancel();
      _itemsSub = _firestoreService.watchSaleItems(user.uid).listen((items) {
        _saleItems = items;
        notifyListeners();
      }, onError: (e) => debugPrint('Sale items stream error: $e'));

      // Stream customers list
      _customersSub?.cancel();
      _customersSub = _firestoreService.watchCustomers(user.uid).listen((
        customerList,
      ) {
        _customers = customerList;
        notifyListeners();
      }, onError: (e) => debugPrint('Customers stream error: $e'));

      // Load business profile for pre-filling (bank account, etc.)
      _businessProfile = await _firestoreService.getBusinessProfile(user.uid);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SETTERS (mutate form state → trigger recalculation via notifyListeners)
  // ══════════════════════════════════════════════════════════════════════════

  /// Select a customer (or Walk-in).
  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void addLineItem(SaleItem item) {
    _lineItems.add(SaleLineItem(item: item));
    notifyListeners();
  }

  void updateLineItem(int index, SaleItem item) {
    if (index >= 0 && index < _lineItems.length) {
      _lineItems[index] = SaleLineItem(item: item);
      notifyListeners();
    }
  }

  void removeLineItem(int index) {
    if (index >= 0 && index < _lineItems.length) {
      _lineItems.removeAt(index);
      notifyListeners();
    }
  }

  void updateLineItemQuantity(int index, double qty) {
    if (index >= 0 && index < _lineItems.length) {
      _lineItems[index].quantity = math.max(1, qty);
      notifyListeners();
    }
  }

  void updateLineItemPrice(int index, double? price) {
    if (index >= 0 && index < _lineItems.length) {
      _lineItems[index].customPrice = price;
      notifyListeners();
    }
  }

  void setQuantity(double value) {
    if (_lineItems.isNotEmpty) {
      _lineItems[0].quantity = value;
      notifyListeners();
    }
  }

  /// Select an item from the catalog. Auto-populates unit price.
  void selectItem(SaleItem? item) {
    if (item != null) {
      _lineItems.clear();
      _lineItems.add(SaleLineItem(item: item));
      notifyListeners();
    }
  }

  void setCustomPrice(double? price) {
    if (_lineItems.isNotEmpty) {
      _lineItems[0].customPrice = price;
      notifyListeners();
    }
  }

  /// Toggle between Rate (%) and Amount (RM) modes.
  void setDiscountRateMode(bool isRate) {
    _isDiscountRateMode = isRate;
    notifyListeners();
  }

  /// Update discount amount. Clamped at 0.
  void setDiscountAmount(double value) {
    _discountAmount = math.max(0.0, value);
    notifyListeners();
  }

  /// Update discount rate. Clamped at 0.
  void setDiscountRate(double value) {
    _discountRate = math.max(0.0, value);
    notifyListeners();
  }

  /// Update fee amount. Clamped at 0.
  void setFeeAmount(double value) {
    _feeAmount = math.max(0.0, value);
    notifyListeners();
  }

  /// Update fee rate. Clamped at 0.
  void setFeeRate(double value) {
    _feeRate = math.max(0.0, value);
    notifyListeners();
  }

  /// Update discount description text.
  void setDiscountDescription(String value) {
    _discountDescription = value;
  }

  /// Update tax type code (from LhdnConstants.taxTypes).
  /// Automatically zeroes the tax rate if set to '06' or 'E'.
  void setTaxType(String code) {
    _taxType = code;
    if (code == '06' || code == 'E') {
      _taxRate = 0.0;
    }
    notifyListeners();
  }

  void setSubmitToLhdnNow(bool val) {
    _submitToLhdnNow = val;
    notifyListeners();
  }

  /// Update tax rate percentage (e.g., 6.0 for 6%).
  void setTaxRate(double value) {
    _taxRate = math.max(0.0, value);
    notifyListeners();
  }

  /// Update payment mode code (from LhdnConstants.paymentModes).
  /// If set to '03' (Bank Transfer), pre-fills the bank account from the profile.
  void setPaymentMode(String code) {
    _paymentMode = code;

    // Pre-fill bank account if it's currently empty and we have a profile with a bank account
    if (code == '03' &&
        _supplierBankAccount.isEmpty &&
        _businessProfile?.bankAccountNumber != null) {
      _supplierBankAccount = _businessProfile!.bankAccountNumber!;
    }
    notifyListeners();
  }

  /// Update notes.
  void setNotes(String value) {
    _notes = value;
  }

  /// Update sale date.
  void setSaleDate(DateTime date) {
    _saleDate = date;
    notifyListeners();
  }

  void setEnableDiscountCharges(bool val) {
    _enableDiscountCharges = val;
    notifyListeners();
  }

  void setEnablePaymentInfo(bool val) {
    _enablePaymentInfo = val;
    notifyListeners();
  }

  void setEnablePrepayment(bool val) {
    _enablePrepayment = val;
    notifyListeners();
  }

  void setEnableBillingExemption(bool val) {
    _enableBillingExemption = val;
    notifyListeners();
  }

  // -- Additional LHDN Setters --

  void setPaymentTerms(String value) {
    _paymentTerms = value;
    notifyListeners();
  }

  void setSupplierBankAccount(String value) {
    _supplierBankAccount = value;
    notifyListeners();
  }

  void setBillReference(String value) {
    _billReference = value;
    notifyListeners();
  }

  void setPrepaymentAmount(double value) {
    _prepaymentAmount = math.max(0.0, value);
    notifyListeners();
  }

  void setPrepaymentDate(DateTime? value) {
    _prepaymentDate = value;
    notifyListeners();
  }

  void setPrepaymentReference(String value) {
    _prepaymentReference = value;
    notifyListeners();
  }

  void setBillingFrequency(String value) {
    _billingFrequency = value;
    notifyListeners();
  }

  void setTaxExemptionAmount(double value) {
    _taxExemptionAmount = math.max(0.0, value);
    notifyListeners();
  }

  void setBillingPeriod(DateTime? start, DateTime? end) {
    _billingStartDate = start;
    _billingEndDate = end;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD FINALIZED SALE RECORD
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates a finalized [SaleRecord] from the current form state.
  ///
  /// [invoiceNumber] should be pre-generated from
  /// [FirestoreService.generateNextInvoiceNumber].
  ///
  /// Returns null if the form is not ready for submission.
  SaleRecord? buildSaleRecord({
    required String invoiceNumber,
    CommercialStatus? statusOverride,
    bool? submitToLhdnOverride,
  }) {
    if (!canSubmit) return null;

    final customer = _selectedCustomer!;
    final finalSubmitToLhdn = submitToLhdnOverride ?? _submitToLhdnNow;

    return SaleRecord(
      id: '', // Will be assigned by Firestore
      invoiceNumber: invoiceNumber,
      saleDate: _saleDate,
      // Customer snapshot
      customerId: customer.id,
      customerName: customer.name,
      customerType: customer.customerType,
      customerTin: customer.tinNumber,
      customerIdNumber: customer.idNumber,
      customerIdScheme: customer.idScheme,
      customerSstRegistrationNumber: customer.sstRegistrationNumber,
      // Item details
      lineItems: _lineItems,
      // Pricing (all computed)
      subtotal: subtotal,
      discountAmount: _enableDiscountCharges ? actualDiscountAmount : null,
      discountRate: _enableDiscountCharges ? _discountRate : null,
      feeAmount: _enableDiscountCharges ? actualFeeAmount : null,
      feeRate: _enableDiscountCharges ? _feeRate : null,
      discountDescription: _enableDiscountCharges ? _discountDescription : null,
      taxType: _taxType,
      taxRate: _taxRate,
      taxAmount: taxAmount,
      totalPayable: totalPayable,
      roundingAmount: roundingAmount,
      // Payment
      paymentMode: _enablePaymentInfo ? _paymentMode : null,
      // Status defaults
      commercialStatus: statusOverride ?? CommercialStatus.pendingPayment,
      complianceStatus: customer.id == 'walk-in'
          ? ComplianceStatus.pendingConsolidation
          : (finalSubmitToLhdn
                ? ComplianceStatus.valid
                : ComplianceStatus.pendingSubmission),
      // Notes
      notes: _notes,
      // Additional LHDN Details
      paymentTerms: _enablePaymentInfo ? _paymentTerms : null,
      supplierBankAccount: _enablePaymentInfo ? _supplierBankAccount : null,
      billReference: _enablePaymentInfo ? _billReference : null,
      prepaymentAmount: _enablePrepayment ? _prepaymentAmount : null,
      prepaymentDate: _enablePrepayment ? _prepaymentDate : null,
      prepaymentReference: _enablePrepayment ? _prepaymentReference : null,
      billingFrequency: _enableBillingExemption ? _billingFrequency : null,
      taxExemptionAmount: _enableBillingExemption ? _taxExemptionAmount : null,
      billingStartDate: _enableBillingExemption ? _billingStartDate : null,
      billingEndDate: _enableBillingExemption ? _billingEndDate : null,
      taxExemptionReason: _taxType == 'E'
          ? _taxConfig.taxExemptionDetails
          : null,
    );
  }

  /// Submits the sale record to Firestore.
  ///
  /// 1. Saves new customer if requested
  /// 2. Generates the next invoice number atomically
  /// 3. Builds the finalized SaleRecord
  /// 4. Persists to Firestore (Fire and Forget)
  ///
  /// Returns the saved [SaleRecord] or null on failure.
  Future<SaleRecord?> submitSale({
    bool saveNewCustomer = false,
    CommercialStatus? statusOverride,
    bool? submitToLhdnOverride,
  }) async {
    if (_currentUserId == null || !canSubmit) return null;

    try {
      _error = null;
      // Step 1: Save new customer if requested
      if (saveNewCustomer && _selectedCustomer?.id == 'temp-new') {
        final savedCustomer = await _firestoreService.addCustomer(
          _currentUserId!,
          _selectedCustomer!,
        );
        _selectedCustomer = savedCustomer;
      }

      // Step 2: Atomic invoice number
      final invoiceNumber = await _firestoreService.generateNextInvoiceNumber(
        _currentUserId!,
      );

      // Step 3: Build finalized record
      final initialRecord = buildSaleRecord(
        invoiceNumber: invoiceNumber,
        statusOverride: statusOverride,
        submitToLhdnOverride: submitToLhdnOverride,
      );
      if (initialRecord == null) return null;

      var record = initialRecord;

      // Step 4 & 5: MANDATORY: Generate Payload ONLY if not pending consolidation
      if (record.complianceStatus != ComplianceStatus.pendingConsolidation) {
        final profile = await _firestoreService.getBusinessProfile(
          _currentUserId!,
        );
        if (profile != null) {
          final payloadMap = LhdnPayloadBuilder.buildInvoicePayload(
            record: record,
            sellerProfile: profile,
          );
          final payloadJson = jsonEncode(payloadMap);
          record = record.copyWith(lastGeneratedPayload: payloadJson);
          debugPrint('LHDN Payload generated for ${record.invoiceNumber}');
        }

        // Step 5: Simulate LHDN Submission if applicable
        if (record.complianceStatus == ComplianceStatus.valid) {
          record = record.copyWith(
            lhdnUuid:
                'LHDN-${math.Random().nextInt(999999).toString().padLeft(6, '0')}',
            lhdnLongId: 'LHDN-LONG-${DateTime.now().millisecondsSinceEpoch}',
            lhdnValidatedAt: DateTime.now(),
          );
        }
      } else {
        debugPrint(
          'Skipping payload generation: Record is Pending Consolidation.',
        );
      }

      // Step 6: Persist
      final saved = await _firestoreService.addSaleRecord(
        _currentUserId!,
        record,
      );

      return saved;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Sale submission error: $e');
      return null;
    }
  }

  /// Resets the form for a fresh sale.
  void resetForm() {
    _lineItems.clear();
    _selectedCustomer = null;
    // Reset flags
    _enableDiscountCharges = false;
    _enablePaymentInfo = false;
    _enablePrepayment = false;
    _enableBillingExemption = false;

    _discountAmount = 0.0;
    _discountRate = 0.0;
    _feeAmount = 0.0;
    _feeRate = 0.0;
    _discountDescription = '';
    _paymentMode = '01';
    _notes = '';
    _saleDate = DateTime.now();
    _submitToLhdnNow = true;
    _previewInvoiceNumber = null;
    // Restore tax defaults from config
    _taxType = _taxConfig.defaultTaxType;
    _taxRate = _taxConfig.taxRate ?? 0.0;
    _numUnits = _taxConfig.numUnits;
    _ratePerUnit = _taxConfig.ratePerUnit;

    // Reset additional LHDN fields
    _paymentTerms = '';
    _supplierBankAccount = '';
    _billReference = '';
    _prepaymentAmount = 0.0;
    _prepaymentDate = null;
    _prepaymentReference = '';
    _billingFrequency = '';
    _taxExemptionAmount = 0.0;
    _billingStartDate = null;
    _billingEndDate = null;

    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRIVATE: ROUNDING LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  /// Rounds a double to 2 decimal places to avoid floating-point drift.
  static double _round2dp(double value) {
    return (value * 100).roundToDouble() / 100;
  }

  /// Calculates the Malaysian 5-cent rounding adjustment.
  ///
  /// Per Bank Negara Malaysia (BNM) Rounding Mechanism:
  /// ┌──────────────────┬──────────────┬────────────────┐
  /// │ Last 2 digits    │ Rounded to   │ Adjustment     │
  /// ├──────────────────┼──────────────┼────────────────┤
  /// │ .01, .02         │ .00          │ -0.01, -0.02   │
  /// │ .03, .04         │ .05          │ +0.02, +0.01   │
  /// │ .05              │ .05          │  0.00          │
  /// │ .06, .07         │ .05          │ -0.01, -0.02   │
  /// │ .08, .09         │ .10          │ +0.02, +0.01   │
  /// │ .00              │ .00          │  0.00          │
  /// └──────────────────┴──────────────┴────────────────┘
  static double _calculateRoundingAdjustment(double amount) {
    // Get the last digit of cents
    final cents = (amount * 100).round();
    final lastDigit = cents % 10;

    // Determine how many cents to adjust
    int adjustmentCents;
    switch (lastDigit) {
      case 0:
      case 5:
        adjustmentCents = 0;
        break;
      case 1:
      case 2:
        adjustmentCents = -lastDigit; // round down to .x0
        break;
      case 3:
      case 4:
        adjustmentCents = 5 - lastDigit; // round up to .x5
        break;
      case 6:
      case 7:
        adjustmentCents = 5 - lastDigit; // round down to .x5 (negative)
        break;
      case 8:
      case 9:
        adjustmentCents = 10 - lastDigit; // round up to .x0
        break;
      default:
        adjustmentCents = 0;
    }

    return adjustmentCents / 100.0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _itemsSub?.cancel();
    _customersSub?.cancel();
    super.dispose();
  }

  /// Pre-fetches the next invoice number for the preview sheet.
  /// Uses a read-only peek so the counter is NOT incremented.
  Future<void> fetchPreviewInvoiceNumber() async {
    if (_currentUserId == null) return;
    try {
      final nextInv = await _firestoreService.peekNextInvoiceNumber(
        _currentUserId!,
      );
      _previewInvoiceNumber = nextInv;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching preview invoice number: $e');
    }
  }
}
