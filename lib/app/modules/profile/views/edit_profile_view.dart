import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/modules/profile/controllers/profile_controller.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  // Helper function to build custom input fields
  Widget _buildCustomInput({
    required String labelText,
    required Function(String) onChanged,
    TextEditingController? controller,
    int maxLines = 1,
    int? maxLength,
    bool alignLabelWithHint = false,
    String? helperText,
  }) {
    return TextFormField(
      style: TextStyle(color: Colors.white),
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      controller: controller,
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: Color(0xff727272)),
        floatingLabelStyle: TextStyle(
          color: Colors.white,
        ), // White label color when focused
        filled: true,
        fillColor: Color(0xff111111),
        alignLabelWithHint: alignLabelWithHint,
        helperText: helperText,
        helperStyle: TextStyle(color: Color(0xff727272)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
    );
  }

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
                    Center(
                      child: GestureDetector(
                        onTap: () async => await profileController.pickImage(),
                        child: Obx(
                          () => Stack(
                            children: [
                              // Avatar image
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Color(0xff111111),
                                backgroundImage:
                                    profileController.selectedImage.value !=
                                            null
                                        ? FileImage(
                                          File(
                                            profileController
                                                .selectedImage
                                                .value!
                                                .path,
                                          ),
                                        )
                                        : ((accountDataProvider
                                                        .avatar
                                                        .value
                                                        .isNotEmpty &&
                                                    accountDataProvider
                                                            .avatar
                                                            .value !=
                                                        "skiped")
                                                ? NetworkImage(
                                                  accountDataProvider
                                                      .avatar
                                                      .value,
                                                )
                                                : (accountDataProvider
                                                        .googleAvatar
                                                        .value
                                                        .isNotEmpty
                                                    ? NetworkImage(
                                                      accountDataProvider
                                                          .googleAvatar
                                                          .value,
                                                    )
                                                    : null))
                                            as ImageProvider?,
                                child:
                                    (profileController.selectedImage.value ==
                                                null &&
                                            accountDataProvider
                                                .avatar
                                                .value
                                                .isEmpty &&
                                            accountDataProvider
                                                .googleAvatar
                                                .value
                                                .isEmpty)
                                        ? Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                              // Blue circle with plus icon
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  height: 30,
                                  width: 30,
                                  decoration: BoxDecoration(
                                    color: Color(0xff0060FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Tap to change profile image",
                      style: TextStyle(fontSize: 12, color: Color(0xff727272)),
                    ),
                    SizedBox(height: 40),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 5),
                              Text(
                                "Profile Information",
                                style: TextStyle(
                                  color: Color(0xffC1C1C1),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.left,
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          // Name input field using helper function
                          _buildCustomInput(
                            labelText: 'Name',
                            controller: profileController.nicknameController,
                            onChanged: (_) {
                              // Controller handles the value internally
                            },
                          ),
                          SizedBox(height: 20),

                          // Username input field using helper function
                          _buildCustomInput(
                            labelText: 'Username',
                            controller: profileController.usernameController,
                            onChanged: (_) {
                              // Controller handles the value internally
                            },
                            helperText:
                                profileController.canUpdateUsername()
                                    ? null
                                    : "Username can only be changed once every 14 days",
                          ),
                          SizedBox(height: 20),

                          // Bio input field using helper function
                          _buildCustomInput(
                            labelText: 'Bio',
                            controller: profileController.bioController,
                            maxLines: 3,
                            maxLength: 100,
                            alignLabelWithHint: true,
                            onChanged: (_) {
                              // Controller handles the value internally
                            },
                          ),
                          SizedBox(height: 20),
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
                      ? CircularProgressIndicator(color: Color(0xff0060FF))
                      : CustomButton(
                        text: "Update Profile",
                        width: 300,
                        backgroundColor: const Color(0xff0060FF),
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
