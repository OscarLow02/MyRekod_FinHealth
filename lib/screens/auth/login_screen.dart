import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'signup_screen.dart';

/// Login screen matching the Figma "Welcome Back" design.
/// Supports Email/Password and Google Sign-In.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthWrapper will handle navigation
    } catch (e) {
      if (!mounted) return;
      // TODO: Implement i18n — localize error messages
      final errorMessage = _parseFirebaseError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      // AuthWrapper will handle navigation
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_parseFirebaseError(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseFirebaseError(Object e) {
    if (e is Exception) {
      final message = e.toString();
      if (message.contains('user-not-found')) {
        return 'No account found with this email.';
      } else if (message.contains('wrong-password') ||
          message.contains('invalid-credential')) {
        return 'Incorrect email or password.';
      } else if (message.contains('too-many-requests')) {
        return 'Too many attempts. Please try again later.';
      } else if (message.contains('google-sign-in-cancelled')) {
        return 'Google Sign-In was cancelled.';
      } else if (message.contains('operation-not-allowed')) {
        return 'Email/Password accounts are not enabled in Firebase Console.';
      }
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Implement i18n — extract all user-facing strings
    const headerTitle = 'Welcome Back';
    const headerSubtitle = 'Securely access your digital treasury';
    const emailLabel = 'EMAIL ADDRESS';
    const emailHint = 'name@business.com';
    const passwordLabel = 'PASSWORD';
    const passwordHint = '••••••••';
    const forgotPasswordText = 'Forgot Password?';
    const loginButtonText = 'Log In  →';
    const orContinueText = 'OR CONTINUE WITH';
    const googleText = 'Google';
    const noAccountText = "Don't have an account?  ";
    const createAccountText = 'Create an account';

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 64, // Subtract padding
                ),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                const SizedBox(height: 24),

                // ── Brand Icon ──
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Title ──
                Center(
                  child: Text(
                    headerTitle,
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    headerSubtitle,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Email Field ──
                _buildFieldLabel(theme, emailLabel, Icons.mail_outline_rounded),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(hintText: emailHint),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Password Field ──
                _buildFieldLabel(
                    theme, passwordLabel, Icons.lock_outline_rounded),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: passwordHint,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(
                            () => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // ── Forgot Password ──
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Implement forgot password flow
                    },
                    child: Text(
                      forgotPasswordText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Login Button ──
                SizedBox(
                  width: double.infinity,
                  height: AppTheme.minTouchTarget + 8,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(loginButtonText),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Divider ──
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        orContinueText,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Google Sign-In Button ──
                SizedBox(
                  width: double.infinity,
                  height: AppTheme.minTouchTarget + 8,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, e, s) => const Icon(
                        Icons.g_mobiledata_rounded,
                        size: 24,
                      ),
                    ),
                    label: const Text(googleText),
                  ),
                ),
                const SizedBox(height: 24),

                const Spacer(),

                // ── Create Account Link ──
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        noAccountText,
                        style: theme.textTheme.bodyLarge,
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          createAccountText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: _isLoading
                                ? theme.disabledColor
                                : AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: _isLoading
                                ? theme.disabledColor
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24), // Buffer for bottom of screen

                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
