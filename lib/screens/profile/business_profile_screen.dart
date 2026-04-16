import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/business_profile.dart';
import '../../core/lhdn_constants.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/phone_input_field.dart';
import '../../core/validators.dart';
import '../../widgets/app_dialogs.dart';
import '../../services/auth_service.dart';

/// Business Profile settings screen.
/// Toggles between read-only and editable modes.
/// Matches the "Luminescent Vault" design with sectioned cards.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  bool _isEditMode = false;
  bool _isLoading = true;
  bool _isSaving = false;
  BusinessProfile? _profile;

  // ── Text Editing Controllers ──
  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _tinCtrl;
  late final TextEditingController _brnCtrl;
  late final TextEditingController _sstCtrl;
  late final TextEditingController _tourismTaxCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _msicCtrl;
  late final TextEditingController _activityDescCtrl;
  late final TextEditingController _addressLine1Ctrl;
  late final TextEditingController _addressLine2Ctrl;
  late final TextEditingController _addressLine3Ctrl;
  late final TextEditingController _postcodeCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _bankAccountCtrl;

  @override
  void initState() {
    super.initState();
    _businessNameCtrl = TextEditingController();
    _tinCtrl = TextEditingController();
    _brnCtrl = TextEditingController();
    _sstCtrl = TextEditingController();
    _tourismTaxCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _msicCtrl = TextEditingController();
    _activityDescCtrl = TextEditingController();
    _addressLine1Ctrl = TextEditingController();
    _addressLine2Ctrl = TextEditingController();
    _addressLine3Ctrl = TextEditingController();
    _postcodeCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _bankAccountCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _tinCtrl.dispose();
    _brnCtrl.dispose();
    _sstCtrl.dispose();
    _tourismTaxCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _msicCtrl.dispose();
    _activityDescCtrl.dispose();
    _addressLine1Ctrl.dispose();
    _addressLine2Ctrl.dispose();
    _addressLine3Ctrl.dispose();
    _postcodeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _bankAccountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await FirestoreService().getBusinessProfile(user.uid);
      if (mounted && profile != null) {
        setState(() {
          _profile = profile;
          _populateControllers(profile);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers(BusinessProfile profile) {
    _businessNameCtrl.text = profile.businessName;
    _tinCtrl.text = profile.tinNumber;
    _brnCtrl.text = profile.brnNumber;
    _sstCtrl.text = profile.sstNumber;
    _tourismTaxCtrl.text = profile.tourismTaxNumber;
    _emailCtrl.text = profile.email;
    _phoneCtrl.text = profile.phoneNumber;
    // Normalize MSIC code (if stored in legacy "Code - Name" format)
    String msic = profile.msicCode;
    if (msic.contains(' - ')) {
      msic = msic.split(' - ').first;
    }
    _msicCtrl.text = msic;
    _activityDescCtrl.text = profile.businessActivityDescription;
    _addressLine1Ctrl.text = profile.addressLine1;
    _addressLine2Ctrl.text = profile.addressLine2;
    _addressLine3Ctrl.text = profile.addressLine3;
    _postcodeCtrl.text = profile.postalCode;
    _cityCtrl.text = profile.city;
    _stateCtrl.text = profile.stateCode;
    _bankAccountCtrl.text = profile.bankAccountNumber ?? '';
  }

  void _toggleEditMode() {
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = BusinessProfile(
        userId: user.uid,
        entityType: _profile?.entityType ?? 'Business',
        businessName: _businessNameCtrl.text.trim(),
        tinNumber: _tinCtrl.text.trim(),
        brnNumber: _brnCtrl.text.trim(),
        sstNumber: _sstCtrl.text.trim().isEmpty ? 'NA' : _sstCtrl.text.trim(),
        tourismTaxNumber: _tourismTaxCtrl.text.trim().isEmpty
            ? 'NA'
            : _tourismTaxCtrl.text.trim(),
        msicCode: _msicCtrl.text.trim(),
        businessActivityDescription: _activityDescCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        imageUrl: _profile?.imageUrl, // CRITICAL: Preserve image URL
        addressLine1: _addressLine1Ctrl.text.trim(),
        addressLine2: _addressLine2Ctrl.text.trim(),
        addressLine3: _addressLine3Ctrl.text.trim(),
        city: _cityCtrl.text.trim(),
        stateCode: _stateCtrl.text.trim(),
        postalCode: _postcodeCtrl.text.trim(),
        bankAccountNumber: _bankAccountCtrl.text.trim().isEmpty
            ? null
            : _bankAccountCtrl.text.trim(),
      );

      await FirestoreService().saveBusinessProfile(updated);

      if (mounted) {
        setState(() {
          _profile = updated;
          _isEditMode = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Profile saved successfully!'),
              ],
            ),
            backgroundColor: AppTheme.neonGreenDark,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      maxWidth: 512, 
      maxHeight: 512,
      imageQuality: 85,
    );
    
    if (pickedFile == null) return;
    
    setState(() => _isLoading = true);
    try {
      final file = File(pickedFile.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('business_profiles')
          .child(user.uid)
          .child('profile.jpg');

      // 1. Upload with metadata
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      
      // 2. Resilience: Retry getDownloadURL with a small delay
      String? url;
      int retries = 3;
      while (retries > 0) {
        try {
          url = await snapshot.ref.getDownloadURL();
          break; 
        } catch (err) {
          retries--;
          if (retries == 0) rethrow;
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      if (url != null && _profile != null) {
        final updated = _profile!.copyWith(imageUrl: url);
        await FirestoreService().saveBusinessProfile(updated);
        if (mounted) {
          setState(() {
            _profile = updated;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo updated successfully'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Shows a premium password confirmation dialog using AppDialogs infrastructure.
  Future<String?> _showPasswordReAuthDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscure = true;
    String? capturedPassword;

    final confirmed = await AppDialogs.showFormModal(
      context,
      title: 'Verify Identity',
      icon: Icons.lock_person_rounded,
      primaryButtonText: 'CONFIRM',
      secondaryButtonText: 'CANCEL',
      formBody: StatefulBuilder(
        builder: (context, setDialogState) => Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please enter your password to confirm account deactivation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                validator: (v) => AppValidators.requiredField(v, 'Password'),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.password_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      onPrimaryPressed: () async {
        if (!formKey.currentState!.validate()) return false;
        capturedPassword = controller.text; // capture before dialog closes
        return true;
      },
    );

    controller.dispose();
    return confirmed ? capturedPassword : null;
  }


  Future<void> _deactivateAccount() async {
    // 1. Initial Confirmation Warning
    bool confirmed = false;
    await AppDialogs.showActionModal(
      context,
      title: 'Deactivate Account',
      body:
          'Are you sure you want to deactivate your business account? This action is permanent and cannot be undone.',
      primaryButtonText: 'PROCEED TO VERIFY',
      onPrimaryPressed: () => confirmed = true,
      secondaryButtonText: 'CANCEL',
      onSecondaryPressed: () => confirmed = false,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.redAccent,
      primaryButtonColor: Colors.redAccent,
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 2. Identity Verification (The Gatekeeper)
      final providers = _authService.getProviderIds();
      bool reAuthSuccess = false;

      if (providers.contains('google.com')) {
        await _authService.reauthenticateWithGoogle();
        reAuthSuccess = true;
      } else if (providers.contains('password')) {
        final password = await _showPasswordReAuthDialog();
        if (password != null) {
          await _authService.reauthenticateWithPassword(password);
          reAuthSuccess = true;
        }
      } else {
        // Unknown provider? Fallback to user.delete() which might fail with re-auth needed
        await user.delete();
        reAuthSuccess = true;
      }

      // 3. Destructive Actions (Only if verified)
      if (reAuthSuccess) {
        // STEP 1: Delete Firestore Data first (Atomic sequence start)
        await FirestoreService().deleteFullProfile(user.uid);
        
        // STEP 2: Delete Auth Account second (Identity wipe)
        await user.delete();

        if (mounted) {
          // Success: Route to external splash/login
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Authentication failed.';
        if (e.code == 'wrong-password') msg = 'Incorrect password. Deactivation aborted.';
        if (e.code == 'user-mismatch') msg = 'Account security mismatch.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification interrupted: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            minimumSize: const Size(
              AppTheme.minTouchTarget,
              AppTheme.minTouchTarget,
            ),
          ),
        ),
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _toggleEditMode,
            icon: Icon(
              _isEditMode ? Icons.close_rounded : Icons.edit_rounded,
              color: _isEditMode
                  ? Colors.redAccent
                  : AppTheme.primary,
            ),
            tooltip: _isEditMode ? 'Cancel Edit' : 'Edit Profile',
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AppTheme.minTouchTarget,
                AppTheme.minTouchTarget,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24, 16, 24, _isEditMode ? 100 : 32,
                    ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Avatar Section ──
                      _buildAvatarSection(theme),
                      const SizedBox(height: 32),

                      // ── Core Identity ──
                      _buildSectionTitle(theme, 'Core Identity'),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.store_rounded,
                        label: 'Legal Business Name',
                        controller: _businessNameCtrl,
                        validator: (v) => AppValidators.requiredField(v, 'Legal Business Name'),
                      ),
                      const SizedBox(height: 16),
                      _buildMsicDropdown(theme),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.description_outlined,
                        label: 'Business Description (Activity Description)',
                        controller: _activityDescCtrl,
                        maxLines: 3,
                        validator: (v) => AppValidators.requiredField(v, 'Business Description'),
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.account_balance_outlined,
                        label: 'Bank Account Number',
                        controller: _bankAccountCtrl,
                      ),
                      const SizedBox(height: 32),

                      // ── Tax Information ──
                      _buildSectionTitle(theme, 'Tax Information'),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.badge_outlined,
                        label: 'TIN',
                        controller: _tinCtrl,
                        validator: AppValidators.tin,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.credit_card_rounded,
                        label: 'Business Registration / IC',
                        controller: _brnCtrl,
                        validator: (v) => AppValidators.brn(v, _profile?.entityType ?? 'Business'),
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.percent_rounded,
                        label: 'SST Number',
                        controller: _sstCtrl,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.flight_takeoff_rounded,
                        label: 'Tourism Tax Number',
                        controller: _tourismTaxCtrl,
                      ),
                      const SizedBox(height: 32),

                      // ── Contact Information ──
                      _buildSectionTitle(theme, 'Contact Information'),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.email_outlined,
                        label: 'Business Email',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        validator: AppValidators.requiredEmail,
                        readOnly: true,
                        hintText: 'Email matched to your authentication account',
                      ),
                      const SizedBox(height: 16),
                      PhoneInputField(
                        label: 'Phone Number',
                        controller: _phoneCtrl,
                        readOnly: !_isEditMode,
                      ),
                      const SizedBox(height: 32),

                      // ── Location ──
                      _buildSectionTitle(theme, 'Location'),
                      const SizedBox(height: 16),
                      if (!_isEditMode)
                        _buildLabeledField(
                          theme,
                          icon: Icons.location_on_outlined,
                          label: 'Address',
                          controller: TextEditingController(
                            text: [
                              _addressLine1Ctrl.text,
                              _addressLine2Ctrl.text,
                              _addressLine3Ctrl.text,
                              '${_postcodeCtrl.text} ${_cityCtrl.text}'.trim(),
                              LhdnConstants.stateCodes[_stateCtrl.text] ?? _stateCtrl.text
                            ].where((s) => s.isNotEmpty).join('\n'),
                          ),
                          maxLines: 4,
                        )
                      else ...[
                        _buildLabeledField(
                          theme,
                          icon: Icons.location_on_outlined,
                          label: 'Address Line 1*',
                          controller: _addressLine1Ctrl,
                          validator: (v) => AppValidators.requiredField(v, 'Address Line 1'),
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          theme,
                          icon: Icons.location_city_outlined,
                          label: 'Address Line 2 (Optional)',
                          controller: _addressLine2Ctrl,
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          theme,
                          icon: Icons.add_business_outlined,
                          label: 'Address Line 3 (Optional)',
                          controller: _addressLine3Ctrl,
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          theme,
                          icon: Icons.apartment_outlined,
                          label: 'City*',
                          controller: _cityCtrl,
                          validator: (v) => AppValidators.requiredField(v, 'City'),
                        ),
                        const SizedBox(height: 16),
                        _buildLabeledField(
                          theme,
                          icon: Icons.mark_as_unread_outlined,
                          label: 'Postcode*',
                          controller: _postcodeCtrl,
                          validator: AppValidators.postalCode,
                        ),
                        const SizedBox(height: 16),
                        _buildStateDropdown(theme),
                      ],
                      const SizedBox(height: 32),

                      // ── Future Sprint Use Cases (Commented for now) ──
                      /*
                      if (_isEditMode)
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              AppDialogs.showActionModal(
                                context,
                                title: 'Test Delete?',
                                body: 'Are you sure you want to delete this test?',
                                primaryButtonText: 'Yes, Delete',
                                onPrimaryPressed: () {},
                                secondaryButtonText: 'Cancel',
                                onSecondaryPressed: () {},
                              );
                            },
                            child: const Text('TEST MODAL'),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (_isEditMode)
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              AppDialogs.showFeatureDiscoverySheet(
                                context,
                                title: 'Score Improved!',
                                body: 'Your Business Health Score is now Excellent!',
                                primaryButtonText: 'Keep it Up',
                                onPrimaryPressed: () {},
                                heroIcon: Icons.verified_rounded,
                                customHeroContent: const Text(
                                  '842',
                                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              );
                            },
                            child: const Text('TEST BOTTOM SHEET'),
                          ),
                        ),
                      const SizedBox(height: 32),
                      */

                      // ── Deactivate Button ──
                      Center(
                        child: TextButton.icon(
                          onPressed: _deactivateAccount,
                          icon: const Icon(Icons.warning_amber_rounded,
                              size: 18),
                          label: const Text(
                            'DEACTIVATE BUSINESS ACCOUNT',
                            style: TextStyle(
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            minimumSize: const Size(0, AppTheme.minTouchTarget),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
                ),

                // ── Floating Save Button (edit mode only) ──
                if (_isEditMode)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: SizedBox(
                      height: AppTheme.minTouchTarget + 8,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 20),
                        label: Text(_isSaving ? 'SAVING…' : 'SAVE CHANGES'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          elevation: 6,
                          shadowColor:
                              AppTheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Avatar with camera overlay ──
  Widget _buildAvatarSection(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _isEditMode ? _uploadProfilePhoto : null,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  backgroundImage: _profile?.imageUrl != null 
                      ? NetworkImage(_profile!.imageUrl!) 
                      : null,
                  child: _profile?.imageUrl == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: AppTheme.primary.withValues(alpha: 0.8),
                        )
                      : null,
                ),
                if (_isEditMode)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isEditMode) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _uploadProfilePhoto,
              child: Text(
                'UPDATE PHOTO',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section title ──
  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Labeled text field with icon ──
  Widget _buildLabeledField(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool? readOnly,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly ?? !_isEditMode,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: (readOnly == true)
                ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
                : theme.colorScheme.onSurface,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: (readOnly == true || !_isEditMode)
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6)
                : theme.colorScheme.surfaceContainerHighest,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: _isEditMode
                  ? BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: _isEditMode
                  ? BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              borderSide: const BorderSide(
                color: AppTheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── MSIC dropdown ──
  Widget _buildMsicDropdown(ThemeData theme) {
    return CustomPremiumDropdown<String>(
      label: 'Industry Sector (MSIC Code)',
      items: CustomDropdownBuilder.fromMap(LhdnConstants.msicCodes, icon: Icons.category_outlined),
      value: LhdnConstants.msicCodes.containsKey(_msicCtrl.text) ? _msicCtrl.text : null,
      onChanged: (val) {
        if (val != null) setState(() => _msicCtrl.text = val);
      },
      isEditMode: _isEditMode,
      isSearchable: true,
      hint: 'Select Industry Sector',
      validator: (v) => AppValidators.requiredField(v, 'Industry Sector'),
    );
  }

  // ── State dropdown ──
  Widget _buildStateDropdown(ThemeData theme) {
    return CustomPremiumDropdown<String>(
      label: 'State / Region',
      items: CustomDropdownBuilder.fromMap(LhdnConstants.stateCodes, icon: Icons.map_outlined),
      value: LhdnConstants.stateCodes.containsKey(_stateCtrl.text) ? _stateCtrl.text : null,
      onChanged: (val) {
        if (val != null) setState(() => _stateCtrl.text = val);
      },
      isEditMode: _isEditMode,
      isSearchable: true,
      hint: 'Select State',
      validator: (v) => AppValidators.requiredField(v, 'State / Region'),
    );
  }

  // ── Public Visibility toggle ── REMOVED (not in scope for this sprint)
}

