import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class ModuleHubScreen extends StatelessWidget {
  final String organizationName;
  final String branchName;
  final String businessType;
  final List<String> enabledModules;
  final String currentRole;
  final String currentUserName;
  final Function(String moduleKey) onSelectModule;
  final VoidCallback onLockTerminal;
  final VoidCallback onOpenBackofficeLogin;
  final Function(String newBranch) onSwitchBranch;

  const ModuleHubScreen({
    super.key,
    required this.organizationName,
    required this.branchName,
    required this.businessType,
    required this.enabledModules,
    this.currentRole = 'owner',
    this.currentUserName = 'Store Manager',
    required this.onSelectModule,
    required this.onLockTerminal,
    required this.onOpenBackofficeLogin,
    required this.onSwitchBranch,
  });

  bool _isModuleAllowed(String moduleKey) {
    if (currentRole == 'owner' || currentRole == 'super_admin') return true;
    if (currentRole == 'branch_manager') {
      return moduleKey != 'admin';
    }
    if (currentRole == 'accountant') {
      return moduleKey == 'accounting' || moduleKey == 'pos_outlets';
    }
    if (currentRole == 'storekeeper') {
      return moduleKey == 'storekeeping';
    }
    if (currentRole == 'cashier') {
      return moduleKey == 'cashier';
    }
    return false;
  }

  Map<String, dynamic> _getSupermarketModuleMetadata(String key) {
    switch (key) {
      case 'cashier':
        return {
          'key': 'cashier',
          'title': 'Cashier POS Checkout',
          'subtitle': 'Barcode scanning, multiplier (*), M-Pesa STK, 80mm thermal receipts',
          'badge': 'Station Active',
          'badgeColor': AppColors.primary,
          'icon': LucideIcons.shoppingCart,
          'color': AppColors.primary,
          'kpiTitle': 'TODAY\'S REGISTER',
          'kpiValue': 'KES 0.00',
          'kpiSub': '0 Completed Sales',
          'minRole': 'Cashier / Staff',
        };
      case 'storekeeping':
        return {
          'key': 'storekeeping',
          'title': 'Storekeeping & Master Catalog',
          'subtitle': 'Stock intake by crates/cartons, supplier invoices & low-stock alerts',
          'badge': 'Master Inventory',
          'badgeColor': AppColors.accent,
          'icon': LucideIcons.package,
          'color': AppColors.accent,
          'kpiTitle': 'STORE CATALOG',
          'kpiValue': 'Master SKUs',
          'kpiSub': 'Aisle & Shelf Allocations',
          'minRole': 'Storekeeper / Manager',
        };
      case 'accounting':
        return {
          'key': 'accounting',
          'title': 'Accounting & Daily Financials',
          'subtitle': 'End-of-shift till count, cash drawer float, M-Pesa breakdown & 16% VAT',
          'badge': 'Shift Open',
          'badgeColor': const Color(0xFF10B981),
          'icon': LucideIcons.calculator,
          'color': const Color(0xFF10B981),
          'kpiTitle': 'DRAWER FLOAT',
          'kpiValue': 'KES 0.00 Float',
          'kpiSub': 'Variance: KES 0.00',
          'minRole': 'Accountant / Manager',
        };
      case 'hr_management':
        return {
          'key': 'hr_management',
          'title': 'Cashier & Staff Roster',
          'subtitle': 'Shift schedules, till lane allocations, PIN codes & clock-in attendance',
          'badge': 'Staff Active',
          'badgeColor': const Color(0xFF6366F1),
          'icon': LucideIcons.users,
          'color': const Color(0xFF6366F1),
          'kpiTitle': 'STAFF ATTENDANCE',
          'kpiValue': 'Active Staff',
          'kpiSub': 'Role RBAC Configured',
          'minRole': 'Manager / HR',
        };
      case 'pos_outlets':
        return {
          'key': 'pos_outlets',
          'title': 'Branches & Till Lanes',
          'subtitle': 'Multi-branch network, till lane management (Till 01, Till 02, Express)',
          'badge': 'Outlets',
          'badgeColor': AppColors.primary,
          'icon': LucideIcons.store,
          'color': AppColors.primary,
          'kpiTitle': 'TILL STATIONS',
          'kpiValue': 'Till Registers',
          'kpiSub': 'Branch Network Synced',
          'minRole': 'Manager / Admin',
        };
      default:
        return {
          'key': 'admin',
          'title': 'Store Admin & Settings',
          'subtitle': 'Staff RBAC, branded sales reports, receipt studio, stock ledger & audit logs',
          'badge': 'Master Suite',
          'badgeColor': AppColors.primary,
          'icon': LucideIcons.settings,
          'color': const Color(0xFF64748B),
          'kpiTitle': 'STORE SUITE',
          'kpiValue': '6 Admin Tools',
          'kpiSub': 'RBAC, Reports & Studio',
          'minRole': 'Owner / Super-Admin',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out waiter module specifically for Supermarkets
    final List<String> activeKeys = enabledModules.where((k) => k != 'waiter').toList();
    if (!activeKeys.contains('admin')) {
      activeKeys.add('admin');
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                border: Border(bottom: BorderSide(color: AppColors.border(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Organization & Branch Info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.shoppingBag, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                organizationName,
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  businessType.toUpperCase(),
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary(context)),
                              const SizedBox(width: 4),
                              Text(
                                'Active Branch: $branchName',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Actions: Authenticated Staff Badge + Lock Terminal Button
                  Row(
                    children: [
                      // Active Staff RBAC Badge
                      InkWell(
                        onTap: onOpenBackofficeLogin,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.userCheck, size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currentUserName,
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                  ),
                                  Text(
                                    'Role: ${currentRole.replaceAll('_', ' ').toUpperCase()}',
                                    style: const TextStyle(fontSize: 9, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 6),
                              Icon(LucideIcons.chevronDown, size: 12, color: AppColors.textMuted(context)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Exit to POS Terminal / Lock Button
                      ElevatedButton.icon(
                        onPressed: onLockTerminal,
                        icon: const Icon(LucideIcons.monitor, size: 14),
                        label: const Text('Exit to POS Terminal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFF141413),
                          foregroundColor: Colors.white,
                          side: BorderSide(color: AppColors.border(context)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Hero Greeting / Hub Title
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Operations & Dashboards',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context), letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage inventory, checkout tills, finances & cashier shifts for $branchName.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                  Text(
                    '${activeKeys.length} Modules Active',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ],
              ),
            ),

            // Modules Bento Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    mainAxisExtent: 220,
                  ),
                  itemCount: activeKeys.length,
                  itemBuilder: (context, index) {
                    final meta = _getSupermarketModuleMetadata(activeKeys[index]);
                    final String moduleKey = meta['key'] as String;
                    final bool isAllowed = _isModuleAllowed(moduleKey);
                    final Color accentColor = meta['color'] as Color;
                    final Color badgeColor = meta['badgeColor'] as Color;

                    return InkWell(
                      onTap: () => onSelectModule(moduleKey),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isAllowed ? AppColors.surface(context) : AppColors.bg(context).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isAllowed ? AppColors.border(context) : AppColors.border(context).withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            if (isAllowed)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top Row: Icon + Badge / Lock
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(11),
                                  decoration: BoxDecoration(
                                    color: isAllowed ? accentColor.withValues(alpha: 0.15) : AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(meta['icon'] as IconData, color: isAllowed ? accentColor : AppColors.textMuted(context), size: 22),
                                ),
                                if (isAllowed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      meta['badge'] as String,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.bg(context),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.border(context)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.lock, size: 11, color: AppColors.textMuted(context)),
                                        const SizedBox(width: 4),
                                        Text('Login Required', style: TextStyle(fontSize: 9, color: AppColors.textMuted(context), fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),

                            // Middle: Title & Subtitle
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  meta['title'] as String,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isAllowed ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  meta['subtitle'] as String,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context), height: 1.3),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            // Bottom KPI & Action Prompt
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.card(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border(context)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        meta['kpiTitle'] as String,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.textMuted(context), letterSpacing: 0.8),
                                      ),
                                      Text(
                                        meta['kpiValue'] as String,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        isAllowed ? 'Open' : 'Authorize',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isAllowed ? accentColor : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(isAllowed ? LucideIcons.arrowRight : LucideIcons.key, size: 13, color: isAllowed ? accentColor : AppColors.primary),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
