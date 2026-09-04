import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/printing_service.dart';
import '../../admin/widgets/thermal_receipt_print_preview_dialog.dart';

class PrinterSettingsDialog extends StatefulWidget {
  final String branchName;
  final String tillNumber;

  const PrinterSettingsDialog({
    super.key,
    required this.branchName,
    required this.tillNumber,
  });

  @override
  State<PrinterSettingsDialog> createState() => _PrinterSettingsDialogState();
}

class _PrinterSettingsDialogState extends State<PrinterSettingsDialog> {
  final PrintingService _printingService = PrintingService.instance;
  List<Printer> _printers = [];
  bool _isLoadingPrinters = true;
  bool _isTestingPrint = false;

  late bool _autoPrint;
  String? _selectedPrinterName;
  String? _selectedPrinterUrl;
  late int _paperWidthMm;
  late int _copies;
  late bool _showQrCode;

  @override
  void initState() {
    super.initState();
    _autoPrint = _printingService.autoPrintEnabled;
    _selectedPrinterName = _printingService.selectedPrinterName;
    _paperWidthMm = _printingService.paperWidthMm;
    _copies = _printingService.copies;
    _showQrCode = _printingService.showQrCode;

    _scanForPrinters();
  }

  Future<void> _scanForPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final found = await _printingService.getAvailablePrinters();
    if (mounted) {
      setState(() {
        _printers = found;
        _isLoadingPrinters = false;
        if (_selectedPrinterName == null && found.isNotEmpty) {
          _selectedPrinterName = found.first.name;
          _selectedPrinterUrl = found.first.url;
        }
      });
    }
  }

  Future<void> _saveAndClose() async {
    await _printingService.saveSettings(
      autoPrint: _autoPrint,
      printerName: _selectedPrinterName,
      printerUrl: _selectedPrinterUrl,
      paperWidthMm: _paperWidthMm,
      copies: _copies,
      showQrCode: _showQrCode,
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_autoPrint
              ? 'Auto-print configured to "$_selectedPrinterName" (Fast Mode ON)!'
              : 'Printer settings saved.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _runTestPrint() async {
    final testSale = {
      'receiptNo': 'TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'dateTime': DateTime.now(),
      'cashier': 'System Self-Test',
      'storeName': 'HIRALL POS TEST',
      'branchName': widget.branchName,
      'tillNumber': widget.tillNumber,
      'items': [
        {
          'name': 'Thermal Printhead Test Item',
          'unitPrice': 100.0,
          'costPrice': 80.0,
          'quantity': 1.0,
          'taxRate': 16.0,
        },
      ],
      'subtotal': 100.0,
      'discount': 0.0,
      'tax': 16.0,
      'total': 100.0,
      'paymentMethod': 'CASH',
      'amountPaid': 100.0,
      'change': 0.0,
      'mpesaCode': null,
    };

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPrintPreviewDialog(
        saleData: testSale,
        paperWidthMm: _paperWidthMm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: Container(
        width: 540,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
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
                        child: const Icon(LucideIcons.printer, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thermal Printer Configuration',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            'Configure high-speed receipt auto-print on checkout',
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
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary(context)),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border(context)),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Auto-print toggle card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _autoPrint
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : (isDark ? AppColors.darkCard : const Color(0xFFF9F9F7)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _autoPrint ? AppColors.primary : AppColors.border(context),
                          width: _autoPrint ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _autoPrint ? LucideIcons.zap : LucideIcons.printerCheck,
                            size: 24,
                            color: _autoPrint ? AppColors.primary : AppColors.textSecondary(context),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Instant Auto-Print on Checkout',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dispatches receipt to thermal printer immediately without popup dialogs (Fast POS mode)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _autoPrint,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _autoPrint = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Printer Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONNECTED THERMAL PRINTER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        InkWell(
                          onTap: _scanForPrinters,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.refreshCw, size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Refresh Scan',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingPrinters)
                      Container(
                        padding: const EdgeInsets.all(20),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (_printers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : const Color(0xFFF9F9F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle, size: 20, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No hardware printer found. App will use system print queue / virtual thermal preview.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : const Color(0xFFF9F9F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Column(
                          children: _printers.map((p) {
                            final isSelected = p.name == _selectedPrinterName;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedPrinterName = p.name;
                                  _selectedPrinterUrl = p.url;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.printer,
                                      size: 18,
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary(context),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              color: isSelected ? AppColors.primary : AppColors.textPrimary(context),
                                            ),
                                          ),
                                          if (p.model != null && p.model!.isNotEmpty)
                                            Text(
                                              p.model!,
                                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(LucideIcons.checkCircle, size: 18, color: AppColors.primary),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Paper Width and Copies
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RECEIPT PAPER WIDTH',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSegmentButton(
                                      label: '80mm Standard',
                                      isSelected: _paperWidthMm == 80,
                                      onTap: () => setState(() => _paperWidthMm = 80),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSegmentButton(
                                      label: '58mm Compact',
                                      isSelected: _paperWidthMm == 58,
                                      onTap: () => setState(() => _paperWidthMm = 58),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'COPIES PER SALE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSegmentButton(
                                      label: '1 Copy',
                                      isSelected: _copies == 1,
                                      onTap: () => setState(() => _copies = 1),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildSegmentButton(
                                      label: '2 Copies (Dual)',
                                      isSelected: _copies == 2,
                                      onTap: () => setState(() => _copies = 2),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // QR Code toggle
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _showQrCode,
                      activeColor: AppColors.primary,
                      title: Text(
                        'Include Digital E-Receipt QR Verification Code',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                      ),
                      subtitle: Text(
                        'Prints a scannable QR code at the bottom of the receipt for customer invoice lookup',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                      ),
                      onChanged: (val) => setState(() => _showQrCode = val ?? true),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.border(context)),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _isTestingPrint ? null : _runTestPrint,
                    icon: _isTestingPrint
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(LucideIcons.printer, size: 16),
                    label: const Text('Test Print Receipt'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveAndClose,
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Save & Apply Settings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isDark ? AppColors.darkCard : const Color(0xFFF9F9F7)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textPrimary(context),
          ),
        ),
      ),
    );
  }
}
