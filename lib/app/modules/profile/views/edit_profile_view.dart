import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/global_widgets/custom_input.dart';
import 'package:yapster/app/modules/profile/constants/profile_constants.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final profileController = Get.find<ProfileController>();

    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Colors.white,
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
                    Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          GetX<ProfileController>(
                            builder: (controller) {
                              final accountDataProvider = Get.find<AccountDataProvider>();
                              
                              // Show selected banner if available, otherwise show existing banner
                              if (controller.selectedBanner.value != null) {
                                return ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: FileImage(
                                          File(controller.selectedBanner.value!.path),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              } else if (accountDataProvider.banner.value.isNotEmpty) {
                                return ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage(accountDataProvider.banner.value),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Get.back(),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () async => await profileController.pickBanner(),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
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
