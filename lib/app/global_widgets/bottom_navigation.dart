import 'package:flutter/material.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation>
    with TickerProviderStateMixin {
  // Controllers for each icon's animation
  late List<AnimationController> _controllers;
  late List<Animation> _animations;

  // Special controller for the add button's 360 rotation
  late AnimationController _addButtonController;
  late Animation<double> _addButtonAnimation;

  // Ripple animation for explore icon
  late AnimationController _exploreRippleController;
  late Animation<double> _exploreRippleAnimation;

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
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    // Create different animations for each icon (excluding home)
    _animations = [
      // Placeholder for explore (not used directly)
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controllers[0], curve: Curves.easeInOut),
      ),

      // Chat icon - improved shake with restricted rotation values
      TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2), weight: 20),
        TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.2), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.1), weight: 30),
        TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 20),
      ]).animate(
        CurvedAnimation(parent: _controllers[1], curve: Curves.easeInOut),
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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Simple scale animation for home icon
    _homeScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _homeController, curve: Curves.easeInOut),
    );

    // Initialize special controller for add button
    _addButtonController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Simple rotation animation for add button
    _addButtonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _addButtonController, curve: Curves.easeOutBack),
    );

    // Initialize explore ripple controller
    _exploreRippleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Create ripple animation for explore icon
    _exploreRippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _exploreRippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers) {
      controller.dispose();
    }
    _homeController.dispose();
    _addButtonController.dispose();
    _exploreRippleController.dispose();
    super.dispose();
  }

  // Build the home icon with simple scale animation
  Widget _buildHomeIcon() {
    return GestureDetector(
      onTap: () {
        _homeController.reset();
        _homeController.forward();
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _homeScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _homeScaleAnimation.value,
              child: child,
            );
          },
          child: Image.asset('assets/icons/home.png', width: 28, height: 28),
        ),
      ),
    );
  }

  // Build the explore icon with fixed animation
  Widget _buildExploreIcon() {
    return GestureDetector(
      onTap: () {
        _exploreRippleController.reset();
        _exploreRippleController.forward();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Base icon
          Image.asset('assets/icons/explore.png', width: 25, height: 25),

          // Ripple effect - fixed to be invisible at start
          AnimatedBuilder(
            animation: _exploreRippleAnimation,
            builder: (context, child) {
              // Only show container when animation is active
              if (_exploreRippleAnimation.value == 0) {
                return SizedBox.shrink();
              }

              return Opacity(
                opacity: (1.0 - _exploreRippleAnimation.value) * 0.8,
                child: Transform.scale(
                  scale: 1.0 + _exploreRippleAnimation.value,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white70,
                        width: 2.0 * (1.0 - _exploreRippleAnimation.value),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Rotating compass needle effect - fixed to be invisible at start
          AnimatedBuilder(
            animation: _exploreRippleAnimation,
            builder: (context, child) {
              // Only show needle when animation is active
              if (_exploreRippleAnimation.value == 0) {
                return SizedBox.shrink();
              }

              return Transform.rotate(
                angle: _exploreRippleAnimation.value * 2.0 * 3.14159,
                child: Opacity(
                  opacity: (1.0 - _exploreRippleAnimation.value) * 0.7,
                  child: Container(
                    width: 2,
                    height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Build the chat icon with improved shake animation
  Widget _buildChatIcon() {
    return GestureDetector(
      onTap: () {
        _controllers[1].reset();
        _controllers[1].forward();
      },
      child: AnimatedBuilder(
        animation: _animations[1],
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + (_animations[1].value.abs() * 0.15),
            child: Transform.rotate(angle: _animations[1].value, child: child),
          );
        },
        child: Image.asset('assets/icons/chat.png', width: 25, height: 25),
      ),
    );
  }

  // Build the profile icon with improved squeeze animation
  Widget _buildProfileIcon() {
    return GestureDetector(
      onTap: () {
        _controllers[2].reset();
        _controllers[2].forward();
      },
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
        child: Image.asset('assets/icons/profile.png', width: 25, height: 25),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.transparent,
      child: SizedBox(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildHomeIcon(),
            _buildExploreIcon(),
            // Special handling for add button with improved animation
            GestureDetector(
              onTap: () {
                _addButtonController.reset();
                _addButtonController.forward();
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xff101010),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _addButtonAnimation,
                  builder: (context, child) {
                    // Convert normalized value to full rotation
                    return Transform.rotate(
                      angle: _addButtonAnimation.value * 2 * 3.14159,
                      child: Transform.scale(
                        scale: 1.0 + (_addButtonAnimation.value * 0.2),
                        child: child,
                      ),
                    );
                  },
                  child: Icon(Icons.add, size: 30, color: Colors.white),
                ),
              ),
            ),
            _buildChatIcon(),
            _buildProfileIcon(),
          ],
        ),
      ),
    );
  }
}
