import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/global_widgets/custom_input.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();
    final themeController = Get.find<ThemeController>();
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
        appBar: CustomAppBar(title: 'Edit Profile'),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 30),
                    Obx(
                      () => ProfileAvatarWidget(
                        selectedImage: profileController.selectedImage.value,
                        onTap: () async => await profileController.pickImage(),
                        isLoaded: profileController.isAvatarLoaded.value,
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
                            onChanged: (_) {
                              // Controller handles the value internally
                            },
                          ),
                          SizedBox(height: ProfileConstants.defaultSpacing),

                          // Username input field
                          CustomInput(
                            label: 'Username',
                            controller: profileController.usernameController,
                            onChanged: (_) {
                              // Controller handles the value internally
                            },
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
            Obx(
              () =>
                  profileController.isLoading.value
                      ? CircularProgressIndicator(
                        color: ProfileConstants.primaryBlue,
                      )
                      : CustomButton(
                        text: "Update Profile",
                        width: 300,
                        backgroundColor: ProfileConstants.primaryBlue,
                        textColor:
                            themeController.isDarkMode
                                ? AppColors.textWhite
                                : AppColors.textDark,
                        onPressed: () async {
                          await profileController.updateFullProfile();
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
