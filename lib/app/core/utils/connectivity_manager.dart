import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'db_cache_service.dart';
import 'supabase_service.dart';

class ConnectivityManager extends GetxService {
  static ConnectivityManager get to => Get.find<ConnectivityManager>();
  
  // Connection state
  final RxBool isOnline = true.obs;
  final RxBool isSyncPending = false.obs;
  final RxString networkType = 'unknown'.obs;
  
  // Queue of operations to sync when back online
  final RxList<Map<String, dynamic>> _syncQueue = <Map<String, dynamic>>[].obs;
  
  // Connectivity stream subscription
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Start monitoring connectivity
  Future<ConnectivityManager> init() async {
    try {
      // Get initial connectivity status
      final connectivityResult = await Connectivity().checkConnectivity();
      _updateConnectionStatus(connectivityResult);
      
      // Listen for connectivity changes
      _subscription = Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
      
      debugPrint('ConnectivityManager initialized: ${isOnline.value ? "online" : "offline"}');
    } catch (e) {
      debugPrint('Error initializing ConnectivityManager: $e');
    }
    
    return this;
  }
  
  // Update connection status based on connectivity result
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    // Use the first result if available, otherwise consider offline
    final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
    
    switch (result) {
      case ConnectivityResult.none:
        isOnline.value = false;
        networkType.value = 'offline';
        Get.find<DbCacheService>().setOfflineModeEnabled(true);
        break;
      case ConnectivityResult.mobile:
        isOnline.value = true;
        networkType.value = 'mobile';
        _handleBackOnline();
        break;
      case ConnectivityResult.wifi:
        isOnline.value = true;
        networkType.value = 'wifi';
        _handleBackOnline();
        break;
      case ConnectivityResult.ethernet:
        isOnline.value = true;
        networkType.value = 'ethernet';
        _handleBackOnline();
        break;
      case ConnectivityResult.vpn:
        isOnline.value = true;
        networkType.value = 'vpn';
        _handleBackOnline();
        break;
      case ConnectivityResult.other:
        isOnline.value = true;
        networkType.value = 'other';
        _handleBackOnline();
        break;
      default:
        isOnline.value = true;
        networkType.value = 'unknown';
        break;
    }
    
    debugPrint('Connection status changed: ${networkType.value} (online: ${isOnline.value})');
  }
  
  // Handle coming back online
  void _handleBackOnline() {
    final dbCacheService = Get.find<DbCacheService>();
    
    // Only process if we were previously in offline mode
    if (dbCacheService.isOfflineModeEnabled.value) {
      dbCacheService.setOfflineModeEnabled(false);
      
      // Process sync queue
      if (_syncQueue.isNotEmpty) {
        _processSyncQueue();
      }
    }
  }
  
  // Add operation to sync queue for when we're back online
  void addToSyncQueue(String operation, Map<String, dynamic> data) {
    if (!isOnline.value) {
      _syncQueue.add({
        'operation': operation,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      isSyncPending.value = true;
      debugPrint('Added operation to sync queue: $operation');
    }
  }
  
  // Process sync queue when back online
  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty || !isOnline.value) return;
    
    isSyncPending.value = true;
    debugPrint('Processing sync queue: ${_syncQueue.length} items');
    
    try {
      final supabaseService = Get.find<SupabaseService>();
      
      // Sort by timestamp to process in order
      _syncQueue.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      
      // Process each operation
      for (final item in _syncQueue.toList()) {
        final operation = item['operation'];
        final data = item['data'] as Map<String, dynamic>;
        
        try {
          switch (operation) {
            case 'create_post':
              await supabaseService.client
                  .from('posts')
                  .insert(data);
              break;
            case 'update_profile':
              await supabaseService.client
                  .from('profiles')
                  .update(data)
                  .eq('user_id', data['user_id']);
              break;
            case 'follow_user':
              await supabaseService.client
                  .from('follows')
                  .insert({
                    'follower_id': data['follower_id'],
                    'following_id': data['following_id'],
                  });
              break;
            case 'unfollow_user':
              await supabaseService.client
                  .from('follows')
                  .delete()
                  .eq('follower_id', data['follower_id'])
                  .eq('following_id', data['following_id']);
              break;
            // Add more operation types as needed
          }
          
          // If successful, remove from queue
          _syncQueue.remove(item);
          debugPrint('Successfully synced: $operation');
        } catch (e) {
          debugPrint('Error syncing operation $operation: $e');
          // Leave in queue to retry next time
        }
      }
    } finally {
      isSyncPending.value = _syncQueue.isNotEmpty;
    }
  }
  
  // Force sync queue processing
  Future<void> syncNow() async {
    if (isOnline.value && _syncQueue.isNotEmpty) {
      await _processSyncQueue();
    }
  }
  
  // Clear sync queue
  void clearSyncQueue() {
    _syncQueue.clear();
    isSyncPending.value = false;
  }
  
  // Get sync queue stats
  Map<String, dynamic> getSyncQueueStats() {
    return {
      'pendingItems': _syncQueue.length,
      'isSyncing': isSyncPending.value,
      'operations': _syncQueue.map((item) => item['operation']).toList(),
      'isOnline': isOnline.value,
      'networkType': networkType.value,
    };
  }
  
  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
} 