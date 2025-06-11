import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ImageEditView extends StatefulWidget {
  const ImageEditView({super.key});

  @override
  State<ImageEditView> createState() => _ImageEditViewState();
}

class _ImageEditViewState extends State<ImageEditView> {
  late File imageFile;
  late double aspectRatio;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    // Get arguments
    final Map<String, dynamic> args = Get.arguments;
    imageFile = args['imageFile'] as File;
    aspectRatio = args['aspectRatio'] as double? ?? 4 / 5; // Default to 4:5

    // Start cropping immediately
    _cropImage();
  }

  Future<void> _cropImage() async {
    setState(() {
      isLoading = true;
    });

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: CropAspectRatio(ratioX: 4, ratioY: 5),
        compressQuality: 100, // Maximum quality
        compressFormat:
            ImageCompressFormat.jpg, // Use JPEG for better quality/size balance
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            statusBarColor: Colors.black,
          ),
          IOSUiSettings(
            title: 'Edit Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          imageFile = File(croppedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      Get.snackbar('Error', 'Failed to crop image');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Edit Image', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          TextButton(
            onPressed:
                isLoading
                    ? null
                    : () {
                      // Return the edited image
                      Get.back(result: {'editedImage': imageFile});
                    },
            child: const Text(
              'Next',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Image.file(imageFile, fit: BoxFit.contain),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const FaIcon(
                            FontAwesomeIcons.crop,
                            color: Colors.white,
                          ),
                          onPressed: _cropImage,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
