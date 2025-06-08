import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/icon_button_widget.dart';
import '../controllers/create_controller.dart';
import 'package:yapster/app/routes/app_pages.dart';

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
            GestureDetector(
              onTap: () {
                Get.toNamed(Routes.CREATE_STORY);
              },
              child: Image.asset(
                "assets/icons/story.png",
                width: 20,
                height: 20,
              ),
            ),
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
                            onTap: controller.pickImages,
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

            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  children: [
                    Row(
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

                    // Image preview section
                    Obx(() {
                      if (controller.selectedImages.isEmpty) {
                        return SizedBox.shrink();
                      }

                      return Container(
                        margin: EdgeInsets.only(top: 16, left: 50),
                        child: _buildImagePreview(controller),
                      );
                    }),

                    Spacer(),

                    // Post button
                    Obx(
                      () => Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 20),
                        child: ElevatedButton(
                          onPressed:
                              controller.canPost.value &&
                                      !controller.isLoading.value
                                  ? controller.createPost
                                  : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                controller.canPost.value
                                    ? Colors.white
                                    : Colors.grey[800],
                            foregroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child:
                              controller.isLoading.value
                                  ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    'Post',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }

  Widget _buildImagePreview(CreateController controller) {
    final imageCount = controller.selectedImages.length;

    if (imageCount == 1) {
      // Single image - full width
      return _buildSingleImagePreview(
        controller.selectedImages[0],
        0,
        controller,
      );
    } else if (imageCount == 2) {
      // Two images - side by side
      return Row(
        children: [
          Expanded(
            child: _buildImagePreviewItem(
              controller.selectedImages[0],
              0,
              controller,
            ),
          ),
          SizedBox(width: 4),
          Expanded(
            child: _buildImagePreviewItem(
              controller.selectedImages[1],
              1,
              controller,
            ),
          ),
        ],
      );
    } else if (imageCount == 3) {
      // Three images - first one full width, bottom two side by side
      return Column(
        children: [
          _buildImagePreviewItem(controller.selectedImages[0], 0, controller),
          SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildImagePreviewItem(
                  controller.selectedImages[1],
                  1,
                  controller,
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: _buildImagePreviewItem(
                  controller.selectedImages[2],
                  2,
                  controller,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox.shrink();
  }

  Widget _buildSingleImagePreview(
    File image,
    int index,
    CreateController controller,
  ) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: FileImage(image), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => controller.removeImage(index),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewItem(
    File image,
    int index,
    CreateController controller,
  ) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        image: DecorationImage(image: FileImage(image), fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => controller.removeImage(index),
              child: Container(
                padding: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
