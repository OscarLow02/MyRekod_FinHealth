import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around FirebaseAuth providing Email/Password
/// and Google Sign-In authentication methods.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns the currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes for reactive UI updates.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Creates a new user with email and password, then sets displayName.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  /// Signs in an existing user with email and password.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Initiates the Google Sign-In flow using google_sign_in v7+ API
  /// and authenticates with Firebase using the idToken.
  Future<UserCredential> signInWithGoogle() async {
    final gsi = GoogleSignIn.instance;

    // Initialize (safe to call multiple times; no-op if already initialized)
    await gsi.initialize();

    // Trigger the interactive sign-in flow.
    // Returns a GoogleSignInAccount on success; throws on failure.
    final GoogleSignInAccount account = await gsi.authenticate();

    // Extract the idToken from the authentication result (synchronous getter).
    final idToken = account.authentication.idToken;

    // Create an OAuthCredential for Firebase using only the idToken.
    final oauthCredential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    return await _auth.signInWithCredential(oauthCredential);
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Returns a list of provider IDs linked to the current user.
  /// Standard IDs: 'password', 'google.com', 'apple.com', 'phone'
  List<String> getProviderIds() {
    final user = _auth.currentUser;
    if (user == null) return [];
    return user.providerData.map((info) => info.providerId).toList();
  }

  /// Re-authenticates the current user using their password.
  /// Required for sensitive actions like account deactivation.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No authenticated user found for re-authentication.');
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
  }

  /// Re-authenticates the current user using Google Sign-In.
  /// Triggers an interactive popup to get fresh credentials.
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found for re-authentication.');
    }

    final gsi = GoogleSignIn.instance;
    await gsi.initialize();
    
    // Trigger identity verification
    final account = await gsi.authenticate();
    
    final idToken = account.authentication.idToken;
    final oauthCredential = GoogleAuthProvider.credential(
      idToken: idToken,
    );

    await user.reauthenticateWithCredential(oauthCredential);
  }
}
