import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/app_dialogs.dart';

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
  late final TextEditingController _tourismTaxCtrl;
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
    _sstCtrl = TextEditingController(text: c?.sstRegistrationNumber ?? 'NA');
    _tourismTaxCtrl = TextEditingController(text: c?.tourismTaxNumber ?? 'NA');
    _emailCtrl = TextEditingController(text: c?.email ?? 'NA');
    _phoneCtrl = TextEditingController(text: c?.phoneNumber ?? 'NA');
    _address1Ctrl = TextEditingController(text: c?.addressLine1 ?? 'NA');
    _address2Ctrl = TextEditingController(text: c?.addressLine2 ?? '');
    _address3Ctrl = TextEditingController(text: c?.addressLine3 ?? '');
    _cityCtrl = TextEditingController(text: c?.city ?? 'NA');
    _postalCodeCtrl = TextEditingController(text: c?.postalCode ?? '00000');

    _customerType = c?.customerType ?? CustomerType.b2c;
    _idScheme = c?.idScheme ?? 'BRN';
    _stateCode = c?.stateCode ?? '17';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tinCtrl.dispose();
    _idNumberCtrl.dispose();
    _sstCtrl.dispose();
    _tourismTaxCtrl.dispose();
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
      sstRegistrationNumber: _sstCtrl.text.trim(),
      tourismTaxNumber: _tourismTaxCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
      addressLine1: _address1Ctrl.text.trim(),
      addressLine2: _address2Ctrl.text.trim(),
      addressLine3: _address3Ctrl.text.trim(),
      city: _cityCtrl.text.trim(),
      stateCode: _stateCode,
      postalCode: _postalCodeCtrl.text.trim(),
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
              : AppTheme.neonGreenLight,
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
                      onTap: () => setState(() => _customerType = CustomerType.b2c),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTypeCard(
                      label: 'Business',
                      icon: Icons.business_rounded,
                      isSelected: isB2B,
                      onTap: () => setState(() => _customerType = CustomerType.b2b),
                      theme: theme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Fields
              _buildField('Full Name', _nameCtrl, Icons.person_outline_rounded, required: true, hint: 'e.g. Ahmad Ibrahim'),
              _buildField('Phone Number', _phoneCtrl, Icons.phone_outlined, hint: '+60 12-345 6789'),
              
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.fingerprint_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text(
                          'TIN (Business Only)',
                          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (isB2B)
                          Text(
                            '* REQUIRED FOR BUSINESS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.red[300],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tinCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. TR123456789',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (val) {
                        if (isB2B && (val == null || val.trim().isEmpty)) {
                          return 'TIN is required for Business';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Photo Placeholder
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_a_photo_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Customer Photo', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Help identify regular customers quickly.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.upload_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Save Customer',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool required = false, String? hint}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                required ? '$label *' : label,
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hint ?? 'Enter $label',
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
            validator: (val) {
              if (required && (val == null || val.trim().isEmpty)) {
                return '$label is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
