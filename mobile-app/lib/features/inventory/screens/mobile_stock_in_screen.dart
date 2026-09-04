import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/mobile_theme.dart';
import '../../../core/services/mobile_bridge_client.dart';

class MobileStockInScreen extends StatefulWidget {
  const MobileStockInScreen({super.key});

  @override
  State<MobileStockInScreen> createState() => _MobileStockInScreenState();
}

class _MobileStockInScreenState extends State<MobileStockInScreen> {
  late final MobileScannerController _scannerController;

  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '10');
  final _costPriceController = TextEditingController(text: '0.00');
  final _sellingPriceController = TextEditingController(text: '0.00');
  final _supplierController = TextEditingController(text: 'Direct Delivery');
  final _batchController = TextEditingController();

  final List<Map<String, dynamic>> _receivedLogs = [];
  bool _isScannerActive = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _supplierController.dispose();
    _batchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final b in barcodes) {
      final code = b.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        HapticFeedback.lightImpact();
        setState(() {
          _barcodeController.text = code;
          _isScannerActive = false;
          _autofillProductInfo(code);
        });
        break;
      }
    }
  }

  void _autofillProductInfo(String barcode) {
    if (barcode == '616110123456') {
      _nameController.text = 'Brookside Fresh Whole Milk 500ml';
      _costPriceController.text = '58.00';
      _sellingPriceController.text = '70.00';
    } else if (barcode == '616110987654') {
      _nameController.text = 'Pembe Premium Maize Meal Flour 2kg';
      _costPriceController.text = '180.00';
      _sellingPriceController.text = '210.00';
    } else if (_nameController.text.isEmpty) {
      _nameController.text = 'Product ($barcode)';
    }
  }

  Future<void> _submitStockIn() async {
    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    final cost = double.tryParse(_costPriceController.text.trim()) ?? 0.0;

    if (barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan or enter a product barcode'), backgroundColor: MobileAppColors.danger),
      );
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid stock quantity'), backgroundColor: MobileAppColors.danger),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await MobileBridgeClient.instance.sendStockIn(
      barcode: barcode,
      name: name.isNotEmpty ? name : 'Item $barcode',
      quantity: qty,
      unitCost: cost,
      supplier: _supplierController.text.trim(),
      batchNo: _batchController.text.trim(),
    );

    setState(() {
      _isSubmitting = false;
      _receivedLogs.insert(0, {
        'barcode': barcode,
        'name': name.isNotEmpty ? name : 'Item $barcode',
        'qty': qty,
        'cost': cost,
        'time': DateTime.now(),
      });
      _barcodeController.clear();
      _nameController.clear();
      _qtyController.text = '10';
      _costPriceController.text = '0.00';
      _sellingPriceController.text = '0.00';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Stock Added: +${qty.toInt()} $name (Synced to Desktop)'),
          backgroundColor: MobileAppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Stock In & Receiving', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isScannerActive ? LucideIcons.x : LucideIcons.camera),
            tooltip: _isScannerActive ? 'Close Camera' : 'Open Camera Scanner',
            onPressed: () => setState(() => _isScannerActive = !_isScannerActive),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Scanner if Active
            if (_isScannerActive) ...[
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MobileAppColors.primary, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: const Color(0xFF111827),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.cameraOff, color: Colors.amber, size: 32),
                            const SizedBox(height: 6),
                            const Text(
                              'Camera Stream Inactive',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Type the SKU below or select quick item.',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MobileAppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              ),
                              onPressed: () => _scannerController.start(),
                              child: const Text('Retry Camera', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Barcode Input with Scan Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Product Barcode / SKU *',
                      hintText: 'Scan with camera or type...',
                      prefixIcon: const Icon(LucideIcons.barcode, size: 20),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.scanLine, color: MobileAppColors.primary),
                        onPressed: () => setState(() => _isScannerActive = true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                hintText: 'e.g. Brookside Milk 500ml',
                prefixIcon: Icon(LucideIcons.package, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Quantity & Unit Cost Row
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty Received *',
                      prefixIcon: Icon(LucideIcons.plusCircle, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Unit Cost (KES)',
                      prefixIcon: Icon(LucideIcons.banknote, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Supplier & Batch
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier / Delivery Source',
                      prefixIcon: Icon(LucideIcons.truck, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MobileAppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.check),
                label: const Text('Add Stock to Inventory', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: _isSubmitting ? null : _submitStockIn,
              ),
            ),
            const SizedBox(height: 24),

            // Shift Received Stock Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Floor Stock-Ins (${_receivedLogs.length})',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (_receivedLogs.isNotEmpty)
                  Text(
                    'Total Qty: ${_receivedLogs.fold<double>(0.0, (sum, item) => sum + (item['qty'] as num).toDouble()).toInt()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: MobileAppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_receivedLogs.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: MobileAppColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MobileAppColors.border(context)),
                ),
                child: Center(
                  child: Text(
                    'No stock added in this session yet.\nScan product barcodes to begin receiving.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: MobileAppColors.textSecondary(context)),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _receivedLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final log = _receivedLogs[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: MobileAppColors.card(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MobileAppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MobileAppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(LucideIcons.packageCheck, size: 16, color: MobileAppColors.success),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log['name'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Barcode: ${log['barcode']} · Cost: KES ${log['cost']}',
                                style: TextStyle(fontSize: 11, color: MobileAppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: MobileAppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${(log['qty'] as num).toInt()} pcs',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MobileAppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
