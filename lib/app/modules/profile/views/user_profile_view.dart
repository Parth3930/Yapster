import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:yapster/app/modules/explore/controllers/explore_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class UserProfileView extends StatelessWidget {
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> posts;

  const UserProfileView({
    required this.userData,
    required this.posts,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreController>();
    final String userId = userData['user_id'] ?? '';

    // Make follower count observable
    final RxInt followerCount = RxInt(userData['follower_count'] ?? 0);

    // Debug avatar info
    debugPrint('Building user profile with avatar: ${userData['avatar']}');
    debugPrint('Google avatar: ${userData['google_avatar']}');

    // Force refresh follower and following counts whenever the view is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.refreshUserFollowData(userId);
    });

    return Scaffold(
      appBar: CustomAppBar(title: "Profile"),
      body: RefreshIndicator(
        onRefresh: () => controller.refreshUserFollowData(userId),
        color: Color(0xff0060FF),
        child: Column(
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
                        backgroundColor: Colors.grey[300],
                        // Try first avatar, then fall back to google avatar
                        backgroundImage: _getAvatarImage(),
                        child: _shouldShowDefaultIcon()
                            ? Icon(
                                Icons.person,
                                size: 45,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userData['nickname'] ?? "User",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "@${userData['username'] ?? ''}",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(
                            width: 200,
                            child: Text(
                              userData['bio'] ?? "No bio available",
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
                  // Follow/Unfollow button
                  Obx(
                    () => ElevatedButton(
                      onPressed: () async {
                        // Get the previous state to determine if we're following or unfollowing
                        final wasFollowing = controller.isFollowingUser(userId);
                        
                        // Show loading indicator using EasyLoading
                        EasyLoading.show(status: 'Processing...');
                        
                        // Toggle follow state
                        await controller.toggleFollowUser(userId);
                        
                        // Close loading indicator
                        EasyLoading.dismiss();
                        
                        // Instantly update follower count in the UI
                        if (wasFollowing) {
                          // Unfollow - decrease count
                          if (followerCount.value > 0) {
                            followerCount.value--;
                            userData['follower_count'] = followerCount.value;
                          }
                        } else {
                          // Follow - increase count
                          followerCount.value++;
                          userData['follower_count'] = followerCount.value;
                        }
                        
                        // Force UI refresh to update the button state
                        controller.update();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            controller.isFollowingUser(userId)
                                ? Colors.grey[800]
                                : Color(0xff0060FF),
                        minimumSize: Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            controller.isFollowingUser(userId)
                                ? Icons.check
                                : Icons.add,
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            controller.isFollowingUser(userId)
                                ? "Unfollow"
                                : "Follow",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildPostsStats(),
                      GestureDetector(
                        onTap: () => controller.openFollowersList(userId),
                        child: Obx(() => _buildFollowersStats(followerCount.value)),
                      ),
                      GestureDetector(
                        onTap: () => controller.openFollowingList(userId),
                        child: _buildFollowingStats(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(controller, 0, "All"),
                _buildTabItem(controller, 1, "Threads"),
                _buildTabItem(controller, 2, "Images"),
                _buildTabItem(controller, 3, "Gif"),
                _buildTabItem(controller, 4, "Sticker"),
              ],
            ),
            Divider(thickness: 0.5, color: Color(0xff4C4C4C)),
            Expanded(
              child: Obx(() {
                // Get posts based on selected tab
                List<Map<String, dynamic>> filteredPosts =
                    controller.getFilteredPosts();

                if (filteredPosts.isEmpty) {
                  return Center(
                    child: Text(
                      "No posts yet!",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    final post = filteredPosts[index];
                    return PostItem(post: post);
                  },
                );
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }

  Widget _buildTabItem(ExploreController controller, int index, String label) {
    return Obx(
      () => GestureDetector(
        onTap: () => controller.setSelectedPostTypeTab(index),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: controller.selectedPostTypeTab.value == index
                ? Colors.white
                : Color(0xffA5A5A5),
          ),
        ),
      ),
    );
  }

  Widget _buildPostsStats() {
    final userPosts = userData['user_posts'];
    int postCount;
    if (userPosts is Map && userPosts.containsKey('post_count')) {
      postCount = userPosts['post_count'] is int ? userPosts['post_count'] : 0;
    } else {
      postCount = 0;
    }
    return _buildStatColumn(postCount.toString(), 'Posts');
  }

  Widget _buildFollowersStats(int followerCount) {
    debugPrint('Displaying follower count: $followerCount');
    return _buildStatColumn(followerCount.toString(), 'Followers');
  }

  Widget _buildFollowingStats() {
    // Use following_count from userData, with a fallback to 0
    int followingCount = userData['following_count'] ?? 0;
    debugPrint('Following count from userData: $followingCount');
    return _buildStatColumn(followingCount.toString(), 'Following');
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey)),
      ],
    );
  }

  ImageProvider? _getAvatarImage() {
    // Debug avatar info
    debugPrint('Getting avatar image:');
    debugPrint('- Avatar: ${userData['avatar']}');
    debugPrint('- Google avatar: ${userData['google_avatar']}');

    // First check if avatar is valid
    if (userData['avatar'] != null && 
        userData['avatar'].toString().isNotEmpty && 
        userData['avatar'] != "skiped" &&
        userData['avatar'].toString() != "skiped" &&
        userData['avatar'].toString() != "null") {
      debugPrint('Using regular avatar');
      return CachedNetworkImageProvider(userData['avatar']);
    }
    // Then try Google avatar if available
    else if (userData['google_avatar'] != null && 
              userData['google_avatar'].toString().isNotEmpty &&
              userData['google_avatar'].toString() != "null") {
      debugPrint('Using Google avatar');
      return CachedNetworkImageProvider(userData['google_avatar']);
    }

    debugPrint('No valid avatar found, returning null');
    return null;
  }

  bool _shouldShowDefaultIcon() {
    final hasRegularAvatar = userData['avatar'] != null && 
                    userData['avatar'].toString().isNotEmpty && 
                    userData['avatar'] != "skiped" &&
                    userData['avatar'].toString() != "skiped" &&
                    userData['avatar'].toString() != "null";
                     
    final hasGoogleAvatar = userData['google_avatar'] != null && 
                          userData['google_avatar'].toString().isNotEmpty &&
                          userData['google_avatar'].toString() != "null";
                          
    final result = !hasRegularAvatar && !hasGoogleAvatar;
    debugPrint('Should show default icon: $result');
    return result;
  }
}

// Post item widget
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
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff0060FF),
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
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
