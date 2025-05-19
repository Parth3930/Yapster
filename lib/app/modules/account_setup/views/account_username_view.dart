import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';
import 'package:yapster/app/global_widgets/custom_input.dart';
import 'package:yapster/app/modules/account_setup/controllers/account_setup_controller.dart';

class AccountUsernameSetupView extends GetView<AccountSetupController> {
  const AccountUsernameSetupView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
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
                          readOnly: controller.isLoading.value,
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
                                  color: Colors.white,
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
                            textColor: Colors.white,
                            isLoading: controller.isLoading.value,
                            onPressed:
                                controller.isLoading.value
                                    ? () {}
                                    : () => controller.saveUsername(),
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
