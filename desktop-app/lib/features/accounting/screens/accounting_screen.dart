import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class AccountingScreen extends StatefulWidget {
  final String branchName;
  const AccountingScreen({super.key, this.branchName = 'Central Branch'});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _AccountingScreenState extends State<AccountingScreen> {
  final List<Map<String, dynamic>> _expenses = [];

  void _openAddExpenseDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCat = 'Petty Cash';
    String selectedMethod = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: AppColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border(context))),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Log Branch Expense / Petty Cash', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedCat,
                  dropdownColor: AppColors.surface(context),
                  decoration: const InputDecoration(labelText: 'Expense Category'),
                  items: const [
                    DropdownMenuItem(value: 'Petty Cash', child: Text('Petty Cash')),
                    DropdownMenuItem(value: 'Utilities', child: Text('Utilities (Water/Power)')),
                    DropdownMenuItem(value: 'Supplies', child: Text('Store Supplies')),
                    DropdownMenuItem(value: 'Salaries', child: Text('Casual Wage Payout')),
                    DropdownMenuItem(value: 'Maintenance', child: Text('Equipment Maintenance')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedCat = val!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Electricity token'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (KES)', hintText: 'e.g. 2500'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        final amt = double.tryParse(amountController.text) ?? 0.0;
                        if (amt > 0 && descController.text.trim().isNotEmpty) {
                          setState(() {
                            _expenses.insert(0, {
                              'category': selectedCat,
                              'desc': descController.text.trim(),
                              'amount': amt,
                              'method': selectedMethod,
                              'time': Formatters.formatTime(DateTime.now()),
                            });
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Expense logged: ${descController.text.trim()} (KES $amt)'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                      child: const Text('Save Expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReconciliationDialog() {
    final cashController = TextEditingController(text: '0');
    final mpesaController = TextEditingController(text: '0');
    final cardController = TextEditingController(text: '0');
    const double expected = 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cash = double.tryParse(cashController.text) ?? 0.0;
          final mpesa = double.tryParse(mpesaController.text) ?? 0.0;
          final card = double.tryParse(cardController.text) ?? 0.0;
          final actual = cash + mpesa + card;
          final variance = actual - expected;

          return Dialog(
            backgroundColor: AppColors.surface(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.border(context))),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('End of Shift Till Reconciliation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                  const SizedBox(height: 6),
                  Text('Count physical cash in drawer, M-Pesa statements, and card receipts.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cashController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(labelText: 'Physical Cash Count', prefixIcon: Icon(LucideIcons.banknote, size: 18)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: mpesaController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setDialogState(() {}),
                          decoration: const InputDecoration(labelText: 'M-Pesa Statement Total', prefixIcon: Icon(LucideIcons.smartphone, size: 18)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cardController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(labelText: 'Card / PDQ Terminal Total', prefixIcon: Icon(LucideIcons.creditCard, size: 18)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Expected System Total:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                            Text(Formatters.formatCurrency(expected), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Actual Count Total:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                            Text(Formatters.formatCurrency(actual), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ],
                        ),
                        Divider(height: 16, color: AppColors.border(context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Variance (Over / Short):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                            Text(
                              Formatters.formatCurrency(variance),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: variance >= 0 ? AppColors.success : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Shift Till Reconciled & Logged!')),
                          );
                        },
                        child: const Text('Confirm & Close Shift'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double grossSales = 0.0;
    const double vatCollected = 0.0;
    final double totalExpenses = _expenses.fold(0.0, (sum, e) => sum + (e['amount'] as double));
    final double netProfit = grossSales - vatCollected - totalExpenses;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Accounting & Daily Financials', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                    Text('Branch: ${widget.branchName} • Live System P&L', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openReconciliationDialog,
                      icon: const Icon(LucideIcons.scale, size: 16),
                      label: const Text('Till Reconciliation'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _openAddExpenseDialog,
                      icon: const Icon(LucideIcons.receipt, size: 18),
                      label: const Text('Log Expense'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // KPI Summary Cards
            Row(
              children: [
                _buildKpiCard('Gross Revenue (Today)', Formatters.formatCurrency(grossSales), LucideIcons.trendingUp, AppColors.primary),
                const SizedBox(width: 16),
                _buildKpiCard('VAT 16% Collected', Formatters.formatCurrency(vatCollected), LucideIcons.percent, AppColors.info),
                const SizedBox(width: 16),
                _buildKpiCard('Total Expenses', Formatters.formatCurrency(totalExpenses), LucideIcons.arrowDownRight, AppColors.danger),
                const SizedBox(width: 16),
                _buildKpiCard('Estimated Net Margin', Formatters.formatCurrency(netProfit), LucideIcons.dollarSign, AppColors.success),
              ],
            ),
            const SizedBox(height: 28),
            // Expense Log Table
            Text('Daily Expense & Petty Cash Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _expenses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.receipt, size: 40, color: AppColors.textMuted(context)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Expenses Logged Today',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Record petty cash payouts, utility tokens, and vendor invoices.',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _openAddExpenseDialog,
                                  icon: const Icon(LucideIcons.plus, size: 16),
                                  label: const Text('Log First Expense'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                    itemCount: _expenses.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border(context)),
                    itemBuilder: (context, index) {
                      final exp = _expenses[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.bg(context), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(LucideIcons.receipt, color: AppColors.accent, size: 20),
                        ),
                        title: Text(exp['desc'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary(context), fontSize: 14)),
                        subtitle: Text('${exp['category']} • Paid via ${exp['method']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '-${Formatters.formatCurrency(exp['amount'] as num)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger, fontSize: 14),
                            ),
                            Text(exp['time'] as String, style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
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
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context))),
          ],
        ),
      ),
    );
  }
}
