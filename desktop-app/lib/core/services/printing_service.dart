import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/formatters.dart';
import '../../features/cashier/models/cart_item.dart';

class PrintingService {
  static final PrintingService _instance = PrintingService._internal();
  static PrintingService get instance => _instance;

  PrintingService._internal();

  bool _autoPrintEnabled = true;
  String? _selectedPrinterName;
  String? _selectedPrinterUrl;
  int _paperWidthMm = 80;
  int _copies = 1;
  bool _showQrCode = true;

  bool get autoPrintEnabled => _autoPrintEnabled;
  String? get selectedPrinterName => _selectedPrinterName;
  int get paperWidthMm => _paperWidthMm;
  int get copies => _copies;
  bool get showQrCode => _showQrCode;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoPrintEnabled = prefs.getBool('printer_auto_print') ?? true;
      _selectedPrinterName = prefs.getString('printer_name');
      _selectedPrinterUrl = prefs.getString('printer_url');
      _paperWidthMm = prefs.getInt('printer_paper_width_mm') ?? 80;
      _copies = prefs.getInt('printer_copies') ?? 1;
      _showQrCode = prefs.getBool('printer_show_qr') ?? true;
    } catch (e) {
      debugPrint('PrintingService init error: $e');
    }
  }

  Future<void> saveSettings({
    required bool autoPrint,
    String? printerName,
    String? printerUrl,
    required int paperWidthMm,
    required int copies,
    required bool showQrCode,
  }) async {
    _autoPrintEnabled = autoPrint;
    _selectedPrinterName = printerName;
    _selectedPrinterUrl = printerUrl;
    _paperWidthMm = paperWidthMm;
    _copies = copies;
    _showQrCode = showQrCode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('printer_auto_print', autoPrint);
    if (printerName != null) {
      await prefs.setString('printer_name', printerName);
    } else {
      await prefs.remove('printer_name');
    }
    if (printerUrl != null) {
      await prefs.setString('printer_url', printerUrl);
    } else {
      await prefs.remove('printer_url');
    }
    await prefs.setInt('printer_paper_width_mm', paperWidthMm);
    await prefs.setInt('printer_copies', copies);
    await prefs.setBool('printer_show_qr', showQrCode);
  }

  /// Get list of all discovered system / network printers
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      debugPrint('Error listing printers: $e');
      return [];
    }
  }

  /// Blazing-fast background auto-print for POS checkout (non-blocking)
  Future<bool> autoPrintReceipt(Map<String, dynamic> saleData) async {
    if (!_autoPrintEnabled) return false;

    // Run printing asynchronously so cashier UI stays at 60+ FPS
    return _dispatchPrintJob(saleData, silent: true);
  }

  /// Manual print or re-print
  Future<bool> printReceipt(Map<String, dynamic> saleData, {bool silent = false}) async {
    return _dispatchPrintJob(saleData, silent: silent);
  }

  Future<bool> _dispatchPrintJob(Map<String, dynamic> saleData, {required bool silent}) async {
    final int widthMm = (saleData['paperWidthMm'] as int?) ?? _paperWidthMm;
    final pageFormat = widthMm == 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;
    final String docTitle = 'Receipt_${saleData['receiptNo'] ?? '001'}';

    try {
      final pdfBytes = await generateThermalReceiptPdf(saleData, paperWidthMm: widthMm, showQr: _showQrCode);
      final printers = await getAvailablePrinters();

      Printer? targetPrinter;
      if (_selectedPrinterUrl != null && _selectedPrinterUrl!.isNotEmpty) {
        final matches = printers.where((p) => p.url == _selectedPrinterUrl);
        if (matches.isNotEmpty) {
          targetPrinter = matches.first;
        }
      }

      if (targetPrinter == null && _selectedPrinterName != null && _selectedPrinterName!.isNotEmpty) {
        final matches = printers.where((p) => p.name == _selectedPrinterName);
        if (matches.isNotEmpty) {
          targetPrinter = matches.first;
        }
      }

      if (targetPrinter == null && printers.isNotEmpty) {
        // Auto-select first available thermal / POS printer if discovered
        final posMatches = printers.where(
          (p) =>
              p.name.toLowerCase().contains('pos') ||
              p.name.toLowerCase().contains('thermal') ||
              p.name.toLowerCase().contains('receipt') ||
              p.name.toLowerCase().contains('80') ||
              p.name.toLowerCase().contains('58'),
        );
        targetPrinter = posMatches.isNotEmpty ? posMatches.first : printers.first;
      }

      // If silent background print requested (checkout auto-print)
      if (silent) {
        if (targetPrinter != null) {
          for (int i = 0; i < _copies; i++) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              onLayout: (PdfPageFormat format) async => pdfBytes,
              name: docTitle,
              format: pageFormat,
            );
          }
          return true;
        }
        return false;
      }

      // If interactive / test print requested (!silent)
      if (targetPrinter != null) {
        try {
          for (int i = 0; i < _copies; i++) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              onLayout: (PdfPageFormat format) async => pdfBytes,
              name: docTitle,
              format: pageFormat,
            );
          }
          return true;
        } catch (directErr) {
          debugPrint('directPrintPdf failed, falling back to layoutPdf: $directErr');
        }
      }

      // Fallback to standard OS interactive print preview & printer selection
      return await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docTitle,
        format: pageFormat,
      );
    } catch (e) {
      debugPrint('Printing dispatch failed: $e');
      if (!silent) {
        try {
          final pdfBytes = await generateThermalReceiptPdf(saleData, paperWidthMm: widthMm, showQr: _showQrCode);
          return await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: docTitle,
            format: pageFormat,
          );
        } catch (inner) {
          debugPrint('Fallback layoutPdf error: $inner');
        }
      }
      return false;
    }
  }

  /// Print a fast hardware test receipt to calibrate cutter and margins
  Future<bool> printTestReceipt({required String branchName, required String tillNumber}) async {
    final testSale = {
      'receiptNo': 'TEST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'dateTime': DateTime.now(),
      'cashier': 'System Self-Test',
      'storeName': 'HIRALL POS TEST',
      'branchName': branchName,
      'tillNumber': tillNumber,
      'items': [
        CartItem(
          id: 'test-1',
          name: 'Thermal Printhead Test Item',
          unitPrice: 100.0,
          costPrice: 80.0,
          quantity: 1.0,
          taxRate: 16.0,
        ),
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
    return _dispatchPrintJob(testSale, silent: false);
  }

  /// Sanitizes text to avoid non-ASCII Unicode crashes in standard Helvetica PDF fonts
  static String sanitizePdfText(String text) {
    var s = text
        .replaceAll('•', '|')
        .replaceAll('★', '*')
        .replaceAll('⚡', '*')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'");
    return s.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  /// Build compact, high-contrast ESC/POS-optimized thermal receipt PDF
  Future<Uint8List> generateThermalReceiptPdf(
    Map<String, dynamic> saleData, {
    int paperWidthMm = 80,
    bool showQr = true,
  }) async {
    final doc = pw.Document();

    final String storeName = sanitizePdfText(saleData['storeName'] ?? 'GIFTMART SUPERMARKET');
    final String branchName = sanitizePdfText(saleData['branchName'] ?? 'KERICHO');
    final String branchTagline = sanitizePdfText(saleData['branchTagline'] ?? '$branchName SUPERMARKET & HYPER STORE');
    final String taxPin = sanitizePdfText(saleData['taxPin'] ?? 'P051234567Z');
    final String etrNote = sanitizePdfText(saleData['etrNote'] ?? 'KRA eTIMS VALIDATED FISCAL RECEIPT');
    final String building = sanitizePdfText(saleData['building'] ?? 'Famous Gate Plaza, Ground Floor');
    final String street = sanitizePdfText(saleData['street'] ?? 'Kenyatta Road');
    final String city = sanitizePdfText(saleData['city'] ?? 'Kericho, Kenya');
    final String phone = sanitizePdfText(saleData['phone'] ?? '+254 711 000 111');
    final String emailWeb = sanitizePdfText(saleData['emailWeb'] ?? 'info@giftmart.co.ke | www.giftmart.co.ke');

    final bool festiveEnabled = saleData['festiveEnabled'] == true;
    final String festiveHeader = sanitizePdfText(saleData['festiveHeader'] ?? '* FESTIVE GREETINGS *');
    final String festiveFooter = sanitizePdfText(saleData['festiveFooter'] ?? 'Thank you for celebrating with us!');

    final String activeSide = saleData['activeSide'] ?? 'front';
    final bool backLogoEnabled = saleData['backLogoEnabled'] ?? true;
    final String backPromotionTitle = sanitizePdfText(saleData['backPromotionTitle'] ?? 'SPECIAL PROMOTIONAL VOUCHER');
    final String backPromotionBody = sanitizePdfText(saleData['backPromotionBody'] ?? 'Get 10% OFF your next purchase of KES 2,500 or more!');
    final String backReturnPolicy = sanitizePdfText(saleData['backReturnPolicy'] ?? 'Goods once sold are exchangeable within 7 days with original receipt.');
    final String backWarrantyTerms = sanitizePdfText(saleData['backWarrantyTerms'] ?? '1. Electrical appliances carry a 12-month manufacturer warranty.\n2. Fresh items must be inspected upon purchase.');

    final String tillNumber = sanitizePdfText(saleData['tillNumber'] ?? 'TILL-01');
    final String receiptNo = sanitizePdfText(saleData['receiptNo'] ?? 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    final String cashierName = sanitizePdfText(saleData['cashier'] ?? 'Active Cashier');
    final DateTime dateTime = saleData['dateTime'] ?? DateTime.now();

    final List<CartItem> items = [];
    if (saleData['items'] != null && saleData['items'] is List) {
      for (var i in (saleData['items'] as List)) {
        if (i is CartItem) {
          items.add(i);
        } else if (i is Map<String, dynamic>) {
          items.add(CartItem.fromMap(i));
        } else if (i is Map) {
          items.add(CartItem.fromMap(Map<String, dynamic>.from(i)));
        }
      }
    }

    final double subtotal = (saleData['subtotal'] as num?)?.toDouble() ?? 0.0;
    final double discount = (saleData['discount'] as num?)?.toDouble() ?? 0.0;
    final double total = (saleData['total'] as num?)?.toDouble() ?? 0.0;
    final double tax = (saleData['tax'] as num?)?.toDouble() ?? (total * 0.16 / 1.16);
    final String paymentMethod = sanitizePdfText((saleData['paymentMethod'] ?? 'CASH').toString().toUpperCase());
    final double amountPaid = (saleData['amountPaid'] as num?)?.toDouble() ?? total;
    final double change = (saleData['change'] as num?)?.toDouble() ?? 0.0;
    final String? mpesaCode = saleData['mpesaCode'] != null ? sanitizePdfText(saleData['mpesaCode'].toString()) : null;

    final bool showLogo = saleData['showLogo'] ?? true;
    final double logoWidth = (saleData['logoWidth'] as num?)?.toDouble() ?? 160.0;
    Uint8List? logoBytes = saleData['logoBytes'];

    if (logoBytes == null && saleData['logoBase64'] != null && saleData['logoBase64'].toString().isNotEmpty) {
      try {
        final clean = saleData['logoBase64'].toString().contains(',')
            ? saleData['logoBase64'].toString().split(',').last
            : saleData['logoBase64'].toString();
        final decoded = base64Decode(clean.trim());
        if (decoded.length >= 8 && (decoded[0] == 0x89 || decoded[0] == 0xFF || decoded[0] == 0x47 || (decoded.length >= 12 && decoded[0] == 0x52))) {
          logoBytes = decoded;
        }
      } catch (_) {}
    }

    if (logoBytes == null && showLogo) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedLogoBase64 = prefs.getString('receipt_logo_base64');
        if (savedLogoBase64 != null && savedLogoBase64.isNotEmpty) {
          final cleanBase64 = savedLogoBase64.contains(',') ? savedLogoBase64.split(',').last : savedLogoBase64;
          final decoded = base64Decode(cleanBase64.trim());
          if (decoded.length >= 8 && (decoded[0] == 0x89 || decoded[0] == 0xFF || decoded[0] == 0x47 || (decoded.length >= 12 && decoded[0] == 0x52))) {
            logoBytes = decoded;
          }
        }
      } catch (_) {}

      if (logoBytes == null) {
        try {
          if (File('/home/kipchir/giftmart.png').existsSync()) {
            logoBytes = await File('/home/kipchir/giftmart.png').readAsBytes();
          } else {
            final assetData = await rootBundle.load('assets/images/giftmart.png');
            logoBytes = assetData.buffer.asUint8List();
          }
        } catch (_) {}
      }
    }

    pw.MemoryImage? pwLogoImage;
    if (showLogo && logoBytes != null && logoBytes.isNotEmpty) {
      try {
        pwLogoImage = pw.MemoryImage(logoBytes);
      } catch (_) {
        try {
          if (File('/home/kipchir/giftmart.png').existsSync()) {
            final fb = File('/home/kipchir/giftmart.png').readAsBytesSync();
            pwLogoImage = pw.MemoryImage(fb);
          }
        } catch (_) {}
      }
    }

    final pageFormat = paperWidthMm == 58
        ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm)
        : const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm);

    // Render FRONT SIDE
    if (activeSide == 'front' || activeSide == 'both') {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  // Store Brand Logo
                  if (showLogo && pwLogoImage != null) ...[
                    pw.Image(
                      pwLogoImage,
                      width: (logoWidth / 2.2).clamp(30.0, 140.0),
                      fit: pw.BoxFit.contain,
                    ),
                    pw.SizedBox(height: 3),
                  ],

                  // Festive Header Banner
                  if (festiveEnabled) ...[
                    pw.Text(
                      festiveHeader,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.Divider(thickness: 0.6, height: 6),
                  ],

                  // Store Name & Header
                  pw.Text(
                    storeName.toUpperCase(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    branchTagline,
                    style: const pw.TextStyle(fontSize: 7.5),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (building.isNotEmpty || street.isNotEmpty)
                    pw.Text(
                      '$building${building.isNotEmpty && street.isNotEmpty ? ", " : ""}$street',
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (city.isNotEmpty)
                    pw.Text(
                      city,
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (phone.isNotEmpty)
                    pw.Text(
                      'TEL: $phone',
                      style: const pw.TextStyle(fontSize: 7),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (taxPin.isNotEmpty)
                    pw.Text(
                      'PIN: $taxPin',
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (etrNote.isNotEmpty)
                    pw.Text(
                      etrNote,
                      style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.center,
                    ),
                  pw.Divider(thickness: 0.8, height: 8),

                  // Receipt No, Date, Cashier info
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('RCPT: $receiptNo', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yy HH:mm').format(dateTime), style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Cashier: $cashierName', style: const pw.TextStyle(fontSize: 7.5)),
                      pw.Text('Lane: $tillNumber', style: const pw.TextStyle(fontSize: 7.5)),
                    ],
                  ),
                  pw.Divider(thickness: 0.8, height: 8),

                  // Item Header
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 5, child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 2, child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(flex: 3, child: pw.Text('AMOUNT', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.Divider(thickness: 0.5, height: 6),

                  // Scanned Cart Items
                  ...items.map((item) {
                    final cleanItemName = sanitizePdfText(item.name);
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 5,
                                child: pw.Text(
                                  cleanItemName,
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                              pw.Expanded(
                                flex: 2,
                                child: pw.Text(
                                  item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2),
                                  textAlign: pw.TextAlign.center,
                                  style: const pw.TextStyle(fontSize: 8),
                                ),
                              ),
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(
                                  item.netTotal.toStringAsFixed(2),
                                  textAlign: pw.TextAlign.right,
                                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (item.quantity > 1 || item.discountPercent > 0)
                            pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 4, top: 1),
                              child: pw.Text(
                                '@ KES ${item.unitPrice.toStringAsFixed(2)}${item.discountPercent > 0 ? " (Disc: ${item.discountPercent.toStringAsFixed(0)}%)" : ""}',
                                style: const pw.TextStyle(fontSize: 6.5),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  pw.Divider(thickness: 0.8, height: 8),

                  // Financial Summary
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SUBTOTAL:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('KES ${subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (discount > 0) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('DISCOUNT APPLIED:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('-KES ${discount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 1.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('16% VAT INCLUDED:', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('KES ${tax.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(height: 3),

                  // Total
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(width: 1),
                        bottom: pw.BorderSide(width: 1),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL AMOUNT:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('KES ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 3),

                  // Payment Breakdown
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('PAID VIA ($paymentMethod):', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('KES ${amountPaid.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  if (paymentMethod == 'CASH' && change > 0) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('CHANGE RETURNED:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text('KES ${change.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                  if (mpesaCode != null && mpesaCode.isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('M-PESA REF:', style: const pw.TextStyle(fontSize: 8)),
                        pw.Text(mpesaCode, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],

                  // Barcode
                  pw.SizedBox(height: 6),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: receiptNo,
                    width: paperWidthMm == 58 ? 120 : 150,
                    height: 28,
                    drawText: false,
                  ),
                  pw.SizedBox(height: 4),

                  if (festiveEnabled) ...[
                    pw.Text(festiveFooter, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 2),
                  ],

                  pw.Text('THANK YOU FOR SHOPPING WITH US!', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                  if (emailWeb.isNotEmpty) ...[
                    pw.SizedBox(height: 1),
                    pw.Text(emailWeb, style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.center),
                  ],
                  pw.SizedBox(height: 1),
                  pw.Text('Goods once sold exchangeable within 48h with receipt', style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 1),
                  pw.Text('Powered by HIRALL POS Cloud', style: const pw.TextStyle(fontSize: 5.5), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      );
    }

    // Render BACK SIDE
    if (activeSide == 'back' || activeSide == 'both') {
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (backLogoEnabled) ...[
                    pw.Text(storeName.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center),
                    pw.SizedBox(height: 1),
                    pw.Text('OFFICIAL STORE REVERSE GUARANTEE', style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                    pw.Divider(thickness: 0.8, height: 8),
                  ],

                  // Promotion Box
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
                    child: pw.Column(
                      children: [
                        pw.Text(backPromotionTitle, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                        pw.SizedBox(height: 2),
                        pw.Text(backPromotionBody, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  // Return Policy
                  pw.Text('RETURN & EXCHANGE POLICY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 2),
                  pw.Text(backReturnPolicy, style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 8),

                  // Terms & Conditions
                  pw.Text('TERMS & CONDITIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center),
                  pw.SizedBox(height: 2),
                  pw.Text(backWarrantyTerms, style: const pw.TextStyle(fontSize: 6.5), textAlign: pw.TextAlign.left),
                  pw.SizedBox(height: 8),

                  // QR Code
                  if (showQr) ...[
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: 'https://hirallpos.com/promotions',
                      width: 40,
                      height: 40,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Scan for customer club rewards & offers', style: const pw.TextStyle(fontSize: 6), textAlign: pw.TextAlign.center),
                  ],
                  pw.SizedBox(height: 6),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}
