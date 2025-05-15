import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/modules/account_setup/controllers/account_setup_controller.dart';

class AccountAvatarSetupView extends GetView<AccountSetupController> {
  const AccountAvatarSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final accountDataProvider = Get.find<AccountDataProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              controller.skipedAvatar();
            },
            child: Text(
              "Skip",
              style: GoogleFonts.roboto(color: Color(0xffC4C4C4)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Obx(
            () => Center(
              child: GestureDetector(
                onTap: () {
                  controller.pickImage();
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[300],
                  // Fix the backgroundImage logic to handle empty values
                  backgroundImage: _getAvatarImage(
                    controller,
                    accountDataProvider,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(accountDataProvider.username.string),
          const Spacer(),
          Obx(
            () => CustomButton(
              text: "Continue",
              width: 300,
              backgroundColor: const Color(0xff0060FF),
              textColor:
                  themeController.isDarkMode
                      ? AppColors.textWhite
                      : AppColors.textDark,
              isLoading: controller.isLoading.value,
              onPressed:
                  controller.isLoading.value
                      ? () {}
                      : () => controller.saveAvatar(),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Helper method to get the correct image provider
  ImageProvider? _getAvatarImage(
    AccountSetupController controller,
    AccountDataProvider accountDataProvider,
  ) {
    // If there's a selected image, use FileImage
    if (controller.selectedImage.value != null) {
      return FileImage(File(controller.selectedImage.value!.path));
    }

    // Check if there's a valid avatar URL
    final avatarUrl =
        accountDataProvider.avatar.value.isNotEmpty
            ? accountDataProvider.avatar.value
            : accountDataProvider.googleAvatar.value;

    // Only use NetworkImage if there's a valid URL
    if (avatarUrl.isNotEmpty && avatarUrl != "skiped") {
      return NetworkImage(avatarUrl);
    }

    return null;
  }
}
