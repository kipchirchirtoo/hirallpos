import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';

class GrnPdfService {
  static Future<Uint8List> generateGrnPdf({
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> grn,
  }) async {
    final pdf = pw.Document();

    final grnNumber = grn['grnNumber'] ?? grn['id'] ?? 'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final dateOfReceipt = grn['date'] ?? '03 Sep 2026';
    final deliveryNoteNumber = grn['deliveryNoteNumber'] ?? grn['deliveryNote'] ?? 'DN-2026-001';
    final deliveryDate = grn['deliveryDate'] ?? dateOfReceipt;
    final carrierDriverName = grn['carrierDriverName'] ?? grn['carrier'] ?? 'Direct Supplier Logistics';
    
    final supplierName = grn['supplierName'] ?? 'Vendor / Supplier';
    final supplierAddress = grn['supplierAddress'] ?? 'Industrial Area, Regional Depot';
    final supplierContact = grn['supplierContact'] ?? '+254 700 000 000';

    final receivedByName = grn['receivedByName'] ?? 'Stock Manager (STOREKEEPER)';
    final receivingDepartment = grn['receivingDepartment'] ?? 'Receiving Bay - $branchName Branch';
    
    final items = (grn['items'] as List<dynamic>?) ?? [];
    final totalAmount = (grn['totalAmount'] as num?)?.toDouble() ?? 0.0;
    int totalItemsCount = 0;
    for (var it in items) {
      totalItemsCount += ((it['quantityReceived'] ?? it['qtyReceived'] ?? it['qty'] ?? 1) as num).toInt();
    }

    final receivedCondition = grn['condition'] ?? 'Good Condition - Seal Verified & Inspected';
    final comments = grn['comments'] ?? 'All items verified against delivery note and stocked into shelf inventory.';

    const navyBlue = PdfColor.fromInt(0xFF0F3A78);
    const lightGrey = PdfColor.fromInt(0xFFF8FAFC);
    const headerGrey = PdfColor.fromInt(0xFFE2E8F0);
    const darkGrey = PdfColor.fromInt(0xFF334155);
    const borderGrey = PdfColor.fromInt(0xFF94A3B8);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. HEADER TITLE
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      organizationName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: navyBlue,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'GOODS RECEIVED NOTE',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Container(
                      height: 2,
                      width: double.infinity,
                      color: PdfColors.black,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // 2. GRN NUMBER & DATE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'GRN NUMBER: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.TextSpan(text: grnNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(text: 'DATE: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.TextSpan(text: dateOfReceipt, style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 3. DELIVERY INFORMATION & SUPPLIER INFORMATION
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Delivery Information
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DELIVERY INFORMATION:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('DELIVERY NOTE NUMBER: $deliveryNoteNumber', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                        pw.Text('DELIVERY DATE: $deliveryDate', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                        pw.Text('CARRIER/DRIVER NAME: $carrierDriverName', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Right: Supplier Information
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SUPPLIER INFORMATION:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('SUPPLIER NAME: $supplierName', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                        pw.Text('SUPPLIER ADDRESS: $supplierAddress', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                        pw.Text('SUPPLIER CONTACT: $supplierContact', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),

              // 4. RECEIVED BY
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RECEIVED BY:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 3),
                  pw.Text('Name: $receivedByName', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                  pw.Text('Receiving Department: $receivingDepartment', style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                ],
              ),
              pw.SizedBox(height: 12),

              // 5. RECEIVED ITEMS TABLE
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
                color: navyBlue,
                child: pw.Center(
                  child: pw.Text(
                    'RECEIVED ITEMS',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 1),
                  ),
                ),
              ),

              pw.Table(
                border: pw.TableBorder.all(color: borderGrey, width: 0.8),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.2), // Item / SKU
                  1: const pw.FlexColumnWidth(4.5), // Description
                  2: const pw.FlexColumnWidth(2.0), // Unit of Measure
                  3: const pw.FlexColumnWidth(2.0), // Qty Ordered
                  4: const pw.FlexColumnWidth(2.0), // Qty Received
                  5: const pw.FlexColumnWidth(2.2), // Unit Price
                  6: const pw.FlexColumnWidth(2.5), // Total Price
                },
                children: [
                  // Table Column Headers
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: headerGrey),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('DESCRIPTION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('UNIT OF MEASURE', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('QUANTITY ORDERED', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('QUANTITY RECEIVED', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('UNIT PRICE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('TOTAL PRICE', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  // Table Rows
                  ...items.map((it) {
                    final sku = it['sku'] ?? 'SKU-001';
                    final name = it['name'] ?? 'Item Name';
                    final unit = it['unit'] ?? 'PCS';
                    final qtyOrdered = (it['qtyOrdered'] ?? it['quantityOrdered'] ?? it['qtyReceived'] ?? 1) as num;
                    final qtyReceived = (it['qtyReceived'] ?? it['quantityReceived'] ?? it['qty'] ?? 1) as num;
                    final unitPrice = (it['unitCost'] ?? it['cost'] ?? it['price'] ?? 0.0) as num;
                    final totalPrice = (it['total'] ?? (qtyReceived * unitPrice)) as num;

                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sku.toString(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(name.toString(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(unit.toString(), style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(qtyOrdered.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(qtyReceived.toString(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(Formatters.formatCurrency(unitPrice), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(Formatters.formatCurrency(totalPrice), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      ],
                    );
                  }),
                  // Pad empty rows if fewer than 5 items
                  if (items.length < 5)
                    ...List.generate(5 - items.length, (_) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('-')),
                        ],
                      );
                    }),
                ],
              ),
              pw.SizedBox(height: 6),

              // 6. TOTAL ITEMS & TOTAL AMOUNT BOX
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 240,
                  child: pw.Table(
                    border: pw.TableBorder.all(color: borderGrey, width: 0.8),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            color: headerGrey,
                            child: pw.Text('TOTAL ITEMS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            child: pw.Text('$totalItemsCount Units', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            color: headerGrey,
                            child: pw.Text('TOTAL AMOUNT', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            color: lightGrey,
                            child: pw.Text(Formatters.formatCurrency(totalAmount), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(height: 12),

              // 7. RECEIVED CONDITION
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('RECEIVED CONDITION:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(receivedCondition, style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                  pw.SizedBox(height: 4),
                  pw.Container(height: 0.8, color: borderGrey),
                ],
              ),
              pw.SizedBox(height: 12),

              // 8. COMMENTS
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('COMMENTS:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text(comments, style: const pw.TextStyle(fontSize: 8.5, color: darkGrey)),
                  pw.SizedBox(height: 4),
                  pw.Container(height: 0.5, color: borderGrey),
                  pw.SizedBox(height: 4),
                  pw.Container(height: 0.5, color: borderGrey),
                  pw.SizedBox(height: 4),
                  pw.Container(height: 0.5, color: borderGrey),
                ],
              ),
              pw.Spacer(),

              // 9. BOTTOM FOOTER BRANDING: Powered By HirallSystems | www.hirall.com
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Goods received into $branchName store stock and verified against invoice / delivery note.',
                      style: const pw.TextStyle(fontSize: 7.5, color: darkGrey),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Powered By HirallSystems | www.hirall.com',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: navyBlue,
                        letterSpacing: 0.6,
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

  static Future<void> printOrSaveGrn({
    required BuildContext context,
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> grn,
  }) async {
    final pdfBytes = await generateGrnPdf(
      organizationName: organizationName,
      branchName: branchName,
      grn: grn,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${grn['grnNumber'] ?? "GRN"}_${organizationName.replaceAll(' ', '_')}.pdf',
    );
  }

  static void showPdfPreviewDialog({
    required BuildContext context,
    required String organizationName,
    required String branchName,
    required Map<String, dynamic> grn,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: 860,
          height: 740,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GOODS RECEIVED NOTE (GRN) - ${grn['grnNumber'] ?? grn['id']}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: Colors.black87),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const Divider(),
              Expanded(
                child: PdfPreview(
                  build: (format) => generateGrnPdf(
                    organizationName: organizationName,
                    branchName: branchName,
                    grn: grn,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName: '${grn['grnNumber'] ?? grn['id']}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
