import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/wireless_bridge_service.dart';

class MobilePairingDialog extends StatefulWidget {
  final String organizationName;
  final String branchName;

  const MobilePairingDialog({
    super.key,
    required this.organizationName,
    required this.branchName,
  });

  @override
  State<MobilePairingDialog> createState() => _MobilePairingDialogState();
}

class _MobilePairingDialogState extends State<MobilePairingDialog> {
  final List<String> _recentScans = [];
  late Map<String, dynamic> _pairingPayload;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _initBridge();
  }

  Future<void> _initBridge() async {
    if (!WirelessBridgeService.instance.isRunning) {
      await WirelessBridgeService.instance.startServer();
    }
    _pairingPayload = WirelessBridgeService.instance.getPairingPayload(
      organizationName: widget.organizationName,
      branchName: widget.branchName,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final payloadJson = jsonEncode(WirelessBridgeService.instance.getPairingPayload(
      organizationName: widget.organizationName,
      branchName: widget.branchName,
    ));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 680,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border(context))),
                color: AppColors.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.smartphone, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mobile Companion & Wireless Scanner Hub',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Scan with Hirall Mobile App to pair camera scanner, floor stock-in & mobile POS',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<int>(
                    stream: WirelessBridgeService.instance.connectedDevicesCountStream,
                    initialData: WirelessBridgeService.instance.connectedDevicesCount,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      final isOnline = count > 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.success.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isOnline ? AppColors.success : Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isOnline ? AppColors.success : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isOnline ? '$count Device(s) Connected' : 'Waiting for Device',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isOnline ? AppColors.success : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: QR Code Display
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300, width: 2),
                          ),
                          child: BarcodeWidget(
                            barcode: Barcode.qrCode(),
                            data: payloadJson,
                            width: 220,
                            height: 220,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.bg(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(LucideIcons.wifi, size: 14, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                '${WirelessBridgeService.instance.localIp}:${WirelessBridgeService.instance.port}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: 'http://${WirelessBridgeService.instance.localIp}:${WirelessBridgeService.instance.port}'));
                                  setState(() => _isCopied = true);
                                  Future.delayed(const Duration(seconds: 2), () {
                                    if (mounted) setState(() => _isCopied = false);
                                  });
                                },
                                child: Icon(
                                  _isCopied ? LucideIcons.check : LucideIcons.copy,
                                  size: 14,
                                  color: _isCopied ? AppColors.success : AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Right Column: Instructions & Live Scan Stream
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Pair Your Smartphone:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStepRow('1', 'Connect your phone to the same WiFi network as this PC.'),
                        _buildStepRow('2', 'Open Hirall Mobile App and tap "Scan to Pair".'),
                        _buildStepRow('3', 'Point camera at the QR code on the left.'),
                        _buildStepRow('4', 'Use phone as Wireless Barcode Gun, Stock In tool, or Mobile Cashier!'),

                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 10),

                        Text(
                          'Live Wireless Scan Feed:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 110,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bg(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border(context)),
                          ),
                          child: StreamBuilder<String>(
                            stream: WirelessBridgeService.instance.barcodeStream,
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                                if (!_recentScans.contains(snapshot.data!)) {
                                  _recentScans.insert(0, snapshot.data!);
                                }
                              }

                              if (_recentScans.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No scans received yet.\nPoint your phone at any barcode to test.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted(context),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                itemCount: _recentScans.length,
                                separatorBuilder: (_, __) => const Divider(height: 6),
                                itemBuilder: (context, index) {
                                  final code = _recentScans[index];
                                  return Row(
                                    children: [
                                      const Icon(LucideIcons.scanBarcode, size: 14, color: AppColors.success),
                                      const SizedBox(width: 8),
                                      Text(
                                        code,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Dispatched to Desktop',
                                          style: TextStyle(fontSize: 9.5, color: AppColors.success, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: AppColors.border(context))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Hirall POS Wireless Zero-Config Bridge Engine',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Done / Close', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
