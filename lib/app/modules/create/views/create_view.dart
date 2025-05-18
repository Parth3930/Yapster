import 'package:flutter/material.dart';
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: AvatarUtils.getAvatarImage(
                    null,
                    accountDataProvider,
                  ),
                ),
                Container(height: 50, width: 1, color: Colors.grey[700]),

                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: AvatarUtils.getAvatarImage(
                    null,
                    accountDataProvider,
                  ),
                ),
              ],
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("@${accountDataProvider.username.string}"),
                  Text("Whats New?", style: TextStyle(color: Colors.grey[500])),
                  SizedBox(height: 10),
                  Row(
                    spacing: 10,
                    children: [
                      IconButtonWidget(
                        assetPath: "assets/icons/add_image.png",
                        width: 20,
                        height: 20,
                        onTap: () {},
                      ),
                      IconButtonWidget(
                        assetPath: "assets/icons/camera.png",
                        width: 20,
                        height: 20,
                        onTap: () {},
                      ),
                      IconButtonWidget(
                        assetPath: "assets/icons/gif.png",
                        width: 20,
                        height: 20,
                        onTap: () {},
                      ),
                      IconButtonWidget(
                        assetPath: "assets/icons/sticker.png",
                        width: 20,
                        height: 20,
                        onTap: () {},
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
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
