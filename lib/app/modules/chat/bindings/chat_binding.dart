import 'package:get/get.dart';
import 'package:yapster/app/modules/chat/controllers/chat_controller.dart';
import 'package:yapster/app/modules/chat/services/chat_message_service.dart';
import 'package:yapster/app/modules/chat/services/chat_subscription_service.dart';
import 'package:yapster/app/modules/chat/services/chat_search_service.dart';
import 'package:yapster/app/modules/chat/services/chat_cleanup_service.dart';
import 'package:yapster/app/core/utils/chat_cache_service.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    // Core services
    Get.lazyPut(() => ChatCacheService());

    // Chat-specific services
    Get.lazyPut(() => ChatMessageService());
    Get.lazyPut(() => ChatSubscriptionService());
    Get.lazyPut(() => ChatSearchService());
    Get.lazyPut(() => ChatCleanupService());

    // Main controller
    Get.lazyPut<ChatController>(() => ChatController());
  }
}
