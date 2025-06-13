import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:yapster/app/data/models/post_model.dart';
import 'package:yapster/app/data/repositories/post_repository.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/services/user_posts_cache_service.dart';

/// Generates a thumbnail for a video post, displays it, and – **for the
/// current user's own posts** – uploads the thumbnail to storage, updates the
/// post's metadata, and refreshes the local cache so subsequent loads are fast.
class VideoThumbnailAutoSaver extends StatefulWidget {
  final PostModel post;
  final BoxFit fit;
  final int? timeMs;

  const VideoThumbnailAutoSaver({
    super.key,
    required this.post,
    this.fit = BoxFit.cover,
    this.timeMs,
  });

  @override
  State<VideoThumbnailAutoSaver> createState() => _VideoThumbnailAutoSaverState();
}

class _VideoThumbnailAutoSaverState extends State<VideoThumbnailAutoSaver> {
  Uint8List? _thumb;
  String? _networkUrl; // After upload
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _generateAndOptionallySave();
  }

  Future<void> _generateAndOptionallySave() async {
    if (_processing) return;
    _processing = true;

    final videoUrl = widget.post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _processing = false;
      return;
    }

    try {
      final encoded = Uri.tryParse(videoUrl)?.isAbsolute == true
          ? Uri.encodeFull(videoUrl)
          : videoUrl;
      final data = await VideoThumbnail.thumbnailData(
        video: encoded,
        imageFormat: ImageFormat.JPEG,
        timeMs: widget.timeMs ?? 0,
        quality: 75,
      );
      if (data == null) {
        _processing = false;
        return;
      }

      if (mounted) {
        setState(() => _thumb = data);
      }

      // Only attempt to upload if the current user owns this post
      final supabase = Get.find<SupabaseService>();
      final currentUserId = supabase.client.auth.currentUser?.id;
      if (currentUserId != widget.post.userId) {
        _processing = false;
        return;
      }

      final postRepo = Get.find<PostRepository>();
      final thumbUrl = await postRepo.uploadPostThumbnail(
        data,
        widget.post.userId,
        widget.post.id,
      );

      if (thumbUrl == null) {
        _processing = false;
        return;
      }

      // Update post metadata server-side
      final updated = await postRepo.updatePostWithVideo(
        widget.post.id,
        widget.post.videoUrl ?? '',
        thumbnailUrl: thumbUrl,
      );

      if (updated) {
        // Update local cache so profiles load quickly next time
        final cacheService = Get.find<UserPostsCacheService>();
        final newMeta = Map<String, dynamic>.from(widget.post.metadata)
          ..['video_thumbnail'] = thumbUrl;
        final updatedPost = widget.post.copyWith(metadata: newMeta);
        cacheService.updatePostInCache(widget.post.userId, updatedPost);
        if (mounted) {
          setState(() => _networkUrl = thumbUrl);
        }
      }
    } catch (e) {
      debugPrint('VideoThumbnailAutoSaver error: $e');
    } finally {
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_networkUrl != null) {
      return Image.network(_networkUrl!, fit: widget.fit);
    }
    if (_thumb != null) {
      return Image.memory(_thumb!, fit: widget.fit);
    }
    return Container(color: Colors.black26);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
