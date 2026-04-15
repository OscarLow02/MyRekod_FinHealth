import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/business_profile.dart';
import '../services/firestore_service.dart';

/// Manages the multi-step onboarding wizard state.
/// Holds all form field values across steps and handles final submission.
class OnboardingProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // ──────────────────────────────────────────────
  // Navigation State
  // ──────────────────────────────────────────────

  int _currentStep = 0;
  int get currentStep => _currentStep;

  /// Total number of wizard pages (entity type + 3 form steps + review).
  static const int totalPages = 5;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  // ──────────────────────────────────────────────
  // Form Keys for Validation
  // ──────────────────────────────────────────────
  final stepBusinessKey = GlobalKey<FormState>();
  final stepContactKey = GlobalKey<FormState>();
  final stepAddressKey = GlobalKey<FormState>();

  bool nextStep() {
    // Validate current step before proceeding
    if (_currentStep == 1) {
      if (!(stepBusinessKey.currentState?.validate() ?? true)) return false;
    } else if (_currentStep == 2) {
      if (!(stepContactKey.currentState?.validate() ?? true)) return false;
    } else if (_currentStep == 3) {
      if (!(stepAddressKey.currentState?.validate() ?? true)) return false;
    }

    if (_currentStep < totalPages - 1) {
      _currentStep++;
      notifyListeners();
      return true;
    }
    return false;
  }

  void prevStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    _currentStep = step;
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Form Field Values
  // ──────────────────────────────────────────────

  // Step 0: Entity Type
  String _entityType = '';
  String get entityType => _entityType;

  // Step 1: Business Details
  String _businessName = '';
  String _tinNumber = '';
  String _brnNumber = '';
  bool _hasSst = false;
  String _sstNumber = '';
  bool _hasTourismTax = false;
  String _tourismTaxNumber = '';
  String _msicCode = '';
  String _businessActivityDescription = '';

  String get businessName => _businessName;
  String get tinNumber => _tinNumber;
  String get brnNumber => _brnNumber;
  bool get hasSst => _hasSst;
  String get sstNumber => _sstNumber;
  bool get hasTourismTax => _hasTourismTax;
  String get tourismTaxNumber => _tourismTaxNumber;
  String get msicCode => _msicCode;
  String get businessActivityDescription => _businessActivityDescription;

  // Step 2: Contact Details
  String _phoneNumber = '';
  String _email = '';
  String _bankAccountNumber = '';

  String get phoneNumber => _phoneNumber;
  String get email => _email;
  String get bankAccountNumber => _bankAccountNumber;

  // Step 3: Address
  String _addressLine1 = '';
  String _addressLine2 = '';
  String _addressLine3 = '';
  String _city = '';
  String _stateCode = '';
  String _postalCode = '';

  String get addressLine1 => _addressLine1;
  String get addressLine2 => _addressLine2;
  String get addressLine3 => _addressLine3;
  String get city => _city;
  String get stateCode => _stateCode;
  String get postalCode => _postalCode;

  // ──────────────────────────────────────────────
  // Field Setters
  // ──────────────────────────────────────────────

  void setEntityType(String value) {
    _entityType = value;
    notifyListeners();
  }

  void setBusinessName(String value) => _businessName = value;
  void setTinNumber(String value) => _tinNumber = value;
  void setBrnNumber(String value) => _brnNumber = value;
  void setHasSst(bool value) {
    _hasSst = value;
    if (!value) _sstNumber = '';
    notifyListeners();
  }
  void setSstNumber(String value) => _sstNumber = value;
  void setHasTourismTax(bool value) {
    _hasTourismTax = value;
    if (!value) _tourismTaxNumber = '';
    notifyListeners();
  }
  void setTourismTaxNumber(String value) => _tourismTaxNumber = value;
  void setMsicCode(String value) => _msicCode = value;
  void setBusinessActivityDescription(String value) => _businessActivityDescription = value;
  
  void setPhoneNumber(String value) => _phoneNumber = value;
  void setEmail(String value) => _email = value;
  void setBankAccountNumber(String value) => _bankAccountNumber = value;

  void setAddressLine1(String value) => _addressLine1 = value;
  void setAddressLine2(String value) => _addressLine2 = value;
  void setAddressLine3(String value) => _addressLine3 = value;
  void setCity(String value) => _city = value;
  void setStateCode(String value) {
    _stateCode = value;
    notifyListeners();
  }
  void setPostalCode(String value) => _postalCode = value;

  // ──────────────────────────────────────────────
  // Progress Helpers
  // ──────────────────────────────────────────────

  /// Returns a user-friendly progress label.
  // TODO: Implement i18n
  String get stepLabel {
    switch (_currentStep) {
      case 0:
        return 'STEP 1 OF 3';
      case 1:
        return 'STEP 1 OF 3';
      case 2:
        return 'STEP 2 OF 3';
      case 3:
        return 'STEP 3 OF 3';
      case 4:
        return 'STEP 3 OF 3';
      default:
        return '';
    }
  }

  /// Returns a percentage for the progress bar (0.0 to 1.0).
  double get progress {
    switch (_currentStep) {
      case 0:
        return 0.17;
      case 1:
        return 0.33;
      case 2:
        return 0.50;
      case 3:
        return 0.75;
      case 4:
        return 1.0;
      default:
        return 0.0;
    }
  }

  /// Returns a friendly progress hint.
  // TODO: Implement i18n
  String get progressHint {
    switch (_currentStep) {
      case 0:
        return '17%';
      case 1:
        return '33%';
      case 2:
        return '50%';
      case 3:
        return '75%';
      case 4:
        return 'Almost there';
      default:
        return '';
    }
  }

  // ──────────────────────────────────────────────
  // Submission
  // ──────────────────────────────────────────────

  /// Submits the completed profile to Firestore.
  Future<void> submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    _isSubmitting = true;
    notifyListeners();

    try {
      final profile = BusinessProfile(
        userId: user.uid,
        entityType: _entityType,
        businessName: _businessName,
        tinNumber: _tinNumber,
        brnNumber: _brnNumber,
        sstNumber: _hasSst && _sstNumber.isNotEmpty ? _sstNumber : "NA",
        tourismTaxNumber: _hasTourismTax && _tourismTaxNumber.isNotEmpty ? _tourismTaxNumber : "NA",
        msicCode: _msicCode,
        businessActivityDescription: _businessActivityDescription,
        phoneNumber: _phoneNumber,
        email: _email,
        addressLine1: _addressLine1,
        addressLine2: _addressLine2,
        addressLine3: _addressLine3,
        city: _city,
        stateCode: _stateCode,
        postalCode: _postalCode,
        bankAccountNumber: _bankAccountNumber.isNotEmpty ? _bankAccountNumber : null,
      );

      await _firestoreService.saveBusinessProfile(profile);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Resets all form state (used after successful submission or logout).
  void reset() {
    _currentStep = 0;
    _entityType = '';
    _businessName = '';
    _tinNumber = '';
    _brnNumber = '';
    _hasSst = false;
    _sstNumber = '';
    _hasTourismTax = false;
    _tourismTaxNumber = '';
    _msicCode = '';
    _businessActivityDescription = '';
    _phoneNumber = '';
    _email = '';
    _bankAccountNumber = '';
    _addressLine1 = '';
    _addressLine2 = '';
    _addressLine3 = '';
    _city = '';
    _stateCode = '';
    _postalCode = '';
    _isSubmitting = false;
    notifyListeners();
  }
}
