import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class SuppliersView extends StatefulWidget {
  final String branchName;
  const SuppliersView({super.key, required this.branchName});

  @override
  State<SuppliersView> createState() => _SuppliersViewState();
}

class _SuppliersViewState extends State<SuppliersView> {
  String _searchQuery = '';
  String _selectedCategoryFilter = 'all';

  List<Map<String, dynamic>> _suppliers = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_suppliers_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              final name = (e['name'] ?? '').toString().toLowerCase();
              final isMock = id.startsWith('SUP-00') ||
                  name.contains('brookside') ||
                  name.contains('pembe') ||
                  name.contains('pwani') ||
                  name.contains('broadway') ||
                  name.contains('kartasi');
              return !isMock;
            })
            .toList();
        setState(() {
          _suppliers = filtered;
        });
        await _persistSuppliers();
      } else {
        setState(() {
          _suppliers = [];
        });
      }
    } catch (_) {
      setState(() {
        _suppliers = [];
      });
    }
  }

  Future<void> _persistSuppliers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_suppliers_${widget.branchName}', jsonEncode(_suppliers));
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

  void _openAddOrEditSupplierDialog([Map<String, dynamic>? supplierToEdit]) {
    final isEditing = supplierToEdit != null;
    final nameController = TextEditingController(text: isEditing ? supplierToEdit['name'] : '');
    final contactPersonController = TextEditingController(text: isEditing ? supplierToEdit['contactPerson'] : '');
    
    String rawPhone = '';
    if (isEditing && supplierToEdit['phone'] != null) {
      final clean = supplierToEdit['phone'].toString().replaceAll(RegExp(r'[^0-9]'), '');
      rawPhone = clean.startsWith('254') && clean.length == 12 ? clean.substring(3) : clean;
    }
    final phoneController = TextEditingController(text: rawPhone);
    final emailController = TextEditingController(text: isEditing ? supplierToEdit['email'] : '');
    final kraPinController = TextEditingController(text: isEditing ? supplierToEdit['kraPin'] : '');
    final addressController = TextEditingController(text: isEditing ? supplierToEdit['address'] : '');
    final leadTimeController = TextEditingController(text: isEditing ? (supplierToEdit['leadTimeDays'] ?? 3).toString() : '3');
    
    String category = isEditing ? supplierToEdit['category'] : 'Groceries & Grains';
    String paymentTerms = isEditing ? supplierToEdit['paymentTerms'] : 'Net 30 Days';
    bool isActive = isEditing ? (supplierToEdit['isActive'] ?? true) : true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppColors.border(context), width: 1.5),
          ),
          child: Container(
            width: 840,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    border: Border(bottom: BorderSide(color: AppColors.border(context))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.truck, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'EDIT VENDOR PROFILE: ${supplierToEdit['id']}' : 'REGISTER LOCAL VENDOR / SUPPLIER',
                            style: TextStyle(
                              fontSize: 14,
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

                // Form Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Supplier / Company Legal Name *'),
                                  TextField(
                                    controller: nameController,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: 'e.g. Brookside Dairy Limited'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Contact Person Name *'),
                                  TextField(
                                    controller: contactPersonController,
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: 'e.g. John Mwangi'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Kenyan Phone (9 Digits) *'),
                                  TextField(
                                    controller: phoneController,
                                    maxLength: 9,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                    decoration: InputDecoration(
                                      prefixText: '+254 ',
                                      prefixStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'monospace'),
                                      hintText: '722100200',
                                      counterText: '',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Orders Email Address'),
                                  TextField(
                                    controller: emailController,
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: 'orders@supplier.co.ke'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Supply Category (Type or Search)'),
                                  Autocomplete<String>(
                                    initialValue: TextEditingValue(text: category),
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      const categories = [
                                        'Dairy & Chilled',
                                        'Groceries & Grains',
                                        'Cooking Oils & Fats',
                                        'Bakery & Confectionery',
                                        'Meat & Butchery',
                                        'Beverages & Soft Drinks',
                                        'Stationery & Packaging',
                                        'Household & Detergents',
                                        'Personal Care & Cosmetics',
                                        'Fresh Produce & Fruits',
                                      ];
                                      if (textEditingValue.text.isEmpty) return categories;
                                      return categories.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String val) => setDialogState(() => category = val),
                                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                        decoration: InputDecoration(
                                          hintText: 'Search category...',
                                          prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.primary),
                                          suffixIcon: const Icon(LucideIcons.chevronDown, size: 14),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onChanged: (val) {
                                          if (val.trim().isNotEmpty) category = val.trim();
                                        },
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 6,
                                          borderRadius: BorderRadius.circular(6),
                                          color: AppColors.card(context),
                                          child: Container(
                                            width: 320,
                                            constraints: const BoxConstraints(maxHeight: 180),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.border(context)),
                                            ),
                                            child: ListView.separated(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                                              itemBuilder: (context, idx) {
                                                final opt = options.elementAt(idx);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(opt, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                                                  onTap: () => onSelected(opt),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Payment Credit Terms (Type or Search)'),
                                  Autocomplete<String>(
                                    initialValue: TextEditingValue(text: paymentTerms),
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      const terms = [
                                        'Cash on Delivery (COD)',
                                        'Net 7 Days',
                                        'Net 14 Days',
                                        'Net 30 Days',
                                        'Net 45 Days',
                                        'Net 60 Days',
                                        'Prepaid / Advance',
                                      ];
                                      if (textEditingValue.text.isEmpty) return terms;
                                      return terms.where((t) => t.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                    },
                                    onSelected: (String val) => setDialogState(() => paymentTerms = val),
                                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                      return TextField(
                                        controller: textEditingController,
                                        focusNode: focusNode,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                        decoration: InputDecoration(
                                          hintText: 'Search payment terms...',
                                          prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.primary),
                                          suffixIcon: const Icon(LucideIcons.chevronDown, size: 14),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onChanged: (val) {
                                          if (val.trim().isNotEmpty) paymentTerms = val.trim();
                                        },
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 6,
                                          borderRadius: BorderRadius.circular(6),
                                          color: AppColors.card(context),
                                          child: Container(
                                            width: 320,
                                            constraints: const BoxConstraints(maxHeight: 180),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.border(context)),
                                            ),
                                            child: ListView.separated(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                                              itemBuilder: (context, idx) {
                                                final opt = options.elementAt(idx);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(opt, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                                                  onTap: () => onSelected(opt),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Lead Time (Days)'),
                                  TextField(
                                    controller: leadTimeController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: '2'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('KRA PIN (Tax Identification)'),
                                  TextField(
                                    controller: kraPinController,
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: 'P051234567Z'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 6,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Physical Address / Depot Location'),
                                  TextField(
                                    controller: addressController,
                                    style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                    decoration: _buildInputDec(hint: 'e.g. Industrial Area, Nairobi'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context)),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isEditing)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () {
                            setState(() {
                              _suppliers.removeWhere((s) => s['id'] == supplierToEdit['id']);
                            });
                            _persistSuppliers();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Supplier "${supplierToEdit['name']}" removed.'), backgroundColor: AppColors.danger),
                            );
                          },
                          icon: const Icon(LucideIcons.trash2, size: 15),
                          label: const Text('DELETE VENDOR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                        )
                      else
                        const SizedBox(),

                      Row(
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('CANCEL'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            onPressed: () {
                              final cleanName = nameController.text.trim();
                              final cleanPhone = phoneController.text.trim();

                              if (cleanName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter supplier name.'), backgroundColor: AppColors.warning),
                                );
                                return;
                              }

                              final formattedPhone = _validateAndFormatKenyanPhone(cleanPhone);
                              if (formattedPhone == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid Kenyan Phone: Must be 9 digits starting with 7 or 1 (e.g. 722100200).'), backgroundColor: AppColors.danger),
                                );
                                return;
                              }

                              setState(() {
                                if (isEditing) {
                                  supplierToEdit['name'] = cleanName;
                                  supplierToEdit['contactPerson'] = contactPersonController.text.trim();
                                  supplierToEdit['phone'] = formattedPhone;
                                  supplierToEdit['email'] = emailController.text.trim();
                                  supplierToEdit['category'] = category;
                                  supplierToEdit['paymentTerms'] = paymentTerms;
                                  supplierToEdit['kraPin'] = kraPinController.text.trim().toUpperCase();
                                  supplierToEdit['address'] = addressController.text.trim();
                                  supplierToEdit['leadTimeDays'] = int.tryParse(leadTimeController.text) ?? 3;
                                  supplierToEdit['isActive'] = isActive;
                                } else {
                                  _suppliers.add({
                                    'id': 'SUP-00${_suppliers.length + 1}',
                                    'name': cleanName,
                                    'contactPerson': contactPersonController.text.trim(),
                                    'phone': formattedPhone,
                                    'email': emailController.text.trim(),
                                    'category': category,
                                    'paymentTerms': paymentTerms,
                                    'kraPin': kraPinController.text.trim().toUpperCase(),
                                    'address': addressController.text.trim(),
                                    'leadTimeDays': int.tryParse(leadTimeController.text) ?? 3,
                                    'isActive': isActive,
                                    'totalPurchasesKES': 0.0,
                                    'pendingBalanceKES': 0.0,
                                  });
                                }
                              });

                              _persistSuppliers();
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Vendor "$cleanName" saved!'), backgroundColor: AppColors.success),
                              );
                            },
                            icon: const Icon(LucideIcons.check, size: 16),
                            label: Text(isEditing ? 'COMMIT CHANGES' : 'REGISTER VENDOR', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
    );
  }

  InputDecoration _buildInputDec({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _suppliers.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      final name = (e['name'] ?? '').toString().toLowerCase();
      return id.startsWith('SUP-00') ||
          name.contains('brookside') ||
          name.contains('pembe') ||
          name.contains('pwani') ||
          name.contains('broadway') ||
          name.contains('kartasi');
    });

    final filtered = _suppliers.where((s) {
      final matchesQuery = s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['contactPerson'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s['phone'].toString().contains(_searchQuery) ||
          s['kraPin'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategoryFilter == 'all' || s['category'] == _selectedCategoryFilter;
      return matchesQuery && matchesCat;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Toolbar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 380,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      hintText: 'Search vendors by company, contact, phone (+254 7XX...), KRA PIN...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: _selectedCategoryFilter,
                  dropdownColor: AppColors.card(context),
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Supply Categories')),
                    DropdownMenuItem(value: 'Dairy & Chilled', child: Text('Dairy & Chilled')),
                    DropdownMenuItem(value: 'Groceries & Grains', child: Text('Groceries & Grains')),
                    DropdownMenuItem(value: 'Cooking Oils & Fats', child: Text('Cooking Oils & Fats')),
                    DropdownMenuItem(value: 'Bakery & Confectionery', child: Text('Bakery & Confectionery')),
                    DropdownMenuItem(value: 'Stationery & Packaging', child: Text('Stationery & Packaging')),
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryFilter = val!),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: () => _openAddOrEditSupplierDialog(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add Local Vendor'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Suppliers Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                itemBuilder: (context, index) {
                  final s = filtered[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.truck, color: AppColors.primary, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Vendor Details
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    s['name'] as String,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.card(context),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppColors.border(context)),
                                    ),
                                    child: Text(
                                      s['id'] as String,
                                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.textSecondary(context)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Contact: ${s['contactPerson']} • ${s['phone']} • ${s['email']}',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),

                        // Category & Terms
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['category'] as String, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                              Text('Terms: ${s['paymentTerms']} • Lead: ${s['leadTimeDays']}d', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // Financials
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Invoiced: ${Formatters.formatCurrency(s['totalPurchasesKES'] as num)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                              Text('Pending Balance: ${Formatters.formatCurrency(s['pendingBalanceKES'] as num)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: const Icon(LucideIcons.pencil, size: 16),
                          tooltip: 'Edit Supplier',
                          onPressed: () => _openAddOrEditSupplierDialog(s),
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
