import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../services/grn_pdf_service.dart';

class BranchRequisitionsView extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final List<Map<String, dynamic>> catalog;
  final Function(Map<String, dynamic> updatedProduct)? onInventoryChanged;

  const BranchRequisitionsView({
    super.key,
    required this.branchName,
    this.organizationName = 'GIFTMART SUPERMARKET',
    required this.catalog,
    this.onInventoryChanged,
  });

  @override
  State<BranchRequisitionsView> createState() => _BranchRequisitionsViewState();
}

class _BranchRequisitionsViewState extends State<BranchRequisitionsView> {
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  List<Map<String, dynamic>> _requisitions = [];

  final List<String> _sourceHubs = [
    'Central Warehouse (Kyogong Main Hub)',
    'Nairobi Regional Distribution Centre',
    'Nakuru Main Supermarket Branch',
    'Eldoret Regional Hub',
    'Bomet Branch Store',
    'Kisumu Lakeside Depot',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequisitions();
  }

  Future<void> _loadRequisitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_requisitions_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              return !(id == 'STR-KER-20260903-8812' || id == 'STR-KER-20260901-4401');
            })
            .toList();
        setState(() {
          _requisitions = filtered;
        });
        await _persistRequisitions();
      } else {
        setState(() {
          _requisitions = [];
        });
      }
    } catch (_) {
      setState(() {
        _requisitions = [];
      });
    }
  }

  Future<void> _persistRequisitions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_requisitions_${widget.branchName}', jsonEncode(_requisitions));
    } catch (_) {}
  }

  void _openCreateRequisitionDialog() {
    String sourceHub = _sourceHubs.first;
    String urgency = 'Standard Urgency';
    DateTime requiredDate = DateTime.now().add(const Duration(days: 2));
    final requiredDateController = TextEditingController(
      text: '${requiredDate.day.toString().padLeft(2, '0')} Sep ${requiredDate.year}',
    );
    final notesController = TextEditingController();

    List<Map<String, dynamic>> reqItems = [];
    if (widget.catalog.isNotEmpty) {
      final first = widget.catalog.first;
      reqItems.add({
        'sku': first['sku'],
        'name': first['name'],
        'unit': first['unit'] ?? 'PCS',
        'qty': 50,
        'cost': (first['cost'] as num).toDouble(),
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double totalEst = 0;
          for (var it in reqItems) {
            totalEst += (it['qty'] as int) * (it['cost'] as double);
          }

          Future<void> pickReqDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: requiredDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 180)),
            );
            if (picked != null) {
              setDialogState(() {
                requiredDate = picked;
                requiredDateController.text =
                    '${picked.day.toString().padLeft(2, '0')} Sep ${picked.year}';
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
              width: 860,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
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
                            const Icon(LucideIcons.gitPullRequest, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'REQUEST STOCK FROM CENTRAL WAREHOUSE / BRANCH - ${widget.branchName}',
                              style: TextStyle(
                                fontSize: 13.5,
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
                              // Source Hub / Branch
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Source Central Warehouse / Branch *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Autocomplete<String>(
                                      initialValue: TextEditingValue(text: sourceHub),
                                      optionsBuilder: (TextEditingValue val) {
                                        if (val.text.isEmpty) return _sourceHubs;
                                        return _sourceHubs.where((h) => h.toLowerCase().contains(val.text.toLowerCase()));
                                      },
                                      onSelected: (val) => setDialogState(() => sourceHub = val),
                                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                          decoration: InputDecoration(
                                            prefixIcon: const Icon(LucideIcons.building2, size: 15, color: AppColors.primary),
                                            suffixIcon: const Icon(LucideIcons.chevronDown, size: 14),
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
                                            color: AppColors.card(context),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              width: 380,
                                              constraints: const BoxConstraints(maxHeight: 180),
                                              decoration: BoxDecoration(border: Border.all(color: AppColors.border(context))),
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

                              // Urgency
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Urgency Priority *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Autocomplete<String>(
                                      initialValue: TextEditingValue(text: urgency),
                                      optionsBuilder: (TextEditingValue val) {
                                        const urg = ['Standard Urgency', 'High Urgency (Weekend Peak)', 'Critical Stockout'];
                                        if (val.text.isEmpty) return urg;
                                        return urg.where((u) => u.toLowerCase().contains(val.text.toLowerCase()));
                                      },
                                      onSelected: (val) => setDialogState(() => urgency = val),
                                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                                        return TextField(
                                          controller: controller,
                                          focusNode: focusNode,
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                          decoration: InputDecoration(
                                            prefixIcon: const Icon(LucideIcons.alertTriangle, size: 15, color: AppColors.warning),
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
                                            color: AppColors.card(context),
                                            child: Container(
                                              width: 260,
                                              decoration: BoxDecoration(border: Border.all(color: AppColors.border(context))),
                                              child: ListView(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                children: options.map((opt) => ListTile(dense: true, title: Text(opt, style: const TextStyle(fontSize: 12)), onTap: () => onSelected(opt))).toList(),
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

                              // Required Date
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Required Delivery Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    InkWell(
                                      onTap: pickReqDate,
                                      child: TextField(
                                        controller: requiredDateController,
                                        readOnly: true,
                                        onTap: pickReqDate,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(LucideIcons.calendar, size: 15, color: AppColors.primary),
                                          isDense: true,
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

                          // Items Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'REQUISITION LINE ITEMS',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                                onPressed: () {
                                  if (widget.catalog.isNotEmpty) {
                                    final item = widget.catalog.first;
                                    setDialogState(() {
                                      reqItems.add({
                                        'sku': item['sku'],
                                        'name': item['name'],
                                        'unit': item['unit'] ?? 'PCS',
                                        'qty': 24,
                                        'cost': (item['cost'] as num).toDouble(),
                                      });
                                    });
                                  }
                                },
                                icon: const Icon(LucideIcons.plus, size: 14),
                                label: const Text('Add Product Line', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Items List
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border(context)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: reqItems.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                              itemBuilder: (context, index) {
                                final item = reqItems[index];
                                final lineTotal = (item['qty'] as int) * (item['cost'] as double);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      // Searchable Autocomplete Product Selector
                                      Expanded(
                                        flex: 6,
                                        child: Autocomplete<Map<String, dynamic>>(
                                          displayStringForOption: (opt) => '${opt['name']} (${opt['sku']})',
                                          initialValue: TextEditingValue(text: '${item['name']} (${item['sku']})'),
                                          optionsBuilder: (TextEditingValue val) {
                                            if (val.text.isEmpty) return widget.catalog;
                                            final q = val.text.toLowerCase();
                                            return widget.catalog.where((p) =>
                                                (p['name'] as String).toLowerCase().contains(q) ||
                                                (p['sku'] as String).toLowerCase().contains(q));
                                          },
                                          onSelected: (selected) {
                                            setDialogState(() {
                                              item['sku'] = selected['sku'];
                                              item['name'] = selected['name'];
                                              item['unit'] = selected['unit'] ?? 'PCS';
                                              item['cost'] = (selected['cost'] as num).toDouble();
                                            });
                                          },
                                          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                                            return TextField(
                                              controller: controller,
                                              focusNode: focusNode,
                                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                              decoration: InputDecoration(
                                                hintText: 'Search product to request...',
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
                                                color: AppColors.card(context),
                                                child: Container(
                                                  width: 380,
                                                  constraints: const BoxConstraints(maxHeight: 180),
                                                  decoration: BoxDecoration(border: Border.all(color: AppColors.border(context))),
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
                                                        subtitle: Text('SKU: ${opt['sku']} • Stock: ${opt['stock']} ${opt['unit']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
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

                                      // Qty
                                      SizedBox(
                                        width: 100,
                                        child: TextField(
                                          keyboardType: TextInputType.number,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            labelText: 'Qty (${item['unit']})',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                          ),
                                          controller: TextEditingController(text: item['qty'].toString()),
                                          onChanged: (val) => setDialogState(() => item['qty'] = int.tryParse(val) ?? 1),
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Line Total
                                      SizedBox(
                                        width: 110,
                                        child: Text(
                                          Formatters.formatCurrency(lineTotal),
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(LucideIcons.trash2, size: 15, color: AppColors.danger),
                                        onPressed: () {
                                          if (reqItems.length > 1) {
                                            setDialogState(() => reqItems.removeAt(index));
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Notes
                          TextField(
                            controller: notesController,
                            style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                            decoration: InputDecoration(
                              labelText: 'Requisition Reason / Justification Notes',
                              hintText: 'e.g. Replenishing high-velocity stock ahead of holiday weekend.',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
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
                                const Text('TOTAL ESTIMATED REQUISITION VALUE:', style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 11.5)),
                                Text(Formatters.formatCurrency(totalEst), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary, fontFamily: 'monospace')),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border(context)),

                  // Modal Actions
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
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () {
                            final reqNumber = 'STR-KER-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${_requisitions.length + 1}';
                            final newReq = {
                              'id': reqNumber,
                              'sourceHub': sourceHub,
                              'destBranch': widget.branchName,
                              'date': '${DateTime.now().day.toString().padLeft(2, '0')} Sep ${DateTime.now().year}',
                              'requiredDate': requiredDateController.text.trim(),
                              'urgency': urgency.toUpperCase().replaceAll(' ', '_'),
                              'status': 'PENDING_APPROVAL',
                              'deliveryNote': 'DN-PENDING',
                              'totalKES': totalEst,
                              'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : 'Stock replenishment request.',
                              'items': reqItems.map((i) => {
                                'sku': i['sku'],
                                'name': i['name'],
                                'unit': i['unit'],
                                'qty': i['qty'],
                                'cost': i['cost'],
                                'total': (i['qty'] as int) * (i['cost'] as double),
                              }).toList(),
                            };

                            setState(() {
                              _requisitions.insert(0, newReq);
                            });
                            _persistRequisitions();
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Stock Requisition "$reqNumber" submitted to $sourceHub!'), backgroundColor: AppColors.success),
                            );
                          },
                          icon: const Icon(LucideIcons.send, size: 15),
                          label: const Text('SUBMIT REQUISITION TO WAREHOUSE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
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

  void _receiveDispatchedTransfer(Map<String, dynamic> req) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border(context), width: 1.5)),
        title: Row(
          children: [
            const Icon(LucideIcons.truck, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'INTAKE BRANCH TRANSFER: ${req['id']}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Confirm goods intake for ${req['items'].length} product lines transferred from ${req['sourceHub']}?\n\nThis will intake stock directly into ${widget.branchName} store and generate a GRN document.',
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), height: 1.4),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () {
              double totalAmount = 0;
              List<Map<String, dynamic>> grnItems = [];

              for (var it in (req['items'] as List<dynamic>)) {
                final sku = it['sku'];
                final qty = it['qty'] as int;
                final catItem = widget.catalog.firstWhere((p) => p['sku'] == sku, orElse: () => {});
                double cost = (it['cost'] as num).toDouble();
                if (catItem.isNotEmpty) {
                  catItem['stock'] = (catItem['stock'] as num).toDouble() + qty;
                  catItem['lastReceived'] = 'Branch Transfer from ${req['sourceHub']}';
                  widget.onInventoryChanged?.call(catItem);
                }
                totalAmount += qty * cost;
                grnItems.add({
                  'sku': sku,
                  'name': it['name'],
                  'unit': it['unit'] ?? 'PCS',
                  'qtyOrdered': qty,
                  'qtyReceived': qty,
                  'cost': cost,
                  'total': qty * cost,
                });
              }

              setState(() {
                req['status'] = 'RECEIVED';
              });
              _persistRequisitions();

              // Record GRN
              final grnNumber = 'GRN-TR-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
              final newGrn = {
                'id': grnNumber,
                'grnNumber': grnNumber,
                'date': '${DateTime.now().day.toString().padLeft(2, '0')} Sep ${DateTime.now().year}',
                'deliveryNoteNumber': req['deliveryNote'] ?? 'DN-TR',
                'deliveryDate': 'Today',
                'carrierDriverName': 'Inter-Branch Transfer Fleet',
                'supplierName': req['sourceHub'],
                'supplierAddress': 'Regional Warehouse Depot',
                'supplierContact': '+254 700 999 888',
                'receivedByName': 'Stock Manager (STOREKEEPER)',
                'receivingDepartment': 'Main Receiving Bay - ${widget.branchName}',
                'condition': 'Good Condition - Transfer Inspected',
                'comments': 'Stock transferred per requisition ${req['id']}.',
                'totalAmount': totalAmount,
                'status': 'POSTED',
                'items': grnItems,
              };

              _saveGrnRecord(newGrn);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Transfer "${req['id']}" received into stock!'), backgroundColor: AppColors.success),
              );

              // Open GRN PDF
              GrnPdfService.showPdfPreviewDialog(
                context: context,
                organizationName: widget.organizationName,
                branchName: widget.branchName,
                grn: newGrn,
              );
            },
            icon: const Icon(LucideIcons.packageCheck, size: 16),
            label: const Text('CONFIRM INTAKE & PRINT GRN'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveGrnRecord(Map<String, dynamic> grn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_grns_${widget.branchName}');
      List<Map<String, dynamic>> list = [];
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        list = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      list.insert(0, grn);
      await prefs.setString('hirall_branch_grns_${widget.branchName}', jsonEncode(list));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    _requisitions.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      return id.startsWith('STR-KER-2026090');
    });

    double totalValuation = 0;
    int pendingCount = 0;
    int inTransitCount = 0;

    for (var req in _requisitions) {
      final status = req['status'];
      if (status == 'PENDING_APPROVAL') pendingCount++;
      if (status == 'IN_TRANSIT') inTransitCount++;
      totalValuation += (req['totalKES'] as num?)?.toDouble() ?? 0.0;
    }

    final filtered = _requisitions.where((req) {
      if (_selectedStatus != 'ALL' && req['status'] != _selectedStatus) return false;
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty) {
        final idMatch = req['id'].toString().toLowerCase().contains(q);
        final hubMatch = req['sourceHub'].toString().toLowerCase().contains(q);
        final noteMatch = (req['notes'] ?? '').toString().toLowerCase().contains(q);
        if (!idMatch && !hubMatch && !noteMatch) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ribbon Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border(context))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.gitPullRequest, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL REQUISITIONS', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text('${_requisitions.length} Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border(context))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.truck, color: AppColors.warning, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('IN-TRANSIT DISPATCHES', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text('$inTransitCount Shipments', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.warning)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: AppColors.surface(context), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border(context))),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.coins, color: Color(0xFF059669), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REQUISITION VALUATION', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text(Formatters.formatCurrency(totalValuation), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Controls Bar
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Search Requisition #, Central Hub, or Notes...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _openCreateRequisitionDialog,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Request Stock from Warehouse', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Requisitions Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.gitPullRequest, size: 42, color: AppColors.textMuted(context)),
                          const SizedBox(height: 10),
                          Text('No Stock Requisitions Found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 4),
                          Text('Click "Request Stock from Warehouse" to request items from Central Hub or branches.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                      itemBuilder: (context, index) {
                        final req = filtered[index];
                        final status = req['status'] as String;
                        final isInTransit = status == 'IN_TRANSIT';
                        final isReceived = status == 'RECEIVED';

                        Color badgeColor = AppColors.primary;
                        if (isInTransit) badgeColor = AppColors.warning;
                        if (isReceived) badgeColor = AppColors.success;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: Center(child: Icon(LucideIcons.gitPullRequest, color: badgeColor, size: 18)),
                              ),
                              const SizedBox(width: 16),

                              // Requisition Info
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(req['id'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                    Text('From: ${req['sourceHub']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                                  ],
                                ),
                              ),

                              // Date & Valuation
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(Formatters.formatCurrency(req['totalKES'] as num), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                    Text('Req Date: ${req['date']} • Delivery: ${req['requiredDate']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                                  ],
                                ),
                              ),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  status.replaceAll('_', ' '),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: badgeColor),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Action Buttons
                              if (isInTransit)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () => _receiveDispatchedTransfer(req),
                                  icon: const Icon(LucideIcons.packageCheck, size: 14),
                                  label: const Text('Receive & Intake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                )
                              else if (isReceived)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('COMPLETED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.success)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.card(context),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border(context)),
                                  ),
                                  child: const Text('Awaiting Dispatch', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
