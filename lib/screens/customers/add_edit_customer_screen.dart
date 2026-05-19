import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../core/app_theme.dart';
import '../../core/lhdn_constants.dart';
import '../../core/validators.dart';
import '../../widgets/app_dialogs.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/phone_input_field.dart';

class AddEditCustomerScreen extends StatefulWidget {
  final Customer? customer;

  const AddEditCustomerScreen({
    super.key,
    this.customer,
  });

  @override
  State<AddEditCustomerScreen> createState() => _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState extends State<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _tinCtrl;
  late final TextEditingController _idNumberCtrl;
  late final TextEditingController _sstCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _address1Ctrl;
  late final TextEditingController _address2Ctrl;
  late final TextEditingController _address3Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _postalCodeCtrl;

  // State
  late CustomerType _customerType;
  late String _idScheme;
  late String _stateCode;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;

    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _tinCtrl = TextEditingController(text: c?.tinNumber ?? '');
    _idNumberCtrl = TextEditingController(text: c?.idNumber ?? '');
    _sstCtrl = TextEditingController(
        text: c != null && c.sstRegistrationNumber != 'NA'
            ? c.sstRegistrationNumber
            : '');
    _emailCtrl = TextEditingController(
        text: c != null && c.email != 'NA' ? c.email : '');
    _phoneCtrl = TextEditingController(
        text: c != null && c.phoneNumber != 'NA' ? c.phoneNumber : '');
    _address1Ctrl = TextEditingController(
        text: c != null && c.addressLine1 != 'NA' ? c.addressLine1 : '');
    _address2Ctrl = TextEditingController(text: c?.addressLine2 ?? '');
    _address3Ctrl = TextEditingController(text: c?.addressLine3 ?? '');
    _cityCtrl = TextEditingController(
        text: c != null && c.city != 'NA' ? c.city : '');
    _postalCodeCtrl = TextEditingController(
        text: c != null && c.postalCode != '00000' ? c.postalCode : '');

    _customerType = c?.customerType ?? CustomerType.b2c;
    _idScheme = c?.idScheme ?? (_customerType == CustomerType.b2b ? 'BRN' : 'NRIC');
    _stateCode = c?.stateCode ?? '17';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tinCtrl.dispose();
    _idNumberCtrl.dispose();
    _sstCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _address3Ctrl.dispose();
    _cityCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<CustomerProvider>();
    final isNew = widget.customer == null;

    final customer = Customer(
      id: widget.customer?.id ?? '',
      name: _nameCtrl.text.trim(),
      customerType: _customerType,
      tinNumber: _tinCtrl.text.trim(),
      idNumber: _idNumberCtrl.text.trim(),
      idScheme: _idScheme,
      sstRegistrationNumber: _sstCtrl.text.trim().isEmpty ? 'NA' : _sstCtrl.text.trim(),
      tourismTaxNumber: 'NA',
      email: _emailCtrl.text.trim().isEmpty ? 'NA' : _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? 'NA' : _phoneCtrl.text.trim(),
      addressLine1: _address1Ctrl.text.trim().isEmpty ? 'NA' : _address1Ctrl.text.trim(),
      addressLine2: _address2Ctrl.text.trim(),
      addressLine3: _address3Ctrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? 'NA' : _cityCtrl.text.trim(),
      stateCode: _stateCode,
      postalCode: _postalCodeCtrl.text.trim().isEmpty ? '00000' : _postalCodeCtrl.text.trim(),
    );

