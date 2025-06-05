import 'dart:io';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/story_model.dart';

class StoryRepository extends GetxService {
  final SupabaseService _supabase = Get.find<SupabaseService>();

  /// Upload story image to storage
  Future<String?> uploadStoryImage(File imageFile, String userId) async {
    try {
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          'story_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final storagePath = '$userId/$fileName';

      // Read file as bytes
      final fileBytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      await _supabase.client.storage
          .from('stories')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: 'no-cache',
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.client.storage
          .from('stories')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      print('Error uploading story image: $e');
      return null;
    }
  }

  /// Create a new story
  Future<String?> createStory(StoryModel story) async {
    try {
      final storyData = story.toMap();
      print('Creating story with data: $storyData');

      // Validate user_id is not empty
      if (storyData['user_id'] == null ||
          storyData['user_id'].toString().isEmpty) {
        print('Error: user_id is null or empty');
        return null;
      }

      final response =
          await _supabase.client
              .from('stories')
              .insert(storyData)
              .select('id')
              .single();

      print('Story created successfully with ID: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      print('Error creating story: $e');
      return null;
    }
  }

  /// Get all active stories (no follower restriction)
  Future<List<StoryModel>> getAllActiveStories(String userId) async {
    try {
      final response = await _supabase.client
          .from('stories')
          .select('''
            *,
            profiles(
              user_id,
              username,
              nickname,
              avatar
            )
          ''')
          .eq('is_active', true)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((story) => StoryModel.fromMap(story))
          .toList();
    } catch (e) {
      print('Error getting all active stories: $e');
      return [];
    }
  }

  /// Get user's own stories
  Future<List<StoryModel>> getUserStories(String userId) async {
    try {
      final response = await _supabase.client
          .from('stories')
          .select()
          .eq('user_id', userId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map((story) => StoryModel.fromMap(story))
          .toList();
    } catch (e) {
      print('Error getting user stories: $e');
      return [];
    }
  }

  /// Delete expired stories using the database function
  Future<int> deleteExpiredStories() async {
    try {
      final response = await _supabase.client.rpc('cleanup_expired_stories');
      return response as int? ?? 0;
    } catch (e) {
      print('Error deleting expired stories: $e');
      return 0;
    }
  }

  /// Delete a specific story
  Future<bool> deleteStory(String storyId, String userId) async {
    try {
      await _supabase.client
          .from('stories')
          .delete()
          .eq('id', storyId)
          .eq('user_id', userId);
      return true;
    } catch (e) {
      print('Error deleting story: $e');
      return false;
    }
  }

  /// Get story analytics (view count and viewers)
  Future<Map<String, dynamic>?> getStoryAnalytics(
    String storyId,
    String userId,
  ) async {
    try {
      final response =
          await _supabase.client
              .from('stories')
              .select('view_count, viewers')
              .eq('id', storyId)
              .eq('user_id', userId)
              .single();

      return response;
    } catch (e) {
      print('Error getting story analytics: $e');
      return null;
    }
  }

  /// Check if current user has viewed a story
  Future<bool> hasUserViewedStory(String storyId, String userId) async {
    try {
      final response =
          await _supabase.client
              .from('stories')
              .select('viewers')
              .eq('id', storyId)
              .single();

      final viewers = response['viewers'] as List<dynamic>? ?? [];
      return viewers.contains(userId);
    } catch (e) {
      print('Error checking story view status: $e');
      return false;
    }
  }
}
