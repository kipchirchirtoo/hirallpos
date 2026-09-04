import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/mobile_theme.dart';
import '../../../core/services/mobile_bridge_client.dart';

class PairingScreen extends StatefulWidget {
  final VoidCallback? onPaired;

  const PairingScreen({super.key, this.onPaired});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8888');
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isManualMode = false;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _ipController.text = MobileBridgeClient.instance.hostIp;
    _portController.text = MobileBridgeClient.instance.port.toString();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isConnecting) return;
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processScannedPayload(rawValue);
        break;
      }
    }
  }

  Future<void> _processScannedPayload(String payload) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      String host = '127.0.0.1';
      int port = 8888;
      String token = '';
      String store = 'GIFTMART SUPERMARKET';
      String branch = 'KERICHO';

      if (payload.trim().startsWith('{')) {
        final data = jsonDecode(payload);
        host = data['host'] ?? data['ip'] ?? '127.0.0.1';
        port = int.tryParse(data['port'].toString()) ?? 8888;
        token = data['token'] ?? '';
        store = data['organization'] ?? data['store'] ?? 'GIFTMART SUPERMARKET';
        branch = data['branch'] ?? 'KERICHO';
      } else if (payload.contains(':')) {
        final parts = payload.split(':');
        host = parts[0];
        port = int.tryParse(parts[1]) ?? 8888;
      } else {
        host = payload.trim();
      }

      final success = await MobileBridgeClient.instance.connect(
        hostIp: host,
        port: port,
        token: token,
        store: store,
        branch: branch,
      );

      if (mounted) {
        setState(() => _isConnecting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 Connected to $store ($host:$port)'),
              backgroundColor: MobileAppColors.success,
            ),
          );
          widget.onPaired?.call();
        } else {
          setState(() {
            _errorMessage = 'Could not connect to $host:$port. Make sure both devices are on the same WiFi.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _errorMessage = 'Invalid QR code format: $e';
        });
      }
    }
  }

  Future<void> _connectManual() async {
    final host = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8888;
    if (host.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid Desktop IP address');
      return;
    }

    await _processScannedPayload('$host:$port');
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = MobileBridgeClient.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair with Desktop POS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isManualMode ? LucideIcons.qrCode : LucideIcons.keyboard),
            tooltip: _isManualMode ? 'Scan QR Code' : 'Manual IP Entry',
            onPressed: () => setState(() => _isManualMode = !_isManualMode),
          ),
          if (!_isManualMode)
            IconButton(
              icon: const Icon(LucideIcons.zap),
              tooltip: 'Toggle Flashlight',
              onPressed: () => _scannerController.toggleTorch(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Connection Banner Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isConnected
                  ? MobileAppColors.success.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              border: Border(bottom: BorderSide(color: isConnected ? MobileAppColors.success : Colors.orange)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isConnected ? MobileAppColors.success : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isConnected
                        ? 'Paired: ${MobileBridgeClient.instance.storeName} (${MobileBridgeClient.instance.hostIp}:${MobileBridgeClient.instance.port})'
                        : 'Not Paired. Point camera at Desktop QR code to connect.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? MobileAppColors.success : Colors.orange,
                    ),
                  ),
                ),
                if (isConnected)
                  TextButton(
                    onPressed: () async {
                      await MobileBridgeClient.instance.disconnect();
                      setState(() {});
                    },
                    child: const Text('Disconnect', style: TextStyle(color: MobileAppColors.danger, fontSize: 11)),
                  ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MobileAppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MobileAppColors.danger),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, color: MobileAppColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: MobileAppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _isManualMode ? _buildManualView() : _buildScannerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _handleBarcodeCapture,
        ),

        // Scanning Target Viewfinder
        Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: MobileAppColors.primary, width: 3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MobileAppColors.primary.withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 30,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.scan, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text(
                  'Scan Desktop "Pair Mobile" QR Code',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),

        if (_isConnecting)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: MobileAppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Pairing with Desktop Terminal...',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildManualView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manual IP Configuration',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the IP address displayed on your Desktop POS screen.',
            style: TextStyle(fontSize: 12.5, color: MobileAppColors.textSecondary(context)),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _ipController,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              labelText: 'Desktop LAN IP Address',
              hintText: 'e.g. 192.168.1.15 or 127.0.0.1',
              prefixIcon: Icon(LucideIcons.wifi, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Bridge Port',
              hintText: '8888',
              prefixIcon: Icon(LucideIcons.server, size: 20),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: MobileAppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isConnecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(LucideIcons.link),
              label: Text(_isConnecting ? 'Connecting...' : 'Connect to Desktop', style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: _isConnecting ? null : _connectManual,
            ),
          ),
          const SizedBox(height: 16),

          // Quick Connect Buttons
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('192.168.100.30:8888 (Desktop POS)'),
                onPressed: () {
                  _ipController.text = '192.168.100.30';
                  _portController.text = '8888';
                },
              ),
              ActionChip(
                label: const Text('localhost:8888'),
                onPressed: () {
                  _ipController.text = '127.0.0.1';
                  _portController.text = '8888';
                },
              ),
              ActionChip(
                label: const Text('10.0.2.2 (Android Emu)'),
                onPressed: () {
                  _ipController.text = '10.0.2.2';
                  _portController.text = '8888';
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
