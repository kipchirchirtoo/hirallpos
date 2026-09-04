import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../cashier/screens/cashier_screen.dart';
import '../../storekeeping/screens/storekeeping_screen.dart';
import '../../outlets/screens/outlets_screen.dart';
import '../../accounting/screens/accounting_screen.dart';
import '../../waiter/screens/waiter_screen.dart';
import '../../hr/screens/hr_screen.dart';
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../activation/screens/activation_screen.dart';
import '../../auth/screens/backoffice_login_screen.dart';
import '../../terminal/screens/pos_terminal_screen.dart';
import '../widgets/mobile_pairing_dialog.dart';
import '../../../core/services/wireless_bridge_service.dart';
import 'module_hub_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  final String organizationName;
  final String branchName;
  final String businessType;
  final List<String> enabledModules;

  const MainShellScreen({
    super.key,
    required this.organizationName,
    required this.branchName,
    required this.businessType,
    required this.enabledModules,
  });

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late String _currentBranch;
  late List<String> _currentModules;
  String _currentRole = 'cashier';
  String _currentUserName = 'Station Supervisor';
  
  // Navigation State: 'terminal' (POS Station Sign-In), 'hub' (Backoffice Hub), or specific module key ('cashier', 'storekeeping', etc.)
  String _currentView = 'terminal';

  @override
  void initState() {
    super.initState();
    _currentBranch = widget.branchName;
    _currentModules = List<String>.from(widget.enabledModules);
    _currentView = 'terminal'; // Default landing is POS Terminal Screen
  }

  bool _isModuleAllowed(String moduleKey) {
    if (_currentRole == 'owner' || _currentRole == 'super_admin') return true;
    if (_currentRole == 'branch_manager') {
      return moduleKey != 'admin';
    }
    if (_currentRole == 'accountant') {
      return moduleKey == 'accounting' || moduleKey == 'pos_outlets';
    }
    if (_currentRole == 'storekeeper') {
      return moduleKey == 'storekeeping';
    }
    if (_currentRole == 'cashier') {
      return moduleKey == 'cashier';
    }
    if (_currentRole == 'waiter') {
      return moduleKey == 'waiter';
    }
    return false;
  }

  void _onSelectModuleFromHub(String moduleKey) {
    if (_isModuleAllowed(moduleKey)) {
      setState(() => _currentView = moduleKey);
    } else {
      _openBackofficeLoginDialog(targetModuleKey: moduleKey);
    }
  }

  void _openBackofficeLoginDialog({String? targetModuleKey}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BackofficeLoginScreen(
        organizationName: widget.organizationName,
        currentBranch: _currentBranch,
        targetModuleKey: targetModuleKey,
        onLoginSuccess: (auth) {
          final role = (auth['role'] ?? 'cashier').toString().toLowerCase();
          if (role == 'cashier' || role == 'waiter') {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Access Denied: Cashier accounts cannot access BackOffice Operations.',
                ),
                backgroundColor: AppColors.danger,
              ),
            );
            return;
          }

          Navigator.pop(ctx);
          setState(() {
            _currentRole = role;
            _currentUserName = auth['full_name'] ?? 'Authorized User';
            if (auth['branch_name'] != null) {
              _currentBranch = auth['branch_name'];
            }
            if (targetModuleKey != null && _isModuleAllowed(targetModuleKey)) {
              _currentView = targetModuleKey;
            } else {
              _currentView = 'hub'; // Go to Backoffice Hub
            }
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Signed in as $_currentUserName (${_currentRole.toUpperCase()}) • Branch: $_currentBranch',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  void _lockToTerminal() {
    setState(() {
      _currentView = 'terminal';
    });
  }

  Widget _buildActiveViewWidget() {
    switch (_currentView) {
      case 'terminal':
        return PosTerminalScreen(
          organizationName: widget.organizationName,
          branchName: _currentBranch,
          businessType: widget.businessType,
          onStaffLogin: (role, staffName, targetStation) {
            setState(() {
              _currentRole = role;
              _currentUserName = staffName;
              _currentView = targetStation; // Boots directly into Cashier or Waiter station
            });
          },
          onOpenBackoffice: () => _openBackofficeLoginDialog(),
        );

      case 'hub':
        return ModuleHubScreen(
          organizationName: widget.organizationName,
          branchName: _currentBranch,
          businessType: widget.businessType,
          enabledModules: _currentModules,
          currentRole: _currentRole,
          currentUserName: _currentUserName,
          onSelectModule: _onSelectModuleFromHub,
          onLockTerminal: _lockToTerminal,
          onOpenBackofficeLogin: () => _openBackofficeLoginDialog(),
          onSwitchBranch: (newBranch) => setState(() => _currentBranch = newBranch),
        );

      case 'cashier':
        return CashierScreen(branchName: _currentBranch);
      case 'storekeeping':
        return StorekeepingScreen(branchName: _currentBranch);
      case 'accounting':
        return AccountingScreen(branchName: _currentBranch);
      case 'waiter':
        return WaiterScreen(branchName: _currentBranch);
      case 'hr_management':
        return HrScreen(branchName: _currentBranch);
      case 'pos_outlets':
        return OutletsScreen(
          currentBranchName: _currentBranch,
          onSwitchBranch: (newBranch) {
            setState(() => _currentBranch = newBranch);
          },
        );
      case 'admin':
        return AdminDashboardScreen(
          organizationName: widget.organizationName,
          branchName: _currentBranch,
          enabledModules: _currentModules,
          onModulesUpdated: (newMods) {
            setState(() => _currentModules = newMods);
          },
        );
      default:
        return PosTerminalScreen(
          organizationName: widget.organizationName,
          branchName: _currentBranch,
          businessType: widget.businessType,
          onStaffLogin: (role, staffName, targetStation) {
            setState(() {
              _currentRole = role;
              _currentUserName = staffName;
              _currentView = targetStation;
            });
          },
          onOpenBackoffice: () => _openBackofficeLoginDialog(),
        );
    }
  }

  String _getModuleTitle(String key) {
    switch (key) {
      case 'cashier':
        return 'Cashier & POS Checkout';
      case 'storekeeping':
        return 'Storekeeping & Inventory';
      case 'accounting':
        return 'Accounting & Finance';
      case 'waiter':
        return 'Waiter & Dining Tables';
      case 'hr_management':
        return 'Staff & HR Roster';
      case 'pos_outlets':
        return 'POS Outlets & Branches';
      case 'admin':
        return 'Super-Admin & Settings';
      default:
        return 'Operational Module';
    }
  }

  IconData _getModuleIcon(String key) {
    switch (key) {
      case 'cashier':
        return LucideIcons.shoppingCart;
      case 'storekeeping':
        return LucideIcons.package;
      case 'accounting':
        return LucideIcons.calculator;
      case 'waiter':
        return LucideIcons.utensils;
      case 'hr_management':
        return LucideIcons.users;
      case 'pos_outlets':
        return LucideIcons.store;
      case 'admin':
        return LucideIcons.settings;
      default:
        return LucideIcons.layoutGrid;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. If currently in Terminal or Hub mode, render without extra sub-bars
    if (_currentView == 'terminal' || _currentView == 'hub') {
      return _buildActiveViewWidget();
    }

    // 2. If inside a dedicated operational module workspace, show Top Navigation Bar
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Column(
        children: [
          // Top Operational Module Navigation Bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(bottom: BorderSide(color: AppColors.border(context))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width > 32 ? MediaQuery.of(context).size.width - 32 : 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                // Left: Back to Hub / Lock Station Buttons + Breadcrumbs
                Row(
                  children: [
                    // Lock / Terminal Button
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeftCircle, color: AppColors.primary, size: 20),
                      tooltip: 'Exit to POS Station Terminal',
                      onPressed: _lockToTerminal,
                    ),
                    const SizedBox(width: 4),

                    // Back to Backoffice Hub Button
                    InkWell(
                      onTap: () => setState(() => _currentView = 'hub'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.layoutGrid, size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Module Hub',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMuted(context)),
                    const SizedBox(width: 12),
                    Icon(_getModuleIcon(_currentView), size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _getModuleTitle(_currentView),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                    ),
                  ],
                ),

                // Center: Quick Module Switcher Tabs (RBAC Filtered)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.bg(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      ..._currentModules.where((modKey) => _isModuleAllowed(modKey)).map((modKey) {
                        final isSelected = modKey == _currentView;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () => setState(() => _currentView = modKey),
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _getModuleIcon(modKey),
                                    size: 13,
                                    color: isSelected ? Colors.white : AppColors.textSecondary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getModuleShortLabel(modKey),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      // Admin tab if allowed
                      if (_isModuleAllowed('admin'))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: InkWell(
                            onTap: () => setState(() => _currentView = 'admin'),
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _currentView == 'admin' ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.settings,
                                    size: 13,
                                    color: _currentView == 'admin' ? Colors.white : AppColors.textSecondary(context),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _currentView == 'admin' ? FontWeight.w700 : FontWeight.w500,
                                      color: _currentView == 'admin' ? Colors.white : AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Right: Theme Toggle + Staff Auth Badge + Branch + Lock Station
                Row(
                  children: [
                    // Mobile Scanner Bridge Button
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => MobilePairingDialog(
                            organizationName: widget.organizationName,
                            branchName: _currentBranch,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.smartphone, size: 13, color: AppColors.primary),
                            const SizedBox(width: 6),
                            StreamBuilder<int>(
                              stream: WirelessBridgeService.instance.connectedDevicesCountStream,
                              initialData: WirelessBridgeService.instance.connectedDevicesCount,
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  count > 0 ? 'Mobile ($count)' : 'Mobile Hub',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: count > 0 ? AppColors.success : AppColors.textSecondary(context),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Theme Toggle Button
                    InkWell(
                      onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Icon(
                          isDark ? LucideIcons.sun : LucideIcons.moon,
                          size: 14,
                          color: isDark ? const Color(0xFFFBBF24) : AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Backoffice Switch Staff Button
                    InkWell(
                      onTap: () => _openBackofficeLoginDialog(),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.user, size: 12, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              '$_currentUserName (${_currentRole.toUpperCase()})',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            _currentBranch,
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(LucideIcons.lock, size: 16, color: AppColors.textSecondary(context)),
                      tooltip: 'Lock to Terminal Screen',
                      onPressed: _lockToTerminal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

          // Main Dedicated Module Dashboard Workspace
          Expanded(
            child: _buildActiveViewWidget(),
          ),
        ],
      ),
    );
  }

  String _getModuleShortLabel(String key) {
    switch (key) {
      case 'cashier':
        return 'Cashier';
      case 'storekeeping':
        return 'Storekeeping';
      case 'accounting':
        return 'Accounting';
      case 'waiter':
        return 'Waiter';
      case 'hr_management':
        return 'Staff & HR';
      case 'pos_outlets':
        return 'Outlets';
      case 'admin':
        return 'Admin';
      default:
        return key;
    }
  }
}
