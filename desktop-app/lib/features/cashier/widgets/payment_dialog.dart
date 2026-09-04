import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';

class PaymentDialog extends StatefulWidget {
  final double totalAmount;
  final String branchName;
  final String tillNumber;
  final Function(String paymentMethod, double amountPaid, String? mpesaCode)? onPaymentSuccess;

  const PaymentDialog({
    super.key,
    required this.totalAmount,
    this.branchName = 'Main Branch',
    this.tillNumber = 'TILL-01',
    this.onPaymentSuccess,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _selectedMethod = 'cash'; // cash | mpesa | card | split
  
  // Cash
  final _cashGivenController = TextEditingController();
  double _changeDue = 0.0;

  // M-Pesa
  final _mpesaPhoneController = TextEditingController();
  bool _isMpesaSending = false;
  String? _mpesaReceipt;

  @override
  void initState() {
    super.initState();
    _cashGivenController.text = widget.totalAmount.toStringAsFixed(0);
    _calculateChange();
  }

  @override
  void dispose() {
    _cashGivenController.dispose();
    _mpesaPhoneController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final given = double.tryParse(_cashGivenController.text) ?? 0.0;
    setState(() {
      _changeDue = (given - widget.totalAmount).clamp(0.0, double.infinity);
    });
  }

  void _setExactCash(double amount) {
    _cashGivenController.text = amount.toStringAsFixed(0);
    _calculateChange();
  }

  void _addCash(double increment) {
    final current = double.tryParse(_cashGivenController.text) ?? 0.0;
    _cashGivenController.text = (current + increment).toStringAsFixed(0);
    _calculateChange();
  }

  Future<void> _sendMpesaStk() async {
    setState(() => _isMpesaSending = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isMpesaSending = false;
      _mpesaReceipt = 'QKJ${DateTime.now().millisecondsSinceEpoch.toString().substring(6, 12)}';
    });
  }

  void _completePayment() {
    final paid = double.tryParse(_cashGivenController.text) ?? widget.totalAmount;
    final mpesaCode = _mpesaReceipt ?? (_selectedMethod == 'mpesa' ? 'QKJ${DateTime.now().millisecondsSinceEpoch.toString().substring(6, 12)}' : null);

    if (widget.onPaymentSuccess != null) {
      widget.onPaymentSuccess!(_selectedMethod, paid, mpesaCode);
    } else {
      Navigator.of(context).pop({
        'payment_method': _selectedMethod,
        'amount_paid': paid,
        'change_due': _changeDue,
        'mpesa_receipt': mpesaCode,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.border(context)),
      ),
      child: Container(
        width: 640,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Complete Checkout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, color: AppColors.textMuted(context), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amount Due', style: TextStyle(fontSize: 15, color: AppColors.textSecondary(context), fontWeight: FontWeight.w600)),
                  Text(
                    Formatters.formatCurrency(widget.totalAmount),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Payment Method Tabs
            Row(
              children: [
                _buildMethodTab('cash', 'Cash', LucideIcons.banknote),
                const SizedBox(width: 10),
                _buildMethodTab('mpesa', 'M-Pesa STK', LucideIcons.smartphone, color: AppColors.mpesaGreen),
                const SizedBox(width: 10),
                _buildMethodTab('card', 'Card / POS', LucideIcons.creditCard),
                const SizedBox(width: 10),
                _buildMethodTab('split', 'Split Bill', LucideIcons.split),
              ],
            ),
            const SizedBox(height: 24),
            _buildMethodContent(),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _completePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMethod == 'mpesa' ? AppColors.mpesaGreen : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(LucideIcons.checkCheck, size: 20),
                    label: const Text('Confirm & Print Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTab(String method, String label, IconData icon, {Color? color}) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? (color ?? AppColors.primary).withValues(alpha: 0.15) : AppColors.card(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? (color ?? AppColors.primary) : AppColors.border(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? (color ?? AppColors.primary) : AppColors.textMuted(context), size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary(context) : AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMethodContent() {
    if (_selectedMethod == 'cash') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash Received (KES)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cashGivenController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _calculateChange(),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(LucideIcons.banknote, color: AppColors.primary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change Due (KES)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Text(
                        Formatters.formatCurrency(_changeDue),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _buildCashChip('Exact', () => _setExactCash(widget.totalAmount)),
              _buildCashChip('+100', () => _addCash(100)),
              _buildCashChip('+200', () => _addCash(200)),
              _buildCashChip('+500', () => _addCash(500)),
              _buildCashChip('+1,000', () => _addCash(1000)),
              _buildCashChip('+2,000', () => _addCash(2000)),
            ],
          ),
        ],
      );
    } else if (_selectedMethod == 'mpesa') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Safaricom M-Pesa Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary(context))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mpesaPhoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(LucideIcons.smartphone, color: AppColors.mpesaGreen),
                    hintText: '07XXXXXXXX',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isMpesaSending ? null : _sendMpesaStk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mpesaGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
                icon: _isMpesaSending
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(_isMpesaSending ? 'Sending...' : 'STK Push'),
              ),
            ],
          ),
          if (_mpesaReceipt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.mpesaGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.mpesaGreen),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle2, color: AppColors.mpesaGreen, size: 18),
                  const SizedBox(width: 10),
                  Text('M-Pesa Received! Receipt: $_mpesaReceipt', style: const TextStyle(color: AppColors.mpesaGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.creditCard, color: AppColors.primary, size: 24),
            const SizedBox(width: 14),
            Text('Swipe/Tap card on connected PDQ / bank terminal.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
          ],
        ),
      );
    }
  }

  Widget _buildCashChip(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
      backgroundColor: AppColors.card(context),
      side: BorderSide(color: AppColors.border(context)),
      onPressed: onTap,
    );
  }
}
