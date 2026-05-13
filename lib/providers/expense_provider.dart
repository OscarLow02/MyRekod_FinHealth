import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_record.dart';
import '../services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/lhdn_constants.dart';

class ExpenseProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<ExpenseRecord> _expenses = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<ExpenseRecord>>? _expensesSubscription;
  String? _currentUserId;
  List<String> _categories = [];

  List<ExpenseRecord> get expenses => _expenses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get categories => _categories;

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
      _initialize(_currentUserId!);
    }
    notifyListeners();
  }

  void loadMore() {
    if (!hasMore) return;
    _limit += 10;
    notifyListeners();
  }

  // 1. The Paginated List (For UI)
  List<ExpenseRecord> get expenseRecords {
    return _allFilteredRecords.take(_limit).toList();
  }

  /// Returns ALL filtered records without the pagination limit.
  List<ExpenseRecord> get allFilteredRecords => _allFilteredRecords;

  // 2. Internal Helper for ALL filtered records
  List<ExpenseRecord> get _allFilteredRecords {
    return _expenses.where((expense) {
      // Search Logic
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        matchesSearch = expense.vendor.toLowerCase().contains(q) ||
            expense.category.toLowerCase().contains(q);
      }

      // Date Logic
      bool matchesDate = true;
      if (_startDate != null && _endDate != null) {
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        matchesDate = (expense.date.isAtSameMomentAs(start) || expense.date.isAfter(start)) &&
                      (expense.date.isAtSameMomentAs(end) || expense.date.isBefore(end));
      }
      return matchesSearch && matchesDate;
    }).toList();
  }

  // 3. Dynamic Totals based on current Filter
  double get filteredExpensesTotal {
    return _allFilteredRecords.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  int get totalFilteredCount => _allFilteredRecords.length;

  bool get hasMore => _allFilteredRecords.length > _limit;

  ExpenseProvider() {
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

    _expensesSubscription?.cancel();
    _expensesSubscription = _firestoreService
        .watchExpenses(userId)
        .listen(
          (expenseList) {
            _expenses = expenseList;
            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
    
    // Load categories when initializing
    loadCategories();
  }

  void _clear() {
    _currentUserId = null;
    _expenses = [];
    _expensesSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _expensesSubscription?.cancel();
    super.dispose();
  }

  Future<void> addExpense(ExpenseRecord expense) async {
    if (_currentUserId == null) throw Exception('No authenticated user');
    try {
      await _firestoreService.addExpense(_currentUserId!, expense);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateExpense(ExpenseRecord expense) async {
    if (_currentUserId == null) throw Exception('No authenticated user');
    try {
      await _firestoreService.updateExpense(_currentUserId!, expense);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    if (_currentUserId == null) throw Exception('No authenticated user');
    try {
      await _firestoreService.deleteExpense(_currentUserId!, expenseId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Analytics & Filtering ────────────────────────────────────────────────

  double get totalExpenses {
    return _expenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  List<ExpenseRecord> getExpensesByCategory(String category) {
    if (category.toLowerCase() == 'all') return _expenses;
    return _expenses.where((e) => e.category == category).toList();
  }

  /// Filter records by date range (inclusive).
  List<ExpenseRecord> getRecordsInRange(DateTime start, DateTime end) {
    // Normalize to start and end of day
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);

    return _expenses.where((r) {
      return (r.date.isAtSameMomentAs(s) || r.date.isAfter(s)) &&
             (r.date.isAtSameMomentAs(e) || r.date.isBefore(e));
    }).toList();
  }

  // ── Categories Management ────────────────────────────────────────────────
  Future<void> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('expense_categories');
    if (saved != null) {
      _categories = saved;
    } else {
      // Default initialization from constants
      _categories = List.from(LhdnConstants.expenseCategories);
    }
    notifyListeners();
  }

  Future<void> addCategory(String category) async {
    if (!_categories.contains(category)) {
      _categories.add(category);
      await _saveCategories();
    }
  }

  Future<void> updateCategory(String oldName, String newName) async {
    final index = _categories.indexOf(oldName);
    if (index != -1 && !_categories.contains(newName)) {
      _categories[index] = newName;
      await _saveCategories();
    }
  }

  Future<void> deleteCategory(String category) async {
    _categories.remove(category);
    await _saveCategories();
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('expense_categories', _categories);
    notifyListeners();
  }
}
