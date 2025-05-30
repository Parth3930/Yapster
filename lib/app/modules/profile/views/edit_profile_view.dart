import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/global_widgets/custom_input.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';
import 'package:yapster/app/modules/profile/widgets/profile_banner_widget.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final profileController = Get.find<ProfileController>();

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white.withOpacity(0.3),
          selectionHandleColor: Colors.white,
        ),
      ),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GetX<ProfileController>(
                      builder:
                          (controller) => ProfileBannerWidget(
                            selectedImage: controller.selectedBanner.value,
                            onTap: () async => await controller.pickBanner(),
                            isLoaded: controller.isBannerLoaded.value,
                            showBackButton: true,
                          ),
                    ),
                    SizedBox(height: 30),
                    GetX<ProfileController>(
                      builder:
                          (controller) => ProfileAvatarWidget(
                            selectedImage: controller.selectedImage.value,
                            onTap: () async => await controller.pickImage(),
                            isLoaded: controller.isAvatarLoaded.value,
                          ),
                    ),
                    SizedBox(height: ProfileConstants.defaultSpacing * 2),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ProfileConstants.defaultPadding,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 5),
                              Text(
                                ProfileConstants.profileInfoTitle,
                                style: ProfileConstants.sectionTitleStyle,
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                          SizedBox(height: ProfileConstants.smallSpacing),
                          // Name input field
                          CustomInput(
                            label: 'Name',
                            controller: profileController.nicknameController,
                          ),
                          SizedBox(height: ProfileConstants.defaultSpacing),

                          // Username input field
                          CustomInput(
                            label: 'Username',
                            controller: profileController.usernameController,
                            suffixIcon:
                                !profileController.canUpdateUsername()
                                    ? Tooltip(
                                      message:
                                          ProfileConstants
                                              .usernameRestrictionMessage,
                                      child: Icon(
                                        Icons.info_outline,
                                        color: ProfileConstants.textGrey,
                                      ),
                                    )
                                    : null,
                          ),
                          SizedBox(height: ProfileConstants.defaultSpacing),

                          // Bio input field
                          CustomInput(
                            label: 'Bio',
                            controller: profileController.bioController,
                            maxLines: 3,
                            minLines: 3,
                            keyboardType: TextInputType.multiline,
                          ),
                          SizedBox(height: ProfileConstants.defaultSpacing),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GetX<ProfileController>(
              builder:
                  (controller) =>
                      controller.isLoading.value
                          ? CircularProgressIndicator(
                            color: ProfileConstants.primaryBlue,
                          )
                          : CustomButton(
                            text: "Update Profile",
                            width: 300,
                            backgroundColor: ProfileConstants.primaryBlue,
                            textColor: Colors.white,
                            onPressed: () async {
                              await controller.updateFullProfile();
                            },
                          ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
