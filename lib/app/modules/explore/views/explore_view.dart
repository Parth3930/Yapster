import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yapster/app/global_widgets/bottom_navigation.dart';
import 'package:yapster/app/global_widgets/custom_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../controllers/explore_controller.dart';

class ExploreView extends GetView<ExploreController> {
  const ExploreView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Explore"),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Obx(
              () =>
                  controller.isLoading.value
                      ? const Center(child: CircularProgressIndicator())
                      : _buildSearchContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(60),
        ),
        child: TextField(
          controller: controller.searchController,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.left,
          decoration: InputDecoration(
            hintText: 'Search Friends',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.search, color: Color(0xFFAAAAAA)),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 15,
              horizontal: 5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    // If we have search results, show them
    if (controller.searchResults.isNotEmpty) {
      return _buildUserList(controller.searchResults, isSearchResult: true);
    }

    // If the search field is empty and we have recent searches, show them
    if (controller.searchText.isEmpty && controller.recentSearches.isNotEmpty) {
      // Explicitly mark as NOT search results to ensure delete buttons show
      return _buildUserList(controller.recentSearches, isSearchResult: false);
    }

    // If search field is not empty but no results
    if (controller.searchText.isNotEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(fontSize: 16)),
      );
    }

    // Default empty state
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 70, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Search for users',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users, {
    bool isSearchResult = false,
  }) {
    return ListView.builder(
      itemCount: users.length,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemBuilder: (context, index) {
        final user = users[index];
        return UserListItem(
          user: user,
          onTap: () => controller.openUserProfile(user),
          isSearchResult: isSearchResult,
        );
      },
    );
  }
}

class UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;
  final bool isSearchResult;

  const UserListItem({
    required this.user,
    required this.onTap,
    this.isSearchResult = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ExploreController>();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['nickname'] != null && user['nickname'].toString().isNotEmpty) 
                          ? user['nickname'] 
                          : 'Yapper',
                          style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    
                    if (user['username'] != null &&
                        user['username'].toString().isNotEmpty)
                      Text(
                        '@${user['username']}',
                        style:  TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
              isSearchResult
                  ? const SizedBox.shrink()
                  : IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    onPressed: () {
                      debugPrint('Deleting search history item');
                      controller.removeFromRecentSearches(user);
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    // Check if user has regular avatar
    final hasRegularAvatar = user['avatar'] != null && 
                           user['avatar'].toString().isNotEmpty && 
                           user['avatar'] != "skiped" &&
                           user['avatar'].toString() != "skiped" &&
                           user['avatar'].toString() != "null";
                           
    // Check if user has Google avatar
    final hasGoogleAvatar = user['google_avatar'] != null && 
                          user['google_avatar'].toString().isNotEmpty &&
                          user['google_avatar'].toString() != "null";
    
    // Debug avatar info
    debugPrint('User avatar: ${user['avatar']}');
    debugPrint('User google avatar: ${user['google_avatar']}');
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[300],
      backgroundImage: hasRegularAvatar
              ? CachedNetworkImageProvider(user['avatar'])
          : hasGoogleAvatar
              ? CachedNetworkImageProvider(user['google_avatar'])
              : null,
      child: (!hasRegularAvatar && !hasGoogleAvatar)
              ? const Icon(Icons.person, color: Colors.white)
              : null,
    );
  }
}
