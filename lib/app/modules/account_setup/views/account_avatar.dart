import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/modules/account_setup/controllers/account_setup_controller.dart';

class AccountAvatarSetupView extends GetView<AccountSetupController> {
  const AccountAvatarSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final supabaseService = Get.find<SupabaseService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () {
              Get.toNamed("/home");
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
            child: Obx(() {
              final avatarUrl = supabaseService.userAvatarUrl.string;
              final photoUrl = supabaseService.userPhotoUrl.string;
              final hasAvatar = avatarUrl.isNotEmpty;
              final hasPhoto = photoUrl.isNotEmpty;
              
              return CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[300],
                backgroundImage: (hasAvatar || hasPhoto) 
                  ? NetworkImage(hasAvatar ? avatarUrl : photoUrl)
                  : null,
                child: (!hasAvatar && !hasPhoto) 
                  ? Icon(Icons.person, size: 50, color: Colors.grey[700])
                  : null,
              );
            }),
          ),
          SizedBox(height: 20),
          Text(supabaseService.userName.string),
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
            onPressed: controller.isLoading.value ? () {} : () => {},
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
