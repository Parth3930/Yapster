import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/modules/settings/controllers/privacy_controller.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller using GetX
    final controller = Get.put(PrivacyController(), tag: 'privacy_settings');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Get.delete<PrivacyController>(tag: 'privacy_settings');
            Get.back();
          },
        ),
        title: const Text(
          'Privacy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.isInitialLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Private Account setting
                Obx(
                  () => _buildPrivacyItem(
                    title: 'Private Account',
                    description:
                        'If your account is private, only your friends and followers can see your profile and posts but if it\'s public, everyone on Yapster can.',
                    value: controller.isPrivateAccount.value,
                    onChanged: controller.togglePrivateAccount,
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

  Widget _buildPrivacyItem({
    required String title,
    required String description,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.roboto().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                        fontFamily: GoogleFonts.roboto().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildCustomSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSwitch({
    required bool value,
    required Function(bool)? onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!value) : null,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        tween: Tween<double>(begin: value ? 0.0 : 1.0, end: value ? 1.0 : 0.0),
        builder: (context, animation, child) {
          return Container(
            width: 50,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Color.lerp(Colors.grey[700]!, Colors.green, animation),
              boxShadow: [
                BoxShadow(
                  color:
                      value
                          ? Colors.green.withOpacity(0.3 * animation)
                          : Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOutCubic,
                  left: value ? 22 : 2,
                  top: 2,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
