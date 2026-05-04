import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';
import '../models/sale_item.dart';
import '../models/sale_record.dart';
import '../models/tax_config.dart';
import '../services/firestore_service.dart';

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
  StreamSubscription<List<SaleItem>>? _itemsSub;
  StreamSubscription<List<Customer>>? _customersSub;

  List<SaleItem> get saleItems => _saleItems;
  List<Customer> get customers => _customers;
  TaxConfig get taxConfig => _taxConfig;

  // ── Form State (mutable, drives computed getters) ──────────────────────

  SaleItem? _selectedItem;
  Customer? _selectedCustomer;
  double _quantity = 1.0;
  double _discountAmount = 0.0;
  String _discountDescription = '';
  String _paymentMode = '01'; // Default: Cash
  String _notes = '';
  DateTime _saleDate = DateTime.now();

  // Tax override fields (populated from TaxConfig, editable per-sale)
  String _taxType = '06'; // Default: Not Applicable
  double _taxRate = 0.0;

  // ── Form State Getters ─────────────────────────────────────────────────

  SaleItem? get selectedItem => _selectedItem;
  Customer? get selectedCustomer => _selectedCustomer;
  double get quantity => _quantity;
  double get discountAmount => _discountAmount;
  String get discountDescription => _discountDescription;
  String get paymentMode => _paymentMode;
  String get notes => _notes;
  DateTime get saleDate => _saleDate;
  String get taxType => _taxType;
  double get taxRate => _taxRate;

  /// Unit price from the selected item, or 0 if none selected.
  double get unitPrice => _selectedItem?.unitPrice ?? 0.0;

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPUTED GETTERS — The Calculation Engine
  // ══════════════════════════════════════════════════════════════════════════

  /// Line subtotal before tax and discount.
  /// Formula: unitPrice × quantity
  double get subtotal {
    return _round2dp(unitPrice * _quantity);
  }

  /// Net amount after discount, before tax.
  /// Formula: subtotal - discountAmount
  /// Clamped at 0 to prevent negative values.
  double get netAmount {
    final net = subtotal - _discountAmount;
    return _round2dp(math.max(0.0, net));
  }

  /// Calculated tax amount.
  /// Formula: netAmount × (taxRate / 100)
  /// Returns 0 if tax type is '06' (Not Applicable) or 'E' (Exempt).
  double get taxAmount {
    if (_taxType == '06' || _taxType == 'E') return 0.0;
    return _round2dp(netAmount * (_taxRate / 100.0));
  }

  /// Exact total before rounding.
  /// Formula: netAmount + taxAmount
  double get totalBeforeRounding {
    return _round2dp(netAmount + taxAmount);
  }

  /// The 5-cent rounding adjustment.
  /// Per Malaysian Central Bank (BNM) Rounding Mechanism:
  ///   Total ending in .01 or .02 → round DOWN (adjustment: -0.01 or -0.02)
  ///   Total ending in .03 or .04 → round UP   (adjustment: +0.02 or +0.01)
  ///   Total ending in .05        → no change   (adjustment: 0.00)
  ///   Total ending in .06 or .07 → round DOWN (adjustment: -0.01 or -0.02)
  ///   Total ending in .08 or .09 → round UP   (adjustment: +0.02 or +0.01)
  ///   Total ending in .00        → no change   (adjustment: 0.00)
  double get roundingAmount {
    return _calculateRoundingAdjustment(totalBeforeRounding);
  }

  /// Final total payable after 5-cent rounding.
  /// This is the amount the customer actually pays.
  double get totalPayable {
    return _round2dp(totalBeforeRounding + roundingAmount);
  }

  /// Whether the form has enough data to be submitted.
  bool get canSubmit {
    return _selectedItem != null &&
        _selectedCustomer != null &&
        _quantity > 0 &&
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

      // Stream sale items catalog
      _itemsSub?.cancel();
      _itemsSub = _firestoreService.watchSaleItems(user.uid).listen(
        (items) {
          _saleItems = items;
          notifyListeners();
        },
        onError: (e) => debugPrint('Sale items stream error: $e'),
      );

      // Stream customers list
      _customersSub?.cancel();
      _customersSub = _firestoreService.watchCustomers(user.uid).listen(
        (customerList) {
          _customers = customerList;
          notifyListeners();
        },
        onError: (e) => debugPrint('Customers stream error: $e'),
      );

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

  /// Select an item from the catalog. Auto-populates unit price.
  void selectItem(SaleItem? item) {
    _selectedItem = item;
    notifyListeners();
  }

  /// Select a customer (or Walk-in).
  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Update quantity. Clamped to minimum 0.01.
  void setQuantity(double value) {
    _quantity = math.max(0.01, value);
    notifyListeners();
  }

  /// Update discount amount. Clamped at 0.
  void setDiscountAmount(double value) {
    _discountAmount = math.max(0.0, value);
    notifyListeners();
  }

  /// Update discount description text.
  void setDiscountDescription(String value) {
    _discountDescription = value;
    // No notifyListeners needed — no computed values depend on this.
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

  /// Update tax rate percentage (e.g., 6.0 for 6%).
  void setTaxRate(double value) {
    _taxRate = math.max(0.0, value);
    notifyListeners();
  }

  /// Update payment mode code (from LhdnConstants.paymentModes).
  void setPaymentMode(String code) {
    _paymentMode = code;
    notifyListeners();
  }

  /// Update notes.
  void setNotes(String value) {
    _notes = value;
    // No notifyListeners needed — no computed values depend on this.
  }

  /// Update sale date.
  void setSaleDate(DateTime date) {
    _saleDate = date;
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
  SaleRecord? buildSaleRecord({required String invoiceNumber}) {
    if (!canSubmit) return null;

    final item = _selectedItem!;
    final customer = _selectedCustomer!;

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
      // Item details
      itemId: item.id,
      itemName: item.name,
      measurementUnit: item.measurementUnit,
      classificationCode: item.classificationCode,
      unitPrice: item.unitPrice,
      quantity: _quantity,
      // Pricing (all computed)
      subtotal: subtotal,
      discountAmount: _discountAmount,
      discountDescription: _discountDescription,
      taxType: _taxType,
      taxRate: _taxRate,
      taxAmount: taxAmount,
      totalPayable: totalPayable,
      roundingAmount: roundingAmount,
      // Payment
      paymentMode: _paymentMode,
      // Status defaults
      commercialStatus: CommercialStatus.pendingPayment,
      complianceStatus: ComplianceStatus.pendingConsolidation,
      // Notes
      notes: _notes,
    );
  }

  /// Submits the sale record to Firestore.
  ///
  /// 1. Generates the next invoice number atomically
  /// 2. Builds the finalized SaleRecord
  /// 3. Persists to Firestore (Fire and Forget)
  ///
  /// Returns the saved [SaleRecord] or null on failure.
  Future<SaleRecord?> submitSale() async {
    if (_currentUserId == null || !canSubmit) return null;

    try {
      // Step 1: Atomic invoice number
      final invoiceNumber = await _firestoreService
          .generateNextInvoiceNumber(_currentUserId!);

      // Step 2: Build finalized record
      final record = buildSaleRecord(invoiceNumber: invoiceNumber);
      if (record == null) return null;

      // Step 3: Persist
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

  /// Resets the form to its initial state for a new sale.
  void resetForm() {
    _selectedItem = null;
    _selectedCustomer = null;
    _quantity = 1.0;
    _discountAmount = 0.0;
    _discountDescription = '';
    _paymentMode = '01';
    _notes = '';
    _saleDate = DateTime.now();
    // Restore tax defaults from config
    _taxType = _taxConfig.defaultTaxType;
    _taxRate = _taxConfig.taxRate ?? 0.0;
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
}
