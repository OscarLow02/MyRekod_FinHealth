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

  List<SaleRecord> get saleRecords => _saleRecords;
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

  void _initialize(String userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;

    _isLoading = true;
    _error = null;
    notifyListeners();

    _salesSubscription?.cancel();
    _salesSubscription = _firestoreService
        .watchSaleRecords(userId)
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