    try {
      if (isNew) {
        await provider.addCustomer(customer);
      } else {
        await provider.updateCustomer(customer);
      }

      if (mounted) {
        final theme = Theme.of(context);
        await AppDialogs.showSystemAlert(
          context,
          title: isNew ? 'Customer Added' : 'Customer Updated',
          body: isNew 
              ? 'Customer profile has been created successfully.' 
              : 'Customer profile has been updated.',
          icon: Icons.check_circle_rounded,
          iconColor: theme.brightness == Brightness.dark 
              ? AppTheme.neonGreenDark 
              : AppTheme.neonGreenDark,
        );
        if (mounted) Navigator.pop(context, customer);
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showSystemAlert(
          context,
          title: 'Operation Failed',
          body: e.toString(),
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isB2B = _customerType == CustomerType.b2b;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add New Customer' : 'Edit Customer'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a profile for your frequent buyers to track sales history.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // Customer Type Selector
              Text(
                'CUSTOMER TYPE',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeCard(
                      label: 'Individual',
                      icon: Icons.person_outline_rounded,
                      isSelected: !isB2B,
                      onTap: () => setState(() {
                        _customerType = CustomerType.b2c;
                        _idScheme = 'NRIC';
                      }),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTypeCard(
                      label: 'Business',
                      icon: Icons.business_rounded,
                      isSelected: isB2B,
                      onTap: () => setState(() {
                        _customerType = CustomerType.b2b;
                        _idScheme = 'BRN';
                      }),
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Fields
              AppTextField(
                label: isB2B ? 'Legal Business Name' : 'Full Name',
                controller: _nameCtrl,
                icon: isB2B ? Icons.business_rounded : Icons.person_outline_rounded,
                isRequired: true,
                hintText: isB2B ? 'e.g. ABC Enterprise' : 'e.g. Ahmad Ibrahim',
                textCapitalization: TextCapitalization.words,
                validator: (val) => AppValidators.requiredField(val, isB2B ? 'Business Name' : 'Full Name'),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: CustomPremiumDropdown<String>(
                      label: 'ID Scheme',
                      value: _idScheme,
                      isRequired: true,
                      items: const [
                        CustomDropdownItem(label: 'BRN', value: 'BRN'),
                        CustomDropdownItem(label: 'NRIC', value: 'NRIC'),
                        CustomDropdownItem(label: 'Passport', value: 'PASSPORT'),
                        CustomDropdownItem(label: 'Army', value: 'ARMY'),
                      ],
                      onChanged: (val) => setState(() => _idScheme = val ?? 'NRIC'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: AppTextField(
                      label: 'ID Number',
                      controller: _idNumberCtrl,
                      isRequired: true,
                      hintText: null, // No placeholder
                      validator: (val) => AppValidators.brn(val, isB2B ? 'Business' : 'Person'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader(theme, 'CONTACT DETAILS'),
              PhoneInputField(
                label: 'Phone Number',
                controller: _phoneCtrl,
                isRequired: true,
                hint: '', // Remove placeholder
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email Address',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) => AppValidators.email(val),
                hintText: null,
              ),
              const SizedBox(height: 32),

              _buildSectionHeader(theme, 'TAX & COMPLIANCE'),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppTextField(
                  label: 'TIN Number',
                  controller: _tinCtrl,
                  icon: Icons.fingerprint_rounded,
                  isRequired: isB2B,
                  hintText: 'e.g. TR123456789',
                  validator: (val) => isB2B ? AppValidators.tin(val) : (val != null && val.isNotEmpty ? AppValidators.tin(val) : null),
                ),
              ),
              AppTextField(
                label: 'SST Number',
                controller: _sstCtrl,
                hintText: null,
              ),
              const SizedBox(height: 32),

              _buildSectionHeader(theme, 'LOCATION / ADDRESS'),
              AppTextField(
                label: 'Address Line 1',
                controller: _address1Ctrl,
                isRequired: true,
                hintText: 'Unit / House No., Street Name',
                validator: (val) => AppValidators.requiredField(val, 'Address Line 1'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Address Line 2',
                controller: _address2Ctrl,
                hintText: 'Building, Floor, etc.',
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Address Line 3',
                controller: _address3Ctrl,
                hintText: 'Area, Landmark',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'City',
                      controller: _cityCtrl,
                      isRequired: true,
                      validator: (val) => AppValidators.requiredField(val, 'City'),
                      hintText: null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AppTextField(
                      label: 'Postal Code',
                      controller: _postalCodeCtrl,
                      isRequired: true,
                      keyboardType: TextInputType.number,
                      validator: (val) => AppValidators.postalCode(val),
                      hintText: null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomPremiumDropdown<String>(
                label: 'State',
                value: _stateCode,
                isRequired: true,
                items: LhdnConstants.stateCodes.entries
                    .map((e) => CustomDropdownItem(label: e.value, value: e.key))
                    .toList(),
                onChanged: (val) => setState(() => _stateCode = val ?? '17'),
              ),
              const SizedBox(height: 40),

              AppButton(
                text: widget.customer == null ? 'Save Customer' : 'Update Customer',
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildTypeCard({required String label, required IconData icon, required bool isSelected, required VoidCallback onTap, required ThemeData theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: isSelected ? AppTheme.primary : theme.colorScheme.surfaceContainerHighest,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: isSelected ? AppTheme.primary : theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primary : theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
