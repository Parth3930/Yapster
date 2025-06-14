import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_compress/video_compress.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';

class PostRepository extends GetxService {
  SupabaseService get _supabase => Get.find<SupabaseService>();

  /// Upload post image to storage with proper structure
  /// Storage structure: posts/{user_id}/{post_id}/{filename}
  Future<String?> uploadPostImage(
    File imageFile,
    String userId,
    String postId, {
    int imageIndex = 0,
  }) async {
    try {
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName =
          imageIndex == 0
              ? 'main.$fileExtension'
              : 'image_$imageIndex.$fileExtension';
      final storagePath = '$userId/$postId/$fileName';

      // Read file as bytes
      final fileBytes = await imageFile.readAsBytes();

      // Upload to Supabase storage with proper structure
      await _supabase.client.storage
          .from('posts')
          .uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(
              cacheControl: '3600', // Cache for 1 hour
              upsert: true,
            ),
          );

      // Get public URL
      final publicUrl = _supabase.client.storage
          .from('posts')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading post image: $e');
      return null;
    }
  }

  /// Upload post video to storage with proper structure
  /// Storage structure: {bucket}/{user_id}/{post_id}/video.{extension}
  Future<Map<String, String?>> uploadPostVideoWithThumbnail(
    File videoFile,
    String userId,
    String postId,
  ) async {
    const bucket = 'videos'; // Supabase bucket for post videos
    debugPrint(
      '🎬 VIDEO UPLOAD: Starting upload for post $postId by user $userId',
    );
    debugPrint(
      '🎬 VIDEO UPLOAD: File size: ${(await videoFile.length()) ~/ 1024} KB',
    );
    debugPrint('🎬 VIDEO UPLOAD: File path: ${videoFile.path}');

    try {
      // ================= Video compression to 720p =================
      File fileToUpload = videoFile;
      try {
        debugPrint('🎬 VIDEO UPLOAD: Compressing video to 720p...');
        final info = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality, // ~720p
          deleteOrigin: false,
        );
        if (info != null && info.file != null) {
          fileToUpload = info.file!;
          debugPrint(
            '🎬 VIDEO UPLOAD: Compression successful  new size: '
            '${(await fileToUpload.length()) ~/ 1024} KB',
          );
        } else {
          debugPrint(
            '🎬 VIDEO UPLOAD: Compression returned null, using original',
          );
        }
      } catch (e) {
        debugPrint('🎬 VIDEO UPLOAD: Compression error – $e');
      }

      final fileExtension = fileToUpload.path.split('.').last.toLowerCase();
      final fileName = 'video.$fileExtension';
      final storagePath = '$userId/$postId/$fileName';
      debugPrint(
        '🎬 VIDEO UPLOAD: Target storage path: $storagePath in bucket "$bucket"',
      );

      // Check if file exists and is readable
      if (!await fileToUpload.exists()) {
        debugPrint(
          '🎬 VIDEO UPLOAD ERROR: File does not exist at path: ${fileToUpload.path}',
        );
        return {'videoUrl': null, 'thumbnailUrl': null};
      }

      // Read file as bytes
      debugPrint('🎬 VIDEO UPLOAD: Reading file as bytes...');
      final fileBytes = await fileToUpload.readAsBytes();
      debugPrint(
        '🎬 VIDEO UPLOAD: Successfully read ${fileBytes.length} bytes',
      );

      // Upload to Supabase storage with retry mechanism
      debugPrint('🎬 VIDEO UPLOAD: Starting upload to Supabase storage...');
      const maxRetries = 3;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('🎬 VIDEO UPLOAD: Upload attempt $attempt of $maxRetries');
          await _supabase.client.storage
              .from(bucket)
              .uploadBinary(
                storagePath,
                fileBytes,
                fileOptions: const FileOptions(
                  cacheControl: '3600', // Cache for 1 hour
                  upsert: true,
                ),
              );
          debugPrint('🎬 VIDEO UPLOAD: Upload to storage successful');
          break; // Success, exit retry loop
        } catch (storageError) {
          debugPrint(
            '🎬 VIDEO UPLOAD ERROR: Storage upload failed (attempt $attempt): $storageError',
          );

          // Check if this is a permissions error (don't retry these)
          if (storageError.toString().contains('permission') ||
              storageError.toString().contains('not authorized') ||
              storageError.toString().contains('security')) {
            debugPrint(
              '🎬 VIDEO UPLOAD ERROR: This appears to be a row-level security issue. '
              'Please check RLS policies for the "$bucket" bucket.',
            );
            return {'videoUrl': null, 'thumbnailUrl': null};
          }

          // If this is the last attempt, return error
          if (attempt == maxRetries) {
            debugPrint('🎬 VIDEO UPLOAD ERROR: All retry attempts failed');
            return {'videoUrl': null, 'thumbnailUrl': null};
          }

          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      // Generate thumbnail from video
      String? thumbnailUrl;
      try {
        debugPrint('🎬 VIDEO UPLOAD: Generating thumbnail...');
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          fileToUpload.path,
          quality: 50, // Medium quality thumbnail
          position: 1000, // 1 second into the video
        );

        debugPrint('🎬 VIDEO UPLOAD: Thumbnail generated successfully');
        final thumbnailBytes = await thumbnailFile.readAsBytes();

        if (thumbnailBytes.isNotEmpty) {
          thumbnailUrl = await uploadPostThumbnail(
            thumbnailBytes,
            userId,
            postId,
          );

          if (thumbnailUrl != null) {
            debugPrint(
              '🎬 VIDEO UPLOAD: Thumbnail uploaded successfully: $thumbnailUrl',
            );
          } else {
            debugPrint(
              '🎬 VIDEO UPLOAD: Failed to upload thumbnail to storage',
            );
          }
        } else {
          debugPrint('🎬 VIDEO UPLOAD: Thumbnail file is empty');
        }

        // Clean up temporary thumbnail file
        try {
          await thumbnailFile.delete();
        } catch (e) {
          debugPrint(
            '🎬 VIDEO UPLOAD: Warning - could not delete temp thumbnail: $e',
          );
        }
      } catch (e) {
        debugPrint('🎬 VIDEO UPLOAD: Error generating thumbnail: $e');
        // Continue without thumbnail - video upload should still succeed
      }

      // Generate a long-lived signed URL (7 days)
      debugPrint('🎬 VIDEO UPLOAD: Generating signed URL...');
      final signedUrlResp = await _supabase.client.storage
          .from(bucket)
          .createSignedUrl(storagePath, 60 * 60 * 24 * 7);

      debugPrint('🎬 VIDEO UPLOAD: Success! Video URL: $signedUrlResp');

      // Return both video URL and thumbnail URL
      return {'videoUrl': signedUrlResp, 'thumbnailUrl': thumbnailUrl};
    } catch (e) {
      debugPrint('🎬 VIDEO UPLOAD ERROR: General error: $e');
      return {'videoUrl': null, 'thumbnailUrl': null};
    }
  }

  /// Legacy method for backward compatibility
  Future<String?> uploadPostVideo(
    File videoFile,
    String userId,
    String postId,
  ) async {
    final result = await uploadPostVideoWithThumbnail(
      videoFile,
      userId,
      postId,
    );
    return result['videoUrl'];
  }

  /// Upload a generated thumbnail for a video post and return its public URL
  Future<String?> uploadPostThumbnail(
    Uint8List thumbData,
    String userId,
    String postId,
  ) async {
    const bucket = 'posts'; // use same bucket to keep structure simple
    try {
      final storagePath = '$userId/$postId/thumbnail.jpg';
      await _supabase.client.storage
          .from(bucket)
          .uploadBinary(
            storagePath,
            thumbData,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // Return public URL
      final publicUrl = _supabase.client.storage
          .from(bucket)
          .getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading post thumbnail: $e');
      return null;
    }
  }

  /// Update post with video URL
  Future<bool> updatePostWithVideo(
    String postId,
    String videoUrl, {
    String? thumbnailUrl,
  }) async {
    debugPrint('🎬 VIDEO POST UPDATE: Updating post $postId with video URL');
    try {
      // Fetch existing metadata to merge video details
      debugPrint('🎬 VIDEO POST UPDATE: Fetching existing post metadata');
      final existing =
          await _supabase.client
              .from('posts')
              .select('metadata')
              .eq('id', postId)
              .maybeSingle();

      Map<String, dynamic> metadata = {};
      if (existing != null && existing['metadata'] is Map) {
        metadata = Map<String, dynamic>.from(existing['metadata'] as Map);
        debugPrint(
          '🎬 VIDEO POST UPDATE: Found existing metadata: ${metadata.keys.join(', ')}',
        );
      } else {
        debugPrint(
          '🎬 VIDEO POST UPDATE: No existing metadata found, creating new',
        );
      }

      // Don't add video_url to metadata since it has its own column
      // Only add thumbnail and processing info to metadata

      // Include thumbnail if provided
      if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
        metadata['video_thumbnail'] = thumbnailUrl;
      }

      // Add timestamp for tracking
      metadata['video_processed_at'] = DateTime.now().toIso8601String();

      debugPrint('🎬 VIDEO POST UPDATE: Executing database update');
      await _supabase.client
          .from('posts')
          .update({'video_url': videoUrl, 'metadata': metadata})
          .eq('id', postId);

      // Verify update
      final verification =
          await _supabase.client
              .from('posts')
              .select('video_url')
              .eq('id', postId)
              .maybeSingle();

      if (verification != null && verification['video_url'] == videoUrl) {
        debugPrint(
          '🎬 VIDEO POST UPDATE: Success! Video URL was saved correctly',
        );
        return true;
      } else {
        debugPrint(
          '🎬 VIDEO POST UPDATE: Warning - database update completed but verification failed',
        );
        return false;
      }
    } catch (e) {
      debugPrint(
        '🎬 VIDEO POST UPDATE ERROR: Failed to update post with video: $e',
      );

      // Try to determine if this is a permissions issue
      if (e.toString().contains('permission') ||
          e.toString().contains('not authorized') ||
          e.toString().contains('security')) {
        debugPrint(
          '🎬 VIDEO POST UPDATE ERROR: This appears to be a permissions issue. '
          'Check RLS policies for the posts table.',
        );
      }

      return false;
    }
  }

  /// Upload multiple post images with proper structure
  Future<List<String>> uploadPostImages(
    List<File> imageFiles,
    String userId,
    String postId,
  ) async {
    final List<String> uploadedUrls = [];

    for (int i = 0; i < imageFiles.length; i++) {
      final imageUrl = await uploadPostImage(
        imageFiles[i],
        userId,
        postId,
        imageIndex: i,
      );
      if (imageUrl != null) {
        uploadedUrls.add(imageUrl);
      }
    }

    return uploadedUrls;
  }

  /// Create a new post with images
  Future<String?> createPostWithImages(
    PostModel post,
    List<File> imageFiles,
  ) async {
    debugPrint(
      '⚠️ Starting createPostWithImages - Tracing for user_posts column issue',
    );
    try {
      // Validate user_id is not empty
      if (post.userId.isEmpty) {
        debugPrint('Error: user_id is null or empty');
        return null;
      }

      // First, create the post to get the ID
      final postData = post.toDatabaseMap();

      debugPrint('⚠️ Post data prepared: ${postData.keys.join(', ')}');

      // Try to fetch profile data to include with post
      try {
        final profileData =
            await _supabase.client
                .from('profiles')
                .select('username, nickname, avatar, google_avatar')
                .eq('user_id', post.userId)
                .maybeSingle();

        if (profileData != null) {
          // Add profile data to post metadata
          if (postData['metadata'] is Map) {
            (postData['metadata'] as Map)['profile_data'] = profileData;
          } else {
            postData['metadata'] = {'profile_data': profileData};
          }
          debugPrint('Added profile data to post metadata: $profileData');
        }
      } catch (e) {
        debugPrint('Error fetching profile data for post creation: $e');
        // Continue without profile data
      }

      debugPrint('Creating post with data: $postData');
      debugPrint(
        '⚠️ About to run SQL insert into posts table - watching for user_posts error',
      );

      final response =
          await _supabase.client
              .from('posts')
              .insert(postData)
              .select('id')
              .single();

      debugPrint('⚠️ SQL insert into posts table completed successfully');

      final postId = response['id'] as String;
      debugPrint('Post created successfully with ID: $postId');
      debugPrint(
        '⚠️ Post created. Now watching for user_posts column error in subsequent operations',
      );

      // Upload images if any
      if (imageFiles.isNotEmpty) {
        final imageUrls = await uploadPostImages(
          imageFiles,
          post.userId,
          postId,
        );

        if (imageUrls.isNotEmpty) {
          // Update post with image URLs
          // Don't store image_urls in metadata since we have separate image_url column
          final updateData = {
            'image_url': imageUrls.first,
            'metadata': {...post.metadata, 'image_count': imageUrls.length},
          };

          // Add a small delay to ensure the post is fully created before updating
          await Future.delayed(const Duration(milliseconds: 300));

          try {
            await _supabase.client
                .from('posts')
                .update(updateData)
                .eq('id', postId);

            // Double check the update
            final updatedPost =
                await _supabase.client
                    .from('posts')
                    .select()
                    .eq('id', postId)
                    .maybeSingle();

            debugPrint(
              'Post update verified: ${updatedPost?['image_url'] != null}',
            );
          } catch (e) {
            debugPrint('Error updating post with images: $e');
            // Try one more time after a longer delay
            await Future.delayed(const Duration(milliseconds: 500));
            await _supabase.client
                .from('posts')
                .update(updateData)
                .eq('id', postId);
          }

          debugPrint('Post updated with ${imageUrls.length} images');
        }
      }

      // Update the user posts cache after creating the post
      try {
        // Get the post with the new ID and add it to cache
        final createdPostResponse =
            await _supabase.client
                .from('posts')
                .select('*')
                .eq('id', postId)
                .single();

        if (createdPostResponse.isNotEmpty) {
          final createdPost = PostModel.fromMap(createdPostResponse);
          // Use the UserPostsCacheService to update the cache
          final cacheService = Get.find<UserPostsCacheService>();
          cacheService.addPostToCache(post.userId, createdPost);
          debugPrint('Added new post to user cache: $postId');

          // Update the user's post count and refresh relevant controllers
          await updateUserPostCount(post.userId);
        }
      } catch (cacheError) {
        debugPrint('Error updating post cache: $cacheError');
      }

      return postId;
    } catch (e) {
      debugPrint('Error creating post: $e');
      return null;
    }
  }

  /// Create a new post (legacy method for backward compatibility)
  Future<String?> createPost(PostModel post) async {
    return createPostWithImages(post, []);
  }

  /// Update the user's post count in memory and notify controllers
  Future<void> updateUserPostCount(String userId) async {
    try {
      // Get current count from database
      final response = await _supabase.client
          .from('posts')
          .select('id')
          .eq('user_id', userId)
          .eq('is_deleted', false);

      final postCount = response.length;
      debugPrint('Updated post count for user $userId is $postCount');

      // Update the post_count column in the profiles table
      try {
        await _supabase.client
            .from('profiles')
            .update({'post_count': postCount})
            .eq('user_id', userId);
        debugPrint('Updated post_count in profiles table for user $userId.');
      } catch (e) {
        debugPrint('Error updating post_count in profiles table: $e');
      }

      // Notify any controllers that need this information
      try {
        final cacheService = Get.find<UserPostsCacheService>();
        await cacheService.refreshUserPosts(userId);
        debugPrint('Refreshed posts cache for user: $userId');
      } catch (e) {
        debugPrint('Error refreshing user posts cache: $e');
      }

      try {
        final tags = ['profile_posts_$userId', 'profile_posts_current'];
        for (final tag in tags) {
          if (Get.isRegistered<ProfilePostsController>(tag: tag)) {
            final controller = Get.find<ProfilePostsController>(tag: tag);
            controller.refreshPosts(forceRefresh: true);
            debugPrint('Refreshed ProfilePostsController with tag: $tag');
            break;
          }
        }
      } catch (e) {
        debugPrint('Error updating profile controllers: $e');
      }
    } catch (e) {
      debugPrint('Error updating user post count: $e');
    }
  }

  /// Get posts feed with engagement-based algorithm
  Future<List<PostModel>> getPostsFeed(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Try the database function first
      try {
        final response = await _supabase.client.rpc(
          'get_posts_feed',
          params: {'p_user_id': userId, 'p_limit': limit, 'p_offset': offset},
        );
        return (response as List).map((post) {
          // Safe type casting to handle Map<dynamic, dynamic> from Supabase RPC
          Map<String, dynamic> safeMap;
          if (post is Map<String, dynamic>) {
            safeMap = post;
          } else if (post is Map) {
            safeMap = <String, dynamic>{};
            post.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
          } else {
            throw Exception('Invalid post data format from get_posts_feed RPC');
          }

          return PostModel.fromMap(safeMap);
        }).toList();
      } catch (rpcError) {
        debugPrint(
          'RPC function get_posts_feed not found, using fallback query: $rpcError',
        );

        // Fallback: Direct query with joins
        debugPrint(
          'Repository: Querying posts with offset: $offset, limit: $limit',
        );
        final response = await _supabase.client
            .from('posts')
            .select('''
              *,
              profiles!posts_user_id_fkey(username, nickname, avatar, google_avatar)
            ''')
            .or(
              'is_active.is.null,is_active.eq.true',
            ) // Include posts where is_active is null or true
            .or(
              'is_deleted.is.null,is_deleted.eq.false',
            ) // Include posts where is_deleted is null or false
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        debugPrint('Repository: Query completed');

        final posts = response as List;
        debugPrint('Repository: Found ${posts.length} posts in database');

        // Transform the data to match PostModel structure
        final List<PostModel> postModels =
            posts.map((post) {
              // Safe type casting to handle Map<dynamic, dynamic> from Supabase
              final postMap = <String, dynamic>{};
              if (post is Map) {
                post.forEach((key, value) {
                  postMap[key.toString()] = value;
                });
              }

              // Extract profile data from the join
              if (postMap['profiles'] != null) {
                final profile = postMap['profiles'];
                if (profile is Map) {
                  postMap['username'] = profile['username'];
                  postMap['nickname'] = profile['nickname'];
                  postMap['avatar'] = profile['avatar'];
                  postMap['google_avatar'] = profile['google_avatar'];
                }
              }

              // Remove the profiles key as it's not part of PostModel
              postMap.remove('profiles');

              return PostModel.fromMap(postMap);
            }).toList();

        return postModels;
      }
    } catch (e) {
      debugPrint('Error getting posts feed: $e');
      return [];
    }
  }

  /// Get user's own posts with pagination support and privacy filter
  Future<List<PostModel>> getUserPosts(
    String userId,
    String currentUserId, {
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      List<dynamic> posts;
      final isCurrentUser = userId == currentUserId;

      if (isCurrentUser) {
        // For current user, show all posts
        final response = await _supabase.client
            .from('posts')
            .select('*')
            .eq('user_id', userId)
            .eq('is_deleted', false)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        posts = response;
        debugPrint('Showing all posts for current user');
      } else {
        // For other users, check if following
        final followingResponse =
            await _supabase.client
                .from('follows')
                .select('id')
                .eq('follower_id', currentUserId)
                .eq('following_id', userId)
                .maybeSingle();

        final isFollowing = followingResponse != null;

        if (isFollowing) {
          // If following, show all posts
          final allResponse = await _supabase.client
              .from('posts')
              .select('*')
              .eq('user_id', userId)
              .eq('is_deleted', false)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          posts = allResponse;
          debugPrint('Showing all posts because user is following');
        } else {
          // If not following, only show global posts
          final publicResponse = await _supabase.client
              .from('posts')
              .select('*')
              .eq('user_id', userId)
              .eq('is_deleted', false)
              .eq('global', true) // Only show global posts
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          posts = publicResponse;
          debugPrint('Showing only global posts because user is not following');
        }
      }

      // Then get the user profile data
      final profileResponse =
          await _supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', userId)
              .single();

      // Combine the data
      final List<PostModel> postModels =
          posts.map((post) {
            // Safe type casting to handle Map<dynamic, dynamic> from Supabase
            final postMap = <String, dynamic>{};
            if (post is Map) {
              post.forEach((key, value) {
                postMap[key.toString()] = value;
              });
            }
            postMap['username'] = profileResponse['username'];
            postMap['nickname'] = profileResponse['nickname'];
            postMap['avatar'] = profileResponse['avatar'];
            postMap['google_avatar'] = profileResponse['google_avatar'];
            return PostModel.fromMap(postMap);
          }).toList();

      return postModels;
    } catch (e) {
      debugPrint('Error getting user posts: $e');
      return [];
    }
  }

  /// Delete a specific post and its associated media
  Future<bool> deletePost(String postId, String userId) async {
    try {
      // 1. Get the post details to find associated media
      final postData =
          await _supabase.client
              .from('posts')
              .select('image_url, video_url, metadata')
              .eq('id', postId)
              .eq('user_id', userId)
              .maybeSingle();

      if (postData == null) {
        debugPrint('Post not found or not owned by user: $postId');
        return false;
      }

      // 2. Permanently delete post from posts table
      await _supabase.client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId);

      debugPrint('Post deleted from database: $postId');

      // 3. Delete associated media from storage - Delete the entire post folder
      try {
        final storagePath = '$userId/$postId';

        // Helper: Delete an entire folder for a bucket
        Future<void> deleteFolder(String bucket) async {
          try {
            final list = await _supabase.client.storage
                .from(bucket)
                .list(path: storagePath);
            final files = list.map((e) => '$storagePath/${e.name}').toList();
            if (files.isNotEmpty) {
              await _supabase.client.storage.from(bucket).remove(files);
              debugPrint(
                'Deleted ${files.length} files from $bucket/$storagePath',
              );
            } else {
              debugPrint('No files found in $bucket/$storagePath');
            }
          } catch (e) {
            debugPrint('Error deleting folder $bucket/$storagePath: $e');
          }
        }

        await deleteFolder('posts'); // images & thumbnails
        await deleteFolder('videos'); // videos

        // --- Fallback: parse URLs directly when folder listing fails (e.g. RLS) ---
        Map<String, String>? parseUrl(String? url) {
          if (url == null || url.isEmpty) return null;
          try {
            final uri = Uri.parse(url);
            final segments = uri.pathSegments;
            // Find marker ('sign', 'public') which is followed by bucket name
            int bucketIdx = segments.indexOf('sign');
            if (bucketIdx == -1) bucketIdx = segments.indexOf('public');
            if (bucketIdx == -1) bucketIdx = segments.indexOf('object') + 1;
            if (bucketIdx < 0 || bucketIdx >= segments.length) return null;
            final bucket = segments[bucketIdx];
            final path = segments.sublist(bucketIdx + 1).join('/');
            return {'bucket': bucket, 'path': path};
          } catch (e) {
            debugPrint('URL parse error: $e');
            return null;
          }
        }

        Future<void> removeByUrl(String? url) async {
          final info = parseUrl(url);
          if (info == null) return;
          try {
            await _supabase.client.storage.from(info['bucket']!).remove([
              info['path']!,
            ]);
            debugPrint(
              'Removed file via URL ${info['bucket']}/${info['path']}',
            );
          } catch (e) {
            debugPrint('Error removing file via URL: $e');
          }
        }

        await removeByUrl(postData['image_url'] as String?);
        await removeByUrl(postData['video_url'] as String?);
      } catch (mediaError) {
        debugPrint('Error processing media deletion: $mediaError');
      }

      // 4. Update post count in profile (skip database update as column doesn't exist)
      try {
        // Get current count from database
        final response = await _supabase.client
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('is_deleted', false);

        final postCount = response.length;

        // Update the post_count column in the profiles table
        try {
          await _supabase.client
              .from('profiles')
              .update({'post_count': postCount})
              .eq('user_id', userId);
          debugPrint(
            'Updated post_count in profiles table for user $userId after deletion.',
          );
        } catch (e) {
          debugPrint(
            'Error updating post_count in profiles table after deletion: $e',
          );
        }

        // Notify controllers about post deletion
        try {
          final cacheService = Get.find<UserPostsCacheService>();
          cacheService.refreshUserPosts(userId);

          try {
            final tags = [
              'profile_posts_$userId',
              'profile_posts_current',
              'profile_threads_current',
            ];
            for (final tag in tags) {
              if (Get.isRegistered<ProfilePostsController>(tag: tag)) {
                final controller = Get.find<ProfilePostsController>(tag: tag);
                controller.refreshPosts(forceRefresh: true);
                debugPrint(
                  'Successfully refreshed ProfilePostsController with tag: $tag',
                );
                break;
              }
            }
          } catch (controllerError) {
            debugPrint(
              'ProfilePostsController refresh attempted but not found: $controllerError',
            );
          }
        } catch (e) {
          debugPrint('Error refreshing data after post deletion: $e');
        }
      } catch (countError) {
        debugPrint('Error calculating post count: $countError');
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Update post engagement (likes, views, etc.)
  Future<bool> updatePostEngagement(
    String postId,
    String engagementType,
    int increment,
  ) async {
    try {
      final columnName = '${engagementType}_count';

      // First, check if the post exists
      final postExists =
          await _supabase.client
              .from('posts')
              .select('id')
              .eq('id', postId)
              .maybeSingle();

      if (postExists == null) {
        debugPrint('Post not found: $postId - cannot update engagement');
        return false;
      }

      // Try RPC function first, fallback to direct update if it fails
      try {
        await _supabase.client.rpc(
          'increment_post_engagement',
          params: {
            'post_id': postId,
            'column_name': columnName,
            'increment_by': increment,
          },
        );
        debugPrint(
          'Successfully updated $columnName for post $postId using RPC',
        );
        return true;
      } catch (rpcError) {
        debugPrint('RPC function failed, using direct update: $rpcError');

        // Fallback: Get current value and update directly
        try {
          final currentPost =
              await _supabase.client
                  .from('posts')
                  .select(columnName)
                  .eq('id', postId)
                  .maybeSingle();

          if (currentPost == null) {
            debugPrint('Post not found during fallback: $postId');
            return false;
          }

          final currentValue = currentPost[columnName] as int? ?? 0;
          final newValue = (currentValue + increment).clamp(
            0,
            999999,
          ); // Prevent negative values

          await _supabase.client
              .from('posts')
              .update({
                columnName: newValue,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', postId);

          debugPrint(
            'Successfully updated $columnName for post $postId using direct update: $currentValue -> $newValue',
          );
          return true;
        } catch (fallbackError) {
          debugPrint('Fallback update also failed: $fallbackError');

          // Last resort: try a simple update without getting current value
          try {
            await _supabase.client.rpc(
              'increment_post_engagement_simple',
              params: {
                'p_post_id': postId,
                'p_column': columnName,
                'p_increment': increment,
              },
            );
            debugPrint(
              'Successfully updated $columnName for post $postId using simple RPC',
            );
            return true;
          } catch (simpleRpcError) {
            debugPrint('Simple RPC also failed: $simpleRpcError');
            return false;
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating post engagement: $e');
      return false;
    }
  }

  /// Toggle post like using the new atomic SQL function
  Future<Map<String, dynamic>?> togglePostLike(
    String postId,
    String userId,
  ) async {
    try {
      final response = await _supabase.client.rpc(
        'toggle_post_like',
        params: {'p_post_id': postId, 'p_user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final result = response.first;
        final status = result['status'] as String?;
        final message = result['message'] as String?;

        if (status == 'error') {
          debugPrint('Error toggling post like: $message');
          return null;
        }

        debugPrint(
          'Successfully toggled like for post $postId by user $userId. New state: ${result['is_liked']}, Count: ${result['new_likes_count']}, Message: $message',
        );
        return {
          'isLiked': result['is_liked'] as bool,
          'likesCount': result['new_likes_count'] as int,
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error toggling post like: $e');
      return null;
    }
  }

  /// Toggle post star using database function
  Future<Map<String, dynamic>?> togglePostStar(
    String postId,
    String userId,
  ) async {
    try {
      debugPrint('Toggling star for post $postId by user $userId');

      final response = await _supabase.client.rpc(
        'toggle_post_star',
        params: {'p_post_id': postId, 'p_user_id': userId},
      );

      if (response != null && response.isNotEmpty) {
        final result = response[0];
        final isStarred = result['is_starred'] as bool;
        final starCount = result['star_count'] as int;
        final status = result['status'] as String;
        final message = result['message'] as String;

        debugPrint(
          'Star toggle result: isStarred=$isStarred, count=$starCount, status=$status, message=$message',
        );

        if (status == 'success') {
          return {
            'isStarred': isStarred,
            'starCount': starCount,
            'status': status,
            'message': message,
          };
        } else {
          debugPrint('Star toggle failed: $message');
          return null;
        }
      }

      debugPrint('No response from toggle_post_star function');
      return null;
    } catch (e) {
      debugPrint('Error toggling post star: $e');
      return null;
    }
  }

  /// Legacy method for backward compatibility - now uses togglePostStar
  @Deprecated('Use togglePostStar instead')
  Future<bool> togglePostEngagement(
    String postId,
    String userId,
    String engagementType,
  ) async {
    if (engagementType == 'stars') {
      final result = await togglePostStar(postId, userId);
      return result != null && result['status'] == 'success';
    }

    throw Exception(
      'Use togglePostLike for likes and togglePostStar for stars.',
    );
  }

  /// Get current like state for a user and post
  Future<Map<String, dynamic>?> getUserPostLikeState(
    String postId,
    String userId,
  ) async {
    try {
      // Use the same system as toggle_post_like to check like state
      // This should use a SQL function that checks the post_likes table or similar
      final response = await _supabase.client.rpc(
        'get_user_post_like_state',
        params: {'p_post_id': postId, 'p_user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final result = response.first;
        return {
          'isLiked': result['is_liked'] as bool? ?? false,
          'likesCount': result['likes_count'] as int? ?? 0,
        };
      }

      // Fallback: get likes count from posts table and check post_likes table directly
      final postResponse =
          await _supabase.client
              .from('posts')
              .select('likes_count')
              .eq('id', postId)
              .maybeSingle();

      final likesCount =
          postResponse != null ? postResponse['likes_count'] ?? 0 : 0;

      // Check if user has liked this post in post_likes table
      final likeResponse =
          await _supabase.client
              .from('post_likes')
              .select('id')
              .eq('user_id', userId)
              .eq('post_id', postId)
              .maybeSingle();

      final isLiked = likeResponse != null;

      return {'isLiked': isLiked, 'likesCount': likesCount};
    } catch (e) {
      debugPrint('Error getting user post like state: $e');
      return {'isLiked': false, 'likesCount': 0};
    }
  }

  /// Check if user has interacted with a post (like or star)
  /// Uses post_likes and user_favorites tables
  Future<Map<String, bool>> getUserPostEngagement(
    String postId,
    String userId,
  ) async {
    try {
      // Check if user liked the post
      final likeResponse =
          await _supabase.client
              .from('post_likes')
              .select('id')
              .eq('post_id', postId)
              .eq('user_id', userId)
              .maybeSingle();

      // Check if user favorited the post
      final favoriteResponse =
          await _supabase.client
              .from('user_favorites')
              .select('id')
              .eq('post_id', postId)
              .eq('user_id', userId)
              .maybeSingle();

      return {
        'isLiked': likeResponse != null,
        'isFavorited': favoriteResponse != null,
      };
    } catch (e) {
      debugPrint('Error checking user post engagement: $e');
      return {'isLiked': false, 'isFavorited': false};
    }
  }

  /// Update a post
  Future<bool> updatePost(String postId, Map<String, dynamic> updates) async {
    try {
      await _supabase.client.from('posts').update(updates).eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('Error updating post: $e');
      return false;
    }
  }

  /// Insert bare post (used for video posts before media upload)
  Future<String?> insertPost(PostModel post) async {
    try {
      final postData = post.toDatabaseMap();

      final response =
          await _supabase.client
              .from('posts')
              .insert(postData)
              .select('id')
              .single();
      return response['id'] as String;
    } catch (e) {
      debugPrint('Error inserting post: $e');
      return null;
    }
  }
}
