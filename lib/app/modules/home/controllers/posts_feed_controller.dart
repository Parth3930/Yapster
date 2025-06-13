import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/data/models/post_model.dart';

import 'package:yapster/app/core/services/user_interaction_service.dart';
import 'package:yapster/app/core/services/intelligent_feed_service.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';

import 'dart:async';

class PostsFeedController extends GetxController {
  SupabaseService get _supabase => Get.find<SupabaseService>();
  PostRepository get _postRepository => Get.find<PostRepository>();
  UserInteractionService get _interactionService =>
      Get.find<UserInteractionService>();
  IntelligentFeedService get _feedService => Get.find<IntelligentFeedService>();
  UserPostsCacheService get _cacheService => Get.find<UserPostsCacheService>();

  // Observable lists
  final RxList<PostModel> posts = <PostModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadedOnce = false.obs;
  final RxString currentUserId = ''.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMorePosts = true.obs;

  // Cache management - optimized for better performance
  DateTime? _lastPostsLoad;
  static const Duration _postsCacheDuration = Duration(
    minutes: 15,
  ); // Significantly increased cache duration for better performance
  static const int _postsPerPage = 20; // Batch size for feed_queue fetch

  // Realtime subscription
  RealtimeChannel? _postsSubscription;

  // Periodic refresh for empty feed
  Timer? _periodicRefreshTimer;

  // Hot reload detection
  static bool _isAppRestart = true;

  @override
  void onInit() {
    super.onInit();
    currentUserId.value = _supabase.client.auth.currentUser?.id ?? '';

    // Detect if this is a hot reload (not app restart)
    if (_isAppRestart) {
      _isAppRestart = false; // Mark that app has been initialized
    }

    // Always try to load posts, even if preloaded data exists
    // This ensures consistency on hot reload
    // Initialize feed using feed_queue table
    _initializeFeed();
    _setupRealtimeSubscription();
  }

  /// Initialize feed with proper fallback handling
  Future<void> _initializeFeed() async {
    try {
      debugPrint('Initializing posts feed...');

      // Load posts from feed_queue without any cache-based filtering
      await loadPosts();

      // Start periodic refresh if feed is empty
      _startPeriodicRefreshIfNeeded();
    } catch (e) {
      debugPrint('Error initializing feed: $e');
      // Fallback to loading posts normally
      await loadPosts();
    }
  }

  @override
  void onClose() {
    _postsSubscription?.unsubscribe();
    _periodicRefreshTimer?.cancel();
    super.onClose();
  }

