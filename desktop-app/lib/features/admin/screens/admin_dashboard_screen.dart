import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_users_view.dart';
import '../widgets/admin_reports_view.dart';
import '../widgets/admin_receipt_designer_view.dart';
import '../widgets/admin_stock_movements_view.dart';
import '../widgets/admin_audit_logs_view.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String organizationName;
  final String branchName;
  final List<String> enabledModules;
  final Function(List<String> newModules)? onModulesUpdated;

  const AdminDashboardScreen({
    super.key,
    required this.organizationName,
    required this.branchName,
    required this.enabledModules,
    this.onModulesUpdated,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedTab = 'receipt'; // Default directly to Receipt Studio for quick access

  Future<Uint8List?> _getLogoBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBase64 = prefs.getString('receipt_logo_base64');
      if (savedBase64 != null && savedBase64.isNotEmpty) {
        final cleanBase64 = savedBase64.contains(',') ? savedBase64.split(',').last : savedBase64;
        final decoded = base64Decode(cleanBase64.trim());
        if (decoded.length >= 8 && (decoded[0] == 0x89 || decoded[0] == 0xFF || decoded[0] == 0x47 || (decoded.length >= 12 && decoded[0] == 0x52))) {
          return decoded;
        }
      }
      if (File('/home/kipchir/giftmart.png').existsSync()) {
        return await File('/home/kipchir/giftmart.png').readAsBytes();
      }
      final assetData = await rootBundle.load('assets/images/giftmart.png');
      return assetData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
  late List<String> _currentModules;

  final List<Map<String, dynamic>> _allModules = [
    {'key': 'cashier', 'name': 'Cashier & POS Checkout', 'desc': 'Fast scanning, cart, VAT calculations, M-Pesa/Cash payments, and receipts.', 'icon': LucideIcons.shoppingCart},
    {'key': 'storekeeping', 'name': 'Storekeeping & Inventory', 'desc': 'Stock receiving, low-stock alerts, supplier deliveries, and inter-branch transfers.', 'icon': LucideIcons.package},
    {'key': 'pos_outlets', 'name': 'POS Outlets & Branches', 'desc': 'Branch directory, multi-branch terminal switching, and till settings.', 'icon': LucideIcons.store},
    {'key': 'accounting', 'name': 'Accounting & Finance', 'desc': 'Daily shift till reconciliations, expense logs, P&L calculations, and VAT.', 'icon': LucideIcons.calculator},
    {'key': 'waiter', 'name': 'Waiter & Table Orders', 'desc': 'Restaurant floor plan, table status, kitchen order tickets (KOT), and bill split.', 'icon': LucideIcons.utensils},
    {'key': 'hr_management', 'name': 'Management & HR', 'desc': 'Staff directory, role and PIN assignments, and shift clock-in/out attendance.', 'icon': LucideIcons.users},
  ];

  @override
  void initState() {
    super.initState();
    _currentModules = List<String>.from(widget.enabledModules);
  }

  void _toggleModule(String key, bool isEnabled) {
    setState(() {
      if (isEnabled) {
        if (!_currentModules.contains(key)) _currentModules.add(key);
      } else {
        _currentModules.remove(key);
      }
    });
    widget.onModulesUpdated?.call(_currentModules);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Module updated for ${widget.branchName}!')),
    );
  }

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 14, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: AppColors.textMuted(context),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required String key,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = key),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.primary : AppColors.textSecondary(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary(context),
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Row(
        children: [
          // SIDEBAR (Left Navigation Panel)
          Container(
            width: 230,
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(right: BorderSide(color: AppColors.border(context), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Module Badge Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUPER-ADMIN',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: 0.8,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'RBAC & AUDIT',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: AppColors.textMuted(context),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context)),

                // Categorized Navigation List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    children: [
                      _buildSidebarSectionHeader('People & Access'),
                      _buildSidebarItem(key: 'users', label: 'Staff & Station PINs', icon: LucideIcons.users),
                      _buildSidebarItem(key: 'audit', label: 'Security & Audit Trail', icon: LucideIcons.shieldAlert),

                      _buildSidebarSectionHeader('Commerce & Reports'),
                      _buildSidebarItem(key: 'reports', label: 'Sales Reports & Metrics', icon: LucideIcons.barChart3),
                      _buildSidebarItem(key: 'movements', label: 'Stock Movements Ledger', icon: LucideIcons.history),

                      _buildSidebarSectionHeader('Branding & System'),
                      _buildSidebarItem(key: 'receipt', label: 'Thermal Receipt Studio', icon: LucideIcons.printer),
                      _buildSidebarItem(key: 'settings', label: 'Store Settings & Modules', icon: LucideIcons.slidersHorizontal),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // MAIN CONTENT AREA (Right Panel)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Executive Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          FutureBuilder<Uint8List?>(
                            future: _getLogoBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                return Container(
                                  height: 28,
                                  margin: const EdgeInsets.only(right: 10),
                                  child: Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          Text(
                            widget.organizationName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'STORE ADMINISTRATOR',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border(context)),
                            ),
                            child: Text(
                              'BRANCH: ${widget.branchName}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(LucideIcons.crown, color: AppColors.primary, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Enterprise Cloud Plan',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // SUB-VIEW SWITCHER
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        switch (_selectedTab) {
                          case 'users':
                            return AdminUsersView(
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                            );
                          case 'reports':
                            return AdminReportsView(
                              organizationName: widget.organizationName,
                              currentBranchName: widget.branchName,
                            );
                          case 'receipt':
                            return AdminReceiptDesignerView(
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                            );
                          case 'movements':
                            return AdminStockMovementsView(
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                            );
                          case 'audit':
                            return AdminAuditLogsView(
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                            );
                          case 'settings':
                            return _buildStoreSettingsTab(context);
                          default:
                            return AdminUsersView(
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                            );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSettingsTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // License Key Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORGANIZATION LICENSE KEY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.1)),
                    const SizedBox(height: 4),
                    Text('HPOS-HF9P-37QH-JZTM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context), fontFamily: 'monospace', letterSpacing: 1.5)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: 'HPOS-HF9P-37QH-JZTM'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Organization license key copied!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.card(context),
                    foregroundColor: AppColors.textPrimary(context),
                    side: BorderSide(color: AppColors.border(context)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  icon: const Icon(LucideIcons.copy, size: 14),
                  label: const Text('Copy License', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Branch Module Entitlements
          Text('Branch Module Configuration', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
          const SizedBox(height: 2),
          Text('Enable or disable specific operational modules for ${widget.branchName} in real time.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
          const SizedBox(height: 14),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 110,
            ),
            itemCount: _allModules.length,
            itemBuilder: (context, index) {
              final mod = _allModules[index];
              final isEnabled = _currentModules.contains(mod['key']);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isEnabled ? AppColors.primary : AppColors.border(context),
                    width: isEnabled ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEnabled ? AppColors.primary.withValues(alpha: 0.15) : AppColors.bg(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(mod['icon'] as IconData, color: isEnabled ? AppColors.primary : AppColors.textMuted(context), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(mod['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 3),
                          Text(mod['desc'] as String, style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context), height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Switch(
                      value: isEnabled,
                      activeColor: AppColors.primary,
                      onChanged: (val) => _toggleModule(mod['key'] as String, val),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
