import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class AdminStockMovementsView extends StatefulWidget {
  final String organizationName;
  final String branchName;

  const AdminStockMovementsView({
    super.key,
    required this.organizationName,
    required this.branchName,
  });

  @override
  State<AdminStockMovementsView> createState() => _AdminStockMovementsViewState();
}

class _AdminStockMovementsViewState extends State<AdminStockMovementsView> {
  String _selectedMovementFilter = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _catalog = [];

  @override
  void initState() {
    super.initState();
    _loadPersistedMovements();
  }

  Future<void> _loadPersistedMovements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catJson = prefs.getString('hirall_branch_catalog_${widget.branchName}');
      if (catJson != null && catJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(catJson);
        _catalog = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _catalog = [];
      }

      final saved = prefs.getString('hirall_inventory_ledger_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        setState(() {
          _movements = decoded.map((e) => Map<String, dynamic>.from(e)).where((m) {
            final id = (m['id'] ?? '').toString();
            final sku = (m['sku'] ?? '').toString();
            return !id.startsWith('MOV-998') && !id.startsWith('mov-00') && !sku.startsWith('GM-');
          }).toList();
        });
      } else {
        setState(() => _movements = []);
      }
    } catch (_) {
      setState(() {
        _movements = [];
        _catalog = [];
      });
    }
  }

  void _openStockAdjustmentDialog() {
    final skuController = TextEditingController(text: 'BRK-500ML');
    final qtyController = TextEditingController();
    final reasonController = TextEditingController(text: 'Damaged / Spoilage');
    final notesController = TextEditingController();
    bool isAddition = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.border(context)),
          ),
          child: Container(
            width: 520,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(LucideIcons.boxes, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Stock Adjustment',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                              Text(
                                'Stock audit, damage write-off or return for ${widget.branchName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context)),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adjustment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => isAddition = false),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: !isAddition ? AppColors.danger.withValues(alpha: 0.15) : AppColors.card(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: !isAddition ? AppColors.danger : AppColors.border(context)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.minusCircle, size: 16, color: !isAddition ? AppColors.danger : AppColors.textSecondary(context)),
                                      const SizedBox(width: 8),
                                      Text('Deduct / Write-Off (-)', style: TextStyle(fontWeight: FontWeight.w700, color: !isAddition ? AppColors.danger : AppColors.textPrimary(context))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () => setDialogState(() => isAddition = true),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isAddition ? AppColors.success.withValues(alpha: 0.15) : AppColors.card(context),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: isAddition ? AppColors.success : AppColors.border(context)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.plusCircle, size: 16, color: isAddition ? AppColors.success : AppColors.textSecondary(context)),
                                      const SizedBox(width: 8),
                                      Text('Add / Recount Surplus (+)', style: TextStyle(fontWeight: FontWeight.w700, color: isAddition ? AppColors.success : AppColors.textPrimary(context))),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text('Product SKU / Barcode *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: skuController,
                          style: TextStyle(color: AppColors.textPrimary(context)),
                          decoration: const InputDecoration(
                            hintText: 'e.g. BRK-500ML or 616110',
                            prefixIcon: Icon(LucideIcons.barcode, size: 16),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Adjustment Quantity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: qtyController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: AppColors.textPrimary(context)),
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. 5',
                                      prefixIcon: Icon(LucideIcons.hash, size: 16),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Reason Code *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: reasonController.text,
                                    isExpanded: true,
                                    dropdownColor: AppColors.surface(context),
                                    decoration: const InputDecoration(),
                                    items: const [
                                      DropdownMenuItem(value: 'Damaged / Spoilage', child: Text('Damaged / Broken')),
                                      DropdownMenuItem(value: 'Expired Stock', child: Text('Expired / Spoilage')),
                                      DropdownMenuItem(value: 'Audit Physical Count Correction', child: Text('Audit Recount')),
                                      DropdownMenuItem(value: 'Return to Supplier', child: Text('Vendor Return')),
                                    ],
                                    onChanged: (val) => setDialogState(() => reasonController.text = val!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text('Supervisor Notes & Authorization', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                        const SizedBox(height: 6),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          style: TextStyle(color: AppColors.textPrimary(context)),
                          decoration: const InputDecoration(
                            hintText: 'Enter reason details, incident reference, or authorization tag...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: AppColors.border(context)),

                // Footer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final qty = int.tryParse(qtyController.text) ?? 0;
                          if (qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a valid adjustment quantity.'), backgroundColor: AppColors.warning),
                            );
                            return;
                          }

                          setState(() {
                            _movements.insert(0, {
                              'id': 'mov-${_movements.length + 1}',
                              'timestamp': 'Just now',
                              'type': 'ADJUSTMENT',
                              'sku': skuController.text.trim(),
                              'productName': 'Brookside Dairy Best Whole Milk 500ml',
                              'delta': isAddition ? qty : -qty,
                              'resultingStock': 38 + (isAddition ? qty : -qty),
                              'staff': 'Store Administrator',
                              'notes': '${reasonController.text}: ${notesController.text.trim()}',
                            });
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Stock adjustment of ${isAddition ? "+$qty" : "-$qty"} recorded!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text('Commit Stock Adjustment'),
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

  Color _getMovementColor(String type) {
    switch (type) {
      case 'GRN_IN':
        return AppColors.success;
      case 'POS_SALE':
        return AppColors.primary;
      case 'TRANSFER_IN':
        return const Color(0xFF0EA5E9);
      case 'TRANSFER_OUT':
        return const Color(0xFF8B5CF6);
      case 'ADJUSTMENT':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  String _formatMovementType(String type) {
    switch (type) {
      case 'GRN_IN':
        return 'GRN INTAKE';
      case 'POS_SALE':
        return 'POS SALE';
      case 'TRANSFER_IN':
        return 'TRANSFER IN';
      case 'TRANSFER_OUT':
        return 'TRANSFER OUT';
      case 'ADJUSTMENT':
        return 'ADJUSTMENT';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    _movements.removeWhere((m) {
      final id = (m['id'] ?? '').toString();
      final sku = (m['sku'] ?? '').toString();
      final name = (m['productName'] ?? '').toString().toLowerCase();
      return id.startsWith('mov-00') ||
          id.startsWith('MOV-998') ||
          sku.startsWith('GM-') ||
          name.contains('brookside') ||
          name.contains('pembe') ||
          name.contains('fresh fri');
    });

    final totalSkus = _catalog.length;
    double stockCostValuation = 0;
    double expectedRetailValuation = 0;
    int lowStockCount = 0;

    for (var it in _catalog) {
      final stock = (it['stock'] as num?)?.toDouble() ?? 0.0;
      final cost = (it['cost'] as num?)?.toDouble() ?? 0.0;
      final price = (it['price'] as num?)?.toDouble() ?? 0.0;
      final reorder = (it['reorder'] as num?)?.toDouble() ?? 10.0;
      stockCostValuation += stock * cost;
      expectedRetailValuation += stock * price;
      if (stock <= reorder) lowStockCount++;
    }

    final filtered = _movements.where((m) {
      final matchesQuery = m['productName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m['sku'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m['notes'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesType = _selectedMovementFilter == 'all' || m['type'] == _selectedMovementFilter;
      return matchesQuery && matchesType;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Inventory Valuation Summary
        Row(
          children: [
            Expanded(
              child: _buildValuationCard(
                title: 'TOTAL ACTIVE CATALOG SKUS',
                value: '$totalSkus Master SKUs',
                subtitle: 'All Supermarket Categories',
                icon: LucideIcons.package,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildValuationCard(
                title: 'TOTAL STOCKROOM VALUATION',
                value: Formatters.formatCurrency(stockCostValuation),
                subtitle: 'Wholesale Cost Basis',
                icon: LucideIcons.calculator,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildValuationCard(
                title: 'EXPECTED RETAIL SALES',
                value: Formatters.formatCurrency(expectedRetailValuation),
                subtitle: 'Potential Shelf Revenue',
                icon: LucideIcons.trendingUp,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildValuationCard(
                title: 'LOW STOCK WARNINGS',
                value: '$lowStockCount SKUs Low',
                subtitle: 'Below reorder threshold',
                icon: LucideIcons.alertTriangle,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Controls
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  hintText: 'Search movement ledger by product name, SKU, or notes...',
                  prefixIcon: Icon(LucideIcons.search, size: 16),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _selectedMovementFilter,
                dropdownColor: AppColors.surface(context),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Movement Types')),
                  DropdownMenuItem(value: 'POS_SALE', child: Text('POS Till Sales')),
                  DropdownMenuItem(value: 'GRN_IN', child: Text('GRN Supplier Deliveries')),
                  DropdownMenuItem(value: 'TRANSFER_OUT', child: Text('Inter-Branch Dispatches')),
                  DropdownMenuItem(value: 'ADJUSTMENT', child: Text('Stock Adjustments')),
                ],
                onChanged: (val) => setState(() => _selectedMovementFilter = val!),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _openStockAdjustmentDialog,
              icon: const Icon(LucideIcons.plusCircle, size: 16),
              label: const Text('Record Stock Adjustment'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Movement Ledger Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.history, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text(
                            'No Stock Movements Logged Yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Movements will appear here automatically when items are received via GRN, sold at POS, or adjusted.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                itemBuilder: (context, index) {
                  final mov = filtered[index];
                  final color = _getMovementColor(mov['type'] as String);
                  final isPositive = (mov['delta'] as int) > 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        // Timestamp
                        SizedBox(
                          width: 120,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov['timestamp'] as String,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                mov['id'] as String,
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),

                        // Movement Type Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _formatMovementType(mov['type'] as String),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Product Details
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov['productName'] as String,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                'SKU: ${mov['sku']} • ${mov['notes']}',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),

                        // Quantity Change Delta
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPositive
                                ? AppColors.success.withValues(alpha: 0.12)
                                : AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isPositive ? "+" : ""}${mov['delta']} units',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isPositive ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Staff & Stock Remaining
                        SizedBox(
                          width: 160,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Stock: ${mov['resultingStock']} avail',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                mov['staff'] as String,
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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

  Widget _buildValuationCard({
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
        borderRadius: BorderRadius.circular(14),
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
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8),
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
}
