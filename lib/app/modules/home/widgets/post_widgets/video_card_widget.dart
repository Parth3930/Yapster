import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_avatar_widget.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_interaction_buttons.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/widgets/post_widgets/post_view_tracker.dart'
    show VisibilityDetector, VisibilityInfo;
import 'package:yapster/app/routes/app_pages.dart';

/// Controller for managing video card state with GetX
class VideoCardController extends GetxController {
  CachedVideoPlayerPlusController? _controller;
  final RxBool isInitialized = false.obs;
  final RxBool isVisible = false.obs;

  @override
  void onClose() {
    _controller?.dispose();
    super.onClose();
  }

  Future<void> initController(String url) async {
    if (_controller != null) return;
    try {
      debugPrint('Initializing video controller for URL: $url');
      _controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0.0); // Mute by default for feed

      // Add listener to handle video state changes
      _controller!.addListener(() {
        if (_controller!.value.isInitialized) {
          // Ensure video keeps looping when visible
          if (isVisible.value &&
              !_controller!.value.isPlaying &&
              _controller!.value.position >= _controller!.value.duration) {
            _controller!.seekTo(Duration.zero);
            _controller!.play();
          }
        }
      });

      if (isVisible.value) {
        debugPrint('Video is visible, starting playback');
        _controller!.play();
      }
      isInitialized.value = true;
      debugPrint('Video controller initialized successfully');
    } catch (e) {
      debugPrint('Video init error: $e');
    }
  }

  void handleVisibility(VisibilityInfo info, String url) {
    final frac = info.visibleFraction;
    debugPrint('Video visibility changed: ${frac * 100}% visible');

    if (frac >= 0.5) {
      debugPrint('Video is now visible (>= 50%)');
      isVisible.value = true;
      if (_controller == null) {
        debugPrint('No controller exists, initializing...');
        initController(url);
      } else if (_controller!.value.isInitialized) {
        if (!_controller!.value.isPlaying) {
          debugPrint('Controller exists but not playing, starting playback');
          _controller!.play();
        }
        if (!_controller!.value.isLooping) {
          _controller!.setLooping(true);
        }
      }
    } else if (frac < 0.5) {
      debugPrint('Video is now hidden (< 50%)');
      isVisible.value = false;
      if (_controller != null && _controller!.value.isPlaying) {
        debugPrint('Pausing video playback');
        _controller!.pause();
      }
    }
  }

  CachedVideoPlayerPlusController? get videoController => _controller;
}

/// Video card with identical aesthetics to ImagePostWidget
class VideoCardWidget extends StatelessWidget {
  const VideoCardWidget({
    super.key,
    required this.post,
    required this.controller,
  });

  final PostModel post;
  final dynamic controller;

  String? _getVideoUrl() {
    // Prefer direct column value first
    String? url = post.videoUrl;

    // Fallback to metadata if direct value is missing / empty
    if (url == null || url.isEmpty) {
      final metaUrl = post.metadata['video_url'];
      if (metaUrl is String && metaUrl.isNotEmpty) {
        url = metaUrl;
      }
    }

    // Treat empty strings as null for consistency
    if (url != null && url.trim().isEmpty) {
      url = null;
    }

    // Only log when URL exists for easier debugging
    if (url != null) {
      debugPrint('🎬 Video URL resolved for post ${post.id}: $url');
    }
    return url;
  }

  void _navigateToProfile() {
    ExploreController exploreController;
    try {
      exploreController = Get.find<ExploreController>();
    } catch (e) {
      exploreController = ExploreController();
      Get.put(exploreController);
    }

    final userData = {
      'user_id': post.userId,
      'username': post.username ?? '',
      'nickname': post.nickname ?? '',
      'avatar': post.avatar ?? '',
    };
    exploreController.openUserProfile(userData);
  }

  String _displayName() {
    if (post.nickname != null && post.nickname!.isNotEmpty) {
      return post.nickname!;
    } else if (post.username != null && post.username!.isNotEmpty) {
      return post.username!;
    }
    return 'Yapper';
  }

  String _truncatedName() {
    final name = _displayName();
    return name.length > 10 ? '${name.substring(0, 10)}..' : name;
  }

  bool _isCurrentUserPost() {
    final uid = Get.find<SupabaseService>().currentUser.value?.id;
    return uid != null && uid == post.userId;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays} Days ago';
    if (diff.inHours > 0) return '${diff.inHours} Hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} Minutes ago';
    return 'now';
  }

  Widget _placeholder() => Container(
    width: double.infinity,
    height: 400,
    color: Colors.grey[800],
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie, color: Colors.grey, size: 48),
          SizedBox(height: 8),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    ),
  );

  Widget _errorPlaceholder() => Container(
    width: double.infinity,
    height: 400,
    color: Colors.grey[900],
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_creation_outlined, size: 40, color: Colors.white70),
          SizedBox(height: 8),
          Text(
            'Video processing... Please check back soon',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final thumb = post.metadata['video_thumbnail'] as String?;
    final duration = post.metadata['video_duration'] as String?;
    final videoUrl = _getVideoUrl();
    final videoController = Get.put(VideoCardController());

    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap:
                      () => Get.toNamed(
                        Routes.VIDEOS,
                        arguments: {
                          'initialIndex': controller.posts.indexOf(post),
                        },
                      ),
                  child: SizedBox(
                    height: 400,
                    width: double.infinity,
                    child: VisibilityDetector(
                      key: Key(post.id),
                      onVisibilityChanged: (info) {
                        if (videoUrl != null) {
                          videoController.handleVisibility(info, videoUrl);
                        }
                      },
                      child: Obx(() {
                        if (videoController.isInitialized.value &&
                            videoController.videoController != null) {
                          return CachedVideoPlayerPlus(
                            videoController.videoController!,
                          );
                        }
                        return thumb != null && thumb.isNotEmpty
                            ? Image.network(
                              thumb,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 400,
                              loadingBuilder:
                                  (c, child, prog) =>
                                      prog == null ? child : _placeholder(),
                              errorBuilder: (c, e, s) => _placeholder(),
                            )
                            : _placeholder();
                      }),
                    ),
                  ),
                ),
                // User info bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        PostAvatarWidget(
                          post: post,
                          radius: 20,
                          onTap: _navigateToProfile,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _timeAgo(post.createdAt),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Content
                if (post.content.isNotEmpty)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 60,
                    child: Text(
                      post.content.length > 50
                          ? '${post.content.substring(0, 50)}... More'
                          : post.content,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Engagement bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: PostInteractionButtons(
                      post: post,
                      controller: controller,
                      glassy: true,
                    ),
                  ),
                ),
                // Duration badge
                if (duration != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
