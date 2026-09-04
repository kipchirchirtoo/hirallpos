import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../models/cart_item.dart';

class SupervisorVoidDialog extends StatefulWidget {
  final CartItem? item;
  final bool isTransactionVoid;
  final int totalItemCount;
  final double totalAmount;
  final VoidCallback onAuthorized;

  const SupervisorVoidDialog({
    super.key,
    this.item,
    this.isTransactionVoid = false,
    this.totalItemCount = 0,
    this.totalAmount = 0.0,
    required this.onAuthorized,
  });

  @override
  State<SupervisorVoidDialog> createState() => _SupervisorVoidDialogState();
}

class _SupervisorVoidDialogState extends State<SupervisorVoidDialog> {
  final _pinOrBarcodeController = TextEditingController();
  final _pinFocusNode = FocusNode();
  String? _errorMessage;
  String _selectedReason = 'Wrong Item Scanned';
  bool _isLoading = false;

  final List<String> _reasons = [
    'Wrong Item Scanned',
    'Customer Changed Mind',
    'Damaged / Defective Goods',
    'Price Mismatch / Dispute',
    'Duplicate Barcode Scan',
    'Test / Training Sale',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinOrBarcodeController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _verifySupervisorAuth(String input) {
    final code = input.trim();
    if (code.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Validate Supervisor PIN (e.g. 4-digit PIN like 1234, 2222, 0000, 9999) or Scanned Badge (e.g. SUP-*, MGR-*, BADGE-*)
    final isPinValid = RegExp(r'^\d{4}$').hasMatch(code);
    final isBadgeValid = code.length >= 4;

    if (isPinValid || isBadgeValid) {
      widget.onAuthorized();
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid Supervisor PIN or Scanned Badge. Minimum 4 characters required.';
        _pinOrBarcodeController.clear();
      });
      _pinFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border(context), width: 1.5),
      ),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Security Shield Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(LucideIcons.shieldAlert, color: AppColors.danger, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isTransactionVoid ? 'Supervisor Void Transaction' : 'Supervisor Void Item',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manager / Supervisor authorization required',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(LucideIcons.x, size: 18, color: AppColors.textMuted(context)),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Item / Transaction Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: widget.isTransactionVoid
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('VOID ENTIRE REGISTER SALE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.danger, letterSpacing: 0.5)),
                            const SizedBox(height: 2),
                            Text('${widget.totalItemCount} Scanned Items in Basket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                          ],
                        ),
                        Text(
                          Formatters.formatCurrency(widget.totalAmount),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.danger),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.item?.name ?? 'Item',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Barcode: ${widget.item?.barcode.isNotEmpty == true ? widget.item!.barcode : 'Generic'} • Qty: ${widget.item?.quantity.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(widget.item?.netTotal ?? 0),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.danger),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 18),

            // Void Reason Selector
            Text('Void Audit Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              dropdownColor: AppColors.surface(context),
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedReason = val);
              },
            ),

            const SizedBox(height: 18),

            // Supervisor Auth Input (Scan Badge or Type 4-Digit PIN)
            Text('Scan Supervisor Badge OR Enter 4-Digit PIN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary(context))),
            const SizedBox(height: 8),
            TextField(
              controller: _pinOrBarcodeController,
              focusNode: _pinFocusNode,
              autofocus: true,
              obscureText: true,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                hintText: '•••• (or scan badge barcode)',
                hintStyle: TextStyle(letterSpacing: 0, fontSize: 13, color: AppColors.textMuted(context)),
                prefixIcon: const Icon(LucideIcons.lockKeyhole, color: AppColors.primary, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(LucideIcons.arrowRightCircle, color: AppColors.primary),
                  onPressed: () => _verifySupervisorAuth(_pinOrBarcodeController.text),
                ),
              ),
              onSubmitted: _verifySupervisorAuth,
              onChanged: (val) {
                if (val.length == 4 && RegExp(r'^\d{4}$').hasMatch(val)) {
                  _verifySupervisorAuth(val);
                }
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.danger),
              ),
            ],

            const SizedBox(height: 24),

            // Bottom Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel (Esc)'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _verifySupervisorAuth(_pinOrBarcodeController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(LucideIcons.shieldCheck, size: 16),
                  label: const Text('Authorize & Void', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
