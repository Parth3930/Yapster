import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';

class ProfileAvatarWidget extends StatelessWidget {
  final XFile? selectedImage;
  final VoidCallback onTap;
  final double radius;
  final bool showEditIcon;
  final bool isLoaded;

  const ProfileAvatarWidget({
    super.key,
    required this.selectedImage,
    required this.onTap,
    this.radius = 50,
    this.showEditIcon = true,
    this.isLoaded = false,
  });

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // Avatar image with loading state
              !isLoaded &&
                      !_shouldShowDefaultIcon(
                        selectedImage,
                        accountDataProvider,
                      )
                  ? SizedBox(
                    height: radius * 2,
                    width: radius * 2,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ProfileConstants.primaryBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                  : CircleAvatar(
                    radius: radius,
                    backgroundColor: ProfileConstants.darkBackground,
                    backgroundImage: _getAvatarImage(
                      selectedImage,
                      accountDataProvider,
                    ),
                    child:
                        _shouldShowDefaultIcon(
                              selectedImage,
                              accountDataProvider,
                            )
                            ? Icon(
                              Icons.person,
                              size: radius,
                              color: Colors.white,
                            )
                            : null,
                  ),
              // Edit icon (blue circle with plus icon)
              if (showEditIcon)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: radius * 0.6,
                    width: radius * 0.6,
                    decoration: BoxDecoration(
                      color: ProfileConstants.primaryBlue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: radius * 0.4,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          ProfileConstants.tapToChangeAvatarMessage,
          style: ProfileConstants.hintTextStyle,
        ),
      ],
    );
  }

  // Using centralized avatar utility methods with CachedNetworkImageProvider
  ImageProvider? _getAvatarImage(
    XFile? selectedImage,
    AccountDataProvider provider,
  ) {
    return AvatarUtils.getAvatarImage(selectedImage, provider);
  }

  // Using centralized avatar utility method
  bool _shouldShowDefaultIcon(
    XFile? selectedImage,
    AccountDataProvider provider,
  ) {
    return AvatarUtils.shouldShowDefaultIcon(selectedImage, provider);
  }
}
