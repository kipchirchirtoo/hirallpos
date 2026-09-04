import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class AdminUsersView extends StatefulWidget {
  final String organizationName;
  final String branchName;

  const AdminUsersView({
    super.key,
    required this.organizationName,
    required this.branchName,
  });

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  String _searchQuery = '';
  String _selectedRoleFilter = 'all';

  List<Map<String, dynamic>> _staffList = [];

  @override
  void initState() {
    super.initState();
    _loadPersistedStaff();
  }

  Future<void> _loadPersistedStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('hirall_branch_staff_${widget.branchName}');
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        final list = decoded.map((e) => Map<String, dynamic>.from(e)).where((s) {
          final id = (s['id'] ?? '').toString();
          final email = (s['email'] ?? '').toString().toLowerCase();
          final name = (s['fullName'] ?? s['name'] ?? '').toString().toLowerCase();
          return !id.startsWith('EMP-00') &&
              !email.endsWith('@store.local') &&
              !name.contains('chepkemoi') &&
              !name.contains('kipkoech') &&
              !name.contains('kiprotich');
        }).map((s) {
          // ensure fullName compatibility
          if (s['fullName'] == null && s['name'] != null) {
            s['fullName'] = s['name'];
          }
          if (s['tillLane'] == null) {
            s['tillLane'] = s['station'] ?? 'All Stations';
          }
          if (s['todaySales'] == null) {
            s['todaySales'] = s['salesToday'] ?? 0.0;
          }
          if (s['todayTransactions'] == null) {
            s['todayTransactions'] = 0;
          }
          if (s['voidsCount'] == null) {
            s['voidsCount'] = 0;
          }
          if (s['lastActive'] == null) {
            s['lastActive'] = s['clockIn'] != null ? 'Clocked in at ${s['clockIn']}' : 'Inactive';
          }
          return s;
        }).toList();

        setState(() {
          _staffList = list;
        });
      } else {
        setState(() {
          _staffList = [];
        });
      }
    } catch (_) {
      setState(() {
        _staffList = [];
      });
    }
  }

  Future<void> _persistStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_staff_${widget.branchName}', jsonEncode(_staffList));
    } catch (_) {}
  }

  String? _validateAndFormatKenyanPhone(String input) {
    String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('254') && digits.length == 12) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length == 10) {
      digits = digits.substring(1);
    }

    if (digits.length != 9 || (!digits.startsWith('7') && !digits.startsWith('1'))) {
      return null;
    }

    return '+254 ${digits.substring(0, 3)} ${digits.substring(3, 6)} ${digits.substring(6)}';
  }

  void _confirmDeleteStaff(Map<String, dynamic> staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(color: AppColors.border(context), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.trash2, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Text(
              'DELETE RECORD: ${staff['id'] ?? ""}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        content: Text(
          'Confirm permanent deletion of "${staff['fullName']}" from ${widget.branchName}.\nAll station PINs and credentials will be removed.',
          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            onPressed: () {
              setState(() {
                _staffList.removeWhere((s) => s['id'] == staff['id']);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Staff member "${staff['fullName']}" deleted.'),
                  backgroundColor: AppColors.danger,
                ),
              );
            },
            child: const Text('CONFIRM DELETE'),
          ),
        ],
      ),
    );
  }

  void _toggleStaffActive(Map<String, dynamic> staff) {
    setState(() {
      staff['isActive'] = !(staff['isActive'] as bool? ?? true);
    });

    final isNowActive = staff['isActive'] as bool;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNowActive
            ? 'Staff "${staff['fullName']}" ACTIVATED.'
            : 'Staff "${staff['fullName']}" DEACTIVATED.'),
        backgroundColor: isNowActive ? AppColors.success : AppColors.warning,
      ),
    );
  }

  void _openAddOrEditUserDialog([Map<String, dynamic>? existingUser]) {
    final isEditing = existingUser != null;
    final empIdController = TextEditingController(text: isEditing ? existingUser['id'] : 'EMP-00${_staffList.length + 1}');
    final nameController = TextEditingController(text: isEditing ? existingUser['fullName'] : '');

    String rawPhone = '';
    if (isEditing && existingUser['phone'] != null) {
      final clean = existingUser['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.startsWith('254') && clean.length == 12) {
        rawPhone = clean.substring(3);
      } else {
        rawPhone = clean;
      }
    }
    final phoneController = TextEditingController(text: rawPhone);
    final emailController = TextEditingController(text: isEditing ? existingUser['email'] : '');
    final pinController = TextEditingController(text: isEditing ? existingUser['pin'] : '');
    String selectedDepartment = isEditing ? (existingUser['department'] ?? 'POS Cashier & Checkout') : 'POS Cashier & Checkout';
    String role = isEditing ? existingUser['role'] : 'cashier';
    String tillLane = isEditing ? existingUser['tillLane'] : 'Lane 01 (Main Register)';
    bool isActive = isEditing ? (existingUser['isActive'] ?? true) : true;
    bool obscurePin = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: AppColors.border(context), width: 1.5),
          ),
          child: Container(
            width: 940, // BROAD SCREEN-PAINTER ERP MATRIX
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    border: Border(bottom: BorderSide(color: AppColors.border(context), width: 1.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.layoutGrid, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            isEditing
                                ? 'Screen Painter: Change Staff Profile [${existingUser['id'] ?? ""}] - ${widget.branchName}'
                                : 'Screen Painter: Staff Profile & Station PIN - ${widget.branchName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary(context)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Form Matrix
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT FRAME
                            Expanded(
                              child: _buildGroupBox(
                                context: context,
                                title: '01. Staff Identity & Communication',
                                child: Column(
                                  children: [
                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Staff ID:',
                                      input: SizedBox(
                                        width: 140,
                                        child: TextField(
                                          controller: empIdController,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                          decoration: _buildMechanicalInputDecoration(hint: 'EMP-009'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Full Name:',
                                      input: Expanded(
                                        child: TextField(
                                          controller: nameController,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          decoration: _buildMechanicalInputDecoration(hint: 'e.g. Faith Chepkemoi'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Phone (9 Digits):',
                                      input: Expanded(
                                        child: TextField(
                                          controller: phoneController,
                                          maxLength: 9,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                          decoration: InputDecoration(
                                            prefixText: '+254 ',
                                            prefixStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'monospace'),
                                            hintText: '712345678',
                                            counterText: '',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            isDense: true,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Work Email:',
                                      input: Expanded(
                                        child: TextField(
                                          controller: emailController,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(hint: 'staff@store.local'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // RIGHT FRAME
                            Expanded(
                              child: _buildGroupBox(
                                context: context,
                                title: '02. Store Role & Assigned Terminal Lane',
                                child: Column(
                                  children: [
                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Department:',
                                      input: Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: selectedDepartment,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'POS Cashier & Checkout', child: Text('POS Cashier & Checkout')),
                                            DropdownMenuItem(value: 'Branch Operations', child: Text('Branch Operations & Management')),
                                            DropdownMenuItem(value: 'Storekeeping & Inventory', child: Text('Storekeeping & Stockroom')),
                                            DropdownMenuItem(value: 'Accounting & Finance', child: Text('Accounting & Financial Audit')),
                                            DropdownMenuItem(value: 'Hospitality & Dining', child: Text('Hospitality & Dining Floor')),
                                            DropdownMenuItem(value: 'Floor Operations & Security', child: Text('Floor Operations & Logistics')),
                                          ],
                                          onChanged: (val) => setDialogState(() => selectedDepartment = val!),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'System Role:',
                                      input: Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: role,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'owner', child: Text('Organization Owner (Admin)')),
                                            DropdownMenuItem(value: 'branch_manager', child: Text('Branch Supervisor / Manager')),
                                            DropdownMenuItem(value: 'accountant', child: Text('Store Accountant / Auditor')),
                                            DropdownMenuItem(value: 'storekeeper', child: Text('Storekeeper / Stock Controller')),
                                            DropdownMenuItem(value: 'cashier', child: Text('Counter Till Cashier')),
                                            DropdownMenuItem(value: 'waiter', child: Text('Floor Server / Waiter')),
                                          ],
                                          onChanged: (val) => setDialogState(() => role = val!),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Till Lane:',
                                      input: Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: tillLane,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'Lane 01 (Main Register)', child: Text('Lane 01 (Main Register)')),
                                            DropdownMenuItem(value: 'Lane 02 (Express Register)', child: Text('Lane 02 (Express Register)')),
                                            DropdownMenuItem(value: 'Management Station', child: Text('Management Station')),
                                            DropdownMenuItem(value: 'Audit Terminal', child: Text('Audit Terminal')),
                                            DropdownMenuItem(value: 'Stockroom Intake', child: Text('Stockroom Intake')),
                                            DropdownMenuItem(value: 'All Lanes', child: Text('All Lanes')),
                                          ],
                                          onChanged: (val) => setDialogState(() => tillLane = val!),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // FULL-WIDTH FRAME 03: PIN CREDENTIALS & STATUS
                        _buildGroupBox(
                          context: context,
                          title: '03. Station Credentials & Authority Configuration',
                          child: Row(
                            children: [
                              const SizedBox(width: 120, child: Text('4-Digit PIN:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
                              SizedBox(
                                width: 130,
                                child: TextField(
                                  controller: pinController,
                                  maxLength: 4,
                                  obscureText: obscurePin,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 6, fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    hintText: '••••',
                                    counterText: '',
                                    isDense: true,
                                    prefixIcon: const Icon(LucideIcons.hash, size: 14),
                                    suffixIcon: IconButton(
                                      icon: Icon(obscurePin ? LucideIcons.eyeOff : LucideIcons.eye, size: 14),
                                      onPressed: () => setDialogState(() => obscurePin = !obscurePin),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onPressed: () {
                                  final generated = (1000 + Random().nextInt(8999)).toString();
                                  setDialogState(() {
                                    pinController.text = generated;
                                    obscurePin = false;
                                  });
                                },
                                icon: const Icon(LucideIcons.dices, size: 14),
                                label: const Text('AUTO-GENERATE PIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                              ),
                              const Spacer(),

                              Row(
                                children: [
                                  const Text('Authority: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? AppColors.success.withValues(alpha: 0.15) : AppColors.danger.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(color: isActive ? AppColors.success : AppColors.danger),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVE / AUTHORIZED' : 'DEACTIVATED / BLOCKED',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: isActive ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: isActive,
                                    activeColor: AppColors.success,
                                    onChanged: (val) => setDialogState(() => isActive = val),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context), thickness: 1.5),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isEditing)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDeleteStaff(existingUser);
                          },
                          icon: const Icon(LucideIcons.trash2, size: 14),
                          label: const Text('DELETE RECORD', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'monospace')),
                        )
                      else
                        const SizedBox(),

                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CANCEL [ESC]', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            ),
                            onPressed: () {
                              final cleanName = nameController.text.trim();
                              final cleanPhoneInput = phoneController.text.trim();
                              final cleanPin = pinController.text.trim();

                              if (cleanName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a staff name.'), backgroundColor: AppColors.warning),
                                );
                                return;
                              }

                              final formattedPhone = _validateAndFormatKenyanPhone(cleanPhoneInput);
                              if (formattedPhone == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid Kenyan Phone: Must be 9 digits starting with 7 or 1 (e.g. 712 345 678).'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                                return;
                              }

                              if (cleanPin.length != 4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid 4-digit PIN.'), backgroundColor: AppColors.warning),
                                );
                                return;
                              }

                              for (final s in _staffList) {
                                if (isEditing && s['id'] == existingUser['id']) continue;

                                final sName = (s['fullName'] ?? '').toString().trim().toLowerCase();
                                final sPhone = (s['phone'] ?? '').toString().trim();
                                final sPin = (s['pin'] ?? '').toString().trim();

                                if (sName == cleanName.toLowerCase() && sPhone == formattedPhone) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate Staff Error: "$cleanName" with phone "$formattedPhone" is already registered.'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                if (sPhone == formattedPhone) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate Phone Error: Mobile number "$formattedPhone" is already assigned to "${s['fullName']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                if (sPin == cleanPin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate PIN Error: Station PIN "$cleanPin" is already assigned to "${s['fullName']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }
                              }

                              setState(() {
                                if (isEditing) {
                                  existingUser['fullName'] = cleanName;
                                  existingUser['phone'] = formattedPhone;
                                  existingUser['email'] = emailController.text.trim();
                                  existingUser['pin'] = cleanPin;
                                  existingUser['department'] = selectedDepartment;
                                  existingUser['role'] = role;
                                  existingUser['tillLane'] = tillLane;
                                  existingUser['isActive'] = isActive;
                                } else {
                                  _staffList.add({
                                    'id': empIdController.text.trim(),
                                    'fullName': cleanName,
                                    'phone': formattedPhone,
                                    'email': emailController.text.trim().isNotEmpty
                                        ? emailController.text.trim()
                                        : '${cleanName.toLowerCase().replaceAll(' ', '.')}@store.local',
                                    'department': selectedDepartment,
                                    'role': role,
                                    'branch': widget.branchName,
                                    'tillLane': tillLane,
                                    'pin': cleanPin,
                                    'isActive': isActive,
                                    'todaySales': 0.0,
                                    'todayTransactions': 0,
                                    'voidsCount': 0,
                                    'lastActive': 'Never',
                                  });
                                }
                              });

                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing
                                      ? 'Staff profile updated!'
                                      : 'Staff "$cleanName" registered with PIN $cleanPin!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            },
                            icon: const Icon(LucideIcons.check, size: 15),
                            label: Text(isEditing ? 'COMMIT [SAVE]' : 'COMMIT [REGISTER]', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'monospace')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupBox({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.border(context), thickness: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildAlignedRow({
    required BuildContext context,
    required String label,
    required Widget input,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: AppColors.textPrimary(context),
            ),
          ),
        ),
        input,
      ],
    );
  }

  InputDecoration _buildMechanicalInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return const Color(0xFF8B5CF6);
      case 'branch_manager':
        return AppColors.primary;
      case 'accountant':
        return const Color(0xFF0EA5E9);
      case 'storekeeper':
        return const Color(0xFFF59E0B);
      case 'cashier':
        return AppColors.success;
      case 'waiter':
        return const Color(0xFFEC4899);
      default:
        return Colors.grey;
    }
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'owner':
        return 'ORGANIZATION OWNER';
      case 'branch_manager':
        return 'BRANCH SUPERVISOR';
      case 'accountant':
        return 'STORE ACCOUNTANT';
      case 'storekeeper':
        return 'STOREKEEPER';
      case 'cashier':
        return 'TILL CASHIER';
      case 'waiter':
        return 'FLOOR WAITER';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    _staffList.removeWhere((s) {
      final id = (s['id'] ?? '').toString();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final name = (s['fullName'] ?? s['name'] ?? '').toString().toLowerCase();
      return id.startsWith('EMP-00') ||
          email.endsWith('@store.local') ||
          name.contains('chepkemoi') ||
          name.contains('kipkoech') ||
          name.contains('kiprotich');
    });

    final filteredStaff = _staffList.where((u) {
      final matchesQuery = u['fullName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u['phone'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u['tillLane'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRoleFilter == 'all' || u['role'] == _selectedRoleFilter;
      return matchesQuery && matchesRole;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Search staff by name, phone (+254 7XX...), email, or till...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedRoleFilter,
                dropdownColor: AppColors.surface(context),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Staff Roles')),
                  DropdownMenuItem(value: 'owner', child: Text('Owners & Admins')),
                  DropdownMenuItem(value: 'branch_manager', child: Text('Branch Supervisors')),
                  DropdownMenuItem(value: 'cashier', child: Text('Till Cashiers')),
                  DropdownMenuItem(value: 'accountant', child: Text('Accountants')),
                  DropdownMenuItem(value: 'storekeeper', child: Text('Storekeepers')),
                ],
                onChanged: (val) => setState(() => _selectedRoleFilter = val!),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
              onPressed: () => _openAddOrEditUserDialog(),
              icon: const Icon(LucideIcons.userPlus, size: 16),
              label: const Text('Add Staff & PIN'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Staff Directory Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: filteredStaff.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.users, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No Staff Members Registered Yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "+ Add Staff & PIN" to register branch employees, assign station PINs, and set roles.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                            onPressed: () => _openAddOrEditUserDialog(),
                            icon: const Icon(LucideIcons.userPlus, size: 16),
                            label: const Text('Register First Employee'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                itemCount: filteredStaff.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                itemBuilder: (context, index) {
                  final staff = filteredStaff[index];
                  final roleColor = _getRoleColor(staff['role'] as String);
                  final isCashier = staff['role'] == 'cashier';
                  final isActive = staff['isActive'] as bool? ?? true;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // Avatar Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? roleColor.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: isActive ? roleColor.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              staff['fullName'].toString().substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: isActive ? roleColor : AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Name & Phone/Email
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    staff['fullName'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isActive ? AppColors.textPrimary(context) : AppColors.textMuted(context),
                                      decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.success.withValues(alpha: 0.12)
                                          : AppColors.danger.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      isActive ? 'ACTIVE' : 'DEACTIVATED',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'monospace',
                                        color: isActive ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${staff['phone'] ?? ""} • ${staff['email']}',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),

                        // Role Badge
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: roleColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  _formatRoleName(staff['role'] as String),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: roleColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                staff['tillLane'] as String,
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),

                        // Station PIN
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(LucideIcons.keyRound, size: 14, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'PIN: ${staff['pin']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Today's Performance (for Cashiers)
                        Expanded(
                          flex: 3,
                          child: isCashier
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Today: ${Formatters.formatCurrency(staff['todaySales'] as double)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    Text(
                                      '${staff['todayTransactions']} receipts • ${staff['voidsCount']} voids',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                    ),
                                  ],
                                )
                              : Text(
                                  staff['lastActive'] as String,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                ),
                        ),

                        // Actions: Activate/Deactivate, Edit, Delete
                        IconButton(
                          icon: Icon(
                            isActive ? LucideIcons.userCheck : LucideIcons.userX,
                            size: 16,
                            color: isActive ? AppColors.success : AppColors.danger,
                          ),
                          tooltip: isActive ? 'Deactivate Staff' : 'Activate Staff',
                          onPressed: () => _toggleStaffActive(staff),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          tooltip: 'Edit Staff Profile & PIN',
                          onPressed: () => _openAddOrEditUserDialog(staff),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                          tooltip: 'Delete Staff Member',
                          onPressed: () => _confirmDeleteStaff(staff),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
