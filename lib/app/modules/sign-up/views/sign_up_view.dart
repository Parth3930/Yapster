import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/global_widgets/custom_input.dart';
import 'package:yapster/app/modules/sign-up/controllers/sign_up_controller.dart';
import '../../../global_widgets/loading_widget.dart';

class SignUpView extends GetView<SignUpController> {
  const SignUpView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Scaffold(
      body: Obx(() {
        if (controller.isLoading.value) {
          return const LoadingWidget(message: 'Signing in...');
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(
              context,
            ).unfocus(); // Unfocuses the input and closes the keyboard
          },
          behavior:
              HitTestBehavior
                  .opaque, // Ensures the GestureDetector captures taps everywhere
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Center(
                  child: Text(
                    "Create Yap ID",
                    style: TextStyle(
                      fontSize: 50,
                      fontFamily: GoogleFonts.dongle().fontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: CustomInput(
                          label: 'Username',
                          hintText: 'Enter your username',
                          controller: controller.usernameController,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: GoogleFonts.roboto().fontFamily,
                                  color:
                                      themeController.isDarkMode
                                          ? AppColors.textWhite
                                          : AppColors.textDark,
                                ),
                                children: [
                                  const TextSpan(
                                    text:
                                        'By tapping Continue, you agree to the ',
                                  ),
                                  TextSpan(
                                    text: "Yapster's ",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const TextSpan(
                                    text:
                                        'Terms of Service and Privacy Policy.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CustomButton(
                            text: "Continue",
                            width: 300,
                            backgroundColor: const Color(0xff0060FF),
                            textColor:
                                themeController.isDarkMode
                                    ? AppColors.textWhite
                                    : AppColors.textDark,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }),
    );
  }
}
