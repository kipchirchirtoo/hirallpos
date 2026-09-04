import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/mobile_theme.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/services/mobile_bridge_client.dart';

class MobileCashierScreen extends StatefulWidget {
  const MobileCashierScreen({super.key});

  @override
  State<MobileCashierScreen> createState() => _MobileCashierScreenState();
}

class _MobileCashierScreenState extends State<MobileCashierScreen> {
  late final MobileScannerController _scannerController;

  final List<MobileCartItem> _cart = [];
  bool _isScannerOpen = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      autoStart: true,
    );
  }

  // Demo Product Catalog
  final List<Map<String, dynamic>> _catalog = [
    {'id': '1', 'barcode': '616110123456', 'name': 'Brookside Whole Milk 500ml', 'price': 70.0, 'cost': 58.0},
    {'id': '2', 'barcode': '616110987654', 'name': 'Pembe Maize Meal Flour 2kg', 'price': 210.0, 'cost': 180.0},
    {'id': '3', 'barcode': '616110555444', 'name': 'Fresh Fri Cooking Oil 1L', 'price': 310.0, 'cost': 265.0},
    {'id': '4', 'barcode': '616110777888', 'name': 'Ariel Washing Powder 1kg', 'price': 380.0, 'cost': 320.0},
    {'id': '5', 'barcode': '616110222333', 'name': 'Broadways White Bread 400g', 'price': 65.0, 'cost': 52.0},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  double get _subtotal => _cart.fold(0.0, (sum, i) => sum + i.grossTotal);
  double get _totalDiscount => _cart.fold(0.0, (sum, i) => sum + i.discountAmount);
  double get _netTotal => _subtotal - _totalDiscount;
  double get _taxAmount => _netTotal * (16.0 / 116.0);

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    for (final b in barcodes) {
      final code = b.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        _ringUpBarcode(code);
        break;
      }
    }
  }

  void _ringUpBarcode(String barcode) {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    final match = _catalog.firstWhere(
      (p) => (p['barcode'] == barcode || (p['name'] as String).toLowerCase().contains(barcode.toLowerCase())),
      orElse: () => {'id': 'temp', 'barcode': barcode, 'name': 'Scanned Item ($barcode)', 'price': 100.0, 'cost': 80.0},
    );

    setState(() {
      final existingIndex = _cart.indexWhere((i) => i.barcode == barcode || i.id == match['id']);
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity += 1.0;
      } else {
        _cart.add(MobileCartItem(
          id: match['id'].toString(),
          name: match['name'].toString(),
          barcode: match['barcode'].toString(),
          unitPrice: (match['price'] as num).toDouble(),
          costPrice: (match['cost'] as num).toDouble(),
          quantity: 1.0,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🛒 Added: ${match['name']}'),
        duration: const Duration(milliseconds: 900),
        backgroundColor: MobileAppColors.primary,
      ),
    );
  }

  void _openCheckoutDialog() {
    if (_cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MobileAppColors.surface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _buildPaymentSheet(ctx),
    );
  }

  Widget _buildPaymentSheet(BuildContext ctx) {
    final phoneController = TextEditingController(text: '254711000111');
    final amountTenderedController = TextEditingController(text: _netTotal.toStringAsFixed(0));
    String paymentMethod = 'mpesa'; // 'mpesa' | 'cash'
    bool isProcessing = false;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),

              // Total Due Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MobileAppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MobileAppColors.primary),
                ),
                child: Column(
                  children: [
                    const Text('TOTAL AMOUNT DUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${_netTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: MobileAppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text('16% VAT Included: KES ${_taxAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: MobileAppColors.textSecondary(context))),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tender Selector
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setSheetState(() => paymentMethod = 'mpesa'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: paymentMethod == 'mpesa' ? MobileAppColors.mpesa : MobileAppColors.card(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: paymentMethod == 'mpesa' ? MobileAppColors.mpesa : MobileAppColors.border(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.smartphone, size: 16, color: paymentMethod == 'mpesa' ? Colors.white : MobileAppColors.textPrimary(context)),
                            const SizedBox(width: 8),
                            Text('M-PESA STK', style: TextStyle(fontWeight: FontWeight.w700, color: paymentMethod == 'mpesa' ? Colors.white : MobileAppColors.textPrimary(context))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setSheetState(() => paymentMethod = 'cash'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: paymentMethod == 'cash' ? MobileAppColors.primary : MobileAppColors.card(context),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: paymentMethod == 'cash' ? MobileAppColors.primary : MobileAppColors.border(context)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.banknote, size: 16, color: paymentMethod == 'cash' ? Colors.white : MobileAppColors.textPrimary(context)),
                            const SizedBox(width: 8),
                            Text('CASH', style: TextStyle(fontWeight: FontWeight.w700, color: paymentMethod == 'cash' ? Colors.white : MobileAppColors.textPrimary(context))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (paymentMethod == 'mpesa')
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Customer M-Pesa Phone Number',
                    hintText: '2547XXXXXXXX',
                    prefixIcon: Icon(LucideIcons.phone, size: 20),
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: amountTenderedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cash Amount Tendered (KES)',
                    prefixIcon: Icon(LucideIcons.banknote, size: 20),
                    border: OutlineInputBorder(),
                  ),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: paymentMethod == 'mpesa' ? MobileAppColors.mpesa : MobileAppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: isProcessing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.checkCheck),
                  label: Text(
                    isProcessing ? 'Processing Transaction...' : (paymentMethod == 'mpesa' ? 'Send M-Pesa STK Push' : 'Complete Cash Sale'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          setSheetState(() => isProcessing = true);
                          final receiptNo = 'RCPT-M-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                          
                          // Sync to Desktop Ledger
                          await MobileBridgeClient.instance.sendMobileSale({
                            'receiptNo': receiptNo,
                            'items': _cart.map((i) => i.toMap()).toList(),
                            'total': _netTotal,
                            'subtotal': _subtotal,
                            'tax': _taxAmount,
                            'paymentMethod': paymentMethod.toUpperCase(),
                            'mpesaCode': paymentMethod == 'mpesa' ? 'QKH${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}' : null,
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            setState(() => _cart.clear());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🎉 Sale Completed! Receipt #$receiptNo synced to Desktop!'),
                                backgroundColor: MobileAppColors.success,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile POS Terminal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isScannerOpen ? LucideIcons.x : LucideIcons.scanBarcode),
            tooltip: _isScannerOpen ? 'Close Scanner' : 'Open Camera Barcode Scanner',
            onPressed: () => setState(() => _isScannerOpen = !_isScannerOpen),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              tooltip: 'Clear Cart',
              onPressed: () => setState(() => _cart.clear()),
            ),
        ],
      ),
      body: Column(
        children: [
          // Live Camera Scanner if open
          if (_isScannerOpen) ...[
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: MobileAppColors.primary, width: 2),
              ),
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
                            'Search by name/barcode below or tap fast-selling items.',
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
          ],

          // Search / Scan Barcode Header
          Container(
            padding: const EdgeInsets.all(12),
            color: MobileAppColors.surface(context),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        _ringUpBarcode(val.trim());
                        _searchController.clear();
                      }
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Scan or search item name/barcode...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.scan, color: MobileAppColors.primary),
                        onPressed: () => setState(() => _isScannerOpen = !_isScannerOpen),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shoppingBag, size: 48, color: MobileAppColors.textSecondary(context)),
                        const SizedBox(height: 12),
                        const Text('Cart is Empty', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Point camera at product barcodes to ring up floor sales.',
                          style: TextStyle(fontSize: 12, color: MobileAppColors.textSecondary(context)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: MobileAppColors.primary, foregroundColor: Colors.white),
                          icon: const Icon(LucideIcons.camera, size: 16),
                          label: const Text('Start Camera Scanner'),
                          onPressed: () => setState(() => _isScannerOpen = true),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MobileAppColors.card(context),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: MobileAppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'KES ${item.unitPrice.toStringAsFixed(2)} · Barcode: ${item.barcode}',
                                    style: TextStyle(fontSize: 11, color: MobileAppColors.textSecondary(context)),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(LucideIcons.minusCircle, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity > 1) {
                                        item.quantity -= 1;
                                      } else {
                                        _cart.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  item.quantity.toInt().toString(),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.plusCircle, size: 20, color: MobileAppColors.primary),
                                  onPressed: () => setState(() => item.quantity += 1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'KES ${item.netTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Checkout Summary Bar
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MobileAppColors.surface(context),
                border: Border(top: BorderSide(color: MobileAppColors.border(context))),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total (${_cart.length} items):', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('KES ${_netTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: MobileAppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MobileAppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(LucideIcons.creditCard),
                      label: Text('Proceed to Checkout (KES ${_netTotal.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      onPressed: _openCheckoutDialog,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
