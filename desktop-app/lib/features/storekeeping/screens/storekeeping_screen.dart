import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../widgets/grn_receiving_view.dart';
import '../widgets/grn_history_view.dart';
import '../widgets/branch_requisitions_view.dart';
import '../widgets/suppliers_view.dart';
import '../widgets/purchase_orders_view.dart';
import '../widgets/stocktake_view.dart';
import '../widgets/inventory_ledger_view.dart';
import '../widgets/csv_product_import_dialog.dart';

class StorekeepingScreen extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final Function(Map<String, dynamic> updatedProduct)? onInventoryChanged;

  const StorekeepingScreen({
    super.key,
    this.branchName = 'KERICHO',
    this.organizationName = 'GIFTMART SUPERMARKET',
    this.onInventoryChanged,
  });

  @override
  State<StorekeepingScreen> createState() => _StorekeepingScreenState();
}

class _StorekeepingScreenState extends State<StorekeepingScreen> {
  String _selectedTab = 'grn'; // 'catalog', 'grn', 'pos', 'vendors', 'stocktake', 'ledger'
  Map<String, dynamic>? _loadedPoForGrn;

  final _searchController = TextEditingController();
  final _barcodeFocusNode = FocusNode();
  String _selectedFilter = 'all';
  String _selectedCategory = 'all';

  final List<String> _categories = [
    'Dairy',
    'Bakery',
    'Groceries & Grains',
    'Cooking Oils & Fats',
    'Beverages & Soft Drinks',
    'Meat & Deli',
    'Personal Care',
    'Household & Detergents',
    'Stationery & Books',
    'Snacks & Confectionery',
  ];

  List<Map<String, dynamic>> _supermarketCatalog = [];

