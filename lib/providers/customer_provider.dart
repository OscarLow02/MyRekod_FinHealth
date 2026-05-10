import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/customer.dart';
import '../services/firestore_service.dart';

class CustomerProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Customer>>? _customersSubscription;
  String? _currentUserId;
  String _searchQuery = '';

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  List<Customer> get filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    final q = _searchQuery.toLowerCase();
    return _customers.where((c) => 
      c.name.toLowerCase().contains(q) || 
      c.tinNumber.toLowerCase().contains(q)
    ).toList();
  }

  CustomerProvider() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _initialize(user.uid);
      } else {
        _clear();
      }
    });
  }

  void _initialize(String userId) {
    if (_currentUserId == userId && _customersSubscription != null) return;
    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    _customersSubscription?.cancel();
    _customersSubscription = _firestoreService.watchCustomers(userId).listen(
      (records) {
        _customers = records;
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
    _customers = [];
    _searchQuery = '';
    _customersSubscription?.cancel();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ── CRUD Operations ────────────────────────────────────────────────────

  Future<void> addCustomer(Customer customer) async {
    if (_currentUserId == null) return;
    try {
      await _firestoreService.addCustomer(_currentUserId!, customer);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    if (_currentUserId == null) return;
    try {
      await _firestoreService.updateCustomer(_currentUserId!, customer);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCustomer(String customerId) async {
    if (_currentUserId == null) return;
    try {
      await _firestoreService.deleteCustomer(_currentUserId!, customerId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _customersSubscription?.cancel();
    super.dispose();
  }
}
