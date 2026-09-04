import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../services/grn_pdf_service.dart';

class GrnReceivingView extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final List<Map<String, dynamic>> catalog;
  final Function(Map<String, dynamic> updatedProduct)? onInventoryChanged;
  final Map<String, dynamic>? initialLoadedPo;

  const GrnReceivingView({
    super.key,
    required this.branchName,
    this.organizationName = 'GIFTMART SUPERMARKET',
    required this.catalog,
    this.onInventoryChanged,
    this.initialLoadedPo,
  });

  @override
  State<GrnReceivingView> createState() => _GrnReceivingViewState();
}

class _GrnReceivingViewState extends State<GrnReceivingView> {
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _deliveryNoteController = TextEditingController();
  final _barcodeInputController = TextEditingController();
  final _manualQtyController = TextEditingController(text: '1');
  final _unitCostController = TextEditingController();
  final _batchExpiryController = TextEditingController();
  final _remarksController = TextEditingController();
  final _scanFocusNode = FocusNode();

  bool _isScannerMode = true; // true = Rapid Scanner, false = Manual Batch Entry
  Map<String, dynamic>? _selectedParentProduct;
  List<Map<String, dynamic>> _currentSessionItems = [];
  List<Map<String, dynamic>> _centralWarehouseDispatches = [];
  List<String> _registeredSupplierNames = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadWarehouseDispatches();
    if (widget.catalog.isNotEmpty) {
      _selectParentProduct(widget.catalog.first);
    }
    if (widget.initialLoadedPo != null) {
      _loadFromPo(widget.initialLoadedPo!);
    }
  }

  Future<void> _loadSuppliers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_suppliers_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        setState(() {
          _registeredSupplierNames = decoded
              .map((e) => (e['name'] ?? '').toString())
              .where((name) => name.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {}
  }

  void _selectParentProduct(Map<String, dynamic> product) {
    setState(() {
      _selectedParentProduct = product;
      _unitCostController.text = (product['cost'] as num).toDouble().toStringAsFixed(2);
    });
  }

  Future<void> _loadWarehouseDispatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_warehouse_dispatches_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              return !id.startsWith('DN-CW-2026090');
            })
            .toList();
        setState(() {
          _centralWarehouseDispatches = filtered;
        });
        await _persistWarehouseDispatches();
      } else {
        setState(() {
          _centralWarehouseDispatches = [];
        });
      }
    } catch (_) {
      setState(() {
        _centralWarehouseDispatches = [];
      });
    }
  }

  Future<void> _persistWarehouseDispatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_warehouse_dispatches_${widget.branchName}', jsonEncode(_centralWarehouseDispatches));
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant GrnReceivingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialLoadedPo != null && widget.initialLoadedPo != oldWidget.initialLoadedPo) {
      _loadFromPo(widget.initialLoadedPo!);
    }
    if (_selectedParentProduct == null && widget.catalog.isNotEmpty) {
      _selectParentProduct(widget.catalog.first);
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _invoiceController.dispose();
    _deliveryNoteController.dispose();
    _barcodeInputController.dispose();
    _manualQtyController.dispose();
    _unitCostController.dispose();
    _batchExpiryController.dispose();
    _remarksController.dispose();
    _scanFocusNode.dispose();
    super.dispose();
  }

  void _loadFromPo(Map<String, dynamic> po) {
    setState(() {
      _supplierController.text = po['supplierName'] ?? '';
      _invoiceController.text = 'INV-PO-${po['id'].toString().replaceAll(RegExp(r'[^0-9]'), '')}';
      _deliveryNoteController.text = 'DN-${po['id']}';
      _currentSessionItems = (po['items'] as List<dynamic>).map((i) {
        return {
          'sku': i['sku'],
          'name': i['name'],
          'barcode': widget.catalog.firstWhere((p) => p['sku'] == i['sku'], orElse: () => {'barcode': '6161100000000'})['barcode'],
          'qtyReceived': i['qtyOrdered'] ?? 1,
          'cost': i['unitCost'] ?? 50.0,
          'batch': 'PO Intake',
        };
      }).toList();
    });
  }

  void _addUnitsToParentProduct(int qtyToAdd) {
    if (_selectedParentProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or search a target parent product first.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    final prod = _selectedParentProduct!;
    final cost = double.tryParse(_unitCostController.text) ?? (prod['cost'] as num).toDouble();
    final batch = _batchExpiryController.text.trim();

    setState(() {
      final existingIdx = _currentSessionItems.indexWhere((i) => i['sku'] == prod['sku']);
      if (existingIdx != -1) {
        _currentSessionItems[existingIdx]['qtyReceived'] = (_currentSessionItems[existingIdx]['qtyReceived'] as int) + qtyToAdd;
        _currentSessionItems[existingIdx]['cost'] = cost;
        if (batch.isNotEmpty) {
          _currentSessionItems[existingIdx]['batch'] = batch;
        }
      } else {
        _currentSessionItems.add({
          'sku': prod['sku'],
          'name': prod['name'],
          'barcode': prod['barcode'],
          'qtyReceived': qtyToAdd,
          'cost': cost,
          'unit': prod['unit'] ?? 'PCS',
          'batch': batch.isNotEmpty ? batch : 'Standard',
        });
      }
    });

    _scanFocusNode.requestFocus();
  }

  void _handleBarcodeScan(String input) {
    final query = input.trim();
    if (query.isEmpty) return;

    // Check if barcode matches the currently selected parent product
    if (_selectedParentProduct != null &&
        (_selectedParentProduct!['barcode'].toString() == query ||
            _selectedParentProduct!['sku'].toString().toLowerCase() == query.toLowerCase())) {
      _addUnitsToParentProduct(1);
      _barcodeInputController.clear();
      _scanFocusNode.requestFocus();
      return;
    }

    // Otherwise find if another product in catalog matches this barcode
    final matched = widget.catalog.where((item) =>
        (item['barcode'] ?? '').toString() == query ||
        (item['sku'] ?? '').toString().toLowerCase() == query.toLowerCase() ||
        (item['name'] ?? '').toString().toLowerCase().contains(query.toLowerCase())).toList();

    if (matched.isNotEmpty) {
      final product = matched.first;
      _selectParentProduct(product);
      _addUnitsToParentProduct(1);
      _barcodeInputController.clear();
      _scanFocusNode.requestFocus();
    } else {
      // If parent is selected, let user receive unit under parent with individual scanned serial/barcode
      if (_selectedParentProduct != null) {
        _addUnitsToParentProduct(1);
        _barcodeInputController.clear();
        _scanFocusNode.requestFocus();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unrecognized Item / Barcode: "$query". Register product in master catalog first.'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
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

  void _postReceiptSession() {
    if (_currentSessionItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items in current receiving session.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    int totalUnits = 0;
    double totalValue = 0;

    for (var item in _currentSessionItems) {
      final sku = item['sku'] as String;
      final qty = item['qtyReceived'] as int;
      final cost = (item['cost'] as num).toDouble();

      totalUnits += qty;
      totalValue += qty * cost;

      final catItem = widget.catalog.firstWhere((p) => p['sku'] == sku, orElse: () => {});
      if (catItem.isNotEmpty) {
        catItem['stock'] = (catItem['stock'] as num).toDouble() + qty;
        catItem['cost'] = cost;
        catItem['lastReceived'] = 'Today (${_invoiceController.text.isNotEmpty ? _invoiceController.text : "GRN Intake"})';
        widget.onInventoryChanged?.call(catItem);
      }
    }

    final grnNumber = 'GRN-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final newGrn = {
      'id': grnNumber,
      'grnNumber': grnNumber,
      'date': '${DateTime.now().day.toString().padLeft(2, '0')} Sep ${DateTime.now().year}',
      'deliveryNoteNumber': _deliveryNoteController.text.trim().isNotEmpty ? _deliveryNoteController.text.trim() : 'DN-STD',
      'deliveryDate': 'Today',
      'carrierDriverName': 'Supplier Delivery Driver',
      'supplierName': _supplierController.text.trim().isNotEmpty ? _supplierController.text.trim() : 'Vendor / Distributor',
      'supplierAddress': 'Industrial Area, Regional Depot',
      'supplierContact': '+254 700 000 000',
      'receivedByName': 'Stock Manager (STOREKEEPER)',
      'receivingDepartment': 'Main Receiving Bay - ${widget.branchName}',
      'condition': 'Good Condition - Seal Verified & Inspected',
      'comments': _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : 'Standard Intake verified against delivery note.',
      'totalAmount': totalValue,
      'status': 'POSTED',
      'items': List<Map<String, dynamic>>.from(_currentSessionItems),
    };

    _saveGrnRecord(newGrn);

    setState(() {
      _currentSessionItems.clear();
      _supplierController.clear();
      _invoiceController.clear();
      _deliveryNoteController.clear();
      _remarksController.clear();
      _batchExpiryController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('GRN Receipt Posted! +$totalUnits units received (${Formatters.formatCurrency(totalValue)}) into ${widget.branchName} stock.'),
        backgroundColor: AppColors.success,
      ),
    );

    // Prompt and display GRN PDF Dialog for printing / saving
    GrnPdfService.showPdfPreviewDialog(
      context: context,
      organizationName: widget.organizationName,
      branchName: widget.branchName,
      grn: newGrn,
    );
  }

  void _loadDispatchIntoIntake(Map<String, dynamic> dispatch) {
    setState(() {
      _supplierController.text = dispatch['source'] ?? 'Central Warehouse (Main Hub)';
      _invoiceController.text = 'INV-CW-${dispatch['id'].toString().replaceAll(RegExp(r'[^0-9]'), '')}';
      _deliveryNoteController.text = dispatch['id'] ?? 'DN-CW';
      _currentSessionItems = (dispatch['items'] as List<dynamic>).map((i) {
        final sku = i['sku'];
        final catItem = widget.catalog.firstWhere((p) => p['sku'] == sku, orElse: () => {});
        return {
          'sku': sku,
          'name': i['name'] ?? catItem['name'] ?? 'Warehouse Product',
          'barcode': i['barcode'] ?? catItem['barcode'] ?? '6161100000000',
          'qtyReceived': i['qty'] ?? 24,
          'cost': catItem.isNotEmpty ? (catItem['cost'] as num).toDouble() : 50.0,
          'unit': i['unit'] ?? catItem['unit'] ?? 'PCS',
        };
      }).toList();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loaded ${dispatch['id']} from ${dispatch['source']} into intake session!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openLoadWarehouseDispatchesDialog() {
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
            width: 800,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                            'SELECT & LOAD CENTRAL WAREHOUSE DISPATCH TO ${widget.branchName}',
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
                  child: _centralWarehouseDispatches.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.truck, size: 40, color: AppColors.textMuted(context)),
                                const SizedBox(height: 12),
                                Text(
                                  'No In-Transit Dispatches Found',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Dispatches from Central Warehouse or other branches will appear here when en route to ${widget.branchName}.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _centralWarehouseDispatches.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final disp = _centralWarehouseDispatches[index];
                            final items = (disp['items'] as List<dynamic>?) ?? [];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(LucideIcons.packageCheck, color: AppColors.primary, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          disp['id'] as String,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                                        ),
                                        Text(
                                          'Dispatched from: ${disp['source']}',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    disp['status'] as String,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(LucideIcons.clock, size: 12, color: AppColors.textMuted(context)),
                                const SizedBox(width: 4),
                                Text('Date: ${disp['dispatchDate']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                                const SizedBox(width: 14),
                                Icon(LucideIcons.user, size: 12, color: AppColors.textMuted(context)),
                                const SizedBox(width: 4),
                                Text('Carrier: ${disp['driver']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border(context)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MANIFEST SUMMARY (${items.length} ITEMS):',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context)),
                                  ),
                                  const SizedBox(height: 4),
                                  ...items.map((i) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('• ${i['name']} (${i['sku']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        Text('+${i['qty']} ${i['unit']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary)),
                                      ],
                                    ),
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                                  onPressed: () {
                                    final exists = _centralWarehouseDispatches.any((d) => d['id'] == disp['id']);
                                    if (!exists) {
                                      setState(() {
                                        _centralWarehouseDispatches.insert(0, Map<String, dynamic>.from(disp));
                                      });
                                      _persistWarehouseDispatches();
                                    }
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Dispatch "${disp['id']}" loaded into In-Transit transfers.'), backgroundColor: AppColors.success),
                                    );
                                  },
                                  icon: const Icon(LucideIcons.listPlus, size: 14),
                                  label: const Text('Load into In-Transit List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                  onPressed: () {
                                    final exists = _centralWarehouseDispatches.any((d) => d['id'] == disp['id']);
                                    if (!exists) {
                                      setState(() {
                                        _centralWarehouseDispatches.insert(0, Map<String, dynamic>.from(disp));
                                      });
                                      _persistWarehouseDispatches();
                                    }
                                    _loadDispatchIntoIntake(disp);
                                    Navigator.pop(ctx);
                                  },
                                  icon: const Icon(LucideIcons.scanLine, size: 14),
                                  label: const Text('⚡ Load into Receiving Scanner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }



  void _receiveCentralDispatch(Map<String, dynamic> dispatch) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border(context), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.truck, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'INTAKE CENTRAL WAREHOUSE DISPATCH',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
            ),
          ],
        ),
        content: Text(
          'Confirm goods receipt for delivery note "${dispatch['id']}" from ${dispatch['source']}?\n\nThis will intake all items directly into ${widget.branchName} shelf stock.',
          style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13, height: 1.4),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () {
              double totalAmount = 0;
              List<Map<String, dynamic>> grnItems = [];

              for (var it in (dispatch['items'] as List<dynamic>)) {
                final sku = it['sku'];
                final qty = it['qty'] as int;
                final catItem = widget.catalog.firstWhere((p) => p['sku'] == sku, orElse: () => {});
                double unitCost = 50.0;
                if (catItem.isNotEmpty) {
                  unitCost = (catItem['cost'] as num).toDouble();
                  catItem['stock'] = (catItem['stock'] as num).toDouble() + qty;
                  catItem['lastReceived'] = 'Dispatched from Central Warehouse';
                  widget.onInventoryChanged?.call(catItem);
                }
                totalAmount += qty * unitCost;
                grnItems.add({
                  'sku': sku,
                  'name': it['name'] ?? catItem['name'] ?? 'Transfer Product',
                  'unit': it['unit'] ?? catItem['unit'] ?? 'PCS',
                  'qtyOrdered': qty,
                  'qtyReceived': qty,
                  'cost': unitCost,
                  'total': qty * unitCost,
                });
              }

              final grnNumber = 'GRN-CW-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
              final newGrn = {
                'id': grnNumber,
                'grnNumber': grnNumber,
                'date': '${DateTime.now().day.toString().padLeft(2, '0')} Sep ${DateTime.now().year}',
                'deliveryNoteNumber': dispatch['id'] ?? 'DN-CW',
                'deliveryDate': 'Today',
                'carrierDriverName': 'Central Logistics Fleet',
                'supplierName': dispatch['source'] ?? 'Central Warehouse (Main Hub)',
                'supplierAddress': 'Regional Central Distribution Hub',
                'supplierContact': '+254 700 999 888',
                'receivedByName': 'Stock Manager (STOREKEEPER)',
                'receivingDepartment': 'Warehouse Inflow Dock - ${widget.branchName}',
                'condition': 'Inspected & Counted - Packaging Intact',
                'comments': 'Central warehouse inter-branch transfer delivery note ${dispatch['id']}.',
                'totalAmount': totalAmount,
                'status': 'POSTED',
                'items': grnItems,
              };

              _saveGrnRecord(newGrn);

              setState(() {
                dispatch['status'] = 'RECEIVED';
              });

              _persistWarehouseDispatches();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Central Warehouse Dispatch "${dispatch['id']}" received successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );

              // Prompt and display GRN PDF Dialog for printing / saving
              GrnPdfService.showPdfPreviewDialog(
                context: context,
                organizationName: widget.organizationName,
                branchName: widget.branchName,
                grn: newGrn,
              );
            },
            icon: const Icon(LucideIcons.packageCheck, size: 16),
            label: const Text('CONFIRM RECEIPT'),
          ),
        ],
      ),
    );
  }

  void _viewDispatchManifest(Map<String, dynamic> dispatch) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border(context), width: 1.5)),
        child: Container(
          width: 620,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DISPATCH MANIFEST: ${dispatch['id']}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 18)),
                ],
              ),
              Text('Source: ${dispatch['source']} • Sent: ${dispatch['date']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 14),

              // Items table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: (dispatch['items'] as List<dynamic>).length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                  itemBuilder: (context, idx) {
                    final item = dispatch['items'][idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                              Text('SKU: ${item['sku']}', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary(context))),
                            ],
                          ),
                          Text(
                            '+${item['qty']} ${item['unit']}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddButton(String label, int qty) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      onPressed: () => _addUnitsToParentProduct(qty),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _centralWarehouseDispatches.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      return id.startsWith('DN-CW-2026090');
    });

    int totalScannedUnits = 0;
    int parentProductScannedUnits = 0;

    for (var it in _currentSessionItems) {
      totalScannedUnits += (it['qtyReceived'] as int);
      if (_selectedParentProduct != null && it['sku'] == _selectedParentProduct!['sku']) {
        parentProductScannedUnits = (it['qtyReceived'] as int);
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP HEADER ROW: SUPPLIER, INVOICE, DELIVERY NOTE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supplier Input & Load from PO
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _supplierController.text),
                      optionsBuilder: (TextEditingValue val) {
                        if (val.text.isEmpty) return _registeredSupplierNames;
                        return _registeredSupplierNames.where(
                          (s) => s.toLowerCase().contains(val.text.toLowerCase()),
                        );
                      },
                      onSelected: (String s) {
                        _supplierController.text = s;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        // Keep _supplierController in sync
                        controller.addListener(() {
                          _supplierController.text = controller.text;
                        });
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.search, size: 16),
                            hintText: 'Supplier Name (e.g. Local Distributor)',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Auto-load PO: Open Purchase Orders tab and click "Load into GRN".')),
                            );
                          },
                          icon: const Icon(LucideIcons.fileSpreadsheet, size: 12),
                          label: const Text('Load from PO', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Auto-load branch PO supplier & items',
                          style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Invoice #
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _invoiceController,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Invoice #',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Delivery Note
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _deliveryNoteController,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: 'Delivery Note (DN #)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // INTAKE ROW: PARENT ITEM LOCK + SCANNER/MANUAL CONTROLS (LEFT) & RECEIVING SESSION (RIGHT)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL: PARENT ITEM LOCK & MULTI-SCAN INTAKE
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STEP 1: PARENT PRODUCT SELECTOR & CURRENT LOCK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                                child: const Icon(LucideIcons.packageCheck, color: AppColors.primary, size: 14),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '01. SELECT TARGET ITEM TO INTAKE',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                              ),
                            ],
                          ),
                          if (_selectedParentProduct != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.card(context), borderRadius: BorderRadius.circular(3)),
                              child: Text(
                                'Shelf Stock: ${_selectedParentProduct!['stock']} ${_selectedParentProduct!['unit']}',
                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary(context)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Parent Product Autocomplete / Search Dropdown
                      if (widget.catalog.isNotEmpty)
                        Autocomplete<Map<String, dynamic>>(
                          displayStringForOption: (option) => '${option['name']} (${option['sku']})',
                          initialValue: _selectedParentProduct != null
                              ? TextEditingValue(text: '${_selectedParentProduct!['name']} (${_selectedParentProduct!['sku']})')
                              : null,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) return widget.catalog;
                            final q = textEditingValue.text.toLowerCase();
                            return widget.catalog.where((p) =>
                                (p['name'] as String).toLowerCase().contains(q) ||
                                (p['sku'] as String).toLowerCase().contains(q) ||
                                (p['barcode'] as String).contains(q));
                          },
                          onSelected: (Map<String, dynamic> selection) {
                            _selectParentProduct(selection);
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              decoration: InputDecoration(
                                hintText: 'Search target item by name, SKU or barcode...',
                                prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.primary),
                                suffixIcon: const Icon(LucideIcons.chevronDown, size: 16),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  width: 440,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border(context)),
                                  ),
                                  child: ListView.separated(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                                    itemBuilder: (context, index) {
                                      final opt = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        title: Text(opt['name'], style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                        subtitle: Text('SKU: ${opt['sku']} • Barcode: ${opt['barcode']} • Cost: KES ${opt['cost']}', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context))),
                                        onTap: () => onSelected(opt),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.packageOpen, size: 18, color: AppColors.textSecondary(context)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Master Catalog is currently empty. Scan a barcode to intake or register products under Master Inventory.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),

                      // STEP 2: INTAKE MODE SELECTOR (SCANNER vs MANUAL)
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isScannerMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isScannerMode ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_isScannerMode) const Icon(LucideIcons.check, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '⚡ Rapid Barcode Multi-Scan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _isScannerMode ? AppColors.primary : AppColors.textSecondary(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isScannerMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isScannerMode ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(LucideIcons.pencil, size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Manual Quantity Intake',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: !_isScannerMode ? AppColors.primary : AppColors.textSecondary(context),
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
                      const SizedBox(height: 12),

                      // STEP 3: ACTIVE INTAKE STREAM
                      if (_isScannerMode) ...[
                        // Barcode Scan Box
                        TextField(
                          controller: _barcodeInputController,
                          focusNode: _scanFocusNode,
                          onSubmitted: _handleBarcodeScan,
                          style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(LucideIcons.scanBarcode, size: 18, color: AppColors.primary),
                            hintText: 'Scan unit / bulk barcode (Continuous Multi-Scan)',
                            suffixIcon: IconButton(
                              icon: const Icon(LucideIcons.plus, color: AppColors.primary),
                              onPressed: () => _handleBarcodeScan(_barcodeInputController.text),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Quick Multiplier Buttons for Bulk Cartons / Crates
                        Row(
                          children: [
                            const Text('Bulk Add:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            _buildQuickAddButton('+1 Unit', 1),
                            const SizedBox(width: 4),
                            _buildQuickAddButton('+6 Pack', 6),
                            const SizedBox(width: 4),
                            _buildQuickAddButton('+12 Dozen', 12),
                            const SizedBox(width: 4),
                            _buildQuickAddButton('+24 Crate', 24),
                            const SizedBox(width: 4),
                            _buildQuickAddButton('+50 Carton', 50),
                          ],
                        ),
                      ] else ...[
                        // Manual Mode: Quantity, Unit Cost, and Batch Input
                        Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quantity *', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _manualQtyController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Unit Cost (KES)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _unitCostController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Batch / Expiry', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _batchExpiryController,
                                    style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. 12/2026',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () {
                            final qty = int.tryParse(_manualQtyController.text) ?? 1;
                            if (qty > 0) {
                              _addUnitsToParentProduct(qty);
                            }
                          },
                          icon: const Icon(LucideIcons.plus, size: 14),
                          label: const Text('Add Quantity to Receiving Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                      const SizedBox(height: 10),

                      // Remarks
                      TextField(
                        controller: _remarksController,
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Remarks / Pallet condition (optional)',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // RIGHT PANEL: LIVE RECEIVING SESSION TABLE
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receiving Session',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                '${_currentSessionItems.length} items • $totalScannedUnits total units scanned',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _postReceiptSession,
                            icon: const Icon(LucideIcons.save, size: 14),
                            label: const Text('Post Receipt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Session Items List
                      _currentSessionItems.isEmpty
                          ? Container(
                              height: 180,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.card(context),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'No items in receiving session yet.\nSelect target product and scan barcodes to intake units.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : Container(
                              constraints: const BoxConstraints(maxHeight: 210),
                              decoration: BoxDecoration(
                                color: AppColors.card(context),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.border(context)),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _currentSessionItems.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                                itemBuilder: (context, index) {
                                  final item = _currentSessionItems[index];
                                  final lineTotal = (item['qtyReceived'] as int) * (item['cost'] as double);

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${item['sku']} • ${item['batch'] ?? "Std"}',
                                                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary(context)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(LucideIcons.minus, size: 13),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setState(() {
                                                    if ((item['qtyReceived'] as int) > 1) {
                                                      item['qtyReceived'] = (item['qtyReceived'] as int) - 1;
                                                    } else {
                                                      _currentSessionItems.removeAt(index);
                                                    }
                                                  });
                                                },
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${item['qtyReceived']}',
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: 'monospace', fontSize: 12.5),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                icon: const Icon(LucideIcons.plus, size: 13),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () {
                                                  setState(() {
                                                    item['qtyReceived'] = (item['qtyReceived'] as int) + 1;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            Formatters.formatCurrency(lineTotal),
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(LucideIcons.trash2, size: 13, color: AppColors.danger),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => setState(() => _currentSessionItems.removeAt(index)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // BOTTOM SECTION: CENTRAL WAREHOUSE DISPATCHES (WAREHOUSE TRANSFERS IN-TRANSIT)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Central Warehouse Dispatches & In-Transit Transfers',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _openLoadWarehouseDispatchesDialog,
                icon: const Icon(LucideIcons.downloadCloud, size: 14),
                label: const Text('Load Central Warehouse Dispatches', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          _centralWarehouseDispatches.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    children: [
                      Icon(LucideIcons.truck, size: 30, color: AppColors.textMuted(context)),
                      const SizedBox(height: 6),
                      Text(
                        'No In-Transit Transfers from Central Warehouse',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Click "Load Central Warehouse Dispatches" to fetch active delivery notes and dispatches from Central Warehouse to ${widget.branchName}.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _centralWarehouseDispatches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final dispatch = _centralWarehouseDispatches[index];
                    final isReceived = dispatch['status'] == 'RECEIVED';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isReceived ? AppColors.success.withValues(alpha: 0.12) : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              LucideIcons.gitFork,
                              color: isReceived ? AppColors.success : AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Dispatch Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dispatch['id'] as String,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'From ${dispatch['source']} | ${dispatch['itemsCount'] ?? '${(dispatch['items'] as List).length} items'}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (!isReceived) ...[
                                      InkWell(
                                        onTap: () => _receiveCentralDispatch(dispatch),
                                        child: const Text(
                                          'Confirm & Intake',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      InkWell(
                                        onTap: () => _loadDispatchIntoIntake(dispatch),
                                        child: const Text(
                                          '⚡ Load to Scanner',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                    ] else ...[
                                      const Text(
                                        'Received',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.success),
                                      ),
                                      const SizedBox(width: 14),
                                    ],
                                    InkWell(
                                      onTap: () => _viewDispatchManifest(dispatch),
                                      child: Text(
                                        'View Manifest',
                                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isReceived ? AppColors.success.withValues(alpha: 0.12) : AppColors.card(context),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isReceived ? AppColors.success : AppColors.border(context)),
                            ),
                            child: Text(
                              isReceived ? 'RECEIVED' : 'IN_TRANSIT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: isReceived ? AppColors.success : AppColors.textSecondary(context),
                              ),
                            ),
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
