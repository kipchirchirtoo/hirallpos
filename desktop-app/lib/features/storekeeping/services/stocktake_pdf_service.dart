import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';

class StocktakePdfService {
  static const PdfColor navyBlue = PdfColor.fromInt(0xFF1E3A8A);
  static const PdfColor lightNavy = PdfColor.fromInt(0xFFDBEAFE);
  static const PdfColor headerGrey = PdfColor.fromInt(0xFFF1F5F9);
  static const PdfColor borderGrey = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor darkGrey = PdfColor.fromInt(0xFF475569);
  static const PdfColor greenAccent = PdfColor.fromInt(0xFF059669);

  /// Generates a Landscape Physical Store Stocktake & Inventory Audit Sheet
  static Future<Uint8List> generateStocktakePdf({
    required String organizationName,
    required String branchName,
    required String cycle,
    required List<Map<String, dynamic>> catalog,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')} Sep ${now.year}';
    final refNumber = 'STK-${branchName.replaceAll(' ', '').toUpperCase()}-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    double totalValuation = 0;
    int totalSystemUnits = 0;
    for (var item in catalog) {
      final stock = (item['stock'] as num?)?.toInt() ?? 0;
      final cost = (item['cost'] as num?)?.toDouble() ?? 0.0;
      totalSystemUnits += stock;
      totalValuation += stock * cost;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Top Organization & Audit Title
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        organizationName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: navyBlue,
                          letterSpacing: 0.8,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'BRANCH STORE: ${branchName.toUpperCase()} | PHYSICAL STORE INVENTORY AUDIT SHEET',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: darkGrey,
                        ),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: lightNavy,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      border: pw.Border.all(color: navyBlue, width: 0.8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'AUDIT REF: $refNumber',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                        ),
                        pw.Text(
                          'SCHEDULE: $cycle | DATE: $dateStr',
                          style: const pw.TextStyle(fontSize: 7.5, color: darkGrey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // Auditor Metadata Ribbon
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: headerGrey,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: borderGrey, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Lead Stock Auditor: ___________________________', style: const pw.TextStyle(fontSize: 7.5, color: darkGrey)),
                    pw.Text('Supervisor / Manager: ___________________________', style: const pw.TextStyle(fontSize: 7.5, color: darkGrey)),
                    pw.Text('Store Aisle Range: [ ALL SECTIONS / CHILLERS ]', style: const pw.TextStyle(fontSize: 7.5, color: darkGrey)),
                    pw.Text('Audit Status: PHYSICAL RECONCILIATION', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.8, color: borderGrey),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount} | Physical Store Inventory Sheet ($dateStr)',
                    style: const pw.TextStyle(fontSize: 7, color: darkGrey),
                  ),
                  pw.Text(
                    'Powered By HirallSystems | www.hirall.com',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: navyBlue,
                      letterSpacing: 0.4,
                    ),
                  ),
                  pw.Text(
                    'Branch: $branchName (Giftmart Supermarket)',
                    style: const pw.TextStyle(fontSize: 7, color: darkGrey),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Landscape Item Audit Table
            pw.Table(
              border: pw.TableBorder.all(color: borderGrey, width: 0.8),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.6), // #
                1: const pw.FlexColumnWidth(1.8), // SKU Code
                2: const pw.FlexColumnWidth(1.8), // Barcode / EAN
                3: const pw.FlexColumnWidth(3.8), // Description & Location
                4: const pw.FlexColumnWidth(1.6), // Category
                5: const pw.FlexColumnWidth(0.9), // UoM
                6: const pw.FlexColumnWidth(1.3), // System Stock
                7: const pw.FlexColumnWidth(2.2), // PHYSICAL COUNT BOX
                8: const pw.FlexColumnWidth(1.4), // Variance (+/-)
                9: const pw.FlexColumnWidth(2.2), // Remarks / Expiry
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: navyBlue),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('#', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('SKU CODE', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('BARCODE / EAN', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('PRODUCT NAME & AISLE LOCATION', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('CATEGORY', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('UOM', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('SYSTEM STOCK', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('PHYSICAL COUNT', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('VARIANCE', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('AUDITOR NOTES', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                  ],
                ),

                // Data Rows
                ...catalog.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  final sku = item['sku'] ?? '-';
                  final barcode = item['barcode'] ?? '-';
                  final name = item['name'] ?? 'Product Name';
                  final location = item['location'] ?? 'Store Floor';
                  final category = item['category'] ?? 'General';
                  final unit = item['unit'] ?? 'PCS';
                  final stock = (item['stock'] as num?)?.toInt() ?? 0;
                  final isEven = idx % 2 == 0;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isEven ? headerGrey : PdfColors.white),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(idx.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(sku.toString(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(barcode.toString(), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(name.toString(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Loc: $location', style: const pw.TextStyle(fontSize: 6.5, color: darkGrey)),
                          ],
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(category.toString(), style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(unit.toString(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          '$stock $unit',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      // Physical Count Write-in Box (Dashed / Bordered Box for Pen Entry)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(2),
                        child: pw.Container(
                          height: 18,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(color: navyBlue, width: 0.8),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                          child: pw.Center(
                            child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                          ),
                        ),
                      ),
                      // Variance Line
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(child: pw.Text('[    ]', style: const pw.TextStyle(fontSize: 7, color: borderGrey))),
                      ),
                      // Remarks
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('', style: const pw.TextStyle(fontSize: 7)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // Summary & Sign-off Section
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Summary Box
                pw.Container(
                  width: 280,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: headerGrey,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: borderGrey, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AUDIT SUMMARY & SYSTEM VALUATION',
                        style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: navyBlue),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total Catalog SKUs Listed:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('${catalog.length} Items', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total System Units:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('$totalSystemUnits Units', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Book Inventory Valuation:', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text(Formatters.formatCurrency(totalValuation), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: greenAccent)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Sign-off Box
                pw.Container(
                  width: 440,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: borderGrey, width: 0.8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('COUNT VERIFIED BY (AUDITOR):', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            pw.SizedBox(height: 14),
                            pw.Text('Signature: ______________________', style: const pw.TextStyle(fontSize: 7)),
                            pw.SizedBox(height: 2),
                            pw.Text('Date / Time: ____________________', style: const pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('RECONCILIATION APPROVED (MANAGER):', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: navyBlue)),
                            pw.SizedBox(height: 14),
                            pw.Text('Signature: ______________________', style: const pw.TextStyle(fontSize: 7)),
                            pw.SizedBox(height: 2),
                            pw.Text('Date / Time: ____________________', style: const pw.TextStyle(fontSize: 7)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Displays the interactive Landscape Stocktake PDF Preview dialog
  static void showPdfPreviewDialog({
    required BuildContext context,
    required String organizationName,
    required String branchName,
    required String cycle,
    required List<Map<String, dynamic>> catalog,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          width: 1040,
          height: 680,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 5)],
          ),
          child: Column(
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.fileSpreadsheet, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'PHYSICAL STOCKTAKE AUDIT SHEET (LANDSCAPE) - $branchName',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(LucideIcons.x, size: 18, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // PDF Preview in Landscape
              Expanded(
                child: PdfPreview(
                  build: (format) => generateStocktakePdf(
                    organizationName: organizationName,
                    branchName: branchName,
                    cycle: cycle,
                    catalog: catalog,
                  ),
                  allowPrinting: true,
                  allowSharing: true,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  initialPageFormat: PdfPageFormat.a4.landscape,
                  pdfFileName: 'Stocktake_Audit_Sheet_${branchName.replaceAll(' ', '_')}_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}.pdf',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
