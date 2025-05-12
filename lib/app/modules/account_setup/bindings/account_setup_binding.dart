import 'package:get/get.dart';
import 'package:yapster/app/modules/account_setup/controllers/account_setup_controller.dart';

class AccountSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountSetupController>(() => AccountSetupController());
  }
}
