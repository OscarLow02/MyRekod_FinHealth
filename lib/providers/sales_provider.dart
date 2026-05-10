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

  // ── Analytics, Filtering & Pagination State ─────────────────────────────
  int _limit = 10;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _startDate = null;
    _endDate = null;
    _limit = 10;
    if (_currentUserId != null) {
      _initialize(_currentUserId!, force: true);
    }
    notifyListeners();
  }

  void loadMore() {
    if (!hasMore) return;
    // Increase limit by 10 when user scrolls to bottom
    _limit += 10;
    notifyListeners();
  }

  // 1. The Paginated List (For UI)
  List<SaleRecord> get saleRecords {
    return _allFilteredRecords.take(_limit).toList();
  }

  // 2. Internal Helper for ALL filtered records (Used for totals)
  List<SaleRecord> get _allFilteredRecords {
    return _saleRecords.where((sale) {
      // Search Logic
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        matchesSearch = sale.customerName.toLowerCase().contains(q) ||
            sale.invoiceNumber.toLowerCase().contains(q) ||
            sale.lineItems.any((line) => line.item.name.toLowerCase().contains(q));
      }

      // Date Logic
      bool matchesDate = true;
      if (_startDate != null && _endDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        matchesDate = (sale.saleDate.isAtSameMomentAs(start) || sale.saleDate.isAfter(start)) &&
                      (sale.saleDate.isAtSameMomentAs(end) || sale.saleDate.isBefore(end));
      }
      return matchesSearch && matchesDate;
    }).toList();
  }

  // 3. Dynamic Totals based on current Filter (Unlimited)
  double get filteredSalesTotal {
    return _allFilteredRecords.fold(0.0, (sum, sale) => sum + sale.totalPayable);
  }

  // 4. Status Counts (Unlimited)
  int getStatusCount({CommercialStatus? commStatus, ComplianceStatus? compStatus}) {
    return _allFilteredRecords.where((r) {
      if (commStatus != null && r.commercialStatus != commStatus) return false;
      if (compStatus != null && r.complianceStatus != compStatus) return false;
      return true;
    }).length;
  }

  int get totalFilteredCount => _allFilteredRecords.length;

  // 5. Consolidation Getters (Unfiltered by limit/search)
  List<SaleRecord> get pendingConsolidationRecords {
    return _saleRecords.where((r) => r.complianceStatus == ComplianceStatus.pendingConsolidation).toList();
  }

  List<SaleRecord> get consolidatedHistoryRecords {
    return _saleRecords.where((r) => r.consolidatedInvoiceRef != null).toList();
  }

  bool get hasMore => _allFilteredRecords.length > _limit;

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

    // Only show full-screen loader if we have no data yet
    if (_saleRecords.isEmpty) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    _salesSubscription?.cancel();
    _salesSubscription = _firestoreService
        .watchSaleRecords(userId) // Removed limit
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
    _startDate = null;
    _endDate = null;
    _limit = 10;
    _salesSubscription?.cancel();
    notifyListeners();
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
