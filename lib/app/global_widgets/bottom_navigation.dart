import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../routes/app_pages.dart';
import '../core/utils/storage_service.dart';
import '../core/values/constants.dart';
import '../data/models/user_model.dart';
import '../core/utils/avatar_utils.dart';
import '../data/providers/account_data_provider.dart';

// Controller to manage bottom navigation animations globally
class BottomNavAnimationController extends GetxController {
  // Observable to trigger animations
  final RxString animateIcon = ''.obs;

  // Observable to control bottom nav visibility globally
  final RxBool showBottomNav = true.obs;

  // Get user data from storage
  UserModel? get currentUser {
    try {
      final storageService = Get.find<StorageService>();
      final userData = storageService.getObject(AppConstants.userDataKey);
      if (userData != null) {
        return UserModel.fromMap(userData);
      }
    } catch (e) {
      // Return null if no user data found
    }
    return null;
  }

  // Trigger animation for specific icon
  void triggerAnimation(String route) {
    animateIcon.value = route;
    // Reset after longer animation duration
    Future.delayed(const Duration(milliseconds: 800), () {
      animateIcon.value = '';
    });
  }

  // Hide bottom navigation with smooth animation
  void hideBottomNav() {
    if (showBottomNav.value) {
      showBottomNav.value = false;
    }
  }

  // Show bottom navigation with smooth animation
  void showBottomNavigation() {
    if (!showBottomNav.value) {
      showBottomNav.value = true;
    }
  }

  // Navigate with bottom nav animation - smooth slide down for all routes
  Future<void> navigateWithAnimation(String route) async {
    // Hide bottom nav first to start the slide animation
    hideBottomNav();

    // Wait just enough for the animation to start (shorter delay for smoothness)
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate to the route
    return Get.toNamed(route);
  }

