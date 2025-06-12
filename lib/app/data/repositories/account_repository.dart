import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository {
  AccountDataProvider get _provider => Get.find<AccountDataProvider>();
  SupabaseService get _supabase => Get.find<SupabaseService>();

  // Realtime subscriptions
  RealtimeChannel? _profilesSubscription;
  RealtimeChannel? _followsSubscription;

  /// Sets up realtime data subscriptions for the current user and fetches initial profile data
  Future<Map<String, dynamic>> userRealtimeData() async {
    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId == null) {
        return {'isAuthenticated': false, 'error': 'User not authenticated'};
      }

      // First, fetch the current profile data from the database
      final profileResponse =
          await _supabase.client
              .from('profiles')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      // If profile data exists, update the provider
      if (profileResponse != null) {
        _updateProfileData(profileResponse);
      }

      // Then set up realtime subscriptions for future changes
      await Future.wait([
        subscribeToProfileChanges(userId),
        subscribeToFollowsChanges(userId),
      ]);

      // Return the profile data along with authentication status
      return profileResponse ?? {'isAuthenticated': true, 'userId': userId};
    } catch (e) {
      return {'isAuthenticated': false, 'error': e.toString()};
    }
  }

  /// Subscribes to profile changes for a specific user
  Future<void> subscribeToProfileChanges(String userId) async {
    try {
      await _profilesSubscription?.unsubscribe();

      _profilesSubscription =
          _supabase.client
              .channel('public:profiles')
              .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'profiles',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'user_id',
                  value: userId,
                ),
                callback: (payload) {
                  final profileData = payload.newRecord;
                  if (profileData.isNotEmpty) _updateProfileData(profileData);
                },
              )
              .subscribe();
    } catch (_) {}
  }

  /// Updates provider with profile data
  void _updateProfileData(Map<String, dynamic> data) {
    try {
      final fields = {
        'username': (val) => _provider.username.value = val,
        'nickname': (val) => _provider.nickname.value = val,
        'bio': (val) => _provider.bio.value = val,
        'avatar': (val) => _provider.avatar.value = val,
        'email': (val) => _provider.email.value = val,
        'follower_count': (val) => _provider.followerCount.value = val,
        'following_count': (val) => _provider.followingCount.value = val,
        'google_avatar': (val) => _provider.googleAvatar.value = val,
        'banner': (val) => _provider.banner.value = val,
      };

      fields.forEach((key, setter) {
        if (data[key] != null) setter(data[key]);
      });
    } catch (_) {}
  }

  /// Subscribes to follows changes for a specific user
  Future<void> subscribeToFollowsChanges(String userId) async {
    try {
      await _followsSubscription?.unsubscribe();

      _followsSubscription =
          _supabase.client
              .channel('public:follows')
              // When user follows someone
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'follows',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'follower_id',
                  value: userId,
                ),
                callback:
                    (payload) => _handleFollowingInsert(payload.newRecord),
              )
              // When user unfollows someone
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'follows',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'follower_id',
                  value: userId,
                ),
                callback:
                    (payload) => _handleFollowingDelete(payload.oldRecord),
              )
              // When someone follows user
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'follows',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'following_id',
                  value: userId,
                ),
                callback: (payload) => _handleFollowerInsert(payload.newRecord),
              )
              // When someone unfollows user
              .onPostgresChanges(
                event: PostgresChangeEvent.delete,
                schema: 'public',
                table: 'follows',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'following_id',
                  value: userId,
                ),
                callback: (payload) => _handleFollowerDelete(payload.oldRecord),
              )
              .subscribe();
    } catch (_) {}
  }

  // Handlers for follow events
  void _handleFollowingInsert(Map<String, dynamic> data) {
    if (data.isNotEmpty && data['following_id'] != null) {
      _provider.addFollowing({
        'following_id': data['following_id'],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  void _handleFollowingDelete(Map<String, dynamic> data) {
    if (data.isNotEmpty && data['following_id'] != null) {
      _provider.removeFollowing(data['following_id']);
    }
  }

  void _handleFollowerInsert(Map<String, dynamic> data) {
    if (data.isNotEmpty && data['follower_id'] != null) {
      _provider.addFollower({
        'follower_id': data['follower_id'],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
      });
    }
  }

  void _handleFollowerDelete(Map<String, dynamic> data) {
    if (data.isNotEmpty && data['follower_id'] != null) {
      _provider.removeFollower(data['follower_id']);
    }
  }

  /// Follow/unfollow user operations with private account support
  Future<Map<String, dynamic>> followUser(String targetUserId) async {
    final userId = _getCurrentUserId();

    try {
      // First check if the target account is private
      final response =
          await _supabase.client
              .from('profiles')
              .select('private')
              .eq('user_id', targetUserId)
              .single();

      final bool isPrivate = response['private'] ?? false;

      if (isPrivate) {
        // For private accounts, send a follow request
        await _supabase.client.rpc(
          'request_follow',
          params: {'p_requester_id': userId, 'p_receiver_id': targetUserId},
        );

        // Return status indicating request was sent
        return {
          'status': 'request_sent',
          'message': 'Follow request sent',
          'isPrivate': true,
        };
      } else {
        // For public accounts, follow directly
        await _supabase.client.rpc(
          'follow_user',
          params: {'p_follower_id': userId, 'p_following_id': targetUserId},
        );

        // Create follow notification
        try {
          final notificationService = Get.find<NotificationService>();
          await notificationService.createFollowNotification(
            followerId: userId,
            followingId: targetUserId,
          );
        } catch (e) {
          debugPrint('Error creating follow notification: $e');
          // Don't throw error - follow operation should still succeed
        }

        await _provider.loadFollowing(userId);

        // Return status indicating follow was successful
        return {
          'status': 'followed',
          'message': 'Successfully followed user',
          'isPrivate': false,
        };
      }
    } catch (e) {
      debugPrint('Error in followUser: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    final userId = _getCurrentUserId();
    await _supabase.client.rpc(
      'unfollow_user',
      params: {'p_follower_id': userId, 'p_following_id': targetUserId},
    );
    await _provider.loadFollowing(userId);
  }

  /// Accept a follow request
  Future<void> acceptFollowRequest(String requesterId) async {
    final userId = _getCurrentUserId();

    try {
      await _supabase.client.rpc(
        'accept_follow_request',
        params: {'p_requester_id': requesterId, 'p_receiver_id': userId},
      );

      // Load updated following data
      await _provider.loadFollowers(userId);
    } catch (e) {
      debugPrint('Error accepting follow request: $e');
      rethrow;
    }
  }

  /// Reject a follow request
  Future<void> rejectFollowRequest(String requesterId) async {
    final userId = _getCurrentUserId();

    try {
      await _supabase.client.rpc(
        'reject_follow_request',
        params: {'p_requester_id': requesterId, 'p_receiver_id': userId},
      );
    } catch (e) {
      debugPrint('Error rejecting follow request: $e');
      rethrow;
    }
  }

  /// Check if a follow request exists
  Future<bool> hasFollowRequest(String targetUserId) async {
    final userId = _getCurrentUserId();

    try {
      final response = await _supabase.client
          .from('follow_requests')
          .select()
          .eq('requester_id', userId)
          .eq('receiver_id', targetUserId);

      return response.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking follow request: $e');
      return false;
    }
  }

  /// Get pending follow requests for the current user
  Future<List<Map<String, dynamic>>> getFollowRequests() async {
    final userId = _getCurrentUserId();

    try {
      final response = await _supabase.client
          .from('follow_requests')
          .select('''
            id,
            requester_id,
            receiver_id,
            created_at,
            profiles:requester_id (
              username,
              nickname,
              avatar
            )
          ''')
          .eq('receiver_id', userId)
          .order('created_at', ascending: false);

      // Format the response to include requester profile info
      return response.map<Map<String, dynamic>>((item) {
        final profile = item['profiles'] as Map<String, dynamic>;
        return {
          'id': item['id'],
          'requester_id': item['requester_id'],
          'receiver_id': item['receiver_id'],
          'requester_username': profile['username'] ?? '',
          'requester_nickname': profile['nickname'] ?? '',
          'requester_avatar': profile['avatar'] ?? '',
          'created_at': item['created_at'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting follow requests: $e');
      return [];
    }
  }

  /// Get current user ID or throw if not authenticated
  String _getCurrentUserId() {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    return userId;
  }

  /// Process data for followers, following and searches
  void processFollowersData(dynamic followersData) {
    if (followersData == null) return;
    try {
      final processedData = Map<String, dynamic>.from(followersData);
      if (processedData['users'] is! List) return;

      final followersList =
          List<String>.from(processedData['users'])
              .map(
                (userId) => {
                  'follower_id': userId,
                  'created_at': DateTime.now().toIso8601String(),
                },
              )
              .toList();

      _provider.updateFollowers(followersList);
    } catch (_) {}
  }

  void processFollowingData(dynamic followingData) {
    if (followingData == null) return;
    try {
      final processedData = Map<String, dynamic>.from(followingData);
      if (processedData['users'] is! List) return;

      final followingList =
          List<String>.from(processedData['users'])
              .map(
                (userId) => {
                  'following_id': userId,
                  'created_at': DateTime.now().toIso8601String(),
                },
              )
              .toList();

      _provider.updateFollowing(followingList);
    } catch (_) {}
  }

  // Search functionality has been moved to use local storage only
  // All search-related data is now managed by the StorageService

  /// Uploads banner image to Supabase storage and updates profile
  Future<String> uploadBanner(File file) async {
    try {
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Get file extension
      final fileExtension = file.path.split('.').last.toLowerCase();
      final fileName = 'banner.$fileExtension';
      final storagePath = '$userId/$fileName';

      // Read file as bytes
      final fileBytes = await file.readAsBytes();

      // Upload to Supabase storage
      await _supabase.client.storage
          .from('profiles')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(cacheControl: 'no-cache', upsert: true),
          );

      // Get public URL with a timestamp to prevent caching
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicUrl =
          '${_supabase.client.storage.from('profiles').getPublicUrl(storagePath)}?t=$timestamp';

      // Update profile with banner URL
      await _supabase.client
          .from('profiles')
          .update({'banner': publicUrl})
          .eq('user_id', userId);

      // Update local state
      _provider.banner.value = publicUrl;

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload banner: $e');
    }
  }

  /// Cleanup methods
  void cleanupSubscriptions() {
    try {
      _profilesSubscription?.unsubscribe();
      _followsSubscription?.unsubscribe();
      _profilesSubscription = _followsSubscription = null;
    } catch (_) {}
  }

  void dispose() {
    _profilesSubscription?.unsubscribe();
    _followsSubscription?.unsubscribe();
  }

  void onClose() => cleanupSubscriptions();
}
