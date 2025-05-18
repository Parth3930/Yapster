import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/icon_button_widget.dart';
import '../controllers/create_controller.dart';

class CreateView extends GetView<CreateController> {
  const CreateView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "New Post",
              style: TextStyle(
                fontFamily: GoogleFonts.dongle().fontFamily,
                fontSize: 38,
              ),
            ),
            Image.asset("assets/icons/story.png", width: 20, height: 20),
          ],
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // Main content area
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Left column with large avatar and line
                Column(
                  children: [
                    SizedBox(height: 20),
                    CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: AvatarUtils.getAvatarImage(
                        null,
                        accountDataProvider,
                      ),
                    ),
                    Container(height: 50, width: 1, color: Colors.grey[700]),
                  ],
                ),
                SizedBox(width: 10),
                // Right column with username and content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("@${accountDataProvider.username.string}"),
                      Text(
                        "Whats New?",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          IconButtonWidget(
                            assetPath: "assets/icons/add_image.png",
                            width: 20,
                            height: 20,
                            onTap: () {},
                          ),
                          SizedBox(width: 10),
                          IconButtonWidget(
                            assetPath: "assets/icons/camera.png",
                            width: 20,
                            height: 20,
                            onTap: () {},
                          ),
                          SizedBox(width: 10),
                          IconButtonWidget(
                            assetPath: "assets/icons/gif.png",
                            width: 20,
                            height: 20,
                            onTap: () {},
                          ),
                          SizedBox(width: 10),
                          IconButtonWidget(
                            assetPath: "assets/icons/sticker.png",
                            width: 20,
                            height: 20,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recreating the layout structure to match the column above
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: AvatarUtils.getAvatarImage(
                      null,
                      accountDataProvider,
                    ),
                  ),
                  SizedBox(width: 10), // Same spacing as in main row
                  Expanded(
                    child: TextField(
                      maxLines: null,
                      maxLength: 200,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      controller: controller.postTextController,
                      cursorColor: Colors.white,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Add Thread',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        counterStyle: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }
}
