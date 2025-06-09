import 'package:get/get.dart';
import 'package:yapster/app/data/repositories/notification_repository.dart';
import '../controllers/notifications_controller.dart';

class NotificationsBinding extends Bindings {
  @override
  void dependencies() {
    // Register the notification repository if not already registered
    if (!Get.isRegistered<NotificationRepository>()) {
      Get.lazyPut<NotificationRepository>(
        () => NotificationRepository(),
        fenix: true,
      );
    }

    Get.lazyPut<NotificationsController>(() => NotificationsController());
  }
}
