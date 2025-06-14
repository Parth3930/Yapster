import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:yapster/app/modules/profile/widgets/profile_avatar_widget.dart';
import 'package:yapster/app/routes/app_pages.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // User Profile Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Obx(
                () => Row(
                  children: [
                    // Large Avatar
                    ProfileAvatarWidget(
                      selectedImage: null,
                      imageUrl: accountDataProvider.avatar.value,
                      googleAvatarUrl: accountDataProvider.googleAvatar.value,
                      onTap: () {},
                      radius: 35,
                      isLoaded: true,
                      hasStory: false,
                      hasUnseenStory: false,
                      showAddButton: false,
                    ),

                    const SizedBox(width: 15),

                    // User Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nickname
                          Text(
                            accountDataProvider.nickname.value.isNotEmpty
                                ? accountDataProvider.nickname.value
                                : 'No Nickname',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Username
                          Text(
                            accountDataProvider.username.value.isNotEmpty
                                ? '@${accountDataProvider.username.value}'
                                : '@username',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 5),

                          // Bio
                          Text(
                            accountDataProvider.bio.value.isNotEmpty
                                ? accountDataProvider.bio.value
                                : 'No bio yet',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Settings Options
            _buildSettingsSection([
              _buildSettingsItem(
                icon: "assets/postIcons/like.png",
                title: 'Likes',
                onTap:
                    () => controller.navigateToSubPage(Routes.SETTINGS_LIKES),
              ),
              _buildSettingsItem(
                icon: "assets/postIcons/comment.png",
                title: 'Comments',
                onTap:
                    () =>
                        controller.navigateToSubPage(Routes.SETTINGS_COMMENTS),
              ),
              _buildSettingsItem(
                icon: "assets/postIcons/star.png",
                title: 'Favourites',
                onTap:
                    () => controller.navigateToSubPage(
                      Routes.SETTINGS_FAVOURITES,
                    ),
              ),
              _buildSettingsItem(
                icon: "assets/settingsIcons/notif.png",
                title: 'Notifications',
                onTap:
                    () => controller.navigateToSubPage(
                      Routes.SETTINGS_NOTIFICATIONS,
                    ),
              ),
              _buildSettingsItem(
                icon: "assets/settingsIcons/privacy.png",
                title: 'Privacy',
                onTap:
                    () => controller.navigateToSubPage(Routes.SETTINGS_PRIVACY),
              ),
              _buildSettingsItem(
                icon: "assets/settingsIcons/about.png",
                title: 'About',
                onTap:
                    () => controller.navigateToSubPage(Routes.SETTINGS_ABOUT),
              ),
            ]),
            // Logout Text Button
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Obx(
                  () => TextButton(
                    onPressed:
                        controller.isLoggingOut.value
                            ? null
                            : () => _showLogoutDialog(context),
                    child:
                        controller.isLoggingOut.value
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            )
                            : const Text(
                              'Log Out',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(children: items),
    );
  }

  Widget _buildSettingsItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                child: Image.asset(icon, color: Colors.white, height: 25),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out? This will clear all your cached data.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[400])),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
