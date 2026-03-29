import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ─── TOP-LEVEL ENUMS ────────────────────────────────────────────────────────
enum SyncOperationType { create, update, delete }

enum SyncDataType { scheduleEvent, solicitation, scheduledPost }

// ─── TOP-LEVEL SYNC OPERATION CLASS ─────────────────────────────────────────
class SyncOperation {
  final String id;
  final SyncOperationType operationType;
  final SyncDataType dataType;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  bool isSynced;
  String? syncError;
  
  SyncOperation({
    required this.id,
    required this.operationType,
    required this.dataType,
    required this.data,
    required this.timestamp,
    this.isSynced = false,
    this.syncError,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'operationType': operationType.toString().split('.').last,
    'dataType': dataType.toString().split('.').last,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'isSynced': isSynced,
    'syncError': syncError,
  };
  
  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] ?? '',
      operationType: _parseOperationType(json['operationType'] ?? 'create'),
      dataType: _parseDataType(json['dataType'] ?? 'scheduleEvent'),
      data: json['data'] ?? {},
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isSynced: json['isSynced'] ?? false,
      syncError: json['syncError'],
    );
  }
  
  static SyncOperationType _parseOperationType(String typeStr) {
    switch (typeStr) {
      case 'update':
        return SyncOperationType.update;
      case 'delete':
        return SyncOperationType.delete;
      default:
        return SyncOperationType.create;
    }
  }
  
  static SyncDataType _parseDataType(String typeStr) {
    switch (typeStr) {
      case 'solicitation':
        return SyncDataType.solicitation;
      case 'scheduledPost':
        return SyncDataType.scheduledPost;
      default:
        return SyncDataType.scheduleEvent;
    }
  }
}

// ─── TOP-LEVEL SYNC STATUS CLASS ────────────────────────────────────────────
class SyncStatus {
  final bool isOnline;
  final bool isSyncing;
  final int pendingOperations;
  final DateTime lastSyncTime;
  final String? lastError;
  
  SyncStatus({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingOperations = 0,
    DateTime? lastSyncTime,
    this.lastError,
  }) : lastSyncTime = lastSyncTime ?? DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'isOnline': isOnline,
    'isSyncing': isSyncing,
    'pendingOperations': pendingOperations,
    'lastSyncTime': lastSyncTime.toIso8601String(),
    'lastError': lastError,
  };
}

/// 🌐 Cloud Sync Framework - Abstraction layer for hierarchical data sync
/// Supports: Local-first offline mode + Optional cloud backend
/// Currently uses local storage; ready to integrate Firebase, Supabase, or custom backend
class CloudSyncFramework {
  // Sync configuration
  static bool _isCloudEnabled = false;
  static String _cloudProviderType = 'offline'; // 'offline', 'firebase', 'supabase', 'custom'
  static const String _syncConfigKey = 'cloud_sync_config';
  static const String _syncQueueKey = 'sync_queue';
  
  // Pending operations to be synced when cloud is available
  static List<SyncOperation> _pendingOperations = [];
  
  // ─── INITIALIZATION & CONFIGURATION ──────────────────────────────────────
  
  /// Initialize cloud sync framework (currently local-first)
  static Future<void> initialize() async {
    await _loadSyncConfig();
    await _loadPendingOperations();
  }
  
  /// Enable cloud sync (for future backend integration)
  static Future<void> enableCloudSync(String providerType) async {
    _cloudProviderType = providerType; // 'firebase', 'supabase', 'custom'
    _isCloudEnabled = true;
    await _saveSyncConfig();
  }
  
  /// Disable cloud sync (revert to local-only)
  static Future<void> disableCloudSync() async {
    _isCloudEnabled = false;
    _cloudProviderType = 'offline';
    await _saveSyncConfig();
  }
  
  // ─── OPERATION TRACKING ─────────────────────────────────────────────────────
  
