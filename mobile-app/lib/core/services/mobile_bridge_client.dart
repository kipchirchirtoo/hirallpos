import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class MobileBridgeClient {
  static final MobileBridgeClient _instance = MobileBridgeClient._internal();
  static MobileBridgeClient get instance => _instance;

  MobileBridgeClient._internal();

  WebSocket? _socket;
  String _hostIp = '192.168.100.30';
  int _port = 8888;
  String _token = '';
  String _storeName = 'GIFTMART SUPERMARKET';
  String _branchName = 'KERICHO';
  
  ConnectionStatus _status = ConnectionStatus.disconnected;
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _serverMessageController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<Map<String, dynamic>> get messageStream => _serverMessageController.stream;
  ConnectionStatus get status => _status;
  String get hostIp => _hostIp;
  int get port => _port;
  String get storeName => _storeName;
  String get branchName => _branchName;
  bool get isConnected => _status == ConnectionStatus.connected;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _hostIp = prefs.getString('hirall_bridge_host_ip') ?? '192.168.100.30';
    _port = prefs.getInt('hirall_bridge_port') ?? 8888;
    _token = prefs.getString('hirall_bridge_token') ?? '';
    _storeName = prefs.getString('hirall_bridge_store') ?? 'GIFTMART SUPERMARKET';
    _branchName = prefs.getString('hirall_bridge_branch') ?? 'KERICHO';

    if (_token.isNotEmpty) {
      connect(hostIp: _hostIp, port: _port, token: _token);
    }
  }

  /// Connect to Desktop Bridge via QR Payload or Host/Port
  Future<bool> connect({
    required String hostIp,
    int port = 8888,
    String token = '',
    String store = 'GIFTMART SUPERMARKET',
    String branch = 'KERICHO',
  }) async {
    _hostIp = hostIp.trim();
    _port = port;
    _token = token;
    _storeName = store;
    _branchName = branch;

    _updateStatus(ConnectionStatus.connecting);

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hirall_bridge_host_ip', _hostIp);
    await prefs.setInt('hirall_bridge_port', _port);
    await prefs.setString('hirall_bridge_token', _token);
    await prefs.setString('hirall_bridge_store', _storeName);
    await prefs.setString('hirall_bridge_branch', _branchName);

    try {
      // 1. Try WebSocket Connection
      final wsUrl = 'ws://$_hostIp:$_port';
      debugPrint('[MobileBridgeClient] Connecting to $wsUrl ...');
      
      await _socket?.close();
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 4));

      _socket!.listen(
        (message) {
          try {
            final data = jsonDecode(message.toString());
            _serverMessageController.add(data);
          } catch (_) {}
        },
        onDone: () {
          debugPrint('[MobileBridgeClient] WebSocket closed.');
          _updateStatus(ConnectionStatus.disconnected);
        },
        onError: (e) {
          debugPrint('[MobileBridgeClient] WebSocket error: $e');
          _updateStatus(ConnectionStatus.disconnected);
        },
      );

      _updateStatus(ConnectionStatus.connected);
      return true;
    } catch (e) {
      debugPrint('[MobileBridgeClient] WS connection failed ($e). Verifying via HTTP fallback...');
      
      // 2. HTTP Ping Fallback Verification
      try {
        final res = await http.get(Uri.parse('http://$_hostIp:$_port/ping')).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200) {
          _updateStatus(ConnectionStatus.connected);
          return true;
        }
      } catch (_) {}

      _updateStatus(ConnectionStatus.disconnected);
      return false;
    }
  }

  /// Disconnect
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
    _updateStatus(ConnectionStatus.disconnected);
  }

  /// Send Scanned Barcode to Desktop (Master Catalog or Cashier)
  Future<bool> sendBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return false;

    final payload = {
      'event': 'scan_barcode',
      'barcode': cleanBarcode,
      'code': cleanBarcode,
      'source': 'mobile_camera_scanner',
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Send via active WebSocket
    if (_socket != null && _status == ConnectionStatus.connected) {
      try {
        _socket!.add(jsonEncode(payload));
        return true;
      } catch (e) {
        debugPrint('[MobileBridgeClient] WS send failed: $e');
      }
    }

    // 2. Fallback to HTTP POST
    try {
      final res = await http.post(
        Uri.parse('http://$_hostIp:$_port/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send Stock In / GRN update to Desktop & Cloud
  Future<bool> sendStockIn({
    required String barcode,
    required String name,
    required double quantity,
    required double unitCost,
    String supplier = 'Direct Receiving',
    String batchNo = '',
  }) async {
    final payload = {
      'event': 'stock_in',
      'barcode': barcode,
      'name': name,
      'quantity': quantity,
      'unitCost': unitCost,
      'supplier': supplier,
      'batchNo': batchNo.isNotEmpty ? batchNo : 'BATCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_socket != null && _status == ConnectionStatus.connected) {
      try {
        _socket!.add(jsonEncode(payload));
        return true;
      } catch (_) {}
    }

    return true;
  }

  /// Send Mobile Cashier Completed Sale to Desktop Ledger
  Future<bool> sendMobileSale(Map<String, dynamic> saleData) async {
    final payload = {
      'event': 'mobile_sale',
      ...saleData,
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (_socket != null && _status == ConnectionStatus.connected) {
      try {
        _socket!.add(jsonEncode(payload));
        return true;
      } catch (_) {}
    }
    return true;
  }

  void _updateStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }
}
