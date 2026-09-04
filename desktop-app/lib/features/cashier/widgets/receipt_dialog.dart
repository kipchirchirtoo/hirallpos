import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/printing_service.dart';
import '../../admin/widgets/thermal_receipt_print_preview_dialog.dart';
import '../models/cart_item.dart';

class ReceiptDialog extends StatelessWidget {
  final Map<String, dynamic> saleData;
  final VoidCallback? onNewSale;

  const ReceiptDialog({
    super.key,
    required this.saleData,
    this.onNewSale,
  });

  Future<Uint8List?> _getLogoBytes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBase64 = prefs.getString('receipt_logo_base64');
      if (savedBase64 != null && savedBase64.isNotEmpty) {
        final cleanBase64 = savedBase64.contains(',') ? savedBase64.split(',').last : savedBase64;
        final decoded = base64Decode(cleanBase64.trim());
        if (decoded.length >= 8 && (decoded[0] == 0x89 || decoded[0] == 0xFF || decoded[0] == 0x47 || (decoded.length >= 12 && decoded[0] == 0x52))) {
          return decoded;
        }
      }
      if (File('/home/kipchir/giftmart.png').existsSync()) {
        return await File('/home/kipchir/giftmart.png').readAsBytes();
      }
      final assetData = await rootBundle.load('assets/images/giftmart.png');
      return assetData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String storeName = saleData['storeName'] ?? 'Store Terminal';
    final String branchName = saleData['branchName'] ?? 'Main Branch';
    final String tillNumber = saleData['tillNumber'] ?? 'TILL-01';
    final String receiptNumber = saleData['receiptNo'] ?? 'REC-001';
    final List<CartItem> items = saleData['items'] != null ? List<CartItem>.from(saleData['items']) : [];
    final double subtotal = (saleData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final double discount = (saleData['discount'] as num?)?.toDouble() ?? 0.0;
    final double taxAmount = (saleData['tax'] as num?)?.toDouble() ?? 0.0;
    final double totalAmount = (saleData['total'] as num?)?.toDouble() ?? 0.0;
    final String paymentMethod = saleData['paymentMethod'] ?? 'cash';
    final double amountPaid = (saleData['amountPaid'] as num?)?.toDouble() ?? totalAmount;
    final double changeDue = (saleData['change'] as num?)?.toDouble() ?? 0.0;
    final String? mpesaReceipt = saleData['mpesaCode'];
    final DateTime saleTime = saleData['dateTime'] ?? DateTime.now();

    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Digital Receipt Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                IconButton(
                  onPressed: onNewSale ?? () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, color: AppColors.textMuted(context), size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // White Paper Receipt Style Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.black, fontFamily: 'monospace', fontSize: 11),
                child: Column(
                  children: [
                    // Store Logo
                    FutureBuilder<Uint8List?>(
                      future: _getLogoBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return Center(
                            child: Container(
                              height: 40,
                              margin: const EdgeInsets.only(bottom: 6),
                              child: Image.memory(
                                snapshot.data!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    Text(storeName.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(branchName, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                    Text('Till: $tillNumber', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
                    const Divider(color: Colors.black54, thickness: 1, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('RCPT: $receiptNumber'),
                        Text(Formatters.formatTime(saleTime)),
                      ],
                    ),
                    Text(Formatters.formatDate(saleTime)),
                    const Divider(color: Colors.black54, thickness: 1, height: 16),
                    // Item List
                    ...items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('${item.quantity.toStringAsFixed(0)}x ${item.name}')),
                            Text(Formatters.formatCurrency(item.netTotal).replaceAll('KES ', '')),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.black54, thickness: 1, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('SUBTOTAL:'),
                        Text(Formatters.formatCurrency(subtotal)),
                      ],
                    ),
                    if (discount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('DISCOUNT:'),
                          Text('-${Formatters.formatCurrency(discount)}'),
                        ],
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('VAT (16% INCL):'),
                        Text(Formatters.formatCurrency(taxAmount)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL AMOUNT:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        Text(Formatters.formatCurrency(totalAmount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                    const Divider(color: Colors.black54, thickness: 1, height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PAID VIA (${paymentMethod.toUpperCase()}):'),
                        Text(Formatters.formatCurrency(amountPaid)),
                      ],
                    ),
                    if (paymentMethod == 'cash')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('CHANGE:'),
                          Text(Formatters.formatCurrency(changeDue)),
                        ],
                      ),
                    if (mpesaReceipt != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('M-PESA REF:'),
                          Text(mpesaReceipt),
                        ],
                      ),
                    const SizedBox(height: 12),
                    // Barcode
                    BarcodeWidget(
                      barcode: Barcode.code128(),
                      data: receiptNumber,
                      width: 180,
                      height: 40,
                      drawText: false,
                    ),
                    const SizedBox(height: 8),
                    const Text('Thank you for shopping with us!', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    const Text('Powered by HIRALL POS', style: TextStyle(fontSize: 9, color: Colors.black54), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNewSale ?? () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Done / New Sale'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ThermalReceiptPrintPreviewDialog(
                          saleData: saleData,
                          paperWidthMm: PrintingService.instance.paperWidthMm,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    icon: const Icon(LucideIcons.printer, size: 16),
                    label: const Text('Print Receipt'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
