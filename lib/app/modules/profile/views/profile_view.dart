import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/profile_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yapster/app/core/utils/avatar_utils.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();
    // Preload avatar images when view is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (accountDataProvider.avatar.value.isNotEmpty ||
          accountDataProvider.googleAvatar.value.isNotEmpty) {
        AvatarUtils.preloadAvatarImages(accountDataProvider);
        controller.isAvatarLoaded.value = true;
      }
      // Force refresh follower/following counts
      controller.refreshFollowData();
    });

    return Scaffold(
      appBar: CustomAppBar(title: "Yapster"),
      body: Column(
        children: [
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: AvatarUtils.getAvatarImage(
                            null,
                            accountDataProvider,
                          ),
                          child:
                              AvatarUtils.shouldShowDefaultIcon(
                                    null,
                                    accountDataProvider,
                                  )
                                  ? Icon(
                                    Icons.person,
                                    size: 45,
                                    color: Colors.white,
                                  )
                                  : null,
                        ),
                        // Blue circle with plus icon (empty functionality)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 30,
                            width: 30,
                            decoration: BoxDecoration(
                              color: Color(0xff0060FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              accountDataProvider.nickname.string == ""
                                  ? "NickName"
                                  : accountDataProvider.nickname.string,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),

                            // add animation of scale down like its pressed
                            GestureDetector(
                              onTap:
                                  () async => {
                                    await Get.toNamed(Routes.EDIT_PROFILE),
                                  },
                              onTapDown:
                                  (_) => controller.setEditIconScale(0.8),
                              onTapUp: (_) => controller.setEditIconScale(1.0),
                              onTapCancel:
                                  () => controller.setEditIconScale(1.0),
                              child: Obx(
                                () => Transform.scale(
                                  scale: controller.editIconScale.value,
                                  child: Image.asset(
                                    "assets/icons/edit.png",
                                    width: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "@${accountDataProvider.username.string}",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: Text(
                            accountDataProvider.bio.isEmpty
                                ? "Something About Yourself"
                                : accountDataProvider.bio.string,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPostsStats(accountDataProvider),
                    _buildFollowersStats(accountDataProvider),
                    _buildFollowingStats(accountDataProvider),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTabItem(0, "All"),
              _buildTabItem(1, "Threads"),
              _buildTabItem(2, "Images"),
              _buildTabItem(3, "Gif"),
              _buildTabItem(4, "Sticker"),
            ],
          ),
          Divider(thickness: 0.5, color: Color(0xff4C4C4C)),
          Expanded(
            child: Obx(() {
              // Get posts based on selected tab
              List<Map<String, dynamic>> posts = [];

              switch (controller.selectedTabIndex.value) {
                case 0: // All
                  posts = accountDataProvider.allPosts;
                  break;
                case 1: // Threads
                  posts = accountDataProvider.threadsList;
                  break;
                case 2: // Images
                  posts = accountDataProvider.imagesList;
                  break;
                case 3: // Gifs
                  posts = accountDataProvider.gifsList;
                  break;
                case 4: // Stickers
                  posts = accountDataProvider.stickersList;
                  break;
              }

              if (posts.isEmpty) {
                return Center(
                  child: Text(
                    "No posts yet!",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return PostItem(post: post);
                },
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }

  Widget _buildPostsStats(AccountDataProvider provider) {
    return Column(
      children: [
        Obx(
          () => Text(
            provider.postsCount.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 5),
        Text("Posts", style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildFollowersStats(AccountDataProvider provider) {
    return GestureDetector(
      onTap: () => controller.openFollowersList(),
      child: Column(
        children: [
          Obx(
            () {
              debugPrint('Displaying follower count: ${provider.followerCount}');
              return Text(
                provider.followerCount.toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              );
            },
          ),
          SizedBox(width: 5),
          Text("Followers", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildFollowingStats(AccountDataProvider provider) {
    return GestureDetector(
      onTap: () => controller.openFollowingList(),
      child: Column(
        children: [
          Obx(
            () {
              debugPrint('Displaying following count: ${provider.followingCount}');
              return Text(
                provider.followingCount.toString(),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              );
            },
          ),
          SizedBox(width: 5),
          Text("Following", style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    return Obx(() {
      final isSelected = controller.selectedTabIndex.value == index;
      return GestureDetector(
        onTap: () => controller.selectTab(index),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Color(0xffA5A5A5),
          ),
        ),
      );
    });
  }
}

// Simple post item widget
class PostItem extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostItem({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Color(0xff1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post['content'] != null)
            Text(
              post['content'].toString(),
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          if (post['image_url'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: post['image_url'].toString(),
                placeholder:
                    (context, url) => Container(
                      height: 200,
                      color: Colors.grey[800],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff0060FF),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                errorWidget:
                    (context, url, error) => Container(
                      height: 100,
                      color: Colors.grey[900],
                      child: Center(
                        child: Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                fit: BoxFit.cover,
                height: 200,
                width: double.infinity,
              ),
            ),
        ],
      ),
    );
  }
}
