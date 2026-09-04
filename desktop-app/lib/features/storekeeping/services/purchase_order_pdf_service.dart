import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';

class PurchaseOrderPdfService {
  static Future<Uint8List> generatePurchaseOrderPdf({
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> po,
  }) async {
    final pdf = pw.Document();

    final poNumber = po['id'] ?? 'PO-2026-001';
    final date = po['date'] ?? '03 Sep 2026';
    final expectedDate = po['expectedDate'] ?? 'Tomorrow';
    final supplierName = po['supplierName'] ?? 'Vendor Supplier';
    final items = (po['items'] as List<dynamic>?) ?? [];
    final totalKES = (po['totalKES'] as num?)?.toDouble() ?? 0.0;
    final comments = po['comments'] ?? 'Please confirm receipt and dispatch by expected delivery date.';

    const navyBlue = PdfColor.fromInt(0xFF2A4365);
    const lightGrey = PdfColor.fromInt(0xFFF1F5F9);
    const darkGrey = PdfColor.fromInt(0xFF334155);
    const borderGrey = PdfColor.fromInt(0xFFCBD5E1);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. HEADER ROW
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Company Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        organizationName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: navyBlue,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('Commercial Street, Retail Plaza', style: const pw.TextStyle(fontSize: 9, color: darkGrey)),
                      pw.Text('$branchName Branch, Kenya', style: const pw.TextStyle(fontSize: 9, color: darkGrey)),
                      pw.Text('Phone: +254 700 111 222', style: const pw.TextStyle(fontSize: 9, color: darkGrey)),
                      pw.Text('Email: orders@${organizationName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.co.ke', style: const pw.TextStyle(fontSize: 9, color: darkGrey)),
                      pw.Text('Website: www.${organizationName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.co.ke', style: const pw.TextStyle(fontSize: 9, color: darkGrey)),
                    ],
                  ),

                  // PO Title & Date/PO Box
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'PURCHASE ORDER',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF4A709C),
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Table(
                        border: pw.TableBorder.all(color: borderGrey, width: 1),
                        children: [
                          pw.TableRow(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                color: lightGrey,
                                child: pw.Text('DATE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                child: pw.Text(date, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                          pw.TableRow(
                            children: [
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                color: lightGrey,
                                child: pw.Text('PO #', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey)),
                              ),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                child: pw.Text(poNumber, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // 2. VENDOR & SHIP TO SECTION
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Vendor Box
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: navyBlue,
                          child: pw.Text('VENDOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey)),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(supplierName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text('Accounts & Supply Division', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('Supplier Depot, Industrial Area', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('Nairobi / Regional Branch, Kenya', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('Phone: +254 722 000 000', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 18),

                  // Ship To Box
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: navyBlue,
                          child: pw.Text('SHIP TO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                        ),
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey)),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Storekeeper / Receiving Bay', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text('$organizationName - $branchName Branch', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('Main Loading Dock, Store Room 01', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('$branchName, Kenya', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                              pw.Text('Phone: +254 700 111 222', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 3. REQUISITIONER & SHIPPING TERMS BAR
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 1),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: navyBlue),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('REQUISITIONER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('SHIP VIA', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('F.O.B.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('SHIPPING TERMS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('Branch Storekeeper', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('Direct Supplier Delivery', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('Destination Store', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: pw.Text('Net 30 Days (Expected: $expectedDate)', style: const pw.TextStyle(fontSize: 8))),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 4. ITEMS TABLE
              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 1),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.5),
                  1: const pw.FlexColumnWidth(6),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(2.5),
                  4: const pw.FlexColumnWidth(2.8),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: navyBlue),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('ITEM # / SKU', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('UNIT PRICE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    ],
                  ),
                  ...items.map((item) {
                    final sku = item['sku'] ?? 'SKU-001';
                    final name = item['name'] ?? 'Product';
                    final qty = (item['qtyOrdered'] ?? item['qty'] ?? 1) as num;
                    final unitCost = (item['unitCost'] ?? item['cost'] ?? 0.0) as num;
                    final lineTotal = (item['total'] ?? (qty * unitCost)) as num;

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(sku.toString(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(name.toString(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(qty.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(Formatters.formatCurrency(unitCost), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(Formatters.formatCurrency(lineTotal), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  }),
                  // Pad blank rows to match template height if few items
                  if (items.length < 6)
                    ...List.generate(6 - items.length, (_) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: pw.Text('-')),
                        ],
                      );
                    }),
                ],
              ),
              pw.SizedBox(height: 12),

              // 5. COMMENTS & TOTALS ROW
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Comments Box
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: double.infinity,
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          color: borderGrey,
                          child: pw.Text('Comments or Special Instructions', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: darkGrey)),
                        ),
                        pw.Container(
                          width: double.infinity,
                          height: 70,
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: borderGrey)),
                          child: pw.Text(
                            comments,
                            style: const pw.TextStyle(fontSize: 8.5, color: darkGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14),

                  // Totals Box
                  pw.Expanded(
                    flex: 5,
                    child: pw.Table(
                      border: pw.TableBorder.all(color: borderGrey, width: 1),
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text(Formatters.formatCurrency(totalKES), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('TAX', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('0.00', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('SHIPPING', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('OTHER', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: darkGrey))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: pw.Text('-', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                          ],
                        ),
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFC7D2FE)),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                            pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: pw.Text(Formatters.formatCurrency(totalKES), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // 6. BOTTOM CONTACT & POWERED BY HIRALLSYSTEMS
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'If you have any questions about this purchase order, please contact [Branch Operations, +254 700 111 222, orders@${organizationName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}.co.ke]',
                      style: const pw.TextStyle(fontSize: 7.5, color: darkGrey),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Powered By HirallSystems | www.hirall.com',
                      style: pw.TextStyle(
                        fontSize: 8.5,
                        fontWeight: pw.FontWeight.bold,
                        color: navyBlue,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printOrSavePurchaseOrder({
    required BuildContext context,
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> po,
  }) async {
    final pdfBytes = await generatePurchaseOrderPdf(
      organizationName: organizationName,
      branchName: branchName,
      po: po,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${po['id'] ?? "PO"}_${organizationName.replaceAll(' ', '_')}.pdf',
    );
  }

  static void showPdfPreviewDialog({
    required BuildContext context,
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> po,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 860,
          height: 720,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PURCHASE ORDER PREVIEW - ${po['id']}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Colors.black87),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => generatePurchaseOrderPdf(
                    organizationName: organizationName,
                    branchName: branchName,
                    po: po,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: '${po['id']}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
