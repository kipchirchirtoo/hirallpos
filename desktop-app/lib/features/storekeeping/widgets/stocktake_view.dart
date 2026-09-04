import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../services/stocktake_pdf_service.dart';

class StocktakeView extends StatefulWidget {
  final String branchName;
  final String organizationName;
  final List<Map<String, dynamic>> catalog;
  final Function(Map<String, dynamic> updatedProduct)? onInventoryChanged;

  const StocktakeView({
    super.key,
    required this.branchName,
    this.organizationName = 'GIFTMART SUPERMARKET',
    required this.catalog,
    this.onInventoryChanged,
  });

  @override
  State<StocktakeView> createState() => _StocktakeViewState();
}

class _StocktakeViewState extends State<StocktakeView> {
  String _configuredCycle = 'Weekly (Sundays)';
  String _searchQuery = '';
  final Map<String, TextEditingController> _countControllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant StocktakeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.catalog.length != oldWidget.catalog.length) {
      _initControllers();
    }
  }

  void _initControllers() {
    for (var item in widget.catalog) {
      final sku = item['sku'] as String;
      if (!_countControllers.containsKey(sku)) {
        final stock = (item['stock'] as num).toInt();
        _countControllers[sku] = TextEditingController(text: stock.toString());
      }
    }
  }

  @override
  void dispose() {
    for (var c in _countControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _openConfigCycleDialog() {
    String selected = _configuredCycle;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border(context))),
          title: Row(
            children: [
              const Icon(LucideIcons.calendarClock, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'CONFIGURE STOCKTAKE CYCLE',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set the mandatory inventory audit schedule for ${widget.branchName}:',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 14),
              RadioListTile<String>(
                title: const Text('Weekly (Every Sunday Close)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Recommended for fast-moving supermarkets & grocery aisles', style: TextStyle(fontSize: 11)),
                value: 'Weekly (Sundays)',
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
              RadioListTile<String>(
                title: const Text('Bi-Weekly (Every 14 Days)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: 'Bi-Weekly (14 Days)',
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
              RadioListTile<String>(
                title: const Text('Monthly (End of Month Reconciliation)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Required for corporate financial statements & audit trail', style: TextStyle(fontSize: 11)),
                value: 'Monthly (End of Month)',
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
              RadioListTile<String>(
                title: const Text('Custom / Ad-Hoc Spot Checks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: 'Ad-Hoc Spot Check',
                groupValue: selected,
                onChanged: (val) => setDialogState(() => selected = val!),
              ),
            ],
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () {
                setState(() => _configuredCycle = selected);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Stocktake cycle updated to "$_configuredCycle" for ${widget.branchName}!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('SAVE CYCLE'),
            ),
          ],
        ),
      ),
    );
  }

  void _commitStocktake() {
    int adjustedCount = 0;
    double netVarianceValue = 0;

    for (var item in widget.catalog) {
      final sku = item['sku'] as String;
      final controller = _countControllers[sku];
      if (controller != null) {
        final physicalCount = double.tryParse(controller.text) ?? (item['stock'] as num).toDouble();
        final currentStock = (item['stock'] as num).toDouble();
        final diff = physicalCount - currentStock;

        if (diff.abs() > 0.001) {
          adjustedCount++;
          netVarianceValue += diff * (item['cost'] as num).toDouble();
          item['stock'] = physicalCount;
          item['lastReceived'] = 'Audited in Stocktake ($diff)';
          widget.onInventoryChanged?.call(item);
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Stocktake committed! $adjustedCount items reconciled (Net Variance: ${Formatters.formatCurrency(netVarianceValue)}).'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanCatalog = widget.catalog.where((e) {
      final sku = (e['sku'] ?? '').toString().toUpperCase();
      final id = (e['id'] ?? '').toString().toUpperCase();
      final name = (e['name'] ?? '').toString().toLowerCase();
      return !(sku.startsWith('GM-') ||
          id.startsWith('PROD-00') ||
          name.contains('brookside') ||
          name.contains('pembe') ||
          name.contains('fresh fri') ||
          name.contains('broadway') ||
          name.contains('kasuku'));
    }).toList();

    final filtered = cleanCatalog.where((item) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return (item['name'] as String).toLowerCase().contains(q) ||
          (item['sku'] as String).toLowerCase().contains(q) ||
          (item['barcode'] as String).contains(q);
    }).toList();

    int totalVariances = 0;
    double totalVarianceKES = 0;

    for (var item in cleanCatalog) {
      final sku = item['sku'] as String;
      final controller = _countControllers[sku];
      if (controller != null) {
        final physicalCount = double.tryParse(controller.text) ?? (item['stock'] as num).toDouble();
        final currentStock = (item['stock'] as num).toDouble();
        final diff = physicalCount - currentStock;
        if (diff.abs() > 0.001) {
          totalVariances++;
          totalVarianceKES += diff * (item['cost'] as num).toDouble();
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Schedule Ribbon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                    child: const Icon(LucideIcons.clipboardCheck, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('ACTIVE STOCK AUDIT SHEET', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.textPrimary(context))),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              'CYCLE: $_configuredCycle',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Count physical store shelf items vs system stock • Variances reconcile automatically', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary(context))),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onPressed: () {
                      StocktakePdfService.showPdfPreviewDialog(
                        context: context,
                        organizationName: widget.organizationName,
                        branchName: widget.branchName,
                        cycle: _configuredCycle,
                        catalog: cleanCatalog,
                      );
                    },
                    icon: const Icon(LucideIcons.printer, size: 15, color: AppColors.primary),
                    label: const Text('Download / Print Sheet (PDF)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onPressed: _openConfigCycleDialog,
                    icon: const Icon(LucideIcons.settings2, size: 14),
                    label: const Text('Configure Schedule', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _commitStocktake,
                    icon: const Icon(LucideIcons.checkCheck, size: 16),
                    label: const Text('Commit Reconciliation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar & Summary
        Row(
          children: [
            Expanded(
              flex: 4,
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Search audit list by product name, SKU, or barcode...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: totalVariances > 0 ? AppColors.warning.withValues(alpha: 0.12) : AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: totalVariances > 0 ? AppColors.warning : AppColors.success),
              ),
              child: Text(
                'Live Variance: $totalVariances items (${Formatters.formatCurrency(totalVarianceKES)})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: totalVariances > 0 ? AppColors.warning : AppColors.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stocktake Table
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
                          Icon(LucideIcons.clipboardCheck, size: 48, color: AppColors.textMuted(context)),
                          const SizedBox(height: 12),
                          Text('No Products Available for Stocktake', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 4),
                          Text('Add products in Master Inventory or receive goods via GRN first.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final sku = item['sku'] as String;
                        final controller = _countControllers[sku] ?? TextEditingController(text: (item['stock'] as num).toInt().toString());

                        final expectedStock = (item['stock'] as num).toDouble();
                        final physicalCount = double.tryParse(controller.text) ?? expectedStock;
                        final diff = physicalCount - expectedStock;
                        final varianceKES = diff * (item['cost'] as num).toDouble();

                        Color statusColor = AppColors.success;
                        String statusText = 'MATCH';
                        if (diff < 0) {
                          statusColor = AppColors.danger;
                          statusText = 'SHORTAGE';
                        } else if (diff > 0) {
                          statusColor = AppColors.primary;
                          statusText = 'SURPLUS';
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            children: [
                              // Product Details
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] as String, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                              Text('SKU: $sku • ${item['shelf']}', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),

                        // System Expected Stock
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('System Stock', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
                              Text(
                                '${expectedStock.toStringAsFixed(0)} ${item['unit']}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ),

                        // Physical Count Input
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Physical Count *', style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Variance Qty & Valuation
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(0)} ${item['unit']}',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: statusColor),
                              ),
                              Text(
                                Formatters.formatCurrency(varianceKES),
                                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: statusColor),
                              ),
                            ],
                          ),
                        ),

                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: statusColor),
                          ),
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
