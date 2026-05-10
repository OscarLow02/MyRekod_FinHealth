import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/sale_record.dart';
import '../services/firestore_service.dart';

/// Global provider that streams and manages the user's sale records.
///
/// Mirrors [ExpenseProvider] architecture:
/// - Auto-initializes on auth state change
/// - Streams sale records from Firestore (newest first)
/// - Provides convenience getters for analytics
///
/// Note: This provider is for *listing* and *managing* existing sales.
/// For *creating* a new sale, the screen-scoped [SaleCalculatorProvider]
/// handles the form state and submission flow.
class SalesProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<SaleRecord> _saleRecords = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<SaleRecord>>? _salesSubscription;
  String? _currentUserId;

  // ── New State for UI Dashboard ───────────────────────────────────────────
  String _searchQuery = '';
  DateTime? _filterDate;
  int _limit = 10;

  String get searchQuery => _searchQuery;
  DateTime? get filterDate => _filterDate;

  List<SaleRecord> get saleRecords {
    Iterable<SaleRecord> filtered = _saleRecords;

    // 1. Filter by search query (customer or item name)
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((r) {
        final nameMatch = r.customerName.toLowerCase().contains(query);
        final itemMatch = r.lineItems.any(
          (li) => li.item.name.toLowerCase().contains(query),
        );
        return nameMatch || itemMatch;
      });
    }

    // 2. Filter by date (Exact match of Y/M/D)
    if (_filterDate != null) {
      filtered = filtered.where((r) {
        return r.saleDate.year == _filterDate!.year &&
            r.saleDate.month == _filterDate!.month &&
            r.saleDate.day == _filterDate!.day;
      });
    }

    return filtered.toList();
  }

  /// Calculates the total amount based strictly on currently filtered records.
  double get filteredSalesTotal {
    return saleRecords.fold(0.0, (sum, r) => sum + r.totalPayable);
  }

  /// Returns only records awaiting monthly consolidated submission.
  List<SaleRecord> get pendingConsolidationRecords => _saleRecords
      .where((r) => r.complianceStatus == ComplianceStatus.pendingConsolidation && r.consolidatedInvoiceRef == null)
      .toList();

  /// Returns records that have already been rolled into a consolidated invoice.
  List<SaleRecord> get consolidatedHistoryRecords => _saleRecords
      .where((r) => r.consolidatedInvoiceRef != null)
      .toList();

  bool get isLoading => _isLoading;
  String? get error => _error;

  SalesProvider() {
    // Listen to auth state changes to auto-initialize or clear
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _initialize(user.uid);
      } else {
        _clear();
      }
    });
  }

  void _initialize(String userId, {bool force = false}) {
    if (!force && _currentUserId == userId && _salesSubscription != null) return;
    _currentUserId = userId;

    _isLoading = true;
    _error = null;
    notifyListeners();

    _salesSubscription?.cancel();
    _salesSubscription = _firestoreService
        .watchSaleRecords(userId, limit: _limit)
        .listen(
          (records) {
            _saleRecords = records;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  void _clear() {
    _currentUserId = null;
    _saleRecords = [];
    _searchQuery = '';
    _filterDate = null;
    _limit = 10;
    _salesSubscription?.cancel();
    notifyListeners();
  }

  // ── Dashboard Control Methods ────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDateFilter(DateTime? date) {
    _filterDate = date;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _filterDate = null;
    _limit = 10;
    if (_currentUserId != null) {
      _initialize(_currentUserId!, force: true);
    }
    notifyListeners();
  }

  void loadMore() {
    _limit += 10;
    if (_currentUserId != null) {
      _initialize(_currentUserId!, force: true);
    }
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }

  // ── CRUD Operations ────────────────────────────────────────────────────

  Future<void> deleteSaleRecord(String recordId) async {
    if (_currentUserId == null) throw Exception('No authenticated user');
    try {
      await _firestoreService.deleteSaleRecord(_currentUserId!, recordId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateSaleRecord(SaleRecord record) async {
    if (_currentUserId == null) throw Exception('No authenticated user');
    try {
      await _firestoreService.updateSaleRecord(_currentUserId!, record);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Analytics & Filtering ────────────────────────────────────────────────

  /// Total sales amount across all records.
  double get totalSales {
    return _saleRecords.fold(0.0, (sum, r) => sum + r.totalPayable);
  }

  /// Today's sales total.
  double get todaySalesTotal {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _saleRecords
        .where((r) => r.saleDate.isAfter(todayStart))
        .fold(0.0, (sum, r) => sum + r.totalPayable);
  }

  /// Filter records by date range.
  List<SaleRecord> getRecordsInRange(DateTime start, DateTime end) {
    return _saleRecords
        .where((r) => r.saleDate.isAfter(start) && r.saleDate.isBefore(end))
        .toList();
  }

  /// Filter records by compliance status.
  List<SaleRecord> getRecordsByStatus(ComplianceStatus status) {
    return _saleRecords
        .where((r) => r.complianceStatus == status)
        .toList();
  }
}
