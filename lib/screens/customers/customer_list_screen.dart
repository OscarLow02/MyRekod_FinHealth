import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import 'add_edit_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final bool isPickerMode;

  const CustomerListScreen({
    super.key,
    this.isPickerMode = false,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<CustomerProvider>();
    final customers = provider.filteredCustomers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          if (widget.isPickerMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Search Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search name or business...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Customer List
          Expanded(
            child: provider.isLoading && customers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? buildEmptyState(
                        context,
                        icon: Icons.people_outline_rounded,
                        message: 'No customers found',
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return _buildCustomerTile(context, customer, theme);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton(
          heroTag: 'customer_list_fab',
          onPressed: () async {
            final newCustomer = await Navigator.push<Customer?>(
              context,
              MaterialPageRoute(
                builder: (_) => const AddEditCustomerScreen(customer: null),
              ),
            );
            if (widget.isPickerMode && newCustomer != null) {
              // If in picker mode and a new customer was added, auto-select it
              if (context.mounted) Navigator.pop(context, newCustomer);
            }
          },
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCustomerTile(BuildContext context, Customer customer, ThemeData theme) {
    final isB2B = customer.customerType == CustomerType.b2b;
    
    // Fallback initials
    final initials = customer.name.isNotEmpty 
        ? customer.name.substring(0, 2 > customer.name.length ? customer.name.length : 2).toUpperCase() 
        : 'C';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          if (widget.isPickerMode) {
            Navigator.pop(context, customer);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddEditCustomerScreen(customer: customer),
              ),
            );
          }
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
          child: Text(
            initials,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(
                isB2B ? Icons.store_rounded : Icons.person_outline_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                isB2B ? 'Business' : 'Individual',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    );
  }


}
