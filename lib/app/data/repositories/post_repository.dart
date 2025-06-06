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

          await _supabase.client
              .from('posts')
              .update(updateData)
              .eq('id', postId);

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

  /// Get user's own posts with pagination support
  Future<List<PostModel>> getUserPosts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // First get the posts with pagination
      final response = await _supabase.client
          .from('posts')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = response as List;

      if (posts.isEmpty) {
        return [];
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

  /// Delete a specific post
  Future<bool> deletePost(String postId, String userId) async {
    try {
      await _supabase.client
          .from('posts')
          .delete()
          .eq('id', postId)
          .eq('user_id', userId);
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
        debugPrint(
          'Successfully toggled like for post $postId by user $userId. New state: ${result['is_liked']}, Count: ${result['new_likes_count']}',
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

  /// Toggle post engagement (stars) using the existing SQL function
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

      await _supabase.client.rpc(
        'toggle_post_engagement',
        params: {'p_post_id': postId, 'p_user_id': userId, 'p_column': 'stars'},
      );
      debugPrint(
        'Successfully toggled $engagementType for post $postId by user $userId',
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
      final response = await _supabase.client.rpc(
        'get_user_post_like_state',
        params: {'p_post_id': postId, 'p_user_id': userId},
      );

      if (response != null && response is List && response.isNotEmpty) {
        final result = response.first;
        return {
          'isLiked': result['is_liked'] as bool,
          'likesCount': result['likes_count'] as int,
        };
      }
      return {'isLiked': false, 'likesCount': 0};
    } catch (e) {
      debugPrint('Error getting user post like state: $e');
      return {'isLiked': false, 'likesCount': 0};
    }
  }

  /// Check if user has interacted with a post (like or star)
  /// @deprecated This method uses the old user_post_engagements table
  /// Use getUserPostLikeState() for likes and implement separate methods for other engagements
  Future<Map<String, bool>> getUserPostEngagement(
    String postId,
    String userId,
  ) async {
    try {
      final response =
          await _supabase.client
              .from('user_post_engagements')
              .select('likes, stars')
              .eq('post_id', postId)
              .eq('user_id', userId)
              .maybeSingle();

      if (response == null) {
        return {'isLiked': false, 'isFavorited': false};
      }

      return {
        'isLiked': response['likes'] == true,
        'isFavorited': response['stars'] == true,
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
