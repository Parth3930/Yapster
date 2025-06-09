import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:yapster/app/modules/stories/controllers/doodle_controller.dart';
import 'package:yapster/app/modules/stories/controllers/text_controller.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';
import 'package:yapster/app/modules/stories/views/create_story_view.dart';
import 'package:yapster/app/data/repositories/story_repository.dart';
import 'package:yapster/app/data/models/story_model.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/home/controllers/stories_home_controller.dart';

class StoriesController extends GetxController {
  // Track if the story creation panel is visible
  final RxBool isStoryPanelVisible = false.obs;

  // Store recent media files
  final RxList<File> recentMedia = <File>[].obs;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();

  // Track loading state
  final RxBool isLoading = false.obs;

  // Track currently selected image
  final Rxn<File> selectedImage = Rxn<File>();

  final Rx<DrawingMode> drawingMode = DrawingMode.none.obs;
  final Rx<Offset> textPosition = const Offset(100, 100).obs;

  // Text elements
  final RxList<TextElement> textElements = <TextElement>[].obs;
  final RxBool isEditingText = false.obs;
  final RxDouble textPositionX = 0.0.obs;
  final RxDouble textPositionY = 0.0.obs;

  // Text controller for editing
  final TextEditingController textEditingController = TextEditingController();

  // Track tap position for text placement
  final Rx<Offset> tapPosition = const Offset(0, 0).obs;

  // Reference to other controllers
  late DoodleController doodleController;
  late TextController textController;
  late StoryRepository storyRepository;
  late SupabaseService supabaseService;

  @override
  void onInit() {
    super.onInit();
    requestPhotoPermission();

    // Get references to other controllers and services
    doodleController = Get.find<DoodleController>();
    textController = Get.find<TextController>();
    storyRepository = Get.find<StoryRepository>();
    supabaseService = Get.find<SupabaseService>();
  }

  // Request photo library permission
  Future<void> requestPhotoPermission() async {
    final status = await Permission.photos.request();
    if (status.isGranted) {
      loadRecentGalleryImages();
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      bool? shouldOpenSettings = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Photo library permission is required to show your recent photos. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
        barrierDismissible: false,
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
    } else {
      Get.snackbar(
        'Permission Required',
        'Please grant photo library access to show recent images',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Load recent images from gallery
  Future<void> loadRecentGalleryImages() async {
    try {
      isLoading.value = true;

      // Check if we have permission
      final status = await Permission.photos.status;
      if (!status.isGranted) {
        // If permission was denied, don't proceed
        return;
      }

      // If we have permission, load the gallery images
      final List<AssetEntity> assets = await PhotoManager.getAssetListRange(
        start: 0,
        end: 5, // Get first 5 images
        type: RequestType.image,
        filterOption: FilterOptionGroup(
          imageOption: const FilterOption(
            sizeConstraint: SizeConstraint(ignoreSize: true),
          ),
        ),
      );

      // Convert assets to files
      final List<File> files = [];
      for (var asset in assets) {
        final file = await asset.file;
        if (file != null) {
          files.add(file);
        }
      }

      recentMedia.assignAll(files);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load recent images: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Toggle the story creation panel
  void toggleStoryPanel() {
    // Navigate to the create story page instead of showing overlay
    Get.toNamed('/create-story');
  }

  // Select an image from the recent media
  void selectImage(File file) {
    selectedImage.value = file;
  }

  // Open image picker to select media
  Future<void> pickMedia() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (image != null) {
        final file = File(image.path);
        // Add to recent media if not already present
        if (!recentMedia.any((element) => element.path == file.path)) {
          recentMedia.insert(0, file);
        }
        selectedImage.value = file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick media: $e');
    }
  }

  // Pick image from gallery
  Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (image != null) {
        final file = File(image.path);
        // Add to recent media if not already present
        if (!recentMedia.any((element) => element.path == file.path)) {
          recentMedia.insert(0, file);
        }
        return file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image: $e');
    }
    return null;
  }

  // Take photo with camera
  Future<File?> takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 90,
      );

      if (photo != null) {
        final file = File(photo.path);
        // Add to recent media
        recentMedia.insert(0, file);
        return file;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to take photo: $e');
    }
    return null;
  }

  /// Post the current story
  Future<void> postStory() async {
    try {
      isLoading.value = true;

      // Get current user
      final user = supabaseService.client.auth.currentUser;
      if (user == null) {
        Get.snackbar('Error', 'You must be logged in to post a story');
        return;
      }

      // Debug print to check user ID
      debugPrint('Creating story for user ID: ${user.id}');
      debugPrint('User email: ${user.email}');
      debugPrint('User metadata: ${user.userMetadata}');

      if (user.id.isEmpty) {
        Get.snackbar('Error', 'Invalid user ID');
        return;
      }

      // Create story model first (without image URL)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final story = StoryModel(
        id: '', // Will be generated by database
        userId: user.id,
        imageUrl: null, // Will be updated after upload
        textItems: textController.textItems.toList(),
        doodlePoints:
            doodleController.drawingPoints
                .map(
                  (drawingPoint) => {
                    'points':
                        drawingPoint.points
                            .map((offset) => {'x': offset.dx, 'y': offset.dy})
                            .toList(),
                    'color': drawingPoint.color.toARGB32(),
                    'stroke_width': drawingPoint.width,
                  },
                )
                .toList(),
        createdAt: now,
        expiresAt: expiresAt,
      );

      // Store the selected image before clearing it
      final imageToUpload = selectedImage.value;

      // Save story to database first (faster response)
      final storyId = await storyRepository.createStory(story);

      if (storyId != null) {
        // Show success message immediately
        Get.snackbar('Success', 'Story posted successfully!');

        // Clear current story data
        selectedImage.value = null;
        textController.textItems.clear();
        textController.selectedTextIndex.value = -1;
        textController.isEditing.value = false;
        doodleController.drawingPoints.clear();
        drawingMode.value = DrawingMode.none;

        // Navigate to home page immediately
        Get.offAllNamed('/home');

        // Refresh the stories home controller to update UI
        if (Get.isRegistered<StoriesHomeController>()) {
          Get.find<StoriesHomeController>().refreshStories();
        }

        // Upload image in background if selected
        if (imageToUpload != null) {
          _uploadImageInBackground(imageToUpload, user.id, storyId);
        }
      } else {
        Get.snackbar('Error', 'Failed to post story');
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to post story: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Upload image in background and update story
  Future<void> _uploadImageInBackground(
    File imageFile,
    String userId,
    String storyId,
  ) async {
    try {
      final imageUrl = await storyRepository.uploadStoryImage(
        imageFile,
        userId,
      );

      if (imageUrl != null && storyId.isNotEmpty) {
        // Update the story with the image URL
        await supabaseService.client
            .from('stories')
            .update({'image_url': imageUrl})
            .eq('id', storyId);

        debugPrint('Story image uploaded and updated successfully');
      }
    } catch (e) {
      debugPrint('Error uploading image in background: $e');
      // Don't show error to user since story was already posted successfully
    }
  }
}
