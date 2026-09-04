import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../services/grn_pdf_service.dart';

class GrnHistoryView extends StatefulWidget {
  final String branchName;
  final String organizationName;

  const GrnHistoryView({
    super.key,
    required this.branchName,
    this.organizationName = 'GIFTMART SUPERMARKET',
  });

  @override
  State<GrnHistoryView> createState() => _GrnHistoryViewState();
}

class _GrnHistoryViewState extends State<GrnHistoryView> {
  String _searchQuery = '';
  String _selectedFilter = 'all';
  List<Map<String, dynamic>> _grnList = [];

  @override
  void initState() {
    super.initState();
    _loadGrns();
  }

  Future<void> _loadGrns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('hirall_branch_grns_${widget.branchName}');
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(saved);
        final filtered = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) {
              final id = (e['id'] ?? '').toString();
              return !(id == 'GRN-20260903-1092' || id == 'GRN-20260902-8871');
            })
            .toList();
        setState(() {
          _grnList = filtered;
        });
        await _persistGrns();
      } else {
        setState(() {
          _grnList = [];
        });
      }
    } catch (_) {
      setState(() {
        _grnList = [];
      });
    }
  }

  Future<void> _persistGrns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hirall_branch_grns_${widget.branchName}', jsonEncode(_grnList));
    } catch (_) {}
  }

  void _viewGrnManifest(Map<String, dynamic> grn) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border(context), width: 1.5)),
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'GRN MANIFEST: ${grn['grnNumber'] ?? grn['id']}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(LucideIcons.x, size: 18)),
                ],
              ),
              Text('Supplier: ${grn['supplierName']} • Date: ${grn['date']} • DN: ${grn['deliveryNoteNumber']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
              const SizedBox(height: 14),
              Divider(height: 1, color: AppColors.border(context)),
              const SizedBox(height: 14),

              // Items table
              Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: ((grn['items'] as List<dynamic>?) ?? []).length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                  itemBuilder: (context, idx) {
                    final item = grn['items'][idx];
                    final qty = item['qtyReceived'] ?? item['qty'] ?? 1;
                    final cost = item['unitCost'] ?? item['cost'] ?? 0.0;
                    final total = (qty as num) * (cost as num);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                              Text('SKU: ${item['sku']} • Unit Cost: ${Formatters.formatCurrency(cost)}', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary(context))),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '+$qty ${item['unit'] ?? "PCS"}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                              ),
                              Text(
                                Formatters.formatCurrency(total),
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      GrnPdfService.showPdfPreviewDialog(
                        context: context,
                        organizationName: widget.organizationName,
                        branchName: widget.branchName,
                        grn: grn,
                      );
                    },
                    icon: const Icon(LucideIcons.printer, size: 14, color: AppColors.primary),
                    label: const Text('PRINT / SAVE PDF', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _grnList.removeWhere((e) {
      final id = (e['id'] ?? '').toString();
      return id.startsWith('GRN-2026090');
    });

    double totalValuation = 0;
    int totalUnits = 0;

    for (var grn in _grnList) {
      totalValuation += (grn['totalAmount'] as num?)?.toDouble() ?? 0.0;
      for (var it in ((grn['items'] as List<dynamic>?) ?? [])) {
        totalUnits += ((it['qtyReceived'] ?? it['qty'] ?? 1) as num).toInt();
      }
    }

    final filtered = _grnList.where((grn) {
      final q = _searchQuery.toLowerCase();
      if (q.isNotEmpty) {
        final numMatch = (grn['grnNumber'] ?? grn['id'] ?? '').toString().toLowerCase().contains(q);
        final suppMatch = (grn['supplierName'] ?? '').toString().toLowerCase().contains(q);
        final dnMatch = (grn['deliveryNoteNumber'] ?? '').toString().toLowerCase().contains(q);
        if (!numMatch && !suppMatch && !dnMatch) return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Ribbon KPI Metrics
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.fileText, color: AppColors.primary, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL GRNS RECORDED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text('${_grnList.length} Receipts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.coins, color: Color(0xFF059669), size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECEIVED GOODS VALUE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text(Formatters.formatCurrency(totalValuation), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: const Icon(LucideIcons.boxes, color: AppColors.warning, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL UNITS INTAKE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textMuted(context))),
                        Text('$totalUnits Units', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Search & Filter Bar
        Row(
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Search GRN number, Supplier name, or Delivery Note...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // GRN List Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.receipt, size: 42, color: AppColors.textMuted(context)),
                          const SizedBox(height: 10),
                          Text('No Goods Received Notes Recorded', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 4),
                          Text('Receive goods from Purchase Orders or Central Warehouse dispatches to create GRNs.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                      itemBuilder: (context, index) {
                        final grn = filtered[index];
                        final grnNum = grn['grnNumber'] ?? grn['id'] ?? 'GRN';
                        final supp = grn['supplierName'] ?? 'Vendor';
                        final dn = grn['deliveryNoteNumber'] ?? '-';
                        final date = grn['date'] ?? 'Today';
                        final total = (grn['totalAmount'] as num?)?.toDouble() ?? 0.0;
                        final itemsCount = ((grn['items'] as List<dynamic>?) ?? []).length;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                ),
                                child: const Center(child: Icon(LucideIcons.receipt, color: AppColors.success, size: 18)),
                              ),
                              const SizedBox(width: 16),

                              // GRN Details
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(grnNum, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                                    Text('Supplier: $supp • DN #: $dn', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                                  ],
                                ),
                              ),

                              // Date & Valuation
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(Formatters.formatCurrency(total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.success)),
                                    Text('$itemsCount item line(s) • Received: $date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                                  ],
                                ),
                              ),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'POSTED',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.success),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // PDF / Print Action
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                onPressed: () {
                                  GrnPdfService.showPdfPreviewDialog(
                                    context: context,
                                    organizationName: widget.organizationName,
                                    branchName: widget.branchName,
                                    grn: grn,
                                  );
                                },
                                icon: const Icon(LucideIcons.printer, size: 14, color: AppColors.primary),
                                label: const Text('PDF / Print GRN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 8),

                              // Manifest View
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                                onPressed: () => _viewGrnManifest(grn),
                                icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
                                label: const Text('Manifest', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
