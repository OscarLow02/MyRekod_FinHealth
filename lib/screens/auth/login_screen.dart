import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/app_dialogs.dart';
import 'signup_screen.dart';

/// Login screen matching the Figma "Welcome Back" design.
/// Supports Email/Password and Google Sign-In.
/// Features: Forgot Password (reset email), Remember Me (persists email).
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
  bool _rememberMe = false;

  // SharedPreferences keys
  static const _kRememberMe = 'login_remember_me';
  static const _kSavedEmail = 'login_saved_email';

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  /// Load persisted "Remember Me" preference and pre-fill email.
  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_kRememberMe) ?? false;
    final savedEmail = prefs.getString(_kSavedEmail) ?? '';

    if (remembered && savedEmail.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
      });
    }
  }

  /// Persist or clear the "Remember Me" state.
  Future<void> _saveRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_kRememberMe, true);
      await prefs.setString(_kSavedEmail, _emailController.text.trim());
    } else {
      await prefs.setBool(_kRememberMe, false);
      await prefs.remove(_kSavedEmail);
    }
  }

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
      // Save remember-me preference before login attempt
      await _saveRememberMe();

      await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // AuthWrapper will handle navigation
    } catch (e) {
      if (!mounted) return;
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

  /// Shows a dialog to enter an email for password reset.
  Future<void> _handleForgotPassword() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    final resetFormKey = GlobalKey<FormState>();

    final confirmed = await AppDialogs.showFormModal<bool>(
      context,
      title: 'Reset Password',
      icon: Icons.lock_reset_rounded,
      primaryButtonText: 'Send Reset Link',
      secondaryButtonText: 'Cancel',
      formBody: Form(
        key: resetFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the email address associated with your account. '
              "We'll send a link to reset your password.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: resetEmailController,
              hintText: 'name@business.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Email is required';
                }
                final emailRegex =
                    RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      onPrimaryPressed: () {
        if (resetFormKey.currentState!.validate()) {
          Navigator.of(context).pop(true);
        }
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _authService
          .sendPasswordResetEmail(resetEmailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.neonGreenDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Password reset link sent to ${resetEmailController.text.trim()}',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_parseFirebaseError(e))),
      );
    } finally {
      resetEmailController.dispose();
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
      } else if (message.contains('invalid-email')) {
        return 'The email address is not valid.';
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
    const rememberMeText = 'Remember Me';
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
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.shadow
                                      .withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                              child: Image.asset(
                                'assets/App Logo.jpeg',
                                fit: BoxFit.cover,
                              ),
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
                        _buildFieldLabel(
                            theme, emailLabel, Icons.mail_outline_rounded),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hintText: emailHint,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            final emailRegex =
                                RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w+$');
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
                        AppTextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // ── Remember Me + Forgot Password Row ──
                        Row(
                          children: [
                            // Remember Me checkbox
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                                activeColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                  color: AppTheme.secondaryDark,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() => _rememberMe = !_rememberMe);
                              },
                              child: Text(
                                rememberMeText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Forgot Password link
                            TextButton(
                              onPressed: _isLoading ? null : _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                forgotPasswordText,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Login Button ──
                        AppButton(
                          text: loginButtonText,
                          onPressed: _handleEmailLogin,
                          isLoading: _isLoading,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                        AppButton(
                          text: googleText,
                          onPressed: _handleGoogleSignIn,
                          isPrimary: false,
                          isLoading: _isLoading,
                          icon: Image.asset(
                            'assets/Google.png',
                            width: 20,
                            height: 20,
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
                                            builder: (_) =>
                                                const SignUpScreen(),
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
                        const SizedBox(
                            height: 24), // Buffer for bottom of screen
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