  /// Track a create operation
  static Future<void> trackCreate({
    required SyncDataType dataType,
    required Map<String, dynamic> data,
  }) async {
    final operation = SyncOperation(
      id: 'op_${DateTime.now().millisecondsSinceEpoch}_${_randomId()}',
      operationType: SyncOperationType.create,
      dataType: dataType,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _pendingOperations.add(operation);
    await _savePendingOperations();
  }
  
  /// Track an update operation
  static Future<void> trackUpdate({
    required SyncDataType dataType,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final operation = SyncOperation(
      id: 'op_${DateTime.now().millisecondsSinceEpoch}_${_randomId()}',
      operationType: SyncOperationType.update,
      dataType: dataType,
      data: {...data, 'entityId': entityId},
      timestamp: DateTime.now(),
    );
    
    _pendingOperations.add(operation);
    await _savePendingOperations();
  }
  
  /// Track a delete operation
  static Future<void> trackDelete({
    required SyncDataType dataType,
    required String entityId,
  }) async {
    final operation = SyncOperation(
      id: 'op_${DateTime.now().millisecondsSinceEpoch}_${_randomId()}',
      operationType: SyncOperationType.delete,
      dataType: dataType,
      data: {'entityId': entityId},
      timestamp: DateTime.now(),
    );
    
    _pendingOperations.add(operation);
    await _savePendingOperations();
  }
  
  // ─── SYNC OPERATIONS ────────────────────────────────────────────────────────
  
  /// Get current sync status
  static SyncStatus getSyncStatus() {
    return SyncStatus(
      isOnline: _isCloudEnabled,
      isSyncing: false, // Will be true during actual sync
      pendingOperations: _pendingOperations.length,
      lastSyncTime: DateTime.now(),
    );
  }
  
  /// Get pending operations
  static List<SyncOperation> getPendingOperations() {
    return _pendingOperations.where((op) => !op.isSynced).toList();
  }
  
  /// Attempt to sync all pending operations (when cloud is available)
  static Future<Map<String, dynamic>> attemptSync() async {
    if (!_isCloudEnabled) {
      return {
        'success': false,
        'message': 'Cloud sync is disabled',
        'synced': 0,
        'failed': 0,
      };
    }
    
    int synced = 0;
    int failed = 0;
    
    // For now, this is a placeholder
    // When cloud is enabled (Firebase, Supabase, etc.),
    // implement actual sync logic here
    
    for (final operation in getPendingOperations()) {
      try {
        // TODO: Implement actual cloud sync based on _cloudProviderType
        // Example:
        // if (_cloudProviderType == 'firebase') {
        //   await _syncToFirebase(operation);
        // }
        
        operation.isSynced = true;
        synced++;
      } catch (e) {
        operation.syncError = e.toString();
        failed++;
      }
    }
    
    await _savePendingOperations();
    
    return {
      'success': failed == 0,
      'synced': synced,
      'failed': failed,
      'message': 'Synced $synced operations, $failed failed',
    };
  }
  
  /// Clear sync history (keep local data)
  static Future<void> clearSyncHistory() async {
    _pendingOperations.clear();
    await _savePendingOperations();
  }
  
  // ─── PERSISTENCE ────────────────────────────────────────────────────────────
  
  static Future<void> _saveSyncConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncConfigKey, jsonEncode({
      'isCloudEnabled': _isCloudEnabled,
      'cloudProviderType': _cloudProviderType,
    }));
  }
  
  static Future<void> _loadSyncConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final configStr = prefs.getString(_syncConfigKey);
    if (configStr != null) {
      final config = jsonDecode(configStr);
      _isCloudEnabled = config['isCloudEnabled'] ?? false;
      _cloudProviderType = config['cloudProviderType'] ?? 'offline';
    }
  }
  
  static Future<void> _savePendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_pendingOperations.map((op) => op.toJson()).toList());
    await prefs.setString(_syncQueueKey, jsonString);
  }
  
  static Future<void> _loadPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_syncQueueKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _pendingOperations = jsonList
          .map((json) => SyncOperation.fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }
  
  // ─── HELPER METHODS ─────────────────────────────────────────────────────────
  
  static String _randomId() {
    return DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13);
  }
  
  /// Export sync data for diagnostics
  static Map<String, dynamic> exportSyncData() {
    return {
      'configuration': {
        'isCloudEnabled': _isCloudEnabled,
        'cloudProviderType': _cloudProviderType,
      },
      'pendingOperations': _pendingOperations.map((op) => op.toJson()).toList(),
      'operationCount': _pendingOperations.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
