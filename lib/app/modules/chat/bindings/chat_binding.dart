import 'package:get/get.dart';
import '../controllers/chat_controller.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    // Ensure ChatCacheService is registered
    if (!Get.isRegistered<ChatCacheService>()) {
      final service = ChatCacheService();
      Get.put<ChatCacheService>(service);
      service.init(); // Initialize asynchronously
    }
    
    // Register the chat controller
    Get.lazyPut<ChatController>(() => ChatController());
  }
}