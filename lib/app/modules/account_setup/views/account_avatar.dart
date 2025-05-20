import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/modules/account_setup/controllers/account_setup_controller.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:image_picker/image_picker.dart';

class AccountAvatarSetupView extends GetView<AccountSetupController> {
  const AccountAvatarSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

    // Preload any existing avatar images when view is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (accountDataProvider.avatar.value.isNotEmpty ||
          accountDataProvider.googleAvatar.value.isNotEmpty) {
        AvatarUtils.preloadAvatarImages(accountDataProvider);
      }
    });

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
          Center(
            child: Text(
              "Add Profile Picture",
              style: GoogleFonts.roboto(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Obx(
            () => Center(
              child: GestureDetector(
                onTap: () {
                  controller.pickImage();
                },
                child: Stack(
                  children: [
                    // Avatar image
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: AvatarUtils.getAvatarImage(
                        controller.selectedImage.value,
                        accountDataProvider,
                      ),
                      child: AvatarUtils.shouldShowDefaultIcon(
                                controller.selectedImage.value,
                                accountDataProvider,
                              )
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
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
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
              textColor: Colors.white,
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
}
