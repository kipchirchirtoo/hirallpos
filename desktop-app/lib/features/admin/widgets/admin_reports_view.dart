import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/printing_service.dart';

class AdminReportsView extends StatefulWidget {
  final String organizationName;
  final String currentBranchName;

  const AdminReportsView({
    super.key,
    required this.organizationName,
    required this.currentBranchName,
  });

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  String _selectedBranchScope = 'global'; // 'global' | 'kericho' | 'nairobi' | 'westlands'
  String _selectedDateRange = 'today'; // 'today' | 'yesterday' | 'week' | 'month'

  // Dynamic Sales Metrics based on Branch Scope
  Map<String, dynamic> _getReportMetrics() {
    final isGlobal = _selectedBranchScope == 'global';
    final multiplier = _selectedDateRange == 'today'
        ? 1.0
        : (_selectedDateRange == 'yesterday'
            ? 0.92
            : (_selectedDateRange == 'week' ? 6.4 : 26.5));

    final baseGross = isGlobal ? 489420.0 : 248500.0;
    final baseOrders = isGlobal ? 284 : 146;

    final gross = baseGross * multiplier;
    final discount = (gross * 0.024);
    final net = gross - discount;
    final vat = net * (16.0 / 116.0);
    final orders = (baseOrders * multiplier).toInt();
    final avgBasket = orders > 0 ? gross / orders : 0.0;

    final mpesa = gross * 0.62;
    final cash = gross * 0.31;
    final card = gross * 0.07;

    return {
      'grossSales': gross,
      'netSales': net,
      'discount': discount,
      'vatCollected': vat,
      'ordersCount': orders,
      'avgBasket': avgBasket,
      'mpesaSales': mpesa,
      'cashSales': cash,
      'cardSales': card,
      'mpesaPct': 62,
      'cashPct': 31,
      'cardPct': 7,
    };
  }

  final List<Map<String, dynamic>> _topSellingProducts = [];

