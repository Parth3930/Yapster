import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:yapster/app/core/utils/banner_utils.dart';
import 'package:yapster/app/data/providers/account_data_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileBannerWidget extends StatefulWidget {
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
  State<ProfileBannerWidget> createState() => _ProfileBannerWidgetState();
}

class _ProfileBannerWidgetState extends State<ProfileBannerWidget> {
  XFile? _currentImage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.selectedImage;
    if (_currentImage != null) {
      _uploadBanner(_currentImage!);
    }
  }

  @override
  void didUpdateWidget(ProfileBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedImage != oldWidget.selectedImage &&
        widget.selectedImage != null) {
      setState(() {
        _currentImage = widget.selectedImage;
        _uploadBanner(_currentImage!);
      });
    }
  }

  Future<void> _uploadBanner(XFile imageFile) async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      await BannerUtils.uploadBannerImage(imageFile);
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', 'Failed to upload banner: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountDataProvider = Get.find<AccountDataProvider>();

    return GestureDetector(
      onTap: widget.onTap,
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
            if (_currentImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child:
                    _currentImage!.path.startsWith('http')
                        ? Image.network(
                          _currentImage!.path,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Center(child: Icon(Icons.error)),
                            );
                          },
                        )
                        : Image.file(
                          File(_currentImage!.path),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Center(child: Icon(Icons.error)),
                            );
                          },
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
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/update_image.png',
                      width: 40,
                      height: 40,
                    ),
                  ],
                ),
              ),
            ),
            // Back button
            if (widget.showBackButton)
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
