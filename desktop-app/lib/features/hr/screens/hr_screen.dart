import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

class HrScreen extends StatefulWidget {
  final String branchName;
  const HrScreen({super.key, this.branchName = 'KERICHO'});

  @override
  State<HrScreen> createState() => _HrScreenState();
}

class _HrScreenState extends State<HrScreen> {
  String _selectedDepartmentFilter = 'all';
  String _searchQuery = '';
  List<Map<String, dynamic>> _staff = [];

  final List<Map<String, dynamic>> _defaultInitialStaff = [];

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
          final name = (s['name'] ?? '').toString().toLowerCase();
          return !id.startsWith('EMP-00') &&
              !email.endsWith('@store.local') &&
              !name.contains('chepkemoi') &&
              !name.contains('kipkoech') &&
              !name.contains('kiprotich');
        }).toList();

        setState(() {
          _staff = list;
        });
        await _persistStaff();
      } else {
        setState(() {
          _staff = [];
        });
      }
    } catch (_) {
      setState(() {
        _staff = [];
      });
    }
  }

  Future<void> _persistStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_staff_${widget.branchName}', jsonEncode(_staff));
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
              'DELETE PERSONNEL: ${staff['id']}',
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
          'Confirm permanent deletion of "${staff['name']}" (${staff['id']}) from ${widget.branchName}.\nAll station PINs and credentials will be purged.',
          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
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
                _staff.removeWhere((s) => s['id'] == staff['id']);
              });
              _persistStaff();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Staff member "${staff['name']}" purged from registry.'),
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
      final current = staff['isActive'] as bool? ?? true;
      staff['isActive'] = !current;
    });
    _persistStaff();

    final isNowActive = staff['isActive'] as bool;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isNowActive
            ? 'Staff "${staff['name']}" ACTIVATED and authorized for station login.'
            : 'Staff "${staff['name']}" DEACTIVATED. Access revoked.'),
        backgroundColor: isNowActive ? AppColors.success : AppColors.warning,
      ),
    );
  }

  /// Broad Mechanical / Screen Painter Form Dialog
  void _openAddOrEditStaffDialog([Map<String, dynamic>? staffToEdit]) {
    final isEditing = staffToEdit != null;

    final empIdController = TextEditingController(text: isEditing ? staffToEdit['id'] : 'EMP-00${_staff.length + 1}');
    final nameController = TextEditingController(text: isEditing ? staffToEdit['name'] : '');
    
    String rawPhone = '';
    if (isEditing && staffToEdit['phone'] != null) {
      final clean = staffToEdit['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (clean.startsWith('254') && clean.length == 12) {
        rawPhone = clean.substring(3);
      } else {
        rawPhone = clean;
      }
    }
    final phoneController = TextEditingController(text: rawPhone);
    final emailController = TextEditingController(text: isEditing ? staffToEdit['email'] : '');
    final pinController = TextEditingController(text: isEditing ? staffToEdit['pin'] : '');

    String selectedDepartment = isEditing ? staffToEdit['department'] : 'POS Cashier & Checkout';
    String selectedRole = isEditing ? staffToEdit['role'] : 'cashier';
    String selectedStation = isEditing ? staffToEdit['station'] : 'Lane 01 (Main Register)';
    String employmentType = isEditing ? staffToEdit['employmentType'] : 'Full-Time Shift Cashier';
    bool requiresPin = isEditing ? (staffToEdit['requiresPin'] ?? true) : true;
    bool isActive = isEditing ? (staffToEdit['isActive'] ?? true) : true;
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
            width: 940, // EXTREMELY BROAD SCREEN-PAINTER WIDTH
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Screen Painter Window Title Bar
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
                                ? 'Screen Painter: Edit Personnel [${staffToEdit['id']}] - ${widget.branchName}'
                                : 'Screen Painter: Personnel Registry & Station Authority - ${widget.branchName}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary(context),
                              letterSpacing: 0.5,
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

                // Mechanical Form Matrix (Scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TWO-COLUMN BROAD LAYOUT
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT COLUMN: IDENTITY & CONTACT FRAME
                            Expanded(
                              flex: 5,
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

                            // RIGHT COLUMN: STORE OPERATIONS & ROUTING FRAME
                            Expanded(
                              flex: 5,
                              child: _buildGroupBox(
                                context: context,
                                title: '02. Department & Workstation Routing',
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
                                          value: selectedRole,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'cashier', child: Text('Counter Till Cashier')),
                                            DropdownMenuItem(value: 'branch_manager', child: Text('Branch Supervisor / Manager')),
                                            DropdownMenuItem(value: 'storekeeper', child: Text('Storekeeper / Stock Controller')),
                                            DropdownMenuItem(value: 'accountant', child: Text('Store Accountant / Auditor')),
                                            DropdownMenuItem(value: 'waiter', child: Text('Floor Server / Waiter')),
                                            DropdownMenuItem(value: 'security', child: Text('Security / Floor Support')),
                                            DropdownMenuItem(value: 'owner', child: Text('Organization Owner / Admin')),
                                          ],
                                          onChanged: (val) {
                                            setDialogState(() {
                                              selectedRole = val!;
                                              requiresPin = selectedRole != 'security';
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Till / Station:',
                                      input: Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: selectedStation,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'Lane 01 (Main Register)', child: Text('Lane 01 (Main Register)')),
                                            DropdownMenuItem(value: 'Lane 02 (Express Register)', child: Text('Lane 02 (Express Register)')),
                                            DropdownMenuItem(value: 'Management Station', child: Text('Management Station')),
                                            DropdownMenuItem(value: 'Stockroom Intake', child: Text('Stockroom Intake')),
                                            DropdownMenuItem(value: 'Audit Terminal', child: Text('Audit Terminal')),
                                            DropdownMenuItem(value: 'Cafe & Bakery Section', child: Text('Cafe & Bakery Section')),
                                            DropdownMenuItem(value: 'Main Entrance / Security Desk', child: Text('Main Entrance / Security Desk')),
                                            DropdownMenuItem(value: 'All Workstations', child: Text('All Workstations')),
                                          ],
                                          onChanged: (val) => setDialogState(() => selectedStation = val!),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _buildAlignedRow(
                                      context: context,
                                      label: 'Contract Type:',
                                      input: Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: employmentType,
                                          isExpanded: true,
                                          dropdownColor: AppColors.surface(context),
                                          style: const TextStyle(fontSize: 13),
                                          decoration: _buildMechanicalInputDecoration(),
                                          items: const [
                                            DropdownMenuItem(value: 'Full-Time Shift Cashier', child: Text('Full-Time Cashier')),
                                            DropdownMenuItem(value: 'Full-Time Staff', child: Text('Full-Time Permanent')),
                                            DropdownMenuItem(value: 'Full-Time Supervisor', child: Text('Full-Time Supervisor')),
                                            DropdownMenuItem(value: 'Stock Controller', child: Text('Stock Controller')),
                                            DropdownMenuItem(value: 'Store Accountant', child: Text('Store Accountant')),
                                            DropdownMenuItem(value: 'Floor Attendant', child: Text('Floor Attendant')),
                                            DropdownMenuItem(value: 'Security Lead', child: Text('Security Lead')),
                                            DropdownMenuItem(value: 'Part-Time / Seasonal', child: Text('Part-Time / Seasonal')),
                                          ],
                                          onChanged: (val) => setDialogState(() => employmentType = val!),
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

                        // FULL-WIDTH FRAME 03: STATION PIN & AUTHORITY STATUS
                        _buildGroupBox(
                          context: context,
                          title: '03. Station Credentials & Authority Configuration',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Checkbox(
                                    value: requiresPin,
                                    activeColor: AppColors.primary,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        requiresPin = val ?? true;
                                        if (requiresPin && pinController.text.isEmpty) {
                                          pinController.text = (1000 + Random().nextInt(8999)).toString();
                                        }
                                      });
                                    },
                                  ),
                                  const Text(
                                    'Require 4-Digit Station PIN for Terminal Logins (Cashier Register & BackOffice Operations)',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),

                              if (requiresPin) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const SizedBox(width: 140, child: Text('PIN Code:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
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

                                    // Status Switch
                                    Row(
                                      children: [
                                        const Text('Status: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
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
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context), thickness: 1.5),

                // Mechanical Pushbutton Action Toolbar
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
                            _confirmDeleteStaff(staffToEdit);
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

                              if (cleanName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter the full staff name.'), backgroundColor: AppColors.warning),
                                );
                                return;
                              }

                              final formattedPhone = _validateAndFormatKenyanPhone(cleanPhoneInput);
                              if (formattedPhone == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Invalid Kenyan Phone: Must be a 9-digit mobile number starting with 7 or 1 (e.g. 712 345 678).'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                                return;
                              }

                              if (requiresPin && pinController.text.trim().length != 4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid 4-digit station PIN.'), backgroundColor: AppColors.warning),
                                );
                                return;
                              }

                              final cleanEmpId = empIdController.text.trim();
                              final cleanPin = requiresPin ? pinController.text.trim() : '';

                              // STRICT DUPLICATE PREVENTION CHECKS
                              for (final s in _staff) {
                                if (isEditing && s['id'] == staffToEdit['id']) continue;

                                final sName = (s['name'] ?? '').toString().trim().toLowerCase();
                                final sPhone = (s['phone'] ?? '').toString().trim();
                                final sPin = (s['pin'] ?? '').toString().trim();
                                final sId = (s['id'] ?? '').toString().trim().toLowerCase();

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
                                      content: Text('Duplicate Phone Error: Mobile number "$formattedPhone" is already assigned to "${s['name']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                if (requiresPin && cleanPin.isNotEmpty && sPin == cleanPin) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate PIN Error: Station PIN "$cleanPin" is already assigned to "${s['name']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                if (sId == cleanEmpId.toLowerCase()) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate Employee ID: "$cleanEmpId" is already registered to "${s['name']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }
                              }

                              setState(() {
                                if (isEditing) {
                                  staffToEdit['id'] = cleanEmpId;
                                  staffToEdit['name'] = cleanName;
                                  staffToEdit['phone'] = formattedPhone;
                                  staffToEdit['email'] = emailController.text.trim();
                                  staffToEdit['department'] = selectedDepartment;
                                  staffToEdit['role'] = selectedRole;
                                  staffToEdit['station'] = selectedStation;
                                  staffToEdit['employmentType'] = employmentType;
                                  staffToEdit['isActive'] = isActive;
                                  staffToEdit['requiresPin'] = requiresPin;
                                  staffToEdit['pin'] = cleanPin;
                                } else {
                                  _staff.add({
                                    'id': cleanEmpId,
                                    'name': cleanName,
                                    'phone': formattedPhone,
                                    'email': emailController.text.trim().isNotEmpty
                                        ? emailController.text.trim()
                                        : '${cleanName.toLowerCase().replaceAll(' ', '.')}@store.local',
                                    'department': selectedDepartment,
                                    'role': selectedRole,
                                    'station': selectedStation,
                                    'employmentType': employmentType,
                                    'isActive': isActive,
                                    'requiresPin': requiresPin,
                                    'pin': cleanPin,
                                    'status': 'On Duty',
                                    'clockIn': '08:00 AM',
                                    'hoursToday': '0.0 hrs',
                                    'salesToday': 0.0,
                                  });
                                }
                              });

                              _persistStaff();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEditing
                                      ? 'Personnel "$cleanName" updated successfully!'
                                      : 'Personnel "$cleanName" registered to ${widget.branchName}!'),
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

  /// Screen Painter Boxed Field Container
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

  /// Aligned Left Label + Right Boxed Field Row
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

  Widget _buildFieldLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: 'monospace',
          color: AppColors.textPrimary(context),
          letterSpacing: 0.5,
        ),
      ),
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
      case 'security':
        return const Color(0xFF64748B);
      default:
        return Colors.grey;
    }
  }

  String _formatRoleLabel(String role) {
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
      case 'security':
        return 'SECURITY / LOGISTICS';
      default:
        return role.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    _staff.removeWhere((s) {
      final id = (s['id'] ?? '').toString();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final name = (s['name'] ?? '').toString().toLowerCase();
      return id.startsWith('EMP-00') ||
          email.endsWith('@store.local') ||
          name.contains('chepkemoi') ||
          name.contains('kipkoech') ||
          name.contains('kiprotich');
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final onDutyCount = _staff.where((s) => s['status'] == 'On Duty' && (s['isActive'] ?? true)).length;
    final pinCount = _staff.where((s) => s['requiresPin'] == true && (s['pin'] ?? '').toString().isNotEmpty && (s['isActive'] ?? true)).length;
    final cashierCount = _staff.where((s) => s['role'] == 'cashier' && (s['isActive'] ?? true)).length;

    final filtered = _staff.where((s) {
      final matchesQuery = s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['phone'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['station'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesDept = _selectedDepartmentFilter == 'all' ||
          (_selectedDepartmentFilter == 'cashiers' && s['role'] == 'cashier') ||
          (_selectedDepartmentFilter == 'management' && (s['role'] == 'branch_manager' || s['role'] == 'owner')) ||
          (_selectedDepartmentFilter == 'inventory' && s['role'] == 'storekeeper') ||
          (_selectedDepartmentFilter == 'finance' && s['role'] == 'accountant');
      return matchesQuery && matchesDept;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Store Personnel & Staff Roster',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'BRANCH: ${widget.branchName}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage all branch store employees, station PIN credentials, shift clock-in & role authorizations',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _openAddOrEditStaffDialog(),
                  icon: const Icon(LucideIcons.userPlus, size: 16),
                  label: const Text('Add Staff Member'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Personnel Summary KPI Cards
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'TOTAL BRANCH PERSONNEL',
                    value: '${_staff.length} Staff',
                    subtitle: 'Across all 6 modules',
                    icon: LucideIcons.users,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'ON DUTY / CLOCKED IN',
                    value: '$onDutyCount Active',
                    subtitle: 'Shift in progress',
                    icon: LucideIcons.userCheck,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'STATION PINS CONFIGURED',
                    value: '$pinCount PINs Active',
                    subtitle: 'Cashier & BackOffice access',
                    icon: LucideIcons.keyRound,
                    color: const Color(0xFF0EA5E9),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildMetricCard(
                    title: 'REGISTER CASHIERS',
                    value: '$cashierCount Cashiers',
                    subtitle: 'Assigned to checkout till lanes',
                    icon: LucideIcons.shoppingCart,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Bar
            Row(
              children: [
                // Search Input
                Expanded(
                  flex: 4,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Search personnel by name, phone (+254 7XX...), employee ID, or till lane...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Department Filter Pills
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Row(
                    children: [
                      _buildDeptPill('all', 'All Personnel'),
                      _buildDeptPill('cashiers', 'Till Cashiers'),
                      _buildDeptPill('inventory', 'Storekeeping'),
                      _buildDeptPill('finance', 'Accounting'),
                      _buildDeptPill('management', 'Supervisors'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Personnel Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.users, size: 48, color: AppColors.textMuted(context)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Personnel Found Matching Filter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Register employee accounts with 9-digit Kenyan phone numbers and 4-digit station PINs.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                                  onPressed: () => _openAddOrEditStaffDialog(),
                                  icon: const Icon(LucideIcons.userPlus, size: 16),
                                  label: const Text('Add Staff Member'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                          itemBuilder: (context, index) {
                            final staff = filtered[index];
                            final roleColor = _getRoleColor(staff['role'] as String);
                            final isOnDuty = staff['status'] == 'On Duty';
                            final isActive = staff['isActive'] as bool? ?? true;
                            final hasPin = staff['requiresPin'] == true && (staff['pin'] ?? '').toString().isNotEmpty;

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              child: Row(
                                children: [
                                  // Avatar
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? roleColor.withValues(alpha: 0.12)
                                          : AppColors.danger.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(2),
                                      border: Border.all(
                                        color: isActive
                                            ? roleColor.withValues(alpha: 0.3)
                                            : AppColors.danger.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        staff['name'].toString().substring(0, 1).toUpperCase(),
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

                                  // Identity & Contact
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              staff['name'] as String,
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
                                                color: AppColors.card(context),
                                                borderRadius: BorderRadius.circular(2),
                                                border: Border.all(color: AppColors.border(context)),
                                              ),
                                              child: Text(
                                                staff['id'] as String,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textSecondary(context),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
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
                                                  fontSize: 9,
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
                                          '${staff['phone']} • ${staff['email']}',
                                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Role & Department
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: roleColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(2),
                                            border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            _formatRoleLabel(staff['role'] as String),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              color: roleColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          staff['station'] as String,
                                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Station PIN Badge
                                  Expanded(
                                    flex: 2,
                                    child: hasPin
                                        ? Row(
                                            children: [
                                              Icon(LucideIcons.keyRound, size: 14, color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'PIN: ${staff['pin']}',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                  fontFamily: 'monospace',
                                                  color: AppColors.textPrimary(context),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'No PIN (Support)',
                                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                          ),
                                  ),

                                  // Shift Status & Hours
                                  Expanded(
                                    flex: 3,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: (isOnDuty && isActive) ? AppColors.success : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (isOnDuty && isActive)
                                                  ? 'On Duty (${staff['clockIn']})'
                                                  : (isActive ? 'Off Duty' : 'Deactivated'),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: (isOnDuty && isActive)
                                                    ? AppColors.success
                                                    : AppColors.textSecondary(context),
                                              ),
                                            ),
                                            Text(
                                              '${staff['hoursToday']} logged today',
                                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quick Actions: Activate/Deactivate Toggle, Edit, Delete
                                  IconButton(
                                    icon: Icon(
                                      isActive ? LucideIcons.userCheck : LucideIcons.userX,
                                      size: 16,
                                      color: isActive ? AppColors.success : AppColors.danger,
                                    ),
                                    tooltip: isActive ? 'Deactivate Staff Access' : 'Activate Staff Access',
                                    onPressed: () => _toggleStaffActive(staff),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.pencil, size: 16),
                                    tooltip: 'Edit Personnel & PIN',
                                    onPressed: () => _openAddOrEditStaffDialog(staff),
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
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary, letterSpacing: 0.8),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptPill(String key, String label) {
    final isSelected = _selectedDepartmentFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedDepartmentFilter = key),
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}