  @override
  void initState() {
    super.initState();
    _loadPersistedCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPersistedCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('hirall_supermarket_catalog_${widget.branchName}');
      await prefs.remove('hirall_supermarket_catalog');

      final saved = prefs.getString('hirall_branch_catalog_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final sku = (e['sku'] ?? '').toString().toUpperCase();
              final id = (e['id'] ?? '').toString().toUpperCase();
              final name = (e['name'] ?? '').toString().toLowerCase();
              final isMock = sku.startsWith('GM-') ||
                  id.startsWith('PROD-00') ||
                  name.contains('brookside') ||
                  name.contains('pembe') ||
                  name.contains('fresh fri') ||
                  name.contains('broadway') ||
                  name.contains('kasuku');
              return !isMock;
            })
            .toList();
        setState(() {
          _supermarketCatalog = filtered;
        });
        await _persistCatalog();
      } else {
        setState(() {
          _supermarketCatalog = [];
        });
      }
    } catch (_) {
      setState(() {
        _supermarketCatalog = [];
      });
    }
  }

  Future<void> _persistCatalog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_catalog_${widget.branchName}', jsonEncode(_supermarketCatalog));
    } catch (_) {}
  }

  String _getOrgShortform(String orgName) {
    final clean = orgName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '');
    if (clean.isEmpty) return 'GS';
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    } else {
      final single = words[0].toUpperCase();
      return single.length >= 3 ? single.substring(0, 3) : single;
    }
  }

  String _getCategoryCode(String category) {
    final catUpper = category.trim().toUpperCase();
    if (catUpper.contains('DAIRY')) return 'DAIRY';
    if (catUpper.contains('BAKERY') || catUpper.contains('BREAD')) return 'BAK';
    if (catUpper.contains('GRAIN') || catUpper.contains('GROCER') || catUpper.contains('FLOUR')) return 'GRN';
    if (catUpper.contains('OIL') || catUpper.contains('FAT')) return 'OIL';
    if (catUpper.contains('BEV') || catUpper.contains('DRINK') || catUpper.contains('WATER')) return 'BEV';
    if (catUpper.contains('MEAT') || catUpper.contains('BUTCHER') || catUpper.contains('DELI')) return 'MEAT';
    if (catUpper.contains('CARE') || catUpper.contains('BEAUTY') || catUpper.contains('SOAP')) return 'CARE';
    if (catUpper.contains('CLEAN') || catUpper.contains('HOUSE') || catUpper.contains('DETERGENT')) return 'CLN';
    if (catUpper.contains('STAT') || catUpper.contains('BOOK') || catUpper.contains('PEN')) return 'STAT';
    if (catUpper.contains('SNACK') || catUpper.contains('CANDY')) return 'SNCK';

    final sanitized = catUpper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return sanitized.length >= 4 ? sanitized.substring(0, 4) : (sanitized.isNotEmpty ? sanitized : 'GEN');
  }

  String _generateUniqueSku({
    required String orgName,
    required String category,
  }) {
    final orgShort = _getOrgShortform(orgName);
    final catCode = _getCategoryCode(category);
    final prefix = '$orgShort-$catCode';

    for (int attempts = 0; attempts < 1000; attempts++) {
      final rand = (1000 + Random().nextInt(8999)).toString();
      final candidateSku = '$prefix-$rand';

      final exists = _supermarketCatalog.any((item) =>
          (item['sku'] ?? '').toString().trim().toUpperCase() == candidateSku);

      if (!exists) {
        return candidateSku;
      }
    }

    return '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}';
  }

  void _openCsvImportDialog() {
    CsvProductImportDialog.show(
      context: context,
      branchName: widget.branchName,
      organizationName: widget.organizationName,
      existingCatalog: _supermarketCatalog,
      onImport: (importedProducts) {
        setState(() {
          for (var p in importedProducts) {
            final idx = _supermarketCatalog.indexWhere((item) => item['barcode'] == p['barcode']);
            if (idx != -1) {
              _supermarketCatalog[idx] = p;
            } else {
              _supermarketCatalog.insert(0, p);
            }
          }
        });
        _persistCatalog();
      },
    );
  }

  void _openRegisterProductDialog({String initialBarcode = ''}) {
    final nameController = TextEditingController();
    String selectedCategory = _categories.first;
    
    final initialSku = _generateUniqueSku(
      orgName: widget.organizationName,
      category: selectedCategory,
    );
    final skuController = TextEditingController(text: initialSku);
    final barcodeController = TextEditingController(text: initialBarcode);
    final costController = TextEditingController();
    final priceController = TextEditingController();
    final reorderController = TextEditingController(text: '15');
    final initialStockController = TextEditingController(text: '24');
    final shelfController = TextEditingController(text: 'Aisle 1');
    final supplierController = TextEditingController();
    
    String selectedUnit = 'PCS';
    double taxRate = 16.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cost = double.tryParse(costController.text) ?? 0.0;
          final price = double.tryParse(priceController.text) ?? 0.0;
          final profit = price - cost;
          final marginPct = cost > 0 ? (profit / cost) * 100 : 0.0;

          return Dialog(
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppColors.border(context), width: 1.5),
            ),
            child: Container(
              width: 960,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      border: Border(bottom: BorderSide(color: AppColors.border(context), width: 1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: List.generate(
                                4,
                                (i) => Container(
                                  width: 3.5,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Screen Painter: Master Product & Barcode Registration - ${widget.branchName}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _openCsvImportDialog();
                              },
                              icon: const Icon(LucideIcons.fileSpreadsheet, size: 14, color: AppColors.primary),
                              label: const Text('Bulk CSV Import', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary(context)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '01. PRODUCT IDENTIFICATION & SKU MAPPING',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          color: AppColors.primary,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Divider(height: 1, color: AppColors.border(context)),
                                      const SizedBox(height: 16),

                                      _buildStackedLabel('Product Name *'),
                                      TextField(
                                        controller: nameController,
                                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                        decoration: _buildModernInputDecoration(hint: 'e.g. KASUKU EXERCISE BOOK 96PAGES'),
                                      ),
                                      const SizedBox(height: 16),

                                      _buildStackedLabel('Category * (Type to Search or Select)'),
                                      Autocomplete<String>(
                                        initialValue: TextEditingValue(text: selectedCategory),
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) return _categories;
                                          return _categories.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                        },
                                        onSelected: (String selection) {
                                          setDialogState(() {
                                            selectedCategory = selection;
                                            skuController.text = _generateUniqueSku(
                                              orgName: widget.organizationName,
                                              category: selectedCategory,
                                            );
                                          });
                                        },
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          return TextField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                            decoration: InputDecoration(
                                              hintText: 'Search category...',
                                              prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppColors.primary),
                                              suffixIcon: const Icon(LucideIcons.chevronDown, size: 16),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onChanged: (val) {
                                              if (val.trim().isNotEmpty) {
                                                selectedCategory = val.trim();
                                                skuController.text = _generateUniqueSku(
                                                  orgName: widget.organizationName,
                                                  category: selectedCategory,
                                                );
                                              }
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
                                                width: 400,
                                                constraints: const BoxConstraints(maxHeight: 220),
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
                                                      title: Text(opt, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                                                      hoverColor: AppColors.primary.withValues(alpha: 0.1),
                                                      onTap: () => onSelected(opt),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _buildStackedLabel('SKU Code *'),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                TextField(
                                                  controller: skuController,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    fontFamily: 'monospace',
                                                    color: AppColors.primary,
                                                  ),
                                                  decoration: _buildModernInputDecoration(hint: 'e.g. GS-DAIRY-5481'),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Format: [ORG]-[CAT]-[4-DIGITS]',
                                                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textSecondary(context)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                            ),
                                            onPressed: () {
                                              final newSku = _generateUniqueSku(
                                                orgName: widget.organizationName,
                                                category: selectedCategory,
                                              );
                                              setDialogState(() {
                                                skuController.text = newSku;
                                              });
                                            },
                                            icon: const Icon(LucideIcons.dices, size: 16),
                                            label: const Text('AUTO-GEN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      _buildStackedLabel('Barcode / EAN *'),
                                      TextField(
                                        controller: barcodeController,
                                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                                        decoration: _buildModernInputDecoration(hint: 'e.g. 6161101536592'),
                                      ),
                                      const SizedBox(height: 16),

                                      _buildStackedLabel('Unit of Measure (Type or Search)'),
                                      Autocomplete<String>(
                                        initialValue: TextEditingValue(text: selectedUnit),
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          const units = ['PCS', 'PACK', 'KG', 'BOTTLE', 'CRATE', 'BOX', 'TIN', 'LITRE', 'DOZEN'];
                                          if (textEditingValue.text.isEmpty) return units;
                                          return units.where((u) => u.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                        },
                                        onSelected: (String val) => setDialogState(() => selectedUnit = val),
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          return TextField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                                            decoration: InputDecoration(
                                              hintText: 'Search unit (e.g. PCS, PACK, KG)...',
                                              prefixIcon: const Icon(LucideIcons.search, size: 14, color: AppColors.primary),
                                              suffixIcon: const Icon(LucideIcons.chevronDown, size: 14),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                            ),
                                            onChanged: (val) {
                                              if (val.trim().isNotEmpty) selectedUnit = val.trim();
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
                                                width: 300,
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
                              ),
                              const SizedBox(width: 18),

                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface(context),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border(context)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '02. PRICING, MARGIN & SHELF INVENTORY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'monospace',
                                          color: AppColors.primary,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Divider(height: 1, color: AppColors.border(context)),
                                      const SizedBox(height: 16),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildStackedLabel('Cost Price (KES) *'),
                                                TextField(
                                                  controller: costController,
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                                  onChanged: (_) => setDialogState(() {}),
                                                  decoration: _buildModernInputDecoration(hint: '50.00'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildStackedLabel('Retail Price (KES) *'),
                                                TextField(
                                                  controller: priceController,
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                                  onChanged: (_) => setDialogState(() {}),
                                                  decoration: _buildModernInputDecoration(hint: '65.00'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: profit >= 0 ? AppColors.success.withValues(alpha: 0.12) : AppColors.danger.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: profit >= 0 ? AppColors.success : AppColors.danger),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Margin: ${Formatters.formatCurrency(profit)} (${marginPct.toStringAsFixed(1)}%)',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                fontFamily: 'monospace',
                                                color: profit >= 0 ? AppColors.success : AppColors.danger,
                                              ),
                                            ),
                                            DropdownButton<double>(
                                              value: taxRate,
                                              dropdownColor: AppColors.card(context),
                                              underline: const SizedBox(),
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                              isDense: true,
                                              items: const [
                                                DropdownMenuItem(value: 16.0, child: Text('16% Standard VAT')),
                                                DropdownMenuItem(value: 0.0, child: Text('0% Zero-Rated')),
                                              ],
                                              onChanged: (val) => setDialogState(() => taxRate = val!),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildStackedLabel('Initial Stock Qty'),
                                                TextField(
                                                  controller: initialStockController,
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                                  decoration: _buildModernInputDecoration(hint: '24'),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildStackedLabel('Low-Stock Alert Level'),
                                                TextField(
                                                  controller: reorderController,
                                                  keyboardType: TextInputType.number,
                                                  style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                                  decoration: _buildModernInputDecoration(hint: '15'),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      _buildStackedLabel('Shelf Location'),
                                      TextField(
                                        controller: shelfController,
                                        style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                        decoration: _buildModernInputDecoration(hint: 'Aisle 1'),
                                      ),
                                      const SizedBox(height: 14),

                                      _buildStackedLabel('Supplier'),
                                      TextField(
                                        controller: supplierController,
                                        style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary(context)),
                                        decoration: _buildModernInputDecoration(hint: 'e.g. Primary Distributor Ltd'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.border(context), thickness: 1),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '// STRICT DUPLICATE GUARD: SKU & BARCODE UNIQUENESS ENFORCED',
                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary(context)),
                        ),
                        Row(
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('CANCEL (ESC)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                              onPressed: () {
                                final cleanName = nameController.text.trim();
                                final cleanBarcode = barcodeController.text.trim();
                                final cleanSku = skuController.text.trim().toUpperCase();

                                if (cleanName.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter product name.'), backgroundColor: AppColors.warning),
                                  );
                                  return;
                                }

                                if (cleanSku.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please provide or generate a valid SKU code.'), backgroundColor: AppColors.warning),
                                  );
                                  return;
                                }

                                final skuMatches = _supermarketCatalog.where((i) =>
                                    (i['sku'] ?? '').toString().trim().toUpperCase() == cleanSku).toList();
                                if (skuMatches.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Duplicate SKU Error: SKU "$cleanSku" is already assigned to "${skuMatches.first['name']}".'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                  return;
                                }

                                if (cleanBarcode.isNotEmpty) {
                                  final barcodeMatches = _supermarketCatalog.where((i) =>
                                      (i['barcode'] ?? '').toString().trim() == cleanBarcode).toList();
                                  if (barcodeMatches.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Duplicate Barcode Error: Barcode "$cleanBarcode" is already registered to "${barcodeMatches.first['name']}".'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                    return;
                                  }
                                }

                                final costVal = double.tryParse(costController.text) ?? 0.0;
                                final priceVal = double.tryParse(priceController.text) ?? (costVal * 1.25);
                                final stockVal = double.tryParse(initialStockController.text) ?? 0.0;
                                final reorderVal = double.tryParse(reorderController.text) ?? 10.0;
                                final barcodeVal = cleanBarcode.isNotEmpty
                                    ? cleanBarcode
                                    : '616${DateTime.now().millisecondsSinceEpoch.toString().substring(3, 13)}';

                                final newProduct = {
                                  'id': 'PROD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                  'sku': cleanSku,
                                  'barcode': barcodeVal,
                                  'name': cleanName,
                                  'category': selectedCategory,
                                  'unit': selectedUnit,
                                  'stock': stockVal,
                                  'reorder': reorderVal,
                                  'cost': costVal,
                                  'price': priceVal,
                                  'taxRate': taxRate,
                                  'shelf': shelfController.text.trim().isNotEmpty ? shelfController.text.trim() : 'General Shelf',
                                  'supplier': supplierController.text.trim().isNotEmpty ? supplierController.text.trim() : 'Primary Supplier',
                                  'lastReceived': 'Just now',
                                };

                                setState(() {
                                  _supermarketCatalog.insert(0, newProduct);
                                });

                                _persistCatalog();
                                widget.onInventoryChanged?.call(newProduct);
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Product "$cleanName" registered! SKU: $cleanSku (Stock: $stockVal $selectedUnit)'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              },
                              icon: const Icon(LucideIcons.check, size: 16),
                              label: const Text('COMMIT [REGISTER PRODUCT]', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'monospace')),
                            ),
                          ],
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

  Widget _buildStackedLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
    );
  }

  Widget _buildFieldLabel(String text, [BuildContext? ctx]) {
    return _buildStackedLabel(text);
  }

  InputDecoration _buildModernInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  InputDecoration _buildMechanicalInputDecoration({String? hint}) {
    return _buildModernInputDecoration(hint: hint);
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
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context))),
        ),
        input,
      ],
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border(context), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary, letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Divider(height: 1, color: AppColors.border(context), thickness: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMasterCatalogView() {
    final filtered = _supermarketCatalog.where((item) {
      final stock = (item['stock'] as num).toDouble();
      final reorder = (item['reorder'] as num).toDouble();
      final isLow = stock <= reorder && stock > 0;
      final isOut = stock <= 0;

      if (_selectedFilter == 'low_stock' && !isLow) return false;
      if (_selectedFilter == 'out_of_stock' && !isOut) return false;
      if (_selectedFilter == 'in_stock' && (isLow || isOut)) return false;

      if (_selectedCategory != 'all' && item['category'] != _selectedCategory) return false;

      final q = _searchController.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (item['name'] as String).toLowerCase().contains(q) ||
          (item['barcode'] as String).contains(q) ||
          (item['sku'] as String).toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Bar & Search
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                controller: _searchController,
                focusNode: _barcodeFocusNode,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Scan Barcode or search product name / SKU...',
                  prefixIcon: const Icon(LucideIcons.scanBarcode, color: AppColors.primary, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(width: 12),

            DropdownButton<String>(
              value: _supermarketCatalog.any((p) => p['category'] == _selectedCategory) ? _selectedCategory : 'all',
              dropdownColor: AppColors.card(context),
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13),
              items: [
                DropdownMenuItem(value: 'all', child: Text('All Categories', style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13))),
                ..._supermarketCatalog
                    .map((p) => (p['category'] ?? '').toString().trim())
                    .where((c) => c.isNotEmpty)
                    .toSet()
                    .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 13)))),
              ],
              onChanged: (val) => setState(() => _selectedCategory = val ?? 'all'),
            ),
            const SizedBox(width: 12),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: _openCsvImportDialog,
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 16, color: AppColors.primary),
              label: const Text('Import CSV / Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
            const SizedBox(width: 10),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => _openRegisterProductDialog(),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Register Master Product'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
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
                          Icon(LucideIcons.packageOpen, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text('Master Product Catalog is Empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 4),
                          Text('Scan barcodes or click "Register Master Product" to add items.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openRegisterProductDialog(),
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Register Master Product'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final stock = (item['stock'] as num).toDouble();
                        final reorder = (item['reorder'] as num).toDouble();
                        final isOut = stock <= 0;
                        final isLow = stock <= reorder && !isOut;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 160,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['barcode'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                                    Text(item['sku'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] as String, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                    Text('Shelf: ${item['shelf']} • Category: ${item['category']}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  '${stock.toStringAsFixed(0)} ${item['unit']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    color: isOut ? AppColors.danger : (isLow ? AppColors.warning : AppColors.textPrimary(context)),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(Formatters.formatCurrency(item['cost'] as num), style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context))),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text(Formatters.formatCurrency(item['price'] as num), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? AppColors.danger.withValues(alpha: 0.15)
                                      : (isLow ? AppColors.warning.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 0.15)),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isOut ? AppColors.danger : (isLow ? AppColors.warning : AppColors.success)),
                                ),
                                child: Text(
                                  isOut ? 'OUT OF STOCK' : (isLow ? 'LOW STOCK' : 'IN STOCK'),
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: isOut ? AppColors.danger : (isLow ? AppColors.warning : AppColors.success)),
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

  // ULTRA-COMPACT METRIC CARD (Reduced height and sleek padding)
  Widget _buildCompactMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color : AppColors.border(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(child: Icon(icon, color: color, size: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: AppColors.textMuted(context),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SLEEK SIDEBAR ITEM WRAPPED IN MATERIAL
  Widget _buildSidebarItem({
    required String key,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          leading: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.textSecondary(context),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? AppColors.primary : AppColors.textPrimary(context),
            ),
          ),
          onTap: () => setState(() => _selectedTab = key),
        ),
      ),
    );
  }

  Widget _buildSidebarSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
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

  @override
  Widget build(BuildContext context) {
    // Purge any legacy mock items from memory on render
    _supermarketCatalog.removeWhere((e) {
      final sku = (e['sku'] ?? '').toString().toUpperCase();
      final id = (e['id'] ?? '').toString().toUpperCase();
      final name = (e['name'] ?? '').toString().toLowerCase();
      return sku.startsWith('GM-') ||
          id.startsWith('PROD-00') ||
          name.contains('brookside') ||
          name.contains('pembe') ||
          name.contains('fresh fri') ||
          name.contains('broadway') ||
          name.contains('kasuku');
    });

    int lowStockCount = 0;
    int outOfStockCount = 0;
    double totalValuation = 0;
    for (var item in _supermarketCatalog) {
      final stock = (item['stock'] as num).toDouble();
      final reorder = (item['reorder'] as num).toDouble();
      final cost = (item['cost'] as num).toDouble();
      if (stock <= 0) {
        outOfStockCount++;
      } else if (stock <= reorder) {
        lowStockCount++;
      }
      totalValuation += stock * cost;
    }

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Row(
        children: [
          // SIDEBAR (Left Navigation Panel)
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border(right: BorderSide(color: AppColors.border(context))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean Sidebar Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(LucideIcons.boxes, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'STOREKEEPING',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary(context),
                        ),
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
                      _buildSidebarSectionHeader('Receiving & Transfers'),
                      _buildSidebarItem(key: 'grn', label: 'Receive Goods (GRN)', icon: LucideIcons.gitFork),
                      _buildSidebarItem(key: 'grn_history', label: 'GRN History & Register', icon: LucideIcons.receipt),
                      _buildSidebarItem(key: 'requisitions', label: 'Branch Stock Requests', icon: LucideIcons.gitPullRequest),
                      _buildSidebarItem(key: 'pos', label: 'Purchase Orders', icon: LucideIcons.fileSpreadsheet),
                      _buildSidebarItem(key: 'vendors', label: 'Local Vendors', icon: LucideIcons.truck),

                      _buildSidebarSectionHeader('Inventory'),
                      _buildSidebarItem(key: 'catalog', label: 'Master Inventory', icon: LucideIcons.package),
                      _buildSidebarItem(key: 'ledger', label: 'Inventory Ledger', icon: LucideIcons.history),

                      _buildSidebarSectionHeader('Stock Takes'),
                      _buildSidebarItem(key: 'stocktake', label: 'Store Stocktake', icon: LucideIcons.clipboardCheck),
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
                  // TOP HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Storekeeping & Inventory',
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
                            child: Text(
                              'BRANCH: ${widget.branchName}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace',
                                color: AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_selectedTab != 'grn')
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () => setState(() => _selectedTab = 'grn'),
                              icon: const Icon(LucideIcons.packagePlus, size: 14),
                              label: const Text('Receive Goods (GRN)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: _openCsvImportDialog,
                            icon: const Icon(LucideIcons.fileSpreadsheet, size: 14, color: AppColors.primary),
                            label: const Text('Import CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => _openRegisterProductDialog(),
                            icon: const Icon(LucideIcons.plus, size: 14),
                            label: const Text('Register Master Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ULTRA-COMPACT KPI METRIC CARDS (Reduced Height)
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactMetricCard(
                          title: 'TOTAL CATALOG SKUS',
                          value: '${_supermarketCatalog.length} Products',
                          subtitle: '${_supermarketCatalog.map((p) => (p['category'] ?? '').toString().trim()).where((c) => c.isNotEmpty).toSet().length} Categories',
                          icon: LucideIcons.package,
                          color: AppColors.primary,
                          onTap: () => setState(() {
                            _selectedTab = 'catalog';
                            _selectedFilter = 'all';
                            _selectedCategory = 'all';
                          }),
                          isSelected: _selectedTab == 'catalog' && _selectedFilter == 'all' && _selectedCategory == 'all',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactMetricCard(
                          title: 'INVENTORY VALUATION',
                          value: Formatters.formatCurrency(totalValuation),
                          subtitle: 'Total Stock at Cost',
                          icon: LucideIcons.badgePercent,
                          color: const Color(0xFF059669),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactMetricCard(
                          title: 'LOW STOCK ALERTS',
                          value: '$lowStockCount Items',
                          subtitle: 'Below Reorder Limit',
                          icon: LucideIcons.alertTriangle,
                          color: AppColors.warning,
                          onTap: () => setState(() {
                            _selectedTab = 'catalog';
                            _selectedFilter = 'low_stock';
                          }),
                          isSelected: _selectedTab == 'catalog' && _selectedFilter == 'low_stock',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactMetricCard(
                          title: 'OUT OF STOCK',
                          value: '$outOfStockCount Items',
                          subtitle: 'Needs Restock',
                          icon: LucideIcons.alertCircle,
                          color: AppColors.danger,
                          onTap: () => setState(() {
                            _selectedTab = 'catalog';
                            _selectedFilter = 'out_of_stock';
                          }),
                          isSelected: _selectedTab == 'catalog' && _selectedFilter == 'out_of_stock',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // MAIN VIEW CONTENT
                  Expanded(
                    child: _selectedTab == 'grn'
                        ? GrnReceivingView(
                            branchName: widget.branchName,
                            organizationName: widget.organizationName,
                            catalog: _supermarketCatalog,
                            initialLoadedPo: _loadedPoForGrn,
                            onInventoryChanged: (p) {
                              setState(() {
                                final idx = _supermarketCatalog.indexWhere((i) => i['sku'] == p['sku']);
                                if (idx != -1) {
                                  _supermarketCatalog[idx] = p;
                                }
                              });
                              _persistCatalog();
                              widget.onInventoryChanged?.call(p);
                            },
                          )
                        : (_selectedTab == 'grn_history'
                            ? GrnHistoryView(
                                branchName: widget.branchName,
                                organizationName: widget.organizationName,
                              )
                            : (_selectedTab == 'requisitions'
                                ? BranchRequisitionsView(
                                    branchName: widget.branchName,
                                    organizationName: widget.organizationName,
                                    catalog: _supermarketCatalog,
                                    onInventoryChanged: (p) {
                                      setState(() {
                                        final idx = _supermarketCatalog.indexWhere((i) => i['sku'] == p['sku']);
                                        if (idx != -1) {
                                          _supermarketCatalog[idx] = p;
                                        }
                                      });
                                      _persistCatalog();
                                      widget.onInventoryChanged?.call(p);
                                    },
                                  )
                                : (_selectedTab == 'pos'
                                    ? PurchaseOrdersView(
                                        branchName: widget.branchName,
                                        organizationName: widget.organizationName,
                                        catalog: _supermarketCatalog,
                                        onLoadPoIntoGrn: (po) {
                                          setState(() {
                                            _loadedPoForGrn = po;
                                            _selectedTab = 'grn';
                                          });
                                        },
                                      )
                                    : (_selectedTab == 'vendors'
                                        ? SuppliersView(branchName: widget.branchName)
                                        : (_selectedTab == 'stocktake'
                                            ? StocktakeView(
                                                branchName: widget.branchName,
                                                organizationName: widget.organizationName,
                                                catalog: _supermarketCatalog,
                                                onInventoryChanged: (p) {
                                                  setState(() {
                                                    final idx = _supermarketCatalog.indexWhere((i) => i['sku'] == p['sku']);
                                                    if (idx != -1) {
                                                      _supermarketCatalog[idx] = p;
                                                    }
                                                  });
                                                  _persistCatalog();
                                                  widget.onInventoryChanged?.call(p);
                                                },
                                              )
                                            : (_selectedTab == 'ledger'
                                                ? InventoryLedgerView(
                                                    branchName: widget.branchName,
                                                    catalog: _supermarketCatalog,
                                                    onInventoryChanged: (p) {
                                                      setState(() {
                                                        final idx = _supermarketCatalog.indexWhere((i) => i['sku'] == p['sku']);
                                                        if (idx != -1) {
                                                          _supermarketCatalog[idx] = p;
                                                        }
                                                      });
                                                      _persistCatalog();
                                                      widget.onInventoryChanged?.call(p);
                                                    },
                                                  )
                                                : _buildMasterCatalogView())))))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
