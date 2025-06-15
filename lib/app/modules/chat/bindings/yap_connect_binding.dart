import 'package:get/get.dart';
import '../pages/yap_connect_page.dart';

class YapConnectBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<YapConnectPageController>(() => YapConnectPageController());
  }
}
