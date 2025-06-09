import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_pages.dart';

// Controller to manage bottom navigation animations globally
class BottomNavAnimationController extends GetxController {
  // Observable to trigger animations
  final RxString animateIcon = ''.obs;

  // Trigger animation for specific icon
  void triggerAnimation(String route) {
    debugPrint('BottomNavAnimationController: Triggering animation for $route');
    animateIcon.value = route;
    // Reset after longer animation duration
    Future.delayed(const Duration(milliseconds: 800), () {
      animateIcon.value = '';
      debugPrint('BottomNavAnimationController: Animation reset for $route');
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
    debugPrint('_playAnimationForRoute called for: $route');
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
      debugPrint('Playing animation for $route');
      controller.reset();
      controller.forward();
    } else {
      debugPrint('No controller found for $route');
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
    return GestureDetector(
      onTap: () => _navigateToPage(Routes.HOME),
      child: Container(
        width: 44,
        height: 44,
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
            'assets/icons/home.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Build the videos icon with simple bounce animation
  Widget _buildVideosIcon() {
    return GestureDetector(
      onTap: () => _navigateToPage(Routes.VIDEOS),
      child: Container(
        width: 44,
        height: 44,
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
            'assets/icons/videos.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Build the chat icon with rotational shake animation
  Widget _buildChatIcon() {
    return GestureDetector(
      onTap: () => _navigateToPage(Routes.CHAT),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _animations[0],
          builder: (context, child) {
            // Use rotation for shake effect (tilt left, tilt right, back to center)
            final rotationValue = _animations[0].value as double;

            return Transform.rotate(angle: rotationValue, child: child);
          },
          child: Image.asset(
            'assets/icons/chat.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Build the profile icon with improved squeeze animation
  Widget _buildProfileIcon() {
    return GestureDetector(
      onTap: () => _navigateToPage(Routes.PROFILE),
      child: Container(
        width: 44,
        height: 44,
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
          child: Image.asset(
            'assets/icons/profile.png',
            width: 24,
            height: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Build the add button with smooth rotation animation
  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () {
        // Navigate immediately for speed
        Get.offNamed(Routes.CREATE);

        // Schedule animation to play on the new page after navigation completes
        Future.delayed(const Duration(milliseconds: 100), () {
          _animationController.triggerAnimation(Routes.CREATE);
        });
      },
      child: RepaintBoundary(
        // Use RepaintBoundary for better performance
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF9C27B0), // Purple
                Color(0xFFE91E63), // Pink
                Color(0xFFF44336), // Red
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
              child: Icon(Icons.add, size: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withAlpha(220),
          borderRadius: BorderRadius.circular(30), // Curved edges
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
    );
  }
}
