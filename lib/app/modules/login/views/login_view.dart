import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import '../controllers/login_controller.dart';
import '../../../global_widgets/custom_button.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    // Track which button is clicked
    final RxString loadingButton = ''.obs;

    return Scaffold(
      body: Obx(() {
        return SafeArea(
          child: Column(
            children: [
              // Add spacer to push content to center
              const Spacer(flex: 1),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Yapster',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                        height: 0.8,
                        fontFamily: GoogleFonts.dongle().fontFamily,
                        color:
                            themeController.isDarkMode
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                    Text(
                      'Comedy lives here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.roboto().fontFamily,
                        color:
                            themeController.isDarkMode
                                ? Colors.white
                                : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Container for login in the bottom
              const Spacer(flex: 1),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(
                  color:
                      themeController.isDarkMode
                          ? AppColors.accentColorDark
                          : AppColors.accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(50),
                    topRight: Radius.circular(50),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomButton(
                      text: 'Continue with Google',
                      onPressed: controller.isLoading.value
                          ? () {} 
                          : () {
                              loadingButton.value = 'google';
                              controller.signInWithGoogle().then((_) {
                                loadingButton.value = '';
                              }).catchError((_) {
                                loadingButton.value = '';
                              });
                            },
                      width: 270,
                      height: 55,
                      textColor: const Color(0xff3C4043),
                      isLoading: controller.isLoading.value && loadingButton.value == 'google',
                      backgroundColor: Colors.white,
                      imageIcon: Image.asset(
                        'assets/icons/google.png',
                        width: 25,
                        height: 25,
                      ),
                      fontFamily: GoogleFonts.roboto().fontFamily,
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      text: 'Create New Account',
                      onPressed: controller.isLoading.value
                          ? () {}
                          : () {
                              loadingButton.value = 'create';
                              controller.signInWithGoogle().then((_) {
                                loadingButton.value = '';
                              }).catchError((_) {
                                loadingButton.value = '';
                              });
                            },
                      width: 270,
                      height: 55,
                      textColor: Colors.white,
                      isLoading: controller.isLoading.value && loadingButton.value == 'create',
                      backgroundColor: Colors.black,
                      fontFamily: GoogleFonts.roboto().fontFamily,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
