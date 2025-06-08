import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/controllers/posts_feed_controller.dart';
import 'package:yapster/app/modules/home/controllers/comment_controller.dart';

class PostDetailController extends GetxController {
  final PostRepository _postRepository = Get.find<PostRepository>();
  final SupabaseService _supabaseService = Get.find<SupabaseService>();

  final Rx<PostModel?> post = Rx<PostModel?>(null);
  final RxBool isLoading = true.obs;
  final RxString error = ''.obs;

  String? postId;

  // Create a feed controller adapter for post interactions
  late final PostsFeedController feedController;

  // Comment controller for this post
  late final CommentController commentController;

  @override
  void onInit() {
    super.onInit();

    // Initialize feed controller for post interactions
    feedController = _PostDetailFeedControllerAdapter(this);

    // Get post ID from route parameters
    postId = Get.parameters['postId'];
    if (postId != null) {
      // Initialize comment controller for this specific post
      commentController = Get.put(CommentController(), tag: 'comment_$postId');

      loadPost(postId!);
      // Load comments after getting post ID - use Future.delayed to avoid build conflicts
      Future.delayed(Duration.zero, () => loadComments());
    } else {
      error.value = 'No post ID provided';
      isLoading.value = false;
    }
  }

  /// Load post by ID
  Future<void> loadPost(String id) async {
    try {
      isLoading.value = true;
      error.value = '';

      debugPrint('Loading post detail for ID: $id');

      // First try to get from cache or existing data
      final cachedPost = await _tryGetCachedPost(id);
      if (cachedPost != null) {
        post.value = cachedPost;
        isLoading.value = false;
        debugPrint('Loaded post from cache: ${cachedPost.id}');
        return;
      }

      // Load from database
      final loadedPost = await _loadPostFromDatabase(id);
      if (loadedPost != null) {
        post.value = loadedPost;
        debugPrint('Loaded post from database: ${loadedPost.id}');
      } else {
        error.value = 'Post not found';
        debugPrint('Post not found in database: $id');
      }
    } catch (e) {
      error.value = 'Failed to load post: $e';
      debugPrint('Error loading post: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Try to get post from various caches
  Future<PostModel?> _tryGetCachedPost(String id) async {
    try {
      // Check if we can get it from any existing controllers
      // This could include feed controller, profile controller, etc.

      // Try to get from feed controller if available
      if (Get.isRegistered<dynamic>(tag: 'posts_feed')) {
        final feedController = Get.find<dynamic>(tag: 'posts_feed');
        if (feedController.posts != null) {
          final posts = feedController.posts as List<PostModel>;
          final cachedPost = posts.where((p) => p.id == id).firstOrNull;
          if (cachedPost != null) {
            return cachedPost;
          }
        }
      }

      // Try other controllers as needed
      return null;
    } catch (e) {
      debugPrint('Error getting cached post: $e');
      return null;
    }
  }

  /// Load post from database
  Future<PostModel?> _loadPostFromDatabase(String id) async {
    try {
      final currentUserId = _supabaseService.currentUser.value?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Get post data from database
      final postResponse =
          await _supabaseService.client
              .from('posts')
              .select('*')
              .eq('id', id)
              .eq('is_active', true)
              .eq('is_deleted', false)
              .maybeSingle();

      if (postResponse == null) {
        return null;
      }

      // Get profile data for the post author
      final profileResponse =
          await _supabaseService.client
              .from('profiles')
              .select('username, nickname, avatar, google_avatar')
              .eq('user_id', postResponse['user_id'])
              .maybeSingle();

      // Combine post and profile data
      final combinedData = Map<String, dynamic>.from(postResponse);
      if (profileResponse != null) {
        combinedData['username'] = profileResponse['username'];
        combinedData['nickname'] = profileResponse['nickname'];
        combinedData['avatar'] = profileResponse['avatar'];
        combinedData['google_avatar'] = profileResponse['google_avatar'];
      }

      // Convert to PostModel
      final postModel = PostModel.fromMap(combinedData);

      // Load engagement state
      final engagementState = await _postRepository.getUserPostLikeState(
        id,
        currentUserId,
      );
      if (engagementState != null) {
        postModel.metadata['isLiked'] = engagementState['isLiked'] ?? false;
        postModel.metadata['isFavorited'] =
            false; // TODO: Add favorite state if needed
      }

      return postModel;
    } catch (e) {
      debugPrint('Error loading post from database: $e');
      return null;
    }
  }

  /// Load comments for the post
  Future<void> loadComments() async {
    if (postId != null) {
      await commentController.loadComments(postId!);
    }
  }

  /// Refresh the post data
  Future<void> refreshPost() async {
    if (postId != null) {
      await loadPost(postId!);
    }
  }

  /// Toggle post like for the detail view
  Future<void> togglePostLike(String postId) async {
    if (post.value == null) return;

    final currentPost = post.value!;
    final isCurrentlyLiked = currentPost.metadata['isLiked'] == true;

    // Optimistic update
    final updatedMetadata = Map<String, dynamic>.from(currentPost.metadata);
    updatedMetadata['isLiked'] = !isCurrentlyLiked;

    post.value = currentPost.copyWith(
      metadata: updatedMetadata,
      likesCount: currentPost.likesCount + (isCurrentlyLiked ? -1 : 1),
    );

    try {
      // Update in database
      final result = await _postRepository.togglePostLike(
        postId,
        _supabaseService.currentUser.value!.id,
      );

      if (result != null) {
        // Update with server response
        final serverMetadata = Map<String, dynamic>.from(currentPost.metadata);
        serverMetadata['isLiked'] = result['isLiked'] ?? false;

        post.value = currentPost.copyWith(
          metadata: serverMetadata,
          likesCount: result['likesCount'] ?? currentPost.likesCount,
        );
      }
    } catch (e) {
      debugPrint('Error toggling like in post detail: $e');
      // Revert optimistic update
      post.value = currentPost;
    }
  }

  /// Toggle post favorite for the detail view
  Future<void> togglePostFavorite(String postId) async {
    if (post.value == null) return;

    final currentPost = post.value!;
    final isCurrentlyFavorited = currentPost.metadata['isFavorited'] == true;

    // Optimistic update
    final updatedMetadata = Map<String, dynamic>.from(currentPost.metadata);
    updatedMetadata['isFavorited'] = !isCurrentlyFavorited;

    post.value = currentPost.copyWith(metadata: updatedMetadata);

    try {
      // Update in database (implement favorite toggle in repository if needed)
      // For now, just keep the optimistic update
      debugPrint('Favorite toggled for post: $postId');
    } catch (e) {
      debugPrint('Error toggling favorite in post detail: $e');
      // Revert optimistic update
      post.value = currentPost;
    }
  }
}

/// Adapter class to make PostDetailController compatible with existing post widgets
class _PostDetailFeedControllerAdapter extends PostsFeedController {
  final PostDetailController _detailController;

  _PostDetailFeedControllerAdapter(this._detailController);

  @override
  Future<void> togglePostLike(String postId) async {
    return _detailController.togglePostLike(postId);
  }

  @override
  Future<void> togglePostFavorite(String postId) async {
    return _detailController.togglePostFavorite(postId);
  }

  // Override other methods as needed
  @override
  Future<void> trackPostShare(String postId) async {
    debugPrint('Post shared from detail view: $postId');
  }
}
