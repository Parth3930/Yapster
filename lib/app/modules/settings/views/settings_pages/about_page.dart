import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
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
          'About',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Yapster',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),

            SizedBox(height: 40),

            Text(
              'About Yapster',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),

            Text(
              'Yapster is a modern social media platform that allows you to connect with friends, share moments, and discover new content. Built with Flutter and powered by Supabase.',
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ),

            SizedBox(height: 30),

            Text(
              'Features',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),

            _FeatureItem(
              icon: Icons.photo_camera,
              title: 'Share Photos & Videos',
              description: 'Capture and share your favorite moments',
            ),

            _FeatureItem(
              icon: Icons.chat_bubble_outline,
              title: 'Real-time Chat',
              description: 'Connect with friends through instant messaging',
            ),

            _FeatureItem(
              icon: Icons.explore_outlined,
              title: 'Discover Content',
              description: 'Explore trending posts and discover new creators',
            ),

            _FeatureItem(
              icon: Icons.favorite_outline,
              title: 'Engage with Posts',
              description: 'Like, comment, and save your favorite content',
            ),

            SizedBox(height: 30),

            Text(
              'Contact',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 16),

            Text(
              'For support or feedback, please contact us at:\nsupport@yapster.com',
              style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ),

            SizedBox(height: 40),

            Center(
              child: Text(
                '© 2024 Yapster. All rights reserved.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
