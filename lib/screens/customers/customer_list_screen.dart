import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/customer.dart';
import '../../providers/customer_provider.dart';
import '../../core/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/glass_widgets.dart';
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

    // Pre-compute counts for the hero card
    final totalCount = provider.customers.length;
    final b2bCount =
        provider.customers.where((c) => c.customerType == CustomerType.b2b).length;
    final b2cCount = totalCount - b2bCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Customers',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (widget.isPickerMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
        ],
      ),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── 1. Hero Summary Card ────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeroCard(theme, totalCount, b2bCount, b2cCount),
          ),

          // ── 2. Glass Search Bar ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: GlassSearchBar(
                controller: _searchController,
                hintText: 'Search name or business...',
                onChanged: (val) {
                  provider.setSearchQuery(val);
                  setState(() {});
                },
                onClear: () {
                  _searchController.clear();
                  provider.setSearchQuery('');
                  setState(() {});
                },
              ),
            ),
          ),

          // ── 3. Section Header ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    provider.searchQuery.isNotEmpty
                        ? 'SEARCH RESULTS'
                        : 'ALL CUSTOMERS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${customers.length} ${customers.length == 1 ? 'CUSTOMER' : 'CUSTOMERS'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 4. Customer List ────────────────────────────────────────────
          if (provider.isLoading && customers.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (customers.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: buildEmptyState(
                context,
                icon: Icons.people_outline_rounded,
                message: provider.searchQuery.isNotEmpty
                    ? 'No customers match your search'
                    : 'No customers yet',
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.3),
                onAction: provider.searchQuery.isEmpty
                    ? () async {
                        final newCustomer =
                            await Navigator.push<Customer?>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AddEditCustomerScreen(customer: null),
                          ),
                        );
                        if (widget.isPickerMode &&
                            newCustomer != null &&
                            context.mounted) {
                          Navigator.pop(context, newCustomer);
                        }
                      }
                    : null,
                actionLabel:
                    provider.searchQuery.isEmpty ? 'Add First Customer' : null,
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final customer = customers[index];
                    return _buildCustomerTile(context, customer, theme, index);
                  },
                  childCount: customers.length,
                ),
              ),
            ),
            // Footer spacing for FAB clearance
            const SliverToBoxAdapter(
              child: SizedBox(height: 140),
            ),
          ],
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

  // ── Hero Summary Card ───────────────────────────────────────────────────
  Widget _buildHeroCard(
      ThemeData theme, int totalCount, int b2bCount, int b2cCount) {
    const accentColor = AppTheme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTOMER DIRECTORY',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$totalCount',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      totalCount == 1
                          ? 'Registered Customer'
                          : 'Registered Customers',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  size: 28,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: accentColor.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 16),
          Text(
            'BREAKDOWN',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildBadge('$b2bCount Business (B2B)', AppTheme.primary),
              _buildBadge(
                  '$b2cCount Individual (B2C)', AppTheme.secondaryDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ── Customer Tile ───────────────────────────────────────────────────────
  Widget _buildCustomerTile(
      BuildContext context, Customer customer, ThemeData theme, int index) {
    final isB2B = customer.customerType == CustomerType.b2b;

    // Fallback initials
    final initials = customer.name.isNotEmpty
        ? customer.name
            .substring(
                0, 2 > customer.name.length ? customer.name.length : 2)
            .toUpperCase()
        : 'C';

    // Accent color per type for visual differentiation
    final typeColor = isB2B ? AppTheme.primary : AppTheme.secondaryDark;

    // Build contact info subtitle
    final contactParts = <String>[];
    if (customer.email.isNotEmpty && customer.email != 'NA') {
      contactParts.add(customer.email);
    }
    if (customer.phoneNumber.isNotEmpty && customer.phoneNumber != 'NA') {
      contactParts.add(customer.phoneNumber);
    }
    final contactLine =
        contactParts.isNotEmpty ? contactParts.join(' • ') : null;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 350 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              typeColor.withValues(alpha: 0.06),
              theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.2),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: typeColor.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            onTap: () {
              if (widget.isPickerMode) {
                Navigator.pop(context, customer);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditCustomerScreen(customer: customer),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ── Avatar with gradient border ──────────────────────
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          typeColor.withValues(alpha: 0.3),
                          typeColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: typeColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: typeColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── Info column ─────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(
                          customer.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Type badge chip
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: typeColor.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isB2B
                                        ? Icons.store_rounded
                                        : Icons.person_outline_rounded,
                                    size: 12,
                                    color: typeColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isB2B ? 'Business' : 'Individual',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: typeColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (customer.tinNumber.isNotEmpty &&
                                customer.tinNumber != 'NA' &&
                                customer.tinNumber !=
                                    'EI00000000010') ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonGreenDark
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.neonGreenDark
                                        .withValues(alpha: 0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 10,
                                      color: AppTheme.neonGreenDark,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'TIN',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: AppTheme.neonGreenDark,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Contact info preview (if available)
                        if (contactLine != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            contactLine,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // ── Chevron ─────────────────────────────────────────
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
