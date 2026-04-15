class AppValidators {
  /// Required field check.
  static String? requiredField(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName is required' : 'This field is required';
    }
    return null;
  }

  /// LHDN TIN Regex validation: ^(IG|C|D|E|F)\d{10,11}$
  static String? tin(String? value) {
    if (value == null || value.trim().isEmpty) return 'TIN is required';
    final regex = RegExp(r'^(IG|C|D|E|F)\d{10,11}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Invalid TIN format (e.g. IG12345678901)';
    }
    return null;
  }

  /// Registration / ID Number (M) - 12-digit (SSM BRN / MyKad) or Alphanumeric (Passport)
  /// For simplicity frontend checks length > 5, backend determines scheme.
  static String? brn(String? value, String entityType) {
    if (value == null || value.trim().isEmpty) return 'Registration/ID is required';
    // Remove dashes for internal validation check
    final numericOnly = value.replaceAll('-', '').trim();
    if (entityType == 'Business' || (entityType == 'Person' && numericOnly.length == 12 && int.tryParse(numericOnly) != null)) {
      if (numericOnly.length != 12) {
        return 'Must be a 12-digit number';
      }
    } else if (entityType == 'Person') {
      // Passport alphanum fallback
      if (value.trim().length < 5) return 'Invalid passport/ID format';
    }
    return null;
  }

  /// International phone number — must start with a + dial code followed by 5–14 digits.
  /// The [PhoneInputField] widget stores the full number (e.g. +60123456789).
  /// Accepts: +60123456789, +1 555 000 1234, +447911123456
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    // Strip spaces and dashes for validation
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    // Must start with + followed by 6–15 digits total (dial code + local number)
    final regex = RegExp(r'^\+\d{6,15}$');
    if (!regex.hasMatch(cleaned)) {
      return 'Invalid format (e.g. +60123456789)';
    }
    return null;
  }

  /// Standard Email Regex — required for Business Profile, optional in onboarding.
  static String? email(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Email address is required' : null;
    }
    final regex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Invalid email address';
    }
    return null;
  }

  /// Required email — convenience wrapper for Business Profile where email is mandatory.
  static String? requiredEmail(String? value) => email(value, required: true);

  /// Postal Zone: 5 digits ^\d{5}$
  static String? postalCode(String? value) {
    if (value == null || value.trim().isEmpty) return 'Postal Code is required';
    final regex = RegExp(r'^\d{5}$');
    if (!regex.hasMatch(value.trim())) {
      return 'Must be 5 digits';
    }
    return null;
  }

  /// Numeric Digits Only (e.g. Bank Account)
  static String? numeric(String? value, [String? fieldName]) {
    // Optional field check
    if (value == null || value.trim().isEmpty) return null;
    final regex = RegExp(r'^\d+$');
    if (!regex.hasMatch(value.replaceAll('-', '').replaceAll(' ', '').trim())) {
      return 'Numeric digits only';
    }
    return null;
  }
}