  Future<void> _printSummaryReport() async {
    final metrics = _getReportMetrics();
    final branchTitle = _selectedBranchScope == 'global' ? 'ALL BRANCHES (GLOBAL ORG)' : widget.currentBranchName;

    final reportSale = {
      'storeName': widget.organizationName,
      'branchName': branchTitle,
      'tillNumber': 'REPORT-AUDIT',
      'receiptNo': 'RPT-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      'cashier': 'Store Administrator',
      'dateTime': DateTime.now(),
      'items': _topSellingProducts.map((p) => {
        'id': p['name'],
        'name': p['name'],
        'unitPrice': (p['revenue'] as double) / (p['units'] as int),
        'quantity': (p['units'] as int).toDouble(),
        'taxRate': 16.0,
      }).toList(),
      'subtotal': metrics['grossSales'],
      'discount': metrics['discount'],
      'tax': metrics['vatCollected'],
      'total': metrics['grossSales'],
      'paymentMethod': 'SUMMARY (M-PESA/CASH/CARD)',
      'amountPaid': metrics['grossSales'],
      'change': 0.0,
      'mpesaCode': 'AUDIT-SUMMARY-${_selectedDateRange.toUpperCase()}',
    };

    final ok = await PrintingService.instance.printReceipt(reportSale, silent: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Financial Summary Report dispatched to thermal printer!'
              : 'Failed to print report.'),
          backgroundColor: ok ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _getReportMetrics();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Branch Scope Selector
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedBranchScope,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.surface(context),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                      items: [
                        const DropdownMenuItem(value: 'global', child: Text('🌐 Global Org (All Branches Aggregate)')),
                        DropdownMenuItem(value: 'kericho', child: Text('🏬 Kericho Branch (${widget.currentBranchName})')),
                        const DropdownMenuItem(value: 'nairobi', child: Text('🏬 Nairobi Hypermarket (HQ)')),
                        const DropdownMenuItem(value: 'westlands', child: Text('🏬 Westlands Express Outlet')),
                      ],
                      onChanged: (val) => setState(() => _selectedBranchScope = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Date Range Segmented
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      children: [
                        _buildDatePill('today', 'Today'),
                        _buildDatePill('yesterday', 'Yesterday'),
                        _buildDatePill('week', 'Last 7 Days'),
                        _buildDatePill('month', 'This Month'),
                      ],
                    ),
                  ),
                ],
              ),

              // Export / Print Branded Report Button
              ElevatedButton.icon(
                onPressed: _printSummaryReport,
                icon: const Icon(LucideIcons.printer, size: 16),
                label: const Text('Print Branded Report'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Primary Financial KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'GROSS STORE REVENUE',
                  value: Formatters.formatCurrency(metrics['grossSales'] as double),
                  subtitle: '+14.2% vs previous period',
                  icon: LucideIcons.trendingUp,
                  iconColor: AppColors.primary,
                  isPositive: true,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: '16% VAT COLLECTED',
                  value: Formatters.formatCurrency(metrics['vatCollected'] as double),
                  subtitle: 'KRA eTIMS Fiscal Tax',
                  icon: LucideIcons.receipt,
                  iconColor: const Color(0xFF0EA5E9),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'CHECKOUT TRANSACTIONS',
                  value: '${metrics['ordersCount']} receipts',
                  subtitle: 'Avg: ${Formatters.formatCurrency(metrics['avgBasket'] as double)} / basket',
                  icon: LucideIcons.shoppingBag,
                  iconColor: AppColors.success,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildMetricCard(
                  title: 'M-PESA REVENUE SHARE',
                  value: Formatters.formatCurrency(metrics['mpesaSales'] as double),
                  subtitle: '${metrics['mpesaPct']}% of total tenders',
                  icon: LucideIcons.smartphone,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Payment Tender Breakdown & Velocity Chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Breakdown Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Tender Distribution',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time breakdown of customer payment channels',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                      ),
                      const SizedBox(height: 20),

                      // M-Pesa Row
                      _buildTenderRow(
                        name: 'Safaricom M-Pesa STK Push',
                        amount: metrics['mpesaSales'] as double,
                        pct: metrics['mpesaPct'] as int,
                        color: const Color(0xFF10B981),
                        icon: LucideIcons.smartphone,
                      ),
                      const SizedBox(height: 14),

                      // Cash Row
                      _buildTenderRow(
                        name: 'Till Cash Drawer',
                        amount: metrics['cashSales'] as double,
                        pct: metrics['cashPct'] as int,
                        color: AppColors.primary,
                        icon: LucideIcons.banknote,
                      ),
                      const SizedBox(height: 14),

                      // Card Row
                      _buildTenderRow(
                        name: 'Visa / Mastercard Terminal',
                        amount: metrics['cardSales'] as double,
                        pct: metrics['cardPct'] as int,
                        color: const Color(0xFF8B5CF6),
                        icon: LucideIcons.creditCard,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Top 10 High Velocity SKUs
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top Velocity Supermarket SKUs',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                              ),
                              Text(
                                'Highest volume products rung up across till registers',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Top 6 Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _topSellingProducts.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(LucideIcons.shoppingBag, size: 36, color: AppColors.textMuted(context)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No Sales Transactions Recorded Yet',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Top-selling items and margins will populate as checkout orders are processed.',
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Table(
                              columnWidths: const {
                                0: FlexColumnWidth(4),
                                1: FlexColumnWidth(2),
                                2: FlexColumnWidth(2.5),
                                3: FlexColumnWidth(1.5),
                              },
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: AppColors.border(context))),
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('PRODUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('UNITS', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('REVENUE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Text('MARGIN', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                                ..._topSellingProducts.map((p) => TableRow(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(p['name'] as String, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text('${p['units']} sold', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(Formatters.formatCurrency(p['revenue'] as double), textAlign: TextAlign.right, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(p['margin'] as String, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                                    ),
                                  ],
                                )),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatePill(String key, String label) {
    final isSelected = _selectedDateRange == key;
    return InkWell(
      onTap: () => setState(() => _selectedDateRange = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    bool? isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.8),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isPositive == true ? AppColors.success : AppColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenderRow({
    required String name,
    required double amount,
    required int pct,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                ),
              ],
            ),
            Text(
              '${Formatters.formatCurrency(amount)} ($pct%)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100.0,
            minHeight: 6,
            backgroundColor: AppColors.border(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
