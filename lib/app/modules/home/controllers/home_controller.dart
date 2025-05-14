import 'package:get/get.dart';
import '../../../core/utils/supabase_service.dart';

class HomeController extends GetxController {
  final supabaseService = Get.find<SupabaseService>();
  final RxString username = ''.obs;
}
