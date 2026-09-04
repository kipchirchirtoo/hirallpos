import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/mobile_theme.dart';
import '../../../core/services/mobile_bridge_client.dart';

class BarcodeGunScreen extends StatefulWidget {
  const BarcodeGunScreen({super.key});

  @override
  State<BarcodeGunScreen> createState() => _BarcodeGunScreenState();
}

class _BarcodeGunScreenState extends State<BarcodeGunScreen> {
  late final MobileScannerController _scannerController;

  final List<Map<String, dynamic>> _scanHistory = [];
  final _manualInputController = TextEditingController();
  bool _isContinuous = true;
  bool _isTorchOn = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue?.trim();
      if (code != null && code.isNotEmpty) {
        // Debounce exact duplicates within 1.2s if continuous mode
        if (_lastScannedCode == code &&
            _lastScanTime != null &&
            DateTime.now().difference(_lastScanTime!).inMilliseconds < 1200) {
          continue;
        }

        _handleScannedCode(code);
        break;
      }
    }
  }

  Future<void> _handleScannedCode(String code) async {
    _lastScannedCode = code;
    _lastScanTime = DateTime.now();

    // Haptic Feedback
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);

    final isSent = await MobileBridgeClient.instance.sendBarcode(code);

    setState(() {
      _scanHistory.insert(0, {
        'code': code,
        'timestamp': DateTime.now(),
        'sent': isSent,
      });
    });
  }

  void _submitManualCode() {
    final code = _manualInputController.text.trim();
    if (code.isNotEmpty) {
      _handleScannedCode(code);
      _manualInputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = MobileBridgeClient.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wireless Barcode Gun', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? LucideIcons.zapOff : LucideIcons.zap),
            tooltip: 'Flashlight',
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: 'Clear Scan History',
            onPressed: () => setState(() => _scanHistory.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Header Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isConnected ? MobileAppColors.success.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
            child: Row(
              children: [
                Icon(
                  isConnected ? LucideIcons.wifi : LucideIcons.wifiOff,
                  size: 14,
                  color: isConnected ? MobileAppColors.success : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Connected to Desktop (${MobileBridgeClient.instance.hostIp}:${MobileBridgeClient.instance.port}) · Ready to Scan'
                        : 'Desktop Not Connected. Tap "Connect" tab to pair via QR code.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? MobileAppColors.success : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Camera Viewfinder (45% of height)
          Expanded(
            flex: 45,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Container(
                      color: const Color(0xFF111827),
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.cameraOff, color: Colors.amber, size: 36),
                            const SizedBox(height: 8),
                            const Text(
                              'Camera Stream Inactive',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use Quick Barcode chips below, type code, or click Retry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MobileAppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  icon: const Icon(LucideIcons.refreshCw, size: 14),
                                  label: const Text('Retry Camera', style: TextStyle(fontSize: 11.5)),
                                  onPressed: () => _scannerController.start(),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Colors.white24),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  icon: const Icon(LucideIcons.switchCamera, size: 14),
                                  label: const Text('Switch Cam', style: TextStyle(fontSize: 11.5)),
                                  onPressed: () => _scannerController.switchCamera(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Viewfinder Reticle
                Container(
                  width: 280,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: MobileAppColors.primary, width: 2.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Container(
                      height: 1.5,
                      width: double.infinity,
                      color: Colors.redAccent.withOpacity(0.8),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _lastScannedCode != null ? 'Last Scan: $_lastScannedCode' : 'Align Barcode Inside Red Line',
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Manual Entry & Actions Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: MobileAppColors.surface(context),
              border: Border(top: BorderSide(color: MobileAppColors.border(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualInputController,
                    keyboardType: TextInputType.text,
                    onSubmitted: (_) => _submitManualCode(),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Type code manually or test (e.g. 616110)...',
                      prefixIcon: Icon(LucideIcons.scanBarcode, size: 18),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MobileAppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  ),
                  icon: const Icon(LucideIcons.send, size: 14),
                  label: const Text('Send', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: _submitManualCode,
                ),
              ],
            ),
          ),

          // Live Scan History Feed (55% of height)
          Expanded(
            flex: 55,
            child: Container(
              color: MobileAppColors.bg(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transmitted Scans (${_scanHistory.length})',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        // Quick demo barcode buttons
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildQuickChip('Milk 500ml', '616110123456'),
                            _buildQuickChip('Pembe 2kg', '616110987654'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  Expanded(
                    child: _scanHistory.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.scanBarcode, size: 40, color: MobileAppColors.textSecondary(context)),
                                const SizedBox(height: 8),
                                Text(
                                  'Ready to scan products on shelves.\nScanned codes stream straight to Desktop POS.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: MobileAppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _scanHistory.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = _scanHistory[index];
                              final code = item['code'] as String;
                              final time = item['timestamp'] as DateTime;
                              final sent = item['sent'] as bool;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: MobileAppColors.card(context),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: MobileAppColors.border(context)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: MobileAppColors.primary.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(LucideIcons.barcode, size: 16, color: MobileAppColors.primary),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            code,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}',
                                            style: TextStyle(fontSize: 10, color: MobileAppColors.textSecondary(context)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (sent ? MobileAppColors.success : Colors.orange).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            sent ? LucideIcons.checkCheck : LucideIcons.clock,
                                            size: 12,
                                            color: sent ? MobileAppColors.success : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            sent ? 'Desktop Synced' : 'Queued',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: sent ? MobileAppColors.success : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String code) {
    return ActionChip(
      visualDensity: VisualDensity.compact,
      label: Text(label, style: const TextStyle(fontSize: 10.5)),
      onPressed: () => _handleScannedCode(code),
    );
  }
}
