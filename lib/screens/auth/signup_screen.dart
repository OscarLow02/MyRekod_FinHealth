import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_widgets.dart';

/// Sign-up screen matching the Figma "Join The Vault" design.
/// Creates a new Firebase Auth user with email, password, and display name.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      // AuthWrapper will detect the new auth state and navigate to Onboarding
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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

  String _parseFirebaseError(Object e) {
    if (e is Exception) {
      final message = e.toString();
      if (message.contains('email-already-in-use')) {
        return 'An account already exists with this email.';
      } else if (message.contains('weak-password')) {
        return 'Password is too weak. Use at least 8 characters.';
      } else if (message.contains('invalid-email')) {
        return 'Please enter a valid email address.';
      } else if (message.contains('operation-not-allowed')) {
        return 'Email/Password accounts are not enabled in Firebase Console.';
      }
    }
    // Output the exact raw error to the UI for easy debugging
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // TODO: Implement i18n — extract all user-facing strings
    const headerTitle = 'Join The Vault';
    const headerSubtitle =
        'Enter your details to get started with\nsimplified financial tracking.';
    const nameLabel = 'Full Name';
    const nameHint = 'e.g. Ahmad Hawker';
    const emailLabel = 'Email Address';
    const emailHint = 'name@example.com';
    const passwordLabel = 'Password';
    const passwordHint = 'Min. 8 characters';
    const confirmPasswordLabel = 'Confirm Password';
    const confirmPasswordHint = 'Repeat your password';
    const createAccountButtonText = 'Create Account  ›';
    const alreadyHaveAccountText = 'Already have an account?  ';
    const loginText = 'Log In';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back Button ──
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(
                            AppTheme.minTouchTarget, AppTheme.minTouchTarget),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      // TODO: Implement i18n
                      'Join The Vault',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Title ──
                Text(headerTitle, style: theme.textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(headerSubtitle, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 32),

                // ── Full Name Field ──
                _buildFieldLabel(
                    theme, nameLabel, Icons.person_outline_rounded),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  hintText: nameHint,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Email Field ──
                _buildFieldLabel(theme, emailLabel, Icons.mail_outline_rounded),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  hintText: emailHint,
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
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Confirm Password Field ──
                _buildFieldLabel(theme, confirmPasswordLabel,
                    Icons.check_circle_outline_rounded),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  hintText: confirmPasswordHint,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                // ── Create Account Button ──
                AppButton(
                  text: createAccountButtonText,
                  onPressed: _handleSignUp,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),

                // ── Login Link ──
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        alreadyHaveAccountText,
                        style: theme.textTheme.bodyLarge,
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text(
                          loginText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
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
          ),
        ),
      ],
    );
  }
}
