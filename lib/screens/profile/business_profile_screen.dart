import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../models/business_profile.dart';
import '../../core/lhdn_constants.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/phone_input_field.dart';

/// Business Profile settings screen.
/// Toggles between read-only and editable modes.
/// Matches the "Luminescent Vault" design with sectioned cards.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
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
        // Populate with mock data if no profile exists yet
        _populateWithMockData();
        setState(() => _isLoading = false);
      }
    } else {
      _populateWithMockData();
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
    _msicCtrl.text = profile.msicCode;
    _activityDescCtrl.text = profile.businessActivityDescription;
    _addressLine1Ctrl.text = profile.addressLine1;
    _addressLine2Ctrl.text = profile.addressLine2;
    _addressLine3Ctrl.text = profile.addressLine3;
    _postcodeCtrl.text = profile.postalCode;
    _cityCtrl.text = profile.city;
    _stateCtrl.text = profile.stateCode;
    _bankAccountCtrl.text = profile.bankAccountNumber ?? '';
  }

  void _populateWithMockData() {
    _businessNameCtrl.text = 'Golden Stall Gourmet';
    _tinCtrl.text = 'C2018274090';
    _brnCtrl.text = '20180102934X';
    _sstCtrl.text = 'W10-1808-32000123';
    _tourismTaxCtrl.text = '-';
    _emailCtrl.text = 'admin@goldenstall.com';
    _phoneCtrl.text = '+60 12-345 6789';
    _msicCtrl.text = '56101';
    _activityDescCtrl.text =
        'Premium artisanal street food serving the central district since 2018. Specialized in fusion hawker cuisine.';
    _addressLine1Ctrl.text =
        'No 4, Central Market Hawker Centre, Jalan Hang Kasturi,';
    _addressLine2Ctrl.text = '50050 Kuala Lumpur, Malaysia';
    _addressLine3Ctrl.text = '';
    _postcodeCtrl.text = '50050';
    _cityCtrl.text = 'Kuala Lumpur';
    _stateCtrl.text = '14';
    _bankAccountCtrl.text = '702-91823-1';
  }

  void _toggleEditMode() {
    setState(() => _isEditMode = !_isEditMode);
  }

  Future<void> _handleSave() async {
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
                SingleChildScrollView(
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
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledField(
                        theme,
                        icon: Icons.credit_card_rounded,
                        label: 'Business Registration / IC',
                        controller: _brnCtrl,
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
                      _buildLabeledField(
                        theme,
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        controller: _addressLine1Ctrl,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _buildStateDropdown(theme),
                      const SizedBox(height: 32),

                      // ── Deactivate Button ──
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            // TODO: Implement deactivation flow
                          },
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
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
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
          if (_isEditMode) ...[
            const SizedBox(height: 8),
            Text(
              'UPDATE PHOTO',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
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
          readOnly: !_isEditMode,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            filled: true,
            fillColor: _isEditMode
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.6),
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
    );
  }

  // ── Public Visibility toggle ── REMOVED (not in scope for this sprint)
}

