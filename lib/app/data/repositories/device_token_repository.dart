import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';

/// Repository for managing device tokens for push notifications
class DeviceTokenRepository extends GetxService {
  SupabaseService get _supabase => Get.find<SupabaseService>();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Initialize the repository
  Future<DeviceTokenRepository> init() async {
    return this;
  }

  /// Get a unique identifier for the current device
  Future<String> getDeviceIdentifier() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else {
        return 'web_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      debugPrint('Error getting device identifier: $e');
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Register the device token for the current user
  Future<bool> registerDeviceToken(String deviceToken) async {
    try {
      final userId = _supabase.currentUser.value?.id;
      if (userId == null) return false;

      // Get the actual device identifier
      final deviceId = await getDeviceIdentifier();

      // Add device model information
      String platform = 'unknown';
      String deviceModel = 'unknown';

      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          platform = 'android';
          deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          platform = 'ios';
          deviceModel = '${iosInfo.name} ${iosInfo.systemVersion}';
        }
      } catch (e) {
        debugPrint('Error getting device info: $e');
      }

      // Check if device already exists
      final existingTokens = await _supabase.client
          .from('device_tokens')
          .select()
          .eq('user_id', userId)
          .eq('token', deviceId);

      // If device doesn't exist, insert it
      if (existingTokens.isEmpty) {
        await _supabase.client.from('device_tokens').insert({
          'user_id': userId,
          'token': deviceId,
          'platform': platform,
          'device_details': deviceModel,
          'created_at': DateTime.now().toIso8601String(),
        });
        debugPrint('Device registered for notifications');
      } else {
        debugPrint('Device already registered for notifications');
      }

      return true;
    } catch (e) {
      debugPrint('Error registering device: $e');
      return false;
    }
  }

  /// Unregister a device token
  Future<bool> unregisterDeviceToken(String deviceToken) async {
    try {
      await _supabase.client
          .from('device_tokens')
          .delete()
          .eq('token', deviceToken);
      debugPrint('Device token unregistered successfully');
      return true;
    } catch (e) {
      debugPrint('Error unregistering device token: $e');
      return false;
    }
  }

  /// Remove all device tokens for the current user
  Future<bool> removeAllUserTokens() async {
    try {
      final userId = _supabase.currentUser.value?.id;
      if (userId == null) return false;

      await _supabase.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId);

      debugPrint('All device tokens for user removed');
      return true;
    } catch (e) {
      debugPrint('Error removing all user tokens: $e');
      return false;
    }
  }
}
