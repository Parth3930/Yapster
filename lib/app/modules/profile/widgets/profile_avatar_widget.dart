import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final XFile? selectedImage;
  final String? imageUrl;
  final String? googleAvatarUrl;
  final VoidCallback onTap;
  final double radius;
  final bool isLoaded;
  final bool hasStory;
  final bool hasUnseenStory;
  final bool showAddButton;

  const ProfileAvatarWidget({
    super.key,
    this.selectedImage,
    this.imageUrl,
    this.googleAvatarUrl,
    required this.onTap,
    this.radius = 40,
    this.isLoaded = false,
    this.hasStory = false,
    this.hasUnseenStory = false,
    this.showAddButton = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine border colors based on story status
    List<Color> borderColors;
    if (hasStory) {
      if (hasUnseenStory) {
        // Gradient for unseen stories - red, yellow, purple, pink
        borderColors = [Colors.red, Colors.pink, Colors.purple];
      } else {
        // Default border for seen stories
        borderColors = [Colors.black, Color(0xff666666)];
      }
    } else {
      // No story - transparent border
      borderColors = [Colors.black, Color(0xff666666)];
    }

    // Calculate border width
    final borderWidth = hasStory && hasUnseenStory ? 10.0 : 1.0;
    final totalSize = (radius * 2) + (borderWidth * 5);

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Border container
          Container(
            width: totalSize,
            height: totalSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: borderColors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              shape: BoxShape.circle,
            ),
          ),

          // Inner avatar content - centered automatically
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child:
                !isLoaded && selectedImage == null && imageUrl == null
                    ? Center(
                      child: CircularProgressIndicator(
                        color: ProfileConstants.primaryBlue,
                        strokeWidth: 2,
                      ),
                    )
                    : GestureDetector(
                      onTap: onTap,
                      child: _buildAvatarContent(),
                    ),
          ),

          // Add button for current user's story
          if (showAddButton)
            Positioned(
              bottom: borderWidth + 5,
              right: borderWidth + 10,
              child: GestureDetector(
                onTap: onTap, // Make the plus button clickable
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent() {
    // Check if we have a selected image (file)
    if (selectedImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: ProfileConstants.darkBackground,
        backgroundImage: FileImage(File(selectedImage!.path)),
      );
    }

    // Check for imageUrl
    if (imageUrl != null &&
        imageUrl!.isNotEmpty &&
        imageUrl != "skiped" &&
        imageUrl != "null") {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero, // Remove fade animation
          fadeOutDuration: Duration.zero, // Remove fade animation
          placeholder: null, // Remove placeholder for instant display
          errorWidget:
              (context, url, error) => CircleAvatar(
                radius: radius,
                backgroundColor: ProfileConstants.darkBackground,
                child: Icon(Icons.person, size: radius, color: Colors.white),
              ),
        ),
      );
    }

    // Check for googleAvatarUrl
    if (googleAvatarUrl != null &&
        googleAvatarUrl!.isNotEmpty &&
        googleAvatarUrl != "skiped" &&
        googleAvatarUrl != "null") {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: googleAvatarUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero, // Remove fade animation
          fadeOutDuration: Duration.zero, // Remove fade animation
          placeholder: null, // Remove placeholder for instant display
          errorWidget:
              (context, url, error) => CircleAvatar(
                radius: radius,
                backgroundColor: ProfileConstants.darkBackground,
                child: Icon(Icons.person, size: radius, color: Colors.white),
              ),
          memCacheWidth: (radius * 2 * 2).toInt(), // 2x for high DPI
          memCacheHeight: (radius * 2 * 2).toInt(),
        ),
      );
    }

    // Default fallback - no image available
    return CircleAvatar(
      radius: radius,
      backgroundColor: ProfileConstants.darkBackground,
      child: Icon(Icons.person, size: radius, color: Colors.white),
    );
  }
}
