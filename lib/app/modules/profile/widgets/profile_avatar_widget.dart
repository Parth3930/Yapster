import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final XFile? selectedImage;
  final String? imageUrl;
  final String? googleAvatarUrl;
  final VoidCallback onTap;
  final double radius;
  final bool isLoaded;

  const ProfileAvatarWidget({
    super.key,
    this.selectedImage,
    this.imageUrl,
    this.googleAvatarUrl,
    required this.onTap,
    this.radius = 40,
    this.isLoaded = false,
  }) : assert(selectedImage != null || imageUrl != null || googleAvatarUrl != null, 'Either selectedImage, imageUrl, or googleAvatarUrl must be provided');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black, Color(0xff666666)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(54),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: !isLoaded && selectedImage == null && imageUrl == null
                    ? Center(
                        child: CircularProgressIndicator(
                          color: ProfileConstants.primaryBlue,
                          strokeWidth: 2,
                        ),
                      )
                    : GestureDetector(
                        onTap: onTap,
                        child: CircleAvatar(
                          radius: radius,
                          backgroundColor: ProfileConstants.darkBackground,
                          backgroundImage: selectedImage != null
                              ? FileImage(File(selectedImage!.path))
                              : (imageUrl != null && 
                                 imageUrl!.isNotEmpty && 
                                 imageUrl != "skiped" && 
                                 imageUrl != "null"
                                    ? NetworkImage(imageUrl!)
                                    : (googleAvatarUrl != null && 
                                       googleAvatarUrl!.isNotEmpty && 
                                       googleAvatarUrl != "skiped" && 
                                       googleAvatarUrl != "null"
                                          ? NetworkImage(googleAvatarUrl!)
                                          : null)),
                          child: selectedImage == null && 
                                 (imageUrl == null || 
                                  imageUrl!.isEmpty || 
                                  imageUrl == "skiped" || 
                                  imageUrl == "null") &&
                                 (googleAvatarUrl == null || 
                                  googleAvatarUrl!.isEmpty || 
                                  googleAvatarUrl == "skiped" || 
                                  googleAvatarUrl == "null")
                              ? Icon(
                                  Icons.person,
                                  size: radius,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