  /// Start periodic refresh if feed is empty
  void _startPeriodicRefreshIfNeeded() {
    if (posts.isEmpty) {
      _periodicRefreshTimer?.cancel();
      _periodicRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (posts.isEmpty) {
          debugPrint('Feed still empty, checking for new posts...');
          loadPosts(forceRefresh: true);
        } else {
          // Stop timer once we have posts
          timer.cancel();
        }
      });
    }
  }

  /// Stop periodic refresh
  void _stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  /// Fetch profile data for a user
  Future<Map<String, dynamic>?> _fetchProfileData(String userId) async {
    try {
      final response =
          await _supabase.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', userId) // Changed from 'id' to 'user_id'
              .maybeSingle();

      debugPrint('Fetched profile data for $userId: $response');
      return response;
    } catch (e) {
      debugPrint('Error fetching profile data for user $userId: $e');
      return null;
    }
  }

  /// Update profile data for a specific post
  void updatePostProfileData(String postId, Map<String, dynamic> profileData) {
    try {
      final index = posts.indexWhere((post) => post.id == postId);
      if (index != -1) {
        final post = posts[index];
        final updatedPost = post.copyWith(
          username: profileData['username'],
          nickname: profileData['nickname'],
          avatar: profileData['avatar'],
          googleAvatar: profileData['google_avatar'],
        );

        posts[index] = updatedPost;
        update(); // Trigger UI update

        debugPrint(
          'Updated profile data for post $postId from widget callback',
        );
      }
    } catch (e) {
      debugPrint('Error updating post profile data: $e');
    }
  }

  /// Refresh profile data for posts that are missing it
  Future<void> refreshMissingProfileData() async {
    try {
      bool hasUpdates = false;

      for (int i = 0; i < posts.length; i++) {
        final post = posts[i];

        // Check if post is missing profile data
        if ((post.avatar == null ||
                post.avatar!.isEmpty ||
                post.avatar == 'null') &&
            (post.username == null || post.username!.isEmpty)) {
          debugPrint(
            'Refreshing profile data for post ${post.id} by user ${post.userId}',
          );

          final profileData = await _fetchProfileData(post.userId);
          if (profileData != null) {
            final updatedPost = post.copyWith(
              username: profileData['username'],
              nickname: profileData['nickname'],
              avatar: profileData['avatar'],
              googleAvatar: profileData['google_avatar'],
            );

            posts[i] = updatedPost;
            hasUpdates = true;

            debugPrint(
              'Updated profile data for post ${post.id}: ${profileData['username']}',
            );
          }
        }
      }

      if (hasUpdates) {
        posts.refresh();
        debugPrint('Refreshed profile data for posts with missing data');
      }
    } catch (e) {
      debugPrint('Error refreshing missing profile data: $e');
    }
  }

  /// Setup realtime subscription for posts
  void _setupRealtimeSubscription() {
    _postsSubscription =
        _supabase.client
            .channel('posts_realtime')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('New post inserted: ${payload.newRecord}');
                _handleNewPost(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('Post updated: ${payload.newRecord}');
                _handlePostUpdate(payload.newRecord);
              },
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.delete,
              schema: 'public',
              table: 'posts',
              callback: (payload) {
                debugPrint('Post deleted: ${payload.oldRecord}');
                _handlePostDelete(payload.oldRecord);
              },
            )
            .subscribe();
  }

  /// Handle new post from realtime
  void _handleNewPost(Map<String, dynamic> postData) async {
    try {
      // Don't add current user's posts to feed
      if (postData['user_id'] == currentUserId.value) return;

      // Check if post is active and not deleted
      if (postData['is_active'] == true && postData['is_deleted'] == false) {
        // Fetch profile data for the post author
        final profileData = await _fetchProfileData(postData['user_id']);

        // Merge profile data with post data
        final enrichedPostData = Map<String, dynamic>.from(postData);
        if (profileData != null) {
          enrichedPostData['username'] = profileData['username'];
          enrichedPostData['nickname'] = profileData['nickname'];
          enrichedPostData['avatar'] = profileData['avatar'];
          enrichedPostData['google_avatar'] = profileData['google_avatar'];
        }

        final newPost = PostModel.fromMap(enrichedPostData);

        // Add to beginning of feed
        posts.insert(0, newPost);

        // Limit feed size to prevent memory issues
        if (posts.length > 100) {
          posts.removeLast();
        }

        debugPrint('Added new post with profile data: ${newPost.username}');
      }
    } catch (e) {
      debugPrint('Error handling new post: $e');
    }
  }

  /// Handle post update from realtime
  void _handlePostUpdate(Map<String, dynamic> postData) async {
    try {
      final postId = postData['id'];
      final postIndex = posts.indexWhere((post) => post.id == postId);

      if (postIndex != -1) {
        // Check if post should be removed (deleted or inactive)
        if (postData['is_active'] == false || postData['is_deleted'] == true) {
          posts.removeAt(postIndex);
        } else {
          // Preserve existing metadata and profile data when updating from realtime
          final existingPost = posts[postIndex];

          // Preserve existing profile data or fetch if missing
          final enrichedPostData = Map<String, dynamic>.from(postData);
          if (existingPost.username != null || existingPost.avatar != null) {
            // Use existing profile data
            enrichedPostData['username'] = existingPost.username;
            enrichedPostData['nickname'] = existingPost.nickname;
            enrichedPostData['avatar'] = existingPost.avatar;
            enrichedPostData['google_avatar'] = existingPost.googleAvatar;
          } else {
            // Fetch profile data if not available
            final profileData = await _fetchProfileData(postData['user_id']);
            if (profileData != null) {
              enrichedPostData['username'] = profileData['username'];
              enrichedPostData['nickname'] = profileData['nickname'];
              enrichedPostData['avatar'] = profileData['avatar'];
              enrichedPostData['google_avatar'] = profileData['google_avatar'];
            }
          }

          final updatedPost = PostModel.fromMap(enrichedPostData);

          // Merge existing metadata with new post data
          final preservedMetadata = Map<String, dynamic>.from(
            existingPost.metadata,
          );
          final newMetadata = Map<String, dynamic>.from(updatedPost.metadata);

          // Keep user-specific engagement states from existing metadata
          preservedMetadata.forEach((key, value) {
            if (key.startsWith('is') || key.contains('user_')) {
              newMetadata[key] = value;
            }
          });

          final finalPost = updatedPost.copyWith(metadata: newMetadata);
          posts[postIndex] = finalPost;

          debugPrint(
            'Updated post $postId from realtime, preserved user metadata and profile data',
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling post update: $e');
    }
  }

  /// Handle post delete from realtime
  void _handlePostDelete(Map<String, dynamic> postData) {
    try {
      final postId = postData['id'];
      final postIndex = posts.indexWhere((post) => post.id == postId);

      if (postIndex != -1) {
        posts.removeAt(postIndex);
      }
    } catch (e) {
      debugPrint('Error handling post delete: $e');
    }
  }

  /// Load posts feed from feed_queue table
  Future<void> loadPosts({bool forceRefresh = false}) async {
    // Declare here so it's accessible after try/catch for _markPostsConsumed
    List<PostModel> newPosts = [];
    try {
      // Check if we should use cached data - increased cache duration for better performance
      if (!forceRefresh && _lastPostsLoad != null && hasLoadedOnce.value) {
        final timeSinceLastLoad = DateTime.now().difference(_lastPostsLoad!);
        if (timeSinceLastLoad < _postsCacheDuration && posts.isNotEmpty) {
          debugPrint('Using cached posts data (${posts.length} posts)');
          return;
        }
      }

      // Only show loading on first load or force refresh
      if (!hasLoadedOnce.value || forceRefresh) {
        isLoading.value = true;

        // Reset intelligent feed on refresh
        if (forceRefresh) {
          _feedService.resetFeed();
        }
      }

      if (currentUserId.value.isEmpty) {
        debugPrint('ERROR: currentUserId is empty, cannot load posts');
        return;
      }
      debugPrint('Loading posts for user: ${currentUserId.value}');

      // Load posts from repository using intelligent feed function
      debugPrint('Loading intelligent posts for user: ${currentUserId.value}');

      try {
        // Try intelligent feed first, then fallback function, then regular feed
        final response = await _supabase.client.rpc(
          'get_feed_for_user',
          params: {'_user': currentUserId.value, '_limit': _postsPerPage},
        );
        newPosts =
            (response as List).map((post) {
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
                throw Exception('Invalid post data format from RPC');
              }
            }).toList();
        debugPrint('Loaded ${newPosts.length} feed_queue posts');
      } catch (e) {
        debugPrint('get_feed_for_user RPC failed: $e');

        try {
          // Try the fallback intelligent feed function
          final response = await _supabase.client.rpc(
            'get_intelligent_posts_feed_fallback',
            params: {
              'p_user_id': currentUserId.value,
              'p_limit': _postsPerPage,
            },
          );
          newPosts =
              (response as List).map((post) {
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
                  throw Exception('Invalid post data format from fallback RPC');
                }
              }).toList();
          debugPrint('Loaded ${newPosts.length} posts using fallback function');
        } catch (fallbackError) {
          debugPrint(
            'Fallback function also failed, using regular feed: $fallbackError',
          );

          newPosts = await _postRepository.getPostsFeed(
            currentUserId.value,
            limit: _postsPerPage,
          );
          debugPrint('Loaded ${newPosts.length} regular posts');
          if (newPosts.isEmpty) {
            debugPrint('WARNING: No posts returned from regular feed!');
          }
        }
      }

      // Load engagement states for posts using the new user_interactions table
      debugPrint(
        'Loading engagement states for ${newPosts.length} posts for user: ${currentUserId.value}',
      );
      await _loadEngagementStates(newPosts);

      // Handle empty posts result
      if (newPosts.isEmpty) {
        debugPrint('No posts found in database');
        if (forceRefresh) {
          // Clear the current posts list to show empty state
          posts.clear();
        }
      } else {
        // Add posts to intelligent feed service for future recommendations
        debugPrint('Adding posts to intelligent feed service...');
        await _feedService.addPostsToFeed(newPosts, currentUserId.value);
        debugPrint('Successfully added posts to feed service');

        // Use posts directly from feed_queue without cache-based filtering
        // The feed_queue table already handles viewed/consumed posts
        var postsToShow = newPosts;

        // Filter out duplicates that might already be in the posts list
        if (!forceRefresh) {
          final existingPostIds = posts.map((p) => p.id).toSet();
          postsToShow =
              postsToShow
                  .where((post) => !existingPostIds.contains(post.id))
                  .toList();
        }

        debugPrint(
          'Filtered ${newPosts.length - postsToShow.length} duplicate posts',
        );

        if (forceRefresh) {
          debugPrint(
            'Refresh: Adding ${postsToShow.length} posts from feed_queue',
          );
          posts.assignAll(postsToShow);
          debugPrint('Refreshed posts list with ${postsToShow.length} posts');
        } else {
          // Append posts from feed_queue
          posts.addAll(postsToShow);
          debugPrint(
            'Added ${postsToShow.length} posts to existing list. Total: ${posts.length}',
          );
        }
      }

      // Check if there are more posts
      hasMorePosts.value = newPosts.length == _postsPerPage;

      hasLoadedOnce.value = true;
      _lastPostsLoad = DateTime.now();
      debugPrint(
        'Posts loading completed. hasLoadedOnce: ${hasLoadedOnce.value}, total posts: ${posts.length}',
      );

      // Refresh any missing profile data and preload avatars
      if (posts.isNotEmpty) {
        await refreshMissingProfileData();

        // Batch preload avatars for better performance
        final avatarData =
            posts
                .map(
                  (post) => {
                    'avatar': post.avatar,
                    'google_avatar': post.googleAvatar,
                  },
                )
                .toList();

        // Don't await this to avoid blocking UI
        AvatarUtils.batchPreloadAvatars(avatarData);
      }

      // Manage periodic refresh based on posts availability
      if (posts.isEmpty) {
        _startPeriodicRefreshIfNeeded();
      } else {
        _stopPeriodicRefresh();
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
    } finally {
      isLoading.value = false;
    }

    // Mark fetched posts as consumed in feed_queue to avoid repeats
    await _markPostsConsumed(newPosts);
  }

  /// Mark retrieved posts as consumed in feed_queue so they won't appear again
  Future<void> _markPostsConsumed(List<PostModel> posts) async {
    if (posts.isEmpty) return;
    final postIds = posts.map((p) => p.id).toList();
    try {
      await _supabase.client
          .from('feed_queue')
          .update({'consumed': true})
          .eq('user_id', currentUserId.value)
          .inFilter('post_id', postIds);
      debugPrint('Marked ${postIds.length} posts consumed in feed_queue');
    } catch (e) {
      debugPrint('Error marking posts consumed: $e');
    }
  }

  /// Load more posts (pagination)
  Future<void> loadMorePosts() async {
    if (isLoadingMore.value || !hasMorePosts.value) return;

    try {
      isLoadingMore.value = true;

      if (currentUserId.value.isEmpty) return;

      List<PostModel> newPosts = [];
      newPosts = await _supabase.client
          .rpc(
            'get_feed_for_user',
            params: {'_user': currentUserId.value, '_limit': _postsPerPage},
          )
          .then((response) {
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
                throw Exception('Invalid post data');
              }
            }).toList();
          });

      // Mark consumed
      await _markPostsConsumed(newPosts);

      if (newPosts.isNotEmpty) {
        // Load engagement states for new posts using the new user_interactions table
        debugPrint(
          'Loading engagement states for ${newPosts.length} new posts',
        );
        await _loadEngagementStates(newPosts);

        // Use posts directly from feed_queue without cache-based filtering
        // Filter out duplicates that might already be in the posts list
        final existingPostIds = posts.map((p) => p.id).toSet();
        final uniquePostsToShow =
            newPosts
                .where((post) => !existingPostIds.contains(post.id))
                .toList();

        debugPrint(
          'Filtered ${newPosts.length - uniquePostsToShow.length} duplicate posts from pagination',
        );

        posts.addAll(uniquePostsToShow);
        debugPrint(
          'Added ${uniquePostsToShow.length} more posts. Total: ${posts.length}',
        );
      }

      // Check if there are more posts
      hasMorePosts.value = newPosts.length == _postsPerPage;
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Refresh posts feed
  Future<void> refreshPosts() async {
    debugPrint('Refreshing posts feed from feed_queue...');

    await loadPosts(forceRefresh: true);

    // Force update of reactive variables
    posts.refresh();

    // Force UI update
    update();
  }

  /// Add new post to the beginning of the feed
  void addNewPost(PostModel post) {
    posts.insert(0, post);

    // Add to user's posts cache
    _cacheService.addPostToCache(post.userId, post);
  }

  /// Update post engagement
  Future<void> updatePostEngagement(
    String postId,
    String engagementType,
    int increment,
  ) async {
    try {
      // Update in database
      await _postRepository.updatePostEngagement(
        postId,
        engagementType,
        increment,
      );

      // Update local post
      final postIndex = posts.indexWhere((post) => post.id == postId);
      if (postIndex != -1) {
        final post = posts[postIndex];
        PostModel updatedPost;

        switch (engagementType) {
          case 'likes':
            updatedPost = post.copyWith(
              likesCount: post.likesCount + increment,
            );
            break;
          case 'comments':
            updatedPost = post.copyWith(
              commentsCount: post.commentsCount + increment,
            );
            break;
          case 'views':
            updatedPost = post.copyWith(
              viewsCount: post.viewsCount + increment,
            );
            break;
          case 'shares':
            updatedPost = post.copyWith(
              sharesCount: post.sharesCount + increment,
            );
            break;
          default:
            return;
        }

        posts[postIndex] = updatedPost;

        // Force UI update
        posts.refresh();
      }
    } catch (e) {
      debugPrint('Error updating post engagement: $e');
    }
  }

  /// Toggle post like status
  Future<void> togglePostLike(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex == -1) {
      debugPrint('Post not found in feed: $postId');
      return;
    }

    final post = posts[postIndex];
    final isCurrentlyLiked =
        _getMetadataValue(post.metadata, 'isLiked') == true;
    final userId = _supabase.client.auth.currentUser?.id;

    if (userId == null) {
      debugPrint('User not authenticated');
      return;
    }

    // Debug current state
    debugPrint(
      '🚀 Like toggle started for $postId: currently liked = $isCurrentlyLiked',
    );
    debugPostLikeState(postId);

    // Optimistic UI update - immediately show the expected state
    final optimisticLiked = !isCurrentlyLiked;
    final optimisticCount = post.likesCount + (optimisticLiked ? 1 : -1);

    debugPrint(
      '⚡ Optimistic update: $postId -> liked: $optimisticLiked, count: $optimisticCount',
    );

    // Update UI immediately for better UX
    final optimisticMetadata = Map<String, dynamic>.from(post.metadata);
    optimisticMetadata['isLiked'] = optimisticLiked;

    final optimisticPost = post.copyWith(
      likesCount: optimisticCount,
      metadata: optimisticMetadata,
    );

    posts[postIndex] = optimisticPost;
    posts.refresh();

    // Debug after optimistic update
    debugPrint('⚡ After optimistic update:');
    debugPostLikeState(postId);

    try {
      // Use the new atomic toggle function
      final result = await _postRepository.togglePostLike(postId, userId);

      if (result != null) {
        final newIsLiked = result['isLiked'] as bool;
        final newLikesCount = result['likesCount'] as int;

        debugPrint(
          'Like toggle successful. Server state: $newIsLiked, Count: $newLikesCount',
        );

        // Track interaction for learning (only if the state actually changed)
        if (newIsLiked != isCurrentlyLiked) {
          await _interactionService.trackPostLike(
            postId,
            post.postType,
            post.userId,
            newIsLiked,
          );
        }

        // Update with actual server response (in case of discrepancy)
        final postIndexAfterUpdate = posts.indexWhere((p) => p.id == postId);
        if (postIndexAfterUpdate != -1) {
          final currentPost = posts[postIndexAfterUpdate];

          // Update metadata with actual server state
          final updatedMetadata = Map<String, dynamic>.from(
            currentPost.metadata,
          );
          updatedMetadata['isLiked'] = newIsLiked;

          // Create updated post with actual server data
          final updatedPost = currentPost.copyWith(
            likesCount: newLikesCount,
            metadata: updatedMetadata,
          );

          posts[postIndexAfterUpdate] = updatedPost;

          // Update cache service only if this is the current user's post
          if (post.userId == userId) {
            _cacheService.updatePostEngagementInCache(
              userId, // Current user's ID, not post author's ID
              postId,
              'likes',
              newLikesCount - post.likesCount, // Calculate from original count
            );
          }

          // Force UI update with server data
          posts.refresh();

          debugPrint(
            '✅ Updated post $postId with server data: liked=$newIsLiked, count=$newLikesCount',
          );

          // Debug final state
          debugPrint('✅ Final state after server update:');
          debugPostLikeState(postId);

          // Debug state after a short delay to catch any interference
          Future.delayed(Duration(milliseconds: 500), () {
            debugPrint('🕐 State after 500ms delay:');
            debugPostLikeState(postId);
          });
        }
      } else {
        debugPrint(
          'Failed to toggle like for post $postId - reverting optimistic update',
        );

        // Revert optimistic update on failure
        final revertedMetadata = Map<String, dynamic>.from(post.metadata);
        revertedMetadata['isLiked'] = isCurrentlyLiked;

        final revertedPost = post.copyWith(
          likesCount: post.likesCount,
          metadata: revertedMetadata,
        );

        final revertPostIndex = posts.indexWhere((p) => p.id == postId);
        if (revertPostIndex != -1) {
          posts[revertPostIndex] = revertedPost;
          posts.refresh();
        }
      }
    } catch (e) {
      debugPrint('Error toggling post like: $e - reverting optimistic update');

      // Revert optimistic update on error
      final revertedMetadata = Map<String, dynamic>.from(post.metadata);
      revertedMetadata['isLiked'] = isCurrentlyLiked;

      final revertedPost = post.copyWith(
        likesCount: post.likesCount,
        metadata: revertedMetadata,
      );

      final revertPostIndex = posts.indexWhere((p) => p.id == postId);
      if (revertPostIndex != -1) {
        posts[revertPostIndex] = revertedPost;
        posts.refresh();
      }
    }
  }

  /// Toggle post favorite status
  Future<void> togglePostFavorite(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      final isCurrentlyFavorited =
          _getMetadataValue(post.metadata, 'isFavorited') == true;

      // Update in database using the new toggle function
      final userId = _supabase.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          // Use the new toggle function
          final success = await _postRepository.togglePostEngagement(
            postId,
            userId,
            'stars',
          );

          if (success) {
            // Update metadata
            final updatedMetadata = Map<String, dynamic>.from(post.metadata);
            updatedMetadata['isFavorited'] = !isCurrentlyFavorited;

            // Update post with new metadata
            final updatedPost = post.copyWith(metadata: updatedMetadata);
            posts[postIndex] = updatedPost;

            // Force UI update
            posts.refresh();
          }
        } catch (e) {
          debugPrint('Error updating favorites in database: $e');
        }
      }
    }
  }

  /// Track post view for learning algorithm
  Future<void> trackPostView(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];

      // Track view interaction
      await _interactionService.trackPostView(
        postId,
        post.postType,
        post.userId,
      );

      // Update view count in database
      await updatePostEngagement(postId, 'views', 1);
    }
  }

  /// Track time spent viewing a post
  Future<void> trackTimeSpent(String postId, Duration timeSpent) async {
    await _interactionService.trackTimeSpent(postId, timeSpent);
  }

  /// Track post comment for learning
  Future<void> trackPostComment(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      await _interactionService.trackPostComment(
        postId,
        post.postType,
        post.userId,
      );
    }
  }

  /// Track post share for learning
  Future<void> trackPostShare(String postId) async {
    final postIndex = posts.indexWhere((post) => post.id == postId);
    if (postIndex != -1) {
      final post = posts[postIndex];
      await _interactionService.trackPostShare(
        postId,
        post.postType,
        post.userId,
      );
    }
  }

  /// Get feed statistics for debugging
  Map<String, dynamic> getFeedStatistics() {
    return {
      'total_posts': posts.length,
      'viewed_posts': _interactionService.viewedPostsCount,
      'user_preferences': _interactionService.getUserPreferencesSummary(),
      'feed_service_stats': _feedService.getFeedStatistics(),
    };
  }

  /// Clear posts cache and reload
  Future<void> clearCacheAndReload() async {
    _lastPostsLoad = null;
    hasLoadedOnce.value = false;
    _feedService.resetFeed();
    await loadPosts(forceRefresh: true);
  }

  /// Load engagement states for posts (likes and favorites) - optimized batch loading
  Future<void> _loadEngagementStates(List<PostModel> postsList) async {
    final userId = _supabase.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Batch load all engagement data in parallel for better performance
      final futures = await Future.wait([
        _loadUserFavorites(userId),
        _loadUserLikes(userId, postsList.map((p) => p.id).toList()),
      ]);

      final userFavorites = futures[0] as Set<String>;
      final userLikes = futures[1] as Map<String, Map<String, dynamic>>;

      debugPrint(
        'Loaded ${userFavorites.length} favorites and ${userLikes.length} likes for user $userId',
      );

      // Update all posts with engagement states
      for (int i = 0; i < postsList.length; i++) {
        final post = postsList[i];
        final likeData = userLikes[post.id];

        // Update metadata with engagement state
        final updatedMetadata = Map<String, dynamic>.from(post.metadata);
        updatedMetadata['isLiked'] = likeData?['isLiked'] ?? false;
        updatedMetadata['isFavorited'] = userFavorites.contains(post.id);

        // Update the post with engagement data
        final updatedLikesCount = likeData?['likesCount'] ?? post.likesCount;
        postsList[i] = post.copyWith(
          metadata: updatedMetadata,
          likesCount: updatedLikesCount,
        );
      }
    } catch (e) {
      debugPrint('Error loading engagement states: $e');
    }
  }

  /// Batch load user likes for multiple posts
  Future<Map<String, Map<String, dynamic>>> _loadUserLikes(
    String userId,
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};

    try {
      // Use a single query to get all like states
      final response = await _supabase.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId)
          .filter('post_id', 'in', postIds);

      final likedPostIds =
          response.map((item) => item['post_id'] as String).toSet();

      // Get posts data for like counts
      final postsResponse = await _supabase.client
          .from('posts')
          .select('id, likes_count')
          .filter('id', 'in', postIds);

      final result = <String, Map<String, dynamic>>{};
      for (final postData in postsResponse) {
        final postId = postData['id'] as String;
        result[postId] = {
          'isLiked': likedPostIds.contains(postId),
          'likesCount': postData['likes_count'] ?? 0,
        };
      }

      return result;
    } catch (e) {
      debugPrint('Error batch loading user likes: $e');
      return {};
    }
  }

  /// Load user favorites for batch processing
  Future<Set<String>> _loadUserFavorites(String userId) async {
    try {
      final response = await _supabase.client
          .from('user_favorites')
          .select('post_id')
          .eq('user_id', userId);

      return response.map((item) => item['post_id'] as String).toSet();
    } catch (e) {
      debugPrint('Error loading user favorites: $e');
      return {};
    }
  }

  /// Helper method to safely access metadata values
  dynamic _getMetadataValue(Map<String, dynamic> metadata, String key) {
    try {
      return metadata[key];
    } catch (e) {
      // If there's any type casting issue, return null
      debugPrint('Error accessing metadata key "$key": $e');
      return null;
    }
  }

  /// Debug helper to check post like state
  void debugPostLikeState(String postId) {
    final post = posts.firstWhereOrNull((p) => p.id == postId);
    if (post != null) {
      final isLiked = _getMetadataValue(post.metadata, 'isLiked');
      debugPrint(
        '🔍 Post $postId debug: isLiked=$isLiked, likesCount=${post.likesCount}, metadata=${post.metadata}',
      );
    } else {
      debugPrint('🔍 Post $postId not found in feed');
    }
  }
}
