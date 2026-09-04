import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

enum SyncState { connected, syncing, offline, error }

class PowerSyncService extends ChangeNotifier {
  SyncState _status = SyncState.offline;
  int _pendingUploadsCount = 0;
  String? _lastSyncTime;
  String? _errorMessage;

  SyncState get status => _status;
  int get pendingUploadsCount => _pendingUploadsCount;
  String? get lastSyncTime => _lastSyncTime;
  String? get errorMessage => _errorMessage;

  bool get isOnline => _status == SyncState.connected || _status == SyncState.syncing;

  Future<void> initialize({
    required String token,
    required String organizationId,
    required String branchId,
    String? powersyncUrl,
  }) async {
    _status = SyncState.syncing;
    notifyListeners();

    try {
      // In production Flutter Desktop runtime:
      // final db = PowerSyncDatabase(schema: schema, path: dbPath);
      // await db.initialize();
      // await db.connect(connector: BackendConnector(token));

      await Future.delayed(const Duration(milliseconds: 800));
      _status = SyncState.connected;
      _lastSyncTime = DateTime.now().toIso8601String();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _status = SyncState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void queueOfflineWrite() {
    _pendingUploadsCount++;
    notifyListeners();
  }

  void completeSync() {
    _pendingUploadsCount = 0;
    _lastSyncTime = DateTime.now().toIso8601String();
    _status = SyncState.connected;
    notifyListeners();
  }

  void setOffline() {
    _status = SyncState.offline;
    notifyListeners();
  }
}
