import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

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
                    CircleAvatar(
                      radius: 45,
                      backgroundImage: NetworkImage(
                        accountDataProvider.avatar.string == "" ||
                                accountDataProvider.avatar.string == "skiped"
                            ? accountDataProvider.googleAvatar.string
                            : accountDataProvider.avatar.string,
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              accountDataProvider.nickname.string == ""
                                  ? accountDataProvider.username.string
                                  : "NickName",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            GestureDetector(
                              onTap:
                                  () async => {
                                    await Get.toNamed(Routes.EDIT_PROFILE),
                                  },
                              child: Image.asset(
                                "assets/icons/edit.png",
                                width: 20,
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
                            accountDataProvider.about.isEmpty
                                ? "Something About Yourself"
                                : accountDataProvider.about.string,
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
    return Column(
      children: [
        Obx(
          () => Text(
            provider.followersCount.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 5),
        Text("Followers", style: TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildFollowingStats(AccountDataProvider provider) {
    return Column(
      children: [
        Obx(
          () => Text(
            provider.followingCount.toString(),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(width: 5),
        Text("Following", style: TextStyle(fontSize: 16)),
      ],
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
            fontSize: 18,
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

  const PostItem({Key? key, required this.post}) : super(key: key);

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
            Container(
              margin: EdgeInsets.only(top: 8),
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(post['image_url']),
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
