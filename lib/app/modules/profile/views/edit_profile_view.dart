import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/theme/theme_controller.dart';
import 'package:yapster/app/core/values/colors.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/global_widgets/custom_button.dart';

class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  // Helper function to build custom input fields
  Widget _buildCustomInput({
    required String labelText,
    required Function(String) onChanged,
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

    return Scaffold(
      appBar: CustomAppBar(title: 'Edit Profile'),
      body: Column(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 30),
                Center(
                  child: GestureDetector(
                    onTap: () async => {},
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        accountDataProvider.avatar.value.isNotEmpty
                            ? accountDataProvider.avatar.value
                            : accountDataProvider.googleAvatar.value,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 40),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 2),
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
                        onChanged: (value) {
                          // Handle name changes
                        },
                      ),
                      SizedBox(height: 20),

                      // Username input field using helper function
                      _buildCustomInput(
                        labelText: 'Username',
                        onChanged: (value) {
                          // Handle username changes
                        },
                      ),
                      SizedBox(height: 20),

                      // Bio input field using helper function
                      _buildCustomInput(
                        labelText: 'Bio',
                        maxLines: 3,
                        maxLength: 100,
                        alignLabelWithHint: true,
                        onChanged: (value) {
                          // Handle bio changes
                        },
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          CustomButton(
            text: "Update Profile",
            width: 300,
            backgroundColor: const Color(0xff0060FF),
            textColor:
                themeController.isDarkMode
                    ? AppColors.textWhite
                    : AppColors.textDark,
            onPressed: () {
              // Handle continue button press
            },
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
