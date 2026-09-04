import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../services/purchase_order_pdf_service.dart';

class PurchaseOrdersView extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final List<Map<String, dynamic>> catalog;
  final Function(Map<String, dynamic> po)? onLoadPoIntoGrn;

  const PurchaseOrdersView({
    super.key,
    required this.branchName,
    this.organizationName = 'GIFTMART SUPERMARKET',
    required this.catalog,
    this.onLoadPoIntoGrn,
  });

  @override
  State<PurchaseOrdersView> createState() => _PurchaseOrdersViewState();
}

class _PurchaseOrdersViewState extends State<PurchaseOrdersView> {
  String _searchQuery = '';
  String _selectedStatusFilter = 'all';

  List<Map<String, dynamic>> _purchaseOrders = [];

  @override
  void initState() {
    super.initState();
    _loadPOs();
  }

  Future<void> _loadPOs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_pos_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              return !(id == 'PO-20260903-001' || id == 'PO-20260902-002' || id == 'PO-20260901-003');
            })
            .toList();
        setState(() {
          _purchaseOrders = filtered;
        });
        await _persistPOs();
      } else {
        setState(() {
          _purchaseOrders = [];
        });
      }
    } catch (_) {
      setState(() {
        _purchaseOrders = [];
      });
    }
  }

  Future<void> _persistPOs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_pos_${widget.branchName}', jsonEncode(_purchaseOrders));
    } catch (_) {}
  }

  void _openCreatePoDialog() {
    final supplierController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final expectedDateController = TextEditingController(
      text: '${selectedDate.day.toString().padLeft(2, '0')} ${_getMonthName(selectedDate.month)} ${selectedDate.year}',
    );
    final notesController = TextEditingController();

    List<Map<String, dynamic>> poItems = [];
    if (widget.catalog.isNotEmpty) {
      final first = widget.catalog.first;
      poItems.add({
        'sku': first['sku'],
        'name': first['name'],
        'qty': 50,
        'cost': (first['cost'] as num).toDouble(),
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double orderTotal = 0;
          for (var item in poItems) {
            orderTotal += (item['qty'] as int) * (item['cost'] as double);
          }

          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.card(context),
                      onSurface: AppColors.textPrimary(context),
                    ),
                  ),
                  child: child!,
                );
              },
            );

            if (picked != null) {
              setDialogState(() {
                selectedDate = picked;
                expectedDateController.text =
                    '${picked.day.toString().padLeft(2, '0')} ${_getMonthName(picked.month)} ${picked.year}';
              });
            }
          }

          return Dialog(
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border(context), width: 1.5),
            ),
            child: Container(
              width: 820,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Bar
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
                            const Icon(LucideIcons.fileSpreadsheet, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'CREATE PURCHASE ORDER (PO) - ${widget.branchName}',
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

                  // Body
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
                                    _buildLabel('Supplier / Vendor Name *'),
                                    TextField(
                                      controller: supplierController,
                                      style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
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
                                    _buildLabel('Expected Delivery Date *'),
                                    InkWell(
                                      onTap: pickDate,
                                      borderRadius: BorderRadius.circular(4),
                                      child: TextField(
                                        controller: expectedDateController,
                                        readOnly: true,
                                        onTap: pickDate,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                        decoration: InputDecoration(
                                          hintText: 'Select delivery date',
                                          isDense: true,
                                          prefixIcon: const Icon(LucideIcons.calendar, size: 16, color: AppColors.primary),
                                          suffixIcon: IconButton(
                                            icon: const Icon(LucideIcons.calendarDays, size: 16, color: AppColors.primary),
                                            onPressed: pickDate,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Line Items Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PURCHASE ORDER LINE ITEMS',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                                onPressed: () {
                                  if (widget.catalog.isNotEmpty) {
                                    final item = widget.catalog.first;
                                    setDialogState(() {
                                      poItems.add({
                                        'sku': item['sku'],
                                        'name': item['name'],
                                        'qty': 20,
                                        'cost': (item['cost'] as num).toDouble(),
                                      });
                                    });
                                  }
                                },
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('Add Item Line', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Items List
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border(context)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: poItems.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                              itemBuilder: (context, index) {
                                final item = poItems[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 5,
                                        child: Autocomplete<Map<String, dynamic>>(
                                          displayStringForOption: (opt) => '${opt['name']} (${opt['sku']})',
                                          initialValue: TextEditingValue(text: '${item['name']} (${item['sku']})'),
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) return widget.catalog;
                                            final q = textEditingValue.text.toLowerCase();
                                            return widget.catalog.where((p) =>
                                                (p['name'] as String).toLowerCase().contains(q) ||
                                                (p['sku'] as String).toLowerCase().contains(q) ||
                                                (p['barcode'] as String).contains(q));
                                          },
                                          onSelected: (Map<String, dynamic> selected) {
                                            setDialogState(() {
                                              item['sku'] = selected['sku'];
                                              item['name'] = selected['name'];
                                              item['cost'] = (selected['cost'] as num).toDouble();
                                            });
                                          },
                                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                            return TextField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                              decoration: InputDecoration(
                                                hintText: 'Search product...',
                                                prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.primary),
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                              ),
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
                                                  width: 360,
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
                                                        title: Text(opt['name'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                                        subtitle: Text('SKU: ${opt['sku']} • Cost: KES ${opt['cost']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
                                                        onTap: () => onSelected(opt),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 90,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
                                          decoration: _buildInputDec(hint: 'Qty'),
                                          controller: TextEditingController(text: item['qty'].toString()),
                                          onChanged: (val) => setDialogState(() => item['qty'] = int.tryParse(val) ?? 1),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 110,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
                                          decoration: _buildInputDec(hint: 'Unit Cost'),
                                          controller: TextEditingController(text: item['cost'].toString()),
                                          onChanged: (val) => setDialogState(() => item['cost'] = double.tryParse(val) ?? 0.0),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          Formatters.formatCurrency((item['qty'] as int) * (item['cost'] as double)),
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'monospace'),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.danger),
                                        onPressed: () {
                                          if (poItems.length > 1) {
                                            setDialogState(() => poItems.removeAt(index));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Total Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL PURCHASE ESTIMATE:', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 12)),
                                Text(Formatters.formatCurrency(orderTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),

                  // Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('CANCEL'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: const BorderSide(color: AppColors.primary),
                          ),
                          onPressed: () {
                            final poNumber = 'PO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${_purchaseOrders.length + 1}';
                            final newPO = {
                              'id': poNumber,
                              'supplierName': supplierController.text.trim().isNotEmpty ? supplierController.text.trim() : 'Vendor Supplier',
                              'date': '${DateTime.now().day.toString().padLeft(2, '0')} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                              'expectedDate': expectedDateController.text.trim(),
                              'status': 'ISSUED',
                              'totalKES': orderTotal,
                              'items': poItems.map((i) => {
                                'sku': i['sku'],
                                'name': i['name'],
                                'qtyOrdered': i['qty'],
                                'unitCost': i['cost'],
                                'total': (i['qty'] as int) * (i['cost'] as double),
                              }).toList(),
                            };

                            setState(() {
                              _purchaseOrders.insert(0, newPO);
                            });
                            _persistPOs();
                            Navigator.pop(ctx);
                            PurchaseOrderPdfService.showPdfPreviewDialog(
                              context: context,
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                              po: newPO,
                            );
                          },
                          icon: const Icon(LucideIcons.printer, size: 15, color: AppColors.primary),
                          label: const Text('ISSUE & PRINT / SAVE PDF', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: () {
                            final poNumber = 'PO-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${_purchaseOrders.length + 1}';
                            final newPO = {
                              'id': poNumber,
                              'supplierName': supplierController.text.trim().isNotEmpty ? supplierController.text.trim() : 'Vendor Supplier',
                              'date': '${DateTime.now().day.toString().padLeft(2, '0')} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}',
                              'expectedDate': expectedDateController.text.trim(),
                              'status': 'ISSUED',
                              'totalKES': orderTotal,
                              'items': poItems.map((i) => {
                                'sku': i['sku'],
                                'name': i['name'],
                                'qtyOrdered': i['qty'],
                                'unitCost': i['cost'],
                                'total': (i['qty'] as int) * (i['cost'] as double),
                              }).toList(),
                            };

                            setState(() {
                              _purchaseOrders.insert(0, newPO);
                            });
                            _persistPOs();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Purchase Order "$poNumber" created!'), backgroundColor: AppColors.success),
                            );
                          },
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text('ISSUE PO'),
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
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return 'Sep';
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    _purchaseOrders.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      final sup = (e['supplierName'] ?? '').toString().toLowerCase();
      return id.startsWith('PO-2026090') || sup.contains('brookside') || sup.contains('pembe') || sup.contains('pwani');
    });

    final filtered = _purchaseOrders.where((po) {
      final matchesQuery = po['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          po['supplierName'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatusFilter == 'all' || po['status'] == _selectedStatusFilter;
      return matchesQuery && matchesStatus;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls
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
                      hintText: 'Search POs by PO number, supplier...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: _selectedStatusFilter,
                  dropdownColor: AppColors.card(context),
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'ISSUED', child: Text('Issued / Pending')),
                    DropdownMenuItem(value: 'PARTIALLY_RECEIVED', child: Text('Partially Received')),
                    DropdownMenuItem(value: 'FULFILLED', child: Text('Fulfilled / Complete')),
                  ],
                  onChanged: (val) => setState(() => _selectedStatusFilter = val!),
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
              onPressed: _openCreatePoDialog,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Create Purchase Order'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // List
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
                  final po = filtered[index];
                  final status = po['status'] as String;

                  Color statusColor = AppColors.primary;
                  if (status == 'FULFILLED') statusColor = AppColors.success;
                  if (status == 'PARTIALLY_RECEIVED') statusColor = AppColors.warning;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Center(child: Icon(LucideIcons.fileSpreadsheet, color: statusColor, size: 18)),
                        ),
                        const SizedBox(width: 16),

                        // PO Info
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(po['id'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                              Text('Supplier: ${po['supplierName']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // Date & Total
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(Formatters.formatCurrency(po['totalKES'] as num), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                              Text('Created: ${po['date']} • Expected: ${po['expectedDate']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // PDF / Print Action
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onPressed: () {
                            PurchaseOrderPdfService.showPdfPreviewDialog(
                              context: context,
                              organizationName: widget.organizationName,
                              branchName: widget.branchName,
                              po: po,
                            );
                          },
                          icon: const Icon(LucideIcons.printer, size: 14, color: AppColors.primary),
                          label: const Text('PDF / Print', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),

                        // Load into GRN
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          onPressed: () {
                            widget.onLoadPoIntoGrn?.call(po);
                          },
                          icon: const Icon(LucideIcons.packagePlus, size: 14),
                          label: const Text('Load into GRN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
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
