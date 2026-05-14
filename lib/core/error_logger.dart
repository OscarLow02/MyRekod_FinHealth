import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralized error logger for UC-12: View Error Logs.
/// 
/// Captures non-fatal errors with custom keys and user identifiers
/// to assist in debugging OCR and LHDN API failures.
Future<void> logSystemError({
  required String errorType,
  required String reason,
  required dynamic error,
  StackTrace? stackTrace,
}) async {
  final crashlytics = FirebaseCrashlytics.instance;
  final user = FirebaseAuth.instance.currentUser;

  // Set User ID for tracking
  if (user != null) {
    await crashlytics.setUserIdentifier(user.uid);
  }

  // Set Custom Keys (Allows Admin to filter by "OCR_Failure" or "API_Timeout")
  await crashlytics.setCustomKey('error_type', errorType);
  
  // Log the actual non-fatal error
  await crashlytics.recordError(
    error,
    stackTrace,
    reason: reason,
    fatal: false, // Set to false for handled API/OCR exceptions
  );
}
