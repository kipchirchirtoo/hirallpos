import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/printing_service.dart';

class ThermalReceiptPrintPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> saleData;
  final int paperWidthMm;

  const ThermalReceiptPrintPreviewDialog({
    super.key,
    required this.saleData,
    this.paperWidthMm = 80,
  });

  @override
  Widget build(BuildContext context) {
    final pageFormat = paperWidthMm == 58
        ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
        : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm);

    final String docTitle = 'Receipt_${saleData['receiptNo'] ?? '001'}';

    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: Container(
        width: 620,
        height: 740,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.printer, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thermal Receipt Print & Preview',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                        ),
                        Text(
                          '${paperWidthMm}mm ESC/POS Thermal Paper • Direct Hardware Dispatch',
                          style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x, size: 18, color: AppColors.textMuted(context)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // In-App Interactive PDF Preview
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PdfPreview(
                  maxPageWidth: paperWidthMm == 58 ? 260 : 340,
                  build: (format) => PrintingService.instance.generateThermalReceiptPdf(
                    saleData,
                    paperWidthMm: paperWidthMm,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  initialPageFormat: pageFormat,
                  pdfFileName: '$docTitle.pdf',
                  loadingWidget: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 15),
                  label: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await PrintingService.instance.printReceipt(saleData, silent: false);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Receipt print job sent to system printer spooler!'
                              : 'Print command dispatched.'),
                          backgroundColor: ok ? AppColors.success : AppColors.primary,
                        ),
                      );
                    }
                  },
                  icon: const Icon(LucideIcons.printer, size: 16),
                  label: const Text('Direct Print to Hardware'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
