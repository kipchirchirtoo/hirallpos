import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// WirelessBridgeService runs a lightweight WebSocket & HTTP server inside the Desktop POS
/// on port 8888. It allows mobile companion devices (Android/Web) on the local WiFi to pair
/// by scanning a QR Code and stream real-time barcode scans, inventory updates, and cashier sales.
class WirelessBridgeService {
  static final WirelessBridgeService _instance = WirelessBridgeService._internal();
  static WirelessBridgeService get instance => _instance;

  WirelessBridgeService._internal();

  HttpServer? _server;
  final List<WebSocket> _activeSockets = [];
  final _barcodeStreamController = StreamController<String>.broadcast();
  final _stockInStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _saleStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _deviceStatusStreamController = StreamController<int>.broadcast();

  Stream<String> get barcodeStream => _barcodeStreamController.stream;
  Stream<Map<String, dynamic>> get stockInStream => _stockInStreamController.stream;
  Stream<Map<String, dynamic>> get saleStream => _saleStreamController.stream;
  Stream<int> get connectedDevicesCountStream => _deviceStatusStreamController.stream;

  int get connectedDevicesCount => _activeSockets.length;
  bool get isRunning => _server != null;
  int port = 8888;
  String localIp = '127.0.0.1';
  String pairingToken = 'HIRALL-SCAN-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';

  /// Start the LAN Bridge Server
  Future<void> startServer({int listenPort = 8888}) async {
    if (_server != null) return;
    port = listenPort;

    try {
      localIp = await _discoverLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      debugPrint('[WirelessBridgeService] Running on ws://$localIp:$port (Pairing Token: $pairingToken)');

      _server!.listen((HttpRequest request) async {
        // Enable CORS for mobile web testing
        request.response.headers.add('Access-Control-Allow-Origin', '*');
        request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        request.response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization');

        if (request.method == 'OPTIONS') {
          request.response.statusCode = HttpStatus.ok;
          await request.response.close();
          return;
        }

        // WebSocket upgrade endpoint: ws://<IP>:8888/ws
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleWebSocket(socket);
          return;
        }

        // HTTP Discovery / Health check: http://<IP>:8888/ping
        if (request.uri.path == '/ping' || request.uri.path == '/info') {
          final info = {
            'status': 'online',
            'system': 'Hirall POS Desktop Bridge',
            'version': '2.0.0',
            'localIp': localIp,
            'port': port,
            'pairingToken': pairingToken,
            'connectedDevices': _activeSockets.length,
          };
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(info));
          await request.response.close();
          return;
        }

        // HTTP Barcode Push fallback: POST http://<IP>:8888/scan
        if (request.method == 'POST' && request.uri.path == '/scan') {
          final body = await utf8.decoder.bind(request).join();
          try {
            final data = jsonDecode(body);
            final barcode = (data['barcode'] ?? data['code'] ?? '').toString().trim();
            if (barcode.isNotEmpty) {
              _barcodeStreamController.add(barcode);
              request.response.headers.contentType = ContentType.json;
              request.response.write(jsonEncode({'status': 'success', 'barcode': barcode}));
            } else {
              request.response.statusCode = HttpStatus.badRequest;
              request.response.write(jsonEncode({'error': 'Empty barcode'}));
            }
          } catch (e) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.write(jsonEncode({'error': 'Invalid JSON: $e'}));
          }
          await request.response.close();
          return;
        }

        // Default 404
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });
    } catch (e) {
      debugPrint('[WirelessBridgeService] Failed to start server: $e');
    }
  }

  /// Handles incoming WebSocket messages from paired mobile companion apps
  void _handleWebSocket(WebSocket socket) {
    _activeSockets.add(socket);
    _deviceStatusStreamController.add(_activeSockets.length);
    debugPrint('[WirelessBridgeService] Mobile device connected. Total: ${_activeSockets.length}');

    // Send handshake acknowledge
    socket.add(jsonEncode({
      'event': 'handshake_ack',
      'system': 'Hirall POS Desktop',
      'timestamp': DateTime.now().toIso8601String(),
    }));

    socket.listen(
      (message) {
        try {
          final data = jsonDecode(message.toString());
          final event = data['event'] ?? 'unknown';

          switch (event) {
            case 'scan_barcode':
            case 'barcode':
              final code = (data['barcode'] ?? data['code'] ?? '').toString().trim();
              if (code.isNotEmpty) {
                _barcodeStreamController.add(code);
                // Send feedback back to phone
                socket.add(jsonEncode({
                  'event': 'barcode_received',
                  'barcode': code,
                  'status': 'applied_to_desktop',
                  'time': DateTime.now().toIso8601String(),
                }));
              }
              break;

            case 'stock_in':
              _stockInStreamController.add(data);
              socket.add(jsonEncode({
                'event': 'stock_in_ack',
                'status': 'recorded',
                'sku': data['sku'] ?? data['barcode'],
              }));
              break;

            case 'mobile_sale':
              _saleStreamController.add(data);
              socket.add(jsonEncode({
                'event': 'sale_ack',
                'status': 'synced_to_desktop_ledger',
                'receiptNo': data['receiptNo'],
              }));
              break;

            case 'ping':
              socket.add(jsonEncode({'event': 'pong', 'time': DateTime.now().toIso8601String()}));
              break;
          }
        } catch (e) {
          debugPrint('[WirelessBridgeService] Error parsing incoming websocket message: $e');
        }
      },
      onDone: () {
        _activeSockets.remove(socket);
        _deviceStatusStreamController.add(_activeSockets.length);
        debugPrint('[WirelessBridgeService] Mobile device disconnected. Total: ${_activeSockets.length}');
      },
      onError: (error) {
        _activeSockets.remove(socket);
        _deviceStatusStreamController.add(_activeSockets.length);
      },
    );
  }

  /// Broadcasts an event to all connected mobile companion apps
  void broadcast(Map<String, dynamic> eventData) {
    final payload = jsonEncode(eventData);
    for (final socket in _activeSockets) {
      try {
        socket.add(payload);
      } catch (_) {}
    }
  }

  /// Generates the Pairing QR Code Payload
  Map<String, dynamic> getPairingPayload({
    String organizationName = 'GIFTMART SUPERMARKET',
    String branchName = 'KERICHO',
  }) {
    return {
      'type': 'hirall_pos_pairing',
      'version': '2.0.0',
      'host': localIp,
      'port': port,
      'wsUrl': 'ws://$localIp:$port',
      'httpUrl': 'http://$localIp:$port',
      'token': pairingToken,
      'organization': organizationName,
      'branch': branchName,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Discovers local network IPv4 address (192.168.x.x, 10.x.x.x, 172.x.x.x)
  Future<String> _discoverLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            // Prioritize standard local subnets
            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.') ||
                addr.address.startsWith('172.')) {
              return addr.address;
            }
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<void> stopServer() async {
    for (final socket in _activeSockets) {
      try {
        await socket.close();
      } catch (_) {}
    }
    _activeSockets.clear();
    await _server?.close(force: true);
    _server = null;
  }
}