  // Method to be called when returning to home page
  void onReturnToHome() {
    Future.delayed(const Duration(milliseconds: 100), () {
      showBottomNavigation();
    });
  }
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with TickerProviderStateMixin {
  // Get the global animation controller
  final BottomNavAnimationController _animationController = Get.put(
    BottomNavAnimationController(),
    permanent: true,
  );

  // Controllers for each icon's animation
  late List<AnimationController> _controllers;
  late List<Animation> _animations;

  // Special controller for the add button's 360 rotation
  late AnimationController _addButtonController;
  late Animation<double> _addButtonAnimation;

  // Home animation controllers
  late AnimationController _homeController;
  late Animation<double> _homeScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize controllers for regular icons (excluding home, which has special animations)
    _controllers = List.generate(
      3, // Reduced to 3 (for explore, chat, profile)
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600), // Slower animations
        vsync: this,
      ),
    );

    // Create different animations for each icon (excluding home)
    _animations = [
      // Chat icon - rotational shake animation (tilt left, tilt right, back to center)
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.3), // Tilt left (up-left)
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: -0.3, end: 0.3), // Tilt right (up-right)
          weight: 30,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.3, end: -0.15), // Small tilt left
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: -0.15, end: 0.0), // Back to center
          weight: 20,
        ),
      ]).animate(
        CurvedAnimation(parent: _controllers[0], curve: Curves.easeInOut),
      ),

      // Videos icon - simple bounce animation
      TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.2), // Scale up
          weight: 50,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 1.0), // Return to normal
          weight: 50,
        ),
      ]).animate(
        CurvedAnimation(parent: _controllers[1], curve: Curves.bounceOut),
      ),

      // Profile icon - improved squeeze with safe transform values
      TweenSequence<Offset>([
        TweenSequenceItem(
          tween: Tween(begin: Offset.zero, end: Offset(0, 0.2)),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: Offset(0, 0.2), end: Offset(0.1, 0.3)),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: Offset(0.1, 0.3), end: Offset(-0.1, 0.1)),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween(begin: Offset(-0.1, 0.1), end: Offset.zero),
          weight: 25,
        ),
      ]).animate(
        CurvedAnimation(parent: _controllers[2], curve: Curves.easeInOut),
      ),
    ];

    // Initialize simple home animation
    _homeController = AnimationController(
      duration: const Duration(milliseconds: 600), // Slower animation
      vsync: this,
    );

    // Wobble animation for home icon (different from videos)
    _homeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.1),
        weight: 50,
      ), // Scale up
      TweenSequenceItem(
        tween: Tween(begin: 1.1, end: 1.0),
        weight: 50,
      ), // Scale back
    ]).animate(
      CurvedAnimation(parent: _homeController, curve: Curves.easeInOutCubic),
    );

    // Initialize special controller for add button with enhanced animation
    _addButtonController = AnimationController(
      duration: const Duration(milliseconds: 600), // Optimized duration
      vsync: this,
    );

    // Simple smooth rotation animation for add button
    _addButtonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _addButtonController, curve: Curves.easeInOut),
    );

    // Listen for animation triggers from navigation
    _animationController.animateIcon.listen((route) {
      if (route.isNotEmpty && mounted) {
        _playAnimationForRoute(route);
      }
    });
  }

  // Play animation for specific route
  void _playAnimationForRoute(String route) {
    AnimationController? controller;

    switch (route) {
      case Routes.HOME:
        controller = _homeController;
        break;
      case Routes.CHAT:
        controller = _controllers[0];
        break;
      case Routes.VIDEOS:
        controller = _controllers[1];
        break;
      case Routes.PROFILE:
        controller = _controllers[2];
        break;
      case Routes.CREATE:
        controller = _addButtonController;
        break;
    }

    // Play animation if controller exists
    if (controller != null) {
      controller.reset();
      controller.forward();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers) {
      controller.dispose();
    }
    _homeController.dispose();
    _addButtonController.dispose();
    super.dispose();
  }

  // Navigate to the appropriate page
  void _navigateToPage(String route) {
    // Only navigate if we're not already on that page
    if (Get.currentRoute != route) {
      // Special handling for create button is in _buildAddButton
      if (route == Routes.CREATE) return;

      // Navigate immediately for speed
      Get.offNamed(route);

      // Schedule animation to play on the new page after navigation completes
      Future.delayed(const Duration(milliseconds: 100), () {
        _animationController.triggerAnimation(route);
      });
    }
  }

  // Build the home icon with wobble and rotation animation
  Widget _buildHomeIcon() {
    final isActive = Get.currentRoute == Routes.HOME;

    return GestureDetector(
      onTap: () => _navigateToPage(Routes.HOME),
      child: Container(
        width: 52, // Increased container size
        height: 52,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _homeScaleAnimation,
          builder: (context, child) {
            // Create wobble effect with scale and slight rotation
            final scaleValue = _homeScaleAnimation.value;
            final rotationValue =
                (scaleValue - 1.0) * 0.3; // Slight rotation based on scale

            return Transform.scale(
              scale: scaleValue,
              child: Transform.rotate(angle: rotationValue, child: child),
            );
          },
          child: Image.asset(
            isActive
                ? 'assets/navigation/home_active.png'
                : 'assets/navigation/home.png',
            width: 28, // Increased icon size
            height: 28,
          ),
        ),
      ),
    );
  }

  // Build the videos icon with simple bounce animation
  Widget _buildVideosIcon() {
    final isActive = Get.currentRoute == Routes.VIDEOS;

    return GestureDetector(
      onTap: () => _navigateToPage(Routes.VIDEOS),
      child: Container(
        width: 52, // Increased container size
        height: 52,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _animations[1],
          builder: (context, child) {
            // Simple bounce animation with subtle rotation
            final scaleValue = _animations[1].value as double;
            final rotationValue =
                (scaleValue - 1.0) * 0.05; // Very subtle rotation

            return Transform.scale(
              scale: scaleValue,
              child: Transform.rotate(angle: rotationValue, child: child),
            );
          },
          child: Image.asset(
            isActive
                ? 'assets/navigation/videos_active.png'
                : 'assets/navigation/videos.png',
            width: 28, // Increased icon size
            height: 28,
          ),
        ),
      ),
    );
  }

  // Build the chat icon with rotational shake animation
  Widget _buildChatIcon() {
    final isActive =
        Get.currentRoute == Routes.CHAT || Get.currentRoute.startsWith('/chat');

    return GestureDetector(
      onTap: () => _navigateToPage(Routes.CHAT),
      child: Container(
        width: 52, // Increased container size
        height: 52,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _animations[0],
          builder: (context, child) {
            // Use rotation for shake effect (tilt left, tilt right, back to center)
            final rotationValue = _animations[0].value as double;

            return Transform.rotate(angle: rotationValue, child: child);
          },
          child: Image.asset(
            isActive
                ? 'assets/navigation/message_active.png'
                : 'assets/navigation/chat.png',
            width: 28, // Increased icon size
            height: 28,
          ),
        ),
      ),
    );
  }

  // Build the profile icon with user avatar and improved squeeze animation
  Widget _buildProfileIcon() {
    final isActive = Get.currentRoute == Routes.PROFILE;
    final user = _animationController.currentUser;

    return GestureDetector(
      onTap: () => _navigateToPage(Routes.PROFILE),
      child: Container(
        width: 52, // Increased container size
        height: 52,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _animations[2],
          builder: (context, child) {
            // Create an improved squeeze with safe values
            final squeeze = _animations[2].value;
            final squeezeX = 1.0 - (squeeze.dy * 0.3);
            final squeezeY = 1.0 - (squeeze.dx * 0.3);

            return Transform(
              transform:
                  Matrix4.identity()
                    ..scale(squeezeX, squeezeY, 1.0)
                    ..rotateZ(squeeze.dx * 0.1),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: _buildUserAvatar(user, isActive),
        ),
      ),
    );
  }

  // Build user avatar with fallback options using AvatarUtils
  Widget _buildUserAvatar(UserModel? user, bool isActive) {
    try {
      // Try to get AccountDataProvider for AvatarUtils
      final accountDataProvider = Get.find<AccountDataProvider>();

      // Get the best avatar URL using AvatarUtils logic
      String? avatarUrl = AvatarUtils.getAvatarUrl(
        isCurrentUser: true,
        accountDataProvider: accountDataProvider,
      );

      // If AvatarUtils doesn't return a valid URL, fall back to user model data
      if (avatarUrl.isNotEmpty ||
          avatarUrl.isEmpty ||
          avatarUrl == "skiped" ||
          avatarUrl == "null") {
        if (user != null) {
          // Check if avatar is "skiped", use google_avatar
          if (user.avatar == "skiped" && user.googleAvatar.isNotEmpty) {
            avatarUrl = user.googleAvatar;
          } else if (user.avatar.isNotEmpty && user.avatar != "skiped") {
            avatarUrl = user.avatar;
          }
        }
      }

      // If we have a valid avatar URL, show it with cached network image
      if (avatarUrl.isNotEmpty &&
          avatarUrl.isNotEmpty &&
          AvatarUtils.isValidUrl(avatarUrl)) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.white, width: 1) : null,
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero, // Instant display
              fadeOutDuration: Duration.zero,
              placeholder:
                  (context, url) => Container(
                    width: 28,
                    height: 28,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    width: 28,
                    height: 28,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting avatar from AccountDataProvider: $e');
    }

    // Final fallback to default profile icon
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isActive ? Border.all(color: Colors.white, width: 2.5) : null,
      ),
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.grey[800],
        child: Icon(
          Icons.person,
          size: 16,
          color: isActive ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }

  // Build the add button with smooth rotation animation
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {
        // Use the new navigation method with animation
        _animationController.navigateWithAnimation(Routes.CREATE);

        // Schedule icon animation to play after navigation completes
        Future.delayed(const Duration(milliseconds: 400), () {
          _animationController.triggerAnimation(Routes.CREATE);
        });
      },
      child: RepaintBoundary(
        // Use RepaintBoundary for better performance
        child: Container(
          width: 52, // Increased container size
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFB41DFF),
                Color(0xFFFF0000), // Red
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedBuilder(
            animation: _addButtonAnimation,
            builder: (context, child) {
              // Simple smooth rotation animation
              final rotationAngle = _addButtonAnimation.value * 2 * 3.14159;

              return Transform.rotate(
                angle: rotationAngle,
                alignment: Alignment.center,
                transformHitTests: false,
                filterQuality: FilterQuality.high,
                child: child,
              );
            },
            child: const Center(
              child: Icon(
                Icons.add,
                size: 40,
                color: Colors.white,
                weight: 500,
              ), // Increased icon size
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AnimatedSlide(
        offset:
            _animationController.showBottomNav.value
                ? Offset.zero
                : const Offset(
                  0,
                  1.2,
                ), // Slide further down for smoother effect
        duration: const Duration(
          milliseconds: 250,
        ), // Slightly longer for smoothness
        curve: Curves.easeInOutCubic, // Smoother curve
        child: AnimatedOpacity(
          opacity: _animationController.showBottomNav.value ? 1.0 : 0.0,
          duration: const Duration(
            milliseconds: 200,
          ), // Slightly longer opacity transition
          curve: Curves.easeOut,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 30, vertical: 30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildHomeIcon(),
                      _buildChatIcon(),
                      _buildAddButton(),
                      _buildVideosIcon(),
                      _buildProfileIcon(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
