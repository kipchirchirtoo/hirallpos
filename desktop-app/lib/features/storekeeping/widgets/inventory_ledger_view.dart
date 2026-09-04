import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class InventoryLedgerView extends StatefulWidget {
  final String branchName;
  final List<Map<String, dynamic>> catalog;
  final Function(Map<String, dynamic> updatedProduct)? onInventoryChanged;

  const InventoryLedgerView({
    super.key,
    required this.branchName,
    required this.catalog,
    this.onInventoryChanged,
  });

  @override
  State<InventoryLedgerView> createState() => _InventoryLedgerViewState();
}

class _InventoryLedgerViewState extends State<InventoryLedgerView> {
  String _selectedType = 'ALL';
  String _searchQuery = '';
  List<Map<String, dynamic>> _movements = [];

  @override
  void initState() {
    super.initState();
    _loadMovements();
  }

  Future<void> _loadMovements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_inventory_ledger_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              return !id.startsWith('MOV-998');
            })
            .toList();
        setState(() {
          _movements = filtered;
        });
        await _persistMovements();
      } else {
        setState(() {
          _movements = [];
        });
      }
    } catch (_) {
      setState(() {
        _movements = [];
      });
    }
  }

  Future<void> _persistMovements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_inventory_ledger_${widget.branchName}', jsonEncode(_movements));
    } catch (_) {}
  }

  void _openRecordSpoilageDialog() {
    if (widget.catalog.isEmpty) return;

    String selectedSku = widget.catalog.first['sku'];
    final qtyController = TextEditingController(text: '1');
    final reasonController = TextEditingController(text: 'Expired / Damaged Packaging');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border(context))),
          title: Row(
            children: [
              const Icon(LucideIcons.trash2, color: AppColors.danger, size: 20),
              const SizedBox(width: 10),
              Text(
                'RECORD SPOILAGE / DAMAGED STOCK',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select product to write off from branch stock:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (opt) => '${opt['name']} (${opt['stock']} avail)',
                initialValue: widget.catalog.isNotEmpty
                    ? TextEditingValue(text: '${widget.catalog.first['name']} (${widget.catalog.first['stock']} avail)')
                    : null,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return widget.catalog;
                  final q = textEditingValue.text.toLowerCase();
                  return widget.catalog.where((p) =>
                      (p['name'] as String).toLowerCase().contains(q) ||
                      (p['sku'] as String).toLowerCase().contains(q));
                },
                onSelected: (Map<String, dynamic> selected) {
                  setDialogState(() => selectedSku = selected['sku']);
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
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
                        width: 380,
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
                              subtitle: Text('SKU: ${opt['sku']} • Available Stock: ${opt['stock']} ${opt['unit']}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
                              onTap: () => onSelected(opt),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Spoiled Quantity', hintText: 'e.g. 2'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason for Write-Off', hintText: 'e.g. Expired seal'),
              ),
            ],
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                final qty = int.tryParse(qtyController.text) ?? 1;
                final prod = widget.catalog.firstWhere((p) => p['sku'] == selectedSku);
                setState(() {
                  prod['stock'] = (prod['stock'] as num).toDouble() - qty;
                  _movements.insert(0, {
                    'id': 'MOV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                    'type': 'SPOILAGE',
                    'sku': selectedSku,
                    'productName': prod['name'],
                    'qty': -qty,
                    'unit': prod['unit'],
                    'ref': reasonController.text.trim(),
                    'timestamp': 'Just now',
                    'user': 'Stock Manager (STOREKEEPER)',
                  });
                });
                _persistMovements();

                widget.onInventoryChanged?.call(prod);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Written off -$qty units of ${prod['name']}.'), backgroundColor: AppColors.warning),
                );
              },
              child: const Text('CONFIRM WRITE-OFF'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _movements.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      return id.startsWith('MOV-998');
    });

    final filtered = _movements.where((m) {
      final matchesSearch = m['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m['productName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m['ref'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedType == 'ALL' || m['type'] == _selectedType;
      return matchesSearch && matchesType;
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
                      hintText: 'Search movements by SKU, product, reference...',
                      prefixIcon: const Icon(LucideIcons.search, size: 16),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                DropdownButton<String>(
                  value: _selectedType,
                  dropdownColor: AppColors.card(context),
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('All Movement Types')),
                    DropdownMenuItem(value: 'GRN_IN', child: Text('Goods Intake (GRN)')),
                    DropdownMenuItem(value: 'TRANSFER_IN', child: Text('Central Transfer In')),
                    DropdownMenuItem(value: 'TRANSFER_OUT', child: Text('Branch Transfer Out')),
                    DropdownMenuItem(value: 'STOCKTAKE_ADJ', child: Text('Stocktake Adjustments')),
                    DropdownMenuItem(value: 'POS_SALE', child: Text('POS Till Sales')),
                    DropdownMenuItem(value: 'SPOILAGE', child: Text('Spoilage & Damaged')),
                  ],
                  onChanged: (val) => setState(() => _selectedType = val!),
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _openRecordSpoilageDialog,
              icon: const Icon(LucideIcons.trash2, size: 16),
              label: const Text('Record Spoilage'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Movements Table
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
                          Icon(LucideIcons.history, size: 40, color: AppColors.textSecondary(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No Stock Movements Recorded',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context)),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Stock receipts (GRNs), transfers, sales, and adjustments will be tracked automatically here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                itemBuilder: (context, index) {
                  final m = filtered[index];
                  final qty = m['qty'] as int;
                  final isPositive = qty > 0;

                  Color typeColor = AppColors.primary;
                  if (m['type'] == 'GRN_IN' || m['type'] == 'TRANSFER_IN') typeColor = AppColors.success;
                  if (m['type'] == 'SPOILAGE') typeColor = AppColors.danger;
                  if (m['type'] == 'TRANSFER_OUT') typeColor = AppColors.warning;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        // Timestamp
                        SizedBox(
                          width: 130,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['timestamp'], style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                              Text(m['id'], style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // Movement Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            m['type'],
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: typeColor),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Item & Reference
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['productName'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                              Text('SKU: ${m['sku']} • Ref: ${m['ref']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // Signed By User
                        Expanded(
                          flex: 3,
                          child: Text(
                            m['user'],
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                          ),
                        ),

                        // Qty Change
                        Text(
                          '${isPositive ? "+" : ""}$qty ${m['unit']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: isPositive ? AppColors.success : (m['type'] == 'SPOILAGE' ? AppColors.danger : AppColors.textPrimary(context)),
                          ),
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
