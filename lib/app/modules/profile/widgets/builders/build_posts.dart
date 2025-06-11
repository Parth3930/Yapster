import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/modules/profile/controllers/profile_posts_controller.dart';
import 'package:yapster/app/routes/app_pages.dart';

final Map<String, bool> _postsInitialized = <String, bool>{};

Widget buildPostsTab(String? userId, bool isCurrentUser) {
  ProfilePostsController profilePostsController;
  bool controllerCreated = false; // Track if we just created a new controller
  try {
    profilePostsController = Get.find<ProfilePostsController>(
      tag: 'profile_posts_${userId ?? 'current'}',
    );
  } catch (e) {
    // If controller not found, create it (happens when navigating back after disposal)
    profilePostsController = Get.put(
      ProfilePostsController(),
      tag: 'profile_posts_${userId ?? 'current'}',
    );
    controllerCreated = true;
  }

  final currentUserId = Get.find<SupabaseService>().currentUser.value?.id;
  final targetUserId = isCurrentUser ? currentUserId ?? '' : userId ?? '';

  // Key used to track whether we've already initialized posts for this user
  final initKey = 'posts_$targetUserId';

  // If we've just created the controller, remove any stale initialization flag
  if (controllerCreated) {
    _postsInitialized.remove(initKey);
  }

  // CRITICAL FIX: Move loading logic to a one-time initialization
  // Use the static map to track if we've already initialized posts for this user
  if (!_postsInitialized.containsKey(initKey)) {
    _postsInitialized[initKey] = true;

    // OPTIMIZATION: Check if posts are already cached using the cache service
    final cacheService = Get.find<UserPostsCacheService>();
    final hasCachedPosts = cacheService.hasCachedPosts(targetUserId);
    final hasPostsInController = profilePostsController.profilePosts.isNotEmpty;
    final isTargetCurrentUser = targetUserId == currentUserId;

    // For other users, only load once and don't cache
    if (!isTargetCurrentUser) {
      // Check if we've already attempted to load posts for this user
      final hasAttempted = profilePostsController.hasLoadAttempted(
        targetUserId,
      );
      if (!hasPostsInController &&
          !profilePostsController.isLoading.value &&
          !hasAttempted) {
        debugPrint('Loading posts once for other user: $targetUserId');
        Future.microtask(() {
          profilePostsController.loadUserPosts(targetUserId);
        });
      } else {
        debugPrint(
          'Posts already loaded, loading, or attempted for other user: $targetUserId (attempted: $hasAttempted)',
        );
      }
    } else {
      // For current user, use caching logic
      if (!hasCachedPosts &&
          !hasPostsInController &&
          !profilePostsController.isLoading.value) {
        debugPrint(
          'No cached posts found, loading for current user: $targetUserId',
        );
        Future.microtask(() {
          profilePostsController.loadUserPosts(targetUserId);
        });
      } else if (hasCachedPosts && !hasPostsInController) {
        debugPrint(
          'Loading cached posts instantly for current user: $targetUserId',
        );
        // Load cached posts immediately and synchronously
        _loadCachedPostsInstantly(
          profilePostsController,
          Get.find<UserPostsCacheService>(),
          targetUserId,
        );
      } else {
        debugPrint(
          'Using existing posts data for current user: $targetUserId (cached: $hasCachedPosts, controller: $hasPostsInController)',
        );
      }
    }
  }

  return Obx(() {
    final posts = profilePostsController.profilePosts;

    // Show loading only if we have no cached posts and are currently loading
    if (posts.isEmpty && profilePostsController.isLoading.value) {
      return Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.post_add_outlined, size: 64, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              isCurrentUser ? 'No posts yet' : 'No posts to show',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            if (isCurrentUser) ...[
              SizedBox(height: 8),
              Text(
                'Create your first post!',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    // Show posts in a Pinterest-like masonry layout
    return MasonryGridView.builder(
      padding: EdgeInsets.all(8),
      itemCount: posts.length,
      gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
      ),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      itemBuilder: (context, index) {
        final post = posts[index];

        // Determine aspect ratio for the post card to achieve masonry effect
        double aspectRatio;
        if (post.postType.toLowerCase() == 'image') {
          // Use a set of predefined aspect ratios and cycle through for visual variety
          const ratios = [0.8, 1.0, 1.25, 1.5];
          aspectRatio = ratios[index % ratios.length];
        } else if (post.postType.toLowerCase() == 'video') {
          aspectRatio = 0.7; // Slightly taller for videos
        } else {
          // Text posts: scale height with content length for visual balance
          final textLength = post.content.length;
          if (textLength > 120) {
            aspectRatio = 1.4;
          } else if (textLength > 60) {
            aspectRatio = 1.1;
          } else {
            aspectRatio = 0.9;
          }
        }

        return Card(
          color: Color(0xFF242424),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1 / aspectRatio, // width : height ratio
            child: GestureDetector(
              onTap: () {
                // Navigate to post detail page
                Get.toNamed(
                  '${Routes.POST_DETAIL}/${post.id}',
                  arguments: {'post': post},
                );
              },
              onLongPress: () {
                // Allow delete only for own posts
                final currentUserId =
                    Get.find<SupabaseService>().client.auth.currentUser?.id;
                if (currentUserId != post.userId) return;
                _showDeleteConfirmation(post);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (post.postType.toLowerCase() == 'image' &&
                      post.imageUrl != null)
                    Image.network(post.imageUrl!, fit: BoxFit.cover)
                  else if (post.postType.toLowerCase() == 'video' &&
                      post.content.isNotEmpty)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          post.videoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.movie,
                                size: 40,
                                color: Colors.grey,
                              ),
                        ),
                        Center(
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        post.content,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  });
}

// Helper method to load cached posts instantly without async delay
void _loadCachedPostsInstantly(
  ProfilePostsController profilePostsController,
  UserPostsCacheService cacheService,
  String targetUserId,
) {
  try {
    // Prevent multiple calls to this method for the same user
    if (profilePostsController.profilePosts.isNotEmpty) {
      debugPrint(
        'Posts already loaded for user: $targetUserId, skipping instant load',
      );
      return;
    }

    // Get cached posts synchronously from the cache service
    final cachedPosts = cacheService.getCachedPosts(targetUserId);
    if (cachedPosts.isNotEmpty) {
      // Load posts immediately into the controller
      profilePostsController.profilePosts.assignAll(cachedPosts);
      debugPrint(
        'Instantly loaded ${cachedPosts.length} cached posts for user: $targetUserId',
      );

      // Load engagement states in background without blocking UI
      Future.microtask(() async {
        await profilePostsController.loadEngagementStatesForCachedPosts(
          cachedPosts,
        );
      });
    } else {
      debugPrint('No cached posts found for user: $targetUserId');
      // If no cached posts, fall back to async loading only once
      Future.microtask(() {
        profilePostsController.loadUserPosts(targetUserId);
      });
    }
  } catch (e) {
    debugPrint('Error loading cached posts instantly: $e');
    // Fall back to async loading on error only once
    Future.microtask(() {
      profilePostsController.loadUserPosts(targetUserId);
    });
  }
}

// Show delete confirmation with blur effect
void _showDeleteConfirmation(PostModel post) {
  final postRepository = Get.find<PostRepository>();
  final userPostsCache = Get.find<UserPostsCacheService>();
  final currentUserId = Get.find<SupabaseService>().client.auth.currentUser?.id;

  // Create backdrop filter for blur effect
  showDialog(
    context: Get.context!,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (context) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Transparent full-screen clickable area to dismiss
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),

              // Center the delete button above the post
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[800],
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          // Close the dialog
                          Navigator.pop(context);

                          // Show loading indicator
                          Get.dialog(
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                            barrierDismissible: false,
                          );

                          // Delete the post
                          final success = await postRepository.deletePost(
                            post.id,
                            currentUserId!,
                          );

                          // Dismiss loading dialog
                          Get.back();

                          if (success) {
                            // Show success snackbar
                            Get.snackbar(
                              'Success',
                              'Post deleted successfully',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );

                            // Refresh controllers to update UI
                            try {
                              final profileController =
                                  Get.find<ProfilePostsController>(
                                    tag: 'profile_posts_${currentUserId}',
                                  );
                              // First remove the post directly from the controller
                              profileController.removePost(post.id);
                              // Then refresh posts to ensure everything is in sync
                              profileController.refreshPosts();
                            } catch (e) {
                              debugPrint(
                                'Error refreshing profile controller: $e',
                              );
                            }

                            // Update cache to reflect the deletion
                            try {
                              userPostsCache.refreshUserPosts(currentUserId);
                              // Decrement post count in AccountDataProvider
                              final accountProvider =
                                  Get.find<AccountDataProvider>();
                              accountProvider.decrementPostCount();
                            } catch (e) {
                              debugPrint(
                                'Error refreshing user posts cache: $e',
                              );
                            }
                          } else {
                            // Show error snackbar
                            Get.snackbar(
                              'Error',
                              'Failed to delete post',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Post',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
