import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:yapster/app/modules/stories/controllers/doodle_controller.dart';
import 'package:yapster/app/modules/stories/controllers/text_editor_controller.dart';
import 'package:yapster/app/modules/stories/models/text_element.dart';
import 'package:yapster/app/modules/stories/views/create_story_view.dart';

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
  final Rxn<TextElement> editingTextElement = Rxn<TextElement>();
  final RxBool isEditingText = false.obs;
  final RxDouble textPositionX = 0.0.obs;
  final RxDouble textPositionY = 0.0.obs;

  // Text controller for editing
  final TextEditingController textEditingController = TextEditingController();

  // Reference to other controllers
  late TextEditorController textEditorController;
  late DoodleController doodleController;

  @override
  void onInit() {
    super.onInit();
    requestPhotoPermission();

    // Get references to other controllers
    textEditorController = Get.find<TextEditorController>();
    doodleController = Get.find<DoodleController>();
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
    isStoryPanelVisible.value = !isStoryPanelVisible.value;
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

  // Start text editing mode
  void startTextEditing() {
    try {
      isEditingText.value = true;
      textEditingController.clear();

      final newElement = TextElement(
        text: 'Tap to edit',
        position: const Offset(100, 100),
        color: textEditorController.textColor.value,
        backgroundColor:
            textEditorController.backgroundColor.value ?? Colors.transparent,
        size: textEditorController.textSize.value,
        fontWeight:
            textEditorController.isBold.value
                ? FontWeight.bold
                : FontWeight.normal,
        isEditing: true,
      );

      editingTextElement.value = newElement;
      textElements.add(newElement);
    } catch (e) {
      Get.snackbar('Error', 'Failed to start text editing: $e');
    }
  }

  // Add a new text element
  void addTextElement(TextElement element) {
    try {
      if (element.text.trim().isEmpty) return;

      textElements.add(element);
      isEditingText.value = false;
      textEditingController.clear();
    } catch (e) {
      Get.snackbar('Error', 'Failed to add text element: $e');
    }
  }

  // Update an existing text element
  void updateTextElement(
    TextElement element, {
    String? text,
    Color? color,
    Color? backgroundColor,
    double? size,
    bool? isBold,
    bool? isEditing,
  }) {
    try {
      final index = textElements.indexWhere((e) => e == element);
      if (index != -1) {
        final updatedElement = element.copyWith(
          text: text ?? element.text,
          color: color ?? element.color,
          backgroundColor: backgroundColor ?? element.backgroundColor,
          size: size ?? element.size,
          fontWeight:
              isBold != null
                  ? (isBold ? FontWeight.bold : FontWeight.normal)
                  : element.fontWeight,
          isEditing: isEditing ?? element.isEditing,
        );

        textElements[index] = updatedElement;

        if (editingTextElement.value == element) {
          editingTextElement.value = updatedElement;
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update text element: $e');
    }
  }

  // Edit an existing text element
  void editTextElement(TextElement element) {
    try {
      textEditingController.text = element.text;

      // Update text editor controller state with element properties
      textEditorController.textColor.value = element.color;
      textEditorController.backgroundColor.value = element.backgroundColor;
      textEditorController.textSize.value = element.size;
      textEditorController.isBold.value = element.fontWeight == FontWeight.bold;
      textPosition.value = element.position;

      // Set as current editing element
      editingTextElement.value = element;
      isEditingText.value = true;

      // Move to top of stack when selected
      textElements.remove(element);
      textElements.add(element.copyWith(isEditing: true));
    } catch (e) {
      Get.snackbar('Error', 'Failed to edit text element: $e');
    }
  }
}
