import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileBannerWidget extends StatelessWidget {
  final XFile? selectedImage;
  final VoidCallback onTap;
  final bool isLoaded;
  final bool showBackButton;

  const ProfileBannerWidget({
    super.key,
    required this.selectedImage,
    required this.onTap,
    this.isLoaded = false,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Stack(
          children: [
            if (selectedImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: Image.network(
                  selectedImage!.path,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (accountDataProvider.banner.value.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: accountDataProvider.banner.value,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            // Edit overlay
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Change Banner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Back button
            if (showBackButton)
              Positioned(
                top: 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
