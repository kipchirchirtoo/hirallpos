import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class CsvProductImportDialog extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final List<Map<String, dynamic>> existingCatalog;
  final Function(List<Map<String, dynamic>> importedProducts) onImport;

  const CsvProductImportDialog({
    super.key,
    required this.branchName,
    required this.organizationName,
    required this.existingCatalog,
    required this.onImport,
  });

  static Future<void> show({
    required BuildContext context,
    required String branchName,
    required String organizationName,
    required List<Map<String, dynamic>> existingCatalog,
    required Function(List<Map<String, dynamic>> importedProducts) onImport,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CsvProductImportDialog(
        branchName: branchName,
        organizationName: organizationName,
        existingCatalog: existingCatalog,
        onImport: onImport,
      ),
    );
  }

  @override
  State<CsvProductImportDialog> createState() => _CsvProductImportDialogState();
}

class _CsvProductImportDialogState extends State<CsvProductImportDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _rawTextController = TextEditingController();

  String? _selectedFileName;
  String _csvContent = '';
  List<Map<String, dynamic>> _parsedRows = [];
  List<String> _parsingErrors = [];
  bool _isProcessing = false;

  static const String sampleCsvTemplate =
      'Product Name,Barcode,Cost Price,Retail Price,Category,SKU Code,Unit,Initial Stock,Low Stock Alert,Shelf Location,Supplier,Tax Rate\n'
      'Fresh Whole Milk 500ml,6161101234567,52.00,65.00,Dairy,GS-DAIRY-1021,PACK,48,15,Aisle 1 - Chiller A,Brookside Dairy,16\n'
      'Fortified Maize Flour 2kg,6161109876543,140.00,165.00,Groceries & Grains,GS-GRN-3042,PACK,120,25,Aisle 2 - Shelf B,Pembe Flour Mills,16\n'
      'Pure Vegetable Cooking Oil 1L,6161105544332,260.00,310.00,Cooking Oils & Fats,GS-OIL-8891,BOTTLE,32,10,Aisle 3 - Shelf A,Pwani Oil Products,16\n';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rawTextController.dispose();
    super.dispose();
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
    if (catUpper.contains('GRAIN') || catUpper.contains('FLOUR') || catUpper.contains('GROCER')) return 'GRN';
    if (catUpper.contains('OIL') || catUpper.contains('FAT')) return 'OIL';
    if (catUpper.contains('BEV') || catUpper.contains('DRINK')) return 'BEV';
    if (catUpper.contains('MEAT') || catUpper.contains('DELI') || catUpper.contains('BUTCHER')) return 'MET';
    if (catUpper.contains('CARE') || catUpper.contains('COSMETIC')) return 'CAR';
    if (catUpper.contains('HOUSE') || catUpper.contains('DETERGENT')) return 'HSE';
    if (catUpper.contains('STAT') || catUpper.contains('BOOK') || catUpper.contains('PAPER')) return 'STAT';
    if (catUpper.contains('SNACK') || catUpper.contains('SWEET')) return 'SNK';

    final clean = catUpper.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return clean.length >= 3 ? clean.substring(0, 3) : (clean.isNotEmpty ? clean : 'GEN');
  }

  Future<void> _pickCsvFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'tsv'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        setState(() {
          _selectedFileName = files.first.name;
          _csvContent = content;
          _rawTextController.text = content;
        });
        _parseCsv(content);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading file: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _copyTemplateToClipboard() {
    Clipboard.setData(const ClipboardData(text: sampleCsvTemplate));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample CSV Template copied to clipboard!'), backgroundColor: AppColors.success),
    );
  }

  Future<void> _downloadSampleCsv() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(sampleCsvTemplate));
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save Sample CSV Template',
        fileName: 'hirall_master_products_template.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );

      if (savedUri != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sample CSV Template saved to "${savedUri.path}"'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      _copyTemplateToClipboard();
    }
  }

  void _parseCsv(String raw) {
    if (raw.trim().isEmpty) {
      setState(() {
        _parsedRows = [];
        _parsingErrors = [];
      });
      return;
    }

    setState(() => _isProcessing = true);

    final lines = raw.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() {
        _parsedRows = [];
        _parsingErrors = ['The uploaded CSV contains no rows.'];
        _isProcessing = false;
      });
      return;
    }

    // Determine delimiter (comma, tab, or semicolon)
    final firstLine = lines.first;
    String delimiter = ',';
    if (firstLine.contains('\t')) {
      delimiter = '\t';
    } else if (firstLine.contains(';') && !firstLine.contains(',')) {
      delimiter = ';';
    }

    final headers = _splitCsvLine(firstLine, delimiter).map((h) => h.trim().toLowerCase()).toList();

    int nameIdx = headers.indexWhere((h) => h.contains('name') || h.contains('title') || h.contains('item') || h.contains('desc'));
    int barcodeIdx = headers.indexWhere((h) => h.contains('barcode') || h.contains('ean') || h.contains('upc') || h.contains('code'));
    int costIdx = headers.indexWhere((h) => h.contains('cost') || h.contains('buying') || h.contains('purchase') || h.contains('buy'));
    int priceIdx = headers.indexWhere((h) => h.contains('price') || h.contains('retail') || h.contains('selling') || h.contains('mrp'));
    int catIdx = headers.indexWhere((h) => h.contains('category') || h.contains('dept') || h.contains('group'));
    int skuIdx = headers.indexWhere((h) => h.contains('sku') || h.contains('sku_code') || h.contains('item_code'));
    int unitIdx = headers.indexWhere((h) => h.contains('unit') || h.contains('uom') || h.contains('measure'));
    int stockIdx = headers.indexWhere((h) => h.contains('stock') || h.contains('qty') || h.contains('quantity'));
    int reorderIdx = headers.indexWhere((h) => h.contains('reorder') || h.contains('low') || h.contains('alert') || h.contains('min'));
    int shelfIdx = headers.indexWhere((h) => h.contains('shelf') || h.contains('location') || h.contains('aisle'));
    int supplierIdx = headers.indexWhere((h) => h.contains('supplier') || h.contains('vendor') || h.contains('distributor'));
    int taxIdx = headers.indexWhere((h) => h.contains('tax') || h.contains('vat'));

    // Check if required headers were identified
    List<String> missingHeaders = [];
    if (nameIdx == -1) missingHeaders.add('Product Name');
    if (barcodeIdx == -1) missingHeaders.add('Barcode');
    if (costIdx == -1) missingHeaders.add('Cost Price');
    if (priceIdx == -1) missingHeaders.add('Retail Price');

    if (missingHeaders.isNotEmpty) {
      // If header matching failed, check if first row is actually data with standard columns
      nameIdx = 0;
      barcodeIdx = 1;
      costIdx = 2;
      priceIdx = 3;
      catIdx = 4;
      skuIdx = 5;
      unitIdx = 6;
      stockIdx = 7;
      reorderIdx = 8;
      shelfIdx = 9;
      supplierIdx = 10;
      taxIdx = 11;
    }

    final List<Map<String, dynamic>> parsed = [];
    final List<String> errors = [];
    final Set<String> encounteredBarcodes = {};
    final existingBarcodes = widget.existingCatalog.map((e) => (e['barcode'] ?? '').toString()).toSet();

    final orgPrefix = _getOrgShortform(widget.organizationName);

    // If first row was a header row, start from line index 1, otherwise 0
    final startIndex = missingHeaders.isEmpty ? 1 : 0;

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsvLine(line, delimiter);
      final rowNum = i + 1;

      String name = cols.length > nameIdx && nameIdx != -1 ? cols[nameIdx].trim() : '';
      String barcode = cols.length > barcodeIdx && barcodeIdx != -1 ? cols[barcodeIdx].trim().replaceAll(RegExp(r'[^0-9A-Za-z\-]'), '') : '';
      String costStr = cols.length > costIdx && costIdx != -1 ? cols[costIdx].trim().replaceAll(RegExp(r'[^0-9.]'), '') : '';
      String priceStr = cols.length > priceIdx && priceIdx != -1 ? cols[priceIdx].trim().replaceAll(RegExp(r'[^0-9.]'), '') : '';
      String category = cols.length > catIdx && catIdx != -1 ? cols[catIdx].trim() : 'Groceries';
      String sku = cols.length > skuIdx && skuIdx != -1 ? cols[skuIdx].trim().toUpperCase() : '';
      String unit = cols.length > unitIdx && unitIdx != -1 ? cols[unitIdx].trim().toUpperCase() : 'PCS';
      String stockStr = cols.length > stockIdx && stockIdx != -1 ? cols[stockIdx].trim().replaceAll(RegExp(r'[^0-9.]'), '') : '0';
      String reorderStr = cols.length > reorderIdx && reorderIdx != -1 ? cols[reorderIdx].trim().replaceAll(RegExp(r'[^0-9.]'), '') : '10';
      String shelf = cols.length > shelfIdx && shelfIdx != -1 ? cols[shelfIdx].trim() : 'Main Shelf';
      String supplier = cols.length > supplierIdx && supplierIdx != -1 ? cols[supplierIdx].trim() : '';
      String taxStr = cols.length > taxIdx && taxIdx != -1 ? cols[taxIdx].trim().replaceAll(RegExp(r'[^0-9.]'), '') : '16';

      if (category.isEmpty) category = 'Groceries';
      if (unit.isEmpty) unit = 'PCS';
      if (shelf.isEmpty) shelf = 'Main Shelf';

      bool isValid = true;
      String errorMsg = '';

      if (name.isEmpty) {
        isValid = false;
        errorMsg = 'Missing Product Name';
      } else if (barcode.isEmpty) {
        isValid = false;
        errorMsg = 'Missing Barcode';
      } else if (encounteredBarcodes.contains(barcode)) {
        isValid = false;
        errorMsg = 'Duplicate Barcode in CSV';
      } else if (existingBarcodes.contains(barcode)) {
        isValid = false;
        errorMsg = 'Barcode already exists in catalog';
      }

      final cost = double.tryParse(costStr);
      final price = double.tryParse(priceStr);

      if (cost == null || cost <= 0) {
        if (isValid) {
          isValid = false;
          errorMsg = 'Invalid Cost Price';
        }
      }

      if (price == null || price <= 0) {
        if (isValid) {
          isValid = false;
          errorMsg = 'Invalid Retail Price';
        }
      }

      if (sku.isEmpty) {
        final catCode = _getCategoryCode(category);
        final randomNum = (1000 + (parsed.length + 1) * 7 + (i * 13)) % 9000 + 1000;
        sku = '$orgPrefix-$catCode-$randomNum';
      }

      if (isValid) {
        encounteredBarcodes.add(barcode);
      } else {
        errors.add('Row $rowNum: $errorMsg ("$name")');
      }

      parsed.add({
        'rowNum': rowNum,
        'isValid': isValid,
        'errorMsg': errorMsg,
        'id': 'PROD-${DateTime.now().millisecondsSinceEpoch}-${parsed.length}',
        'name': name,
        'barcode': barcode,
        'sku': sku,
        'cost': cost ?? 0.0,
        'price': price ?? 0.0,
        'category': category,
        'unit': unit,
        'stock': double.tryParse(stockStr) ?? 0.0,
        'reorder': double.tryParse(reorderStr) ?? 10.0,
        'shelf': shelf,
        'supplier': supplier,
        'taxRate': double.tryParse(taxStr) ?? 16.0,
      });
    }

    setState(() {
      _parsedRows = parsed;
      _parsingErrors = errors;
      _isProcessing = false;
    });
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  void _commitImport() {
    final validRows = _parsedRows.where((r) => r['isValid'] == true).map((r) {
      final map = Map<String, dynamic>.from(r);
      map.remove('rowNum');
      map.remove('isValid');
      map.remove('errorMsg');
      return map;
    }).toList();

    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid product rows to import. Please check required fields.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    widget.onImport(validRows);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully imported ${validRows.length} master products into inventory!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _parsedRows.where((r) => r['isValid'] == true).length;
    final invalidCount = _parsedRows.length - validCount;

    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border(context), width: 1.5),
      ),
      child: Container(
        width: 960,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(LucideIcons.fileSpreadsheet, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BULK IMPORT MASTER PRODUCTS (CSV / EXCEL)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          'Upload CSV file or paste spreadsheet table to batch register items for ${widget.branchName}.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // REQUIRED & OPTIONAL FIELDS NOTICE RIBBON
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'REQUIRED COLUMNS: ',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                            ),
                            Text(
                              'Product Name *, Barcode / EAN *, Cost Price (KES) *, Retail Price (KES) *',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'OPTIONAL COLUMNS: ',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textSecondary(context)),
                            ),
                            Expanded(
                              child: Text(
                                'Category, SKU Code, Unit (PCS, PACK, KG), Initial Stock, Low Stock Alert, Shelf Location, Supplier, Tax Rate (16/0)',
                                style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: _copyTemplateToClipboard,
                        icon: const Icon(LucideIcons.copy, size: 13),
                        label: const Text('Copy Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.card(context),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onPressed: _downloadSampleCsv,
                        icon: const Icon(LucideIcons.download, size: 13),
                        label: const Text('Download Sample CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // TAB SELECTOR (PICK FILE vs PASTE TEXT)
            Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary(context),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                tabs: const [
                  Tab(iconMargin: EdgeInsets.zero, text: '📁 PICK CSV FILE FROM COMPUTER'),
                  Tab(iconMargin: EdgeInsets.zero, text: '📋 PASTE SPREADSHEET / CSV TEXT'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // TAB VIEWS (FILE PICKER vs TEXT AREA)
            SizedBox(
              height: 110,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: File Picker Drop Zone
                  InkWell(
                    onTap: _pickCsvFile,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.uploadCloud, size: 28, color: AppColors.primary),
                            const SizedBox(height: 6),
                            Text(
                              _selectedFileName != null ? 'Selected: $_selectedFileName' : 'Click to Browse and Upload .CSV / .TXT File',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedFileName != null ? AppColors.primary : AppColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              'Supports UTF-8 CSV with comma or tab delimiters',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Tab 2: Raw Text Area
                  TextField(
                    controller: _rawTextController,
                    maxLines: 4,
                    onChanged: (text) => _parseCsv(text),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Paste CSV or tab-separated data copied directly from Excel / Google Sheets here...',
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // VALIDATION & PREVIEW HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'PARSED TABLE PREVIEW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'VALID: $validCount',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.success),
                      ),
                    ),
                    if (invalidCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'INVALID / SKIPPED: $invalidCount',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.danger),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_parsedRows.isNotEmpty)
                  Text(
                    '${_parsedRows.length} total rows parsed',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // PREVIEW TABLE
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _parsedRows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.table, size: 36, color: AppColors.textMuted(context)),
                              const SizedBox(height: 8),
                              Text(
                                'No data uploaded yet',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                'Upload a CSV file or paste spreadsheet rows above to preview products.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _parsedRows.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                          itemBuilder: (context, index) {
                            final row = _parsedRows[index];
                            final isValid = row['isValid'] as bool;

                            return Container(
                              color: isValid ? Colors.transparent : AppColors.danger.withValues(alpha: 0.05),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                children: [
                                  // Row status badge
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isValid ? AppColors.success.withValues(alpha: 0.15) : AppColors.danger.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isValid ? LucideIcons.check : LucideIcons.alertCircle,
                                        size: 13,
                                        color: isValid ? AppColors.success : AppColors.danger,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Barcode & SKU
                                  SizedBox(
                                    width: 140,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row['barcode'].toString().isNotEmpty ? row['barcode'].toString() : '[NO BARCODE]',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'monospace',
                                            color: row['barcode'].toString().isEmpty ? AppColors.danger : AppColors.textPrimary(context),
                                          ),
                                        ),
                                        Text(
                                          row['sku'].toString(),
                                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Name & Category
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          row['name'].toString().isNotEmpty ? row['name'].toString() : '[MISSING NAME]',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: row['name'].toString().isEmpty ? AppColors.danger : AppColors.textPrimary(context),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Category: ${row['category']} • Shelf: ${row['shelf']} • ${row['unit']}',
                                          style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context)),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Stock
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      '${row['stock']} ${row['unit']}',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
                                    ),
                                  ),

                                  // Cost & Price
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      'Cost: ${Formatters.formatCurrency(row['cost'] as num)}',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 90,
                                    child: Text(
                                      Formatters.formatCurrency(row['price'] as num),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                  ),

                                  // Status message / error
                                  if (!isValid)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        row['errorMsg'].toString(),
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Ready',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.success),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // BOTTOM ACTION FOOTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '// DUPLICATE GUARD: BARCODES ARE VALIDATED AGAINST MASTER CATALOG',
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted(context)),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: validCount > 0 ? _commitImport : null,
                      icon: const Icon(LucideIcons.fileCheck2, size: 16),
                      label: Text(
                        'IMPORT $validCount PRODUCTS',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
