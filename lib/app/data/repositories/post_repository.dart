import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';

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
  /// Storage structure: videos/{user_id}/{post_id}/video.{extension}
  Future<String?> uploadPostVideo(
    File videoFile,
    String userId,
    String postId,
  ) async {
    try {
      final fileExtension = videoFile.path.split('.').last.toLowerCase();
      final fileName = 'video.$fileExtension';
      final storagePath = '$userId/$postId/$fileName';

      // Read file as bytes
      final fileBytes = await videoFile.readAsBytes();

      // Upload to Supabase storage with proper structure
      await _supabase.client.storage
          .from('videos')
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
          .from('videos')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading post video: $e');
      return null;
    }
  }

  /// Update post with video URL
  Future<bool> updatePostWithVideo(String postId, String videoUrl) async {
    try {
      await _supabase.client
          .from('posts')
          .update({
            'image_url': null, // Clear image URL if any
            'video_url': videoUrl,
            'metadata': {'video_url': videoUrl, 'video_type': 'mp4'},
          })
          .eq('id', postId);
      return true;
    } catch (e) {
      debugPrint('Error updating post with video: $e');
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
    try {
      // Validate user_id is not empty
      if (post.userId.isEmpty) {
        debugPrint('Error: user_id is null or empty');
        return null;
      }

      // First, create the post to get the ID
      final postData = post.toDatabaseMap();
      postData.remove('id'); // Remove ID so database generates it

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

      final response =
          await _supabase.client
              .from('posts')
              .insert(postData)
              .select('id')
              .single();

      final postId = response['id'] as String;
      debugPrint('Post created successfully with ID: $postId');

      // Upload images if any
      if (imageFiles.isNotEmpty) {
        final imageUrls = await uploadPostImages(
          imageFiles,
          post.userId,
          postId,
        );

        if (imageUrls.isNotEmpty) {
          // Update post with image URLs
          final updateData = {
            'image_url': imageUrls.first,
            'metadata': {
              ...post.metadata,
              'image_urls': imageUrls,
              'image_count': imageUrls.length,
            },
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
          if (post is Map<String, dynamic>) {
            return PostModel.fromMap(post);
          } else if (post is Map) {
            final safeMap = <String, dynamic>{};
            post.forEach((key, value) {
              safeMap[key.toString()] = value;
            });
            return PostModel.fromMap(safeMap);
          } else {
            throw Exception('Invalid post data format from get_posts_feed RPC');
          }
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
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final currentUserId = _supabase.client.auth.currentUser?.id;
      final isCurrentUser = userId == currentUserId;
      List posts;

      // For the current user, fetch all their posts
      if (isCurrentUser) {
        // First get the posts with pagination
        final response = await _supabase.client
            .from('posts')
            .select('*')
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);

        posts = response as List;

        if (posts.isEmpty) {
          return [];
        }
      } else {
        // For other users, check if current user follows them
        bool isFollowing = false;

        try {
          // Check if current user follows the profile user
          if (currentUserId != null) {
            final followResponse = await _supabase.client
                .from('follows')
                .select()
                .eq('follower_id', currentUserId)
                .eq('following_id', userId)
                .limit(1);

            isFollowing = followResponse.isNotEmpty;
            debugPrint(
              'Current user ${isFollowing ? "follows" : "does not follow"} profile user $userId',
            );
          }
        } catch (e) {
          debugPrint('Error checking follow status: $e');
          isFollowing = false;
        }

        // If user follows the profile owner, get all posts
        // Otherwise, only get public/global posts
        final List response;

        if (isFollowing) {
          // If following, show all posts
          final followingResponse = await _supabase.client
              .from('posts')
              .select('*')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          response = followingResponse as List;
          debugPrint('Showing all posts because user is following');
        } else {
          // If not following, only show public posts
          final publicResponse = await _supabase.client
              .from('posts')
              .select('*')
              .eq('user_id', userId)
              .eq('global', true)
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);
          response = publicResponse as List;
          debugPrint('Showing only global posts because user is not following');
        }

        posts = response;

        debugPrint(
          'Retrieved ${posts.length} posts for other user (following: $isFollowing)',
        );

        if (posts.isEmpty) {
          return [];
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

      // 2. Delete from posts table
      await _supabase.client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId);

      debugPrint('Post deleted from database: $postId');

      // 3. Delete associated media from storage - Delete the entire post folder
      try {
        // Delete the entire post folder in storage (userId/postId/)
        final storagePath = '$userId/$postId';
        debugPrint('Attempting to delete post folder: $storagePath');

        // First try the posts bucket (for images)
        try {
          // List all files in the post folder
          final postsResponse = await _supabase.client.storage
              .from('posts')
              .list(path: storagePath);

          // Get file paths to delete
          final List<String> filesToDelete =
              postsResponse.map((FileObject file) {
                return '$storagePath/${file.name}';
              }).toList();

          if (filesToDelete.isNotEmpty) {
            // Delete all files in the folder
            await _supabase.client.storage.from('posts').remove(filesToDelete);
            debugPrint(
              'Deleted ${filesToDelete.length} files from posts storage: $storagePath',
            );
          } else {
            debugPrint('No files found in posts folder: $storagePath');
          }
        } catch (postsError) {
          debugPrint('Error handling posts storage deletion: $postsError');
        }

        // Then try the videos bucket
        try {
          // List all files in the post folder in the videos bucket
          final videosResponse = await _supabase.client.storage
              .from('videos')
              .list(path: storagePath);

          // Get file paths to delete
          final List<String> videosToDelete =
              videosResponse.map((FileObject file) {
                return '$storagePath/${file.name}';
              }).toList();

          if (videosToDelete.isNotEmpty) {
            // Delete all files in the folder
            await _supabase.client.storage
                .from('videos')
                .remove(videosToDelete);
            debugPrint(
              'Deleted ${videosToDelete.length} files from videos storage: $storagePath',
            );
          } else {
            debugPrint('No files found in videos folder: $storagePath');
          }
        } catch (videosError) {
          debugPrint('Error handling videos storage deletion: $videosError');
        }

        // Fallback: If listing fails, try to extract paths from URLs
        if (postData['image_url'] != null || postData['video_url'] != null) {
          debugPrint('Using fallback URL-based deletion method');

          // Handle image URL
          if (postData['image_url'] != null) {
            try {
              final uri = Uri.parse(postData['image_url']);
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 5) {
                final bucket = pathSegments[3]; // 'posts' or 'videos'
                final filePath = pathSegments.sublist(4).join('/');
                await _supabase.client.storage.from(bucket).remove([filePath]);
                debugPrint('Deleted image from URL path: $filePath');
              }
            } catch (imgError) {
              debugPrint('Error deleting image from URL: $imgError');
            }
          }

          // Handle video URL
          if (postData['video_url'] != null) {
            try {
              final uri = Uri.parse(postData['video_url']);
              final pathSegments = uri.pathSegments;
              if (pathSegments.length >= 5) {
                final bucket = pathSegments[3]; // 'posts' or 'videos'
                final filePath = pathSegments.sublist(4).join('/');
                await _supabase.client.storage.from(bucket).remove([filePath]);
                debugPrint('Deleted video from URL path: $filePath');
              }
            } catch (videoError) {
              debugPrint('Error deleting video from URL: $videoError');
            }
          }
        }
      } catch (mediaError) {
        debugPrint('Error processing media deletion: $mediaError');
        // Continue despite media errors - the post is already deleted
      }

      // 4. Update post count in profile
      try {
        // Get current count from database
        final response = await _supabase.client
            .from('posts')
            .select('id')
            .eq('user_id', userId)
            .eq('is_deleted', false);

        final postCount = response.length;

        // Update the profile
        await _supabase.client
            .from('profiles')
            .update({'post_count': postCount})
            .eq('user_id', userId);

        debugPrint('Updated post count for user $userId to $postCount');
      } catch (countError) {
        debugPrint('Error updating post count: $countError');
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
      } catch (rpcError) {
        debugPrint('RPC function failed, using direct update: $rpcError');

        // Fallback: Get current value and update directly
        try {
          final currentPost =
              await _supabase.client
                  .from('posts')
                  .select(columnName)
                  .eq('id', postId)
                  .single();

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
        } catch (fallbackError) {
          debugPrint('Fallback update also failed: $fallbackError');

          // Last resort: try a simple update without getting current value
          await _supabase.client.rpc(
            'increment_post_engagement_simple',
            params: {
              'p_post_id': postId,
              'p_column': columnName,
              'p_increment': increment,
            },
          );
        }
      }

      return true;
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

  /// Toggle post engagement (stars) using user_interactions table
  /// Also updates user_favorites table
  Future<bool> togglePostEngagement(
    String postId,
    String userId,
    String engagementType,
  ) async {
    try {
      // Only handle stars now, likes are handled by togglePostLike
      if (engagementType != 'stars') {
        throw Exception(
          'Use togglePostLike for likes. This function only handles stars.',
        );
      }

      // Check if interaction exists
      final existingInteraction =
          await _supabase.client
              .from('user_interactions')
              .select('id, metadata')
              .eq('user_id', userId)
              .eq('post_id', postId)
              .maybeSingle();

      bool isAddingStar = false;

      if (existingInteraction != null) {
        // Update existing interaction
        final metadata = existingInteraction['metadata'] ?? {};
        if (metadata is Map) {
          // Toggle star status
          final Map<String, dynamic> updatedMetadata =
              Map<String, dynamic>.from(metadata);
          if (updatedMetadata.containsKey('star')) {
            updatedMetadata.remove('star');
            isAddingStar = false;
          } else {
            updatedMetadata['star'] = true;
            isAddingStar = true;
          }

          // Determine primary interaction type
          String primaryInteractionType = 'star';
          if (updatedMetadata.containsKey('like')) {
            primaryInteractionType = 'like';
          }
          if (updatedMetadata.containsKey('comment')) {
            primaryInteractionType = 'comment';
          }
          if (updatedMetadata.containsKey('share')) {
            primaryInteractionType = 'share';
          }

          await _supabase.client
              .from('user_interactions')
              .update({
                'interaction_type': primaryInteractionType,
                'metadata': updatedMetadata,
              })
              .eq('id', existingInteraction['id']);
        }
      } else {
        // Create new interaction with star
        await _supabase.client.from('user_interactions').insert({
          'user_id': userId,
          'post_id': postId,
          'interaction_type': 'star',
          'metadata': {'star': true},
          'created_at': DateTime.now().toIso8601String(),
        });
        isAddingStar = true;
      }

      // Also update user_favorites table
      if (isAddingStar) {
        // Check if favorite already exists to avoid duplicates
        final existingFavorite =
            await _supabase.client
                .from('user_favorites')
                .select('id')
                .eq('user_id', userId)
                .eq('post_id', postId)
                .maybeSingle();

        if (existingFavorite == null) {
          // Add to favorites
          await _supabase.client.from('user_favorites').insert({
            'user_id': userId,
            'post_id': postId,
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Added post $postId to user_favorites for user $userId');
        }
      } else {
        // Remove from favorites
        await _supabase.client
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
        debugPrint('Removed post $postId from user_favorites for user $userId');
      }

      debugPrint(
        'Successfully toggled $engagementType for post $postId by user $userId using user_interactions table',
      );
      return true;
    } catch (e) {
      debugPrint('Error toggling post engagement: $e');
      return false;
    }
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
  /// Uses the new user_interactions table
  /// Use getUserPostLikeState() for likes specifically
  Future<Map<String, bool>> getUserPostEngagement(
    String postId,
    String userId,
  ) async {
    try {
      final response =
          await _supabase.client
              .from('user_interactions')
              .select('metadata')
              .eq('post_id', postId)
              .eq('user_id', userId)
              .maybeSingle();

      if (response == null) {
        return {'isLiked': false, 'isFavorited': false};
      }

      final metadata = response['metadata'];
      if (metadata is! Map) {
        return {'isLiked': false, 'isFavorited': false};
      }

      return {
        'isLiked': metadata.containsKey('like'),
        'isFavorited': metadata.containsKey('star'),
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
}
