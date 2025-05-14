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
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: NetworkImage(
                accountDataProvider.avatar.value.isEmpty
                    ? accountDataProvider.googleAvatar.value
                    : "",
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(accountDataProvider.username.string),
          const Spacer(),
          CustomButton(
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
                    : () => controller.skipedAvatar(),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
