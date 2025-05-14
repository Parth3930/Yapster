import 'package:get/get.dart';
import 'package:yapster/app/modules/account_setup/bindings/account_setup_binding.dart';
import 'package:yapster/app/modules/account_setup/views/account_avatar.dart';
import 'package:yapster/app/modules/account_setup/views/account_username_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
    ),
    GetPage(
      name: _Paths.ACCOUNT_USERNAME_SETUP,
      page: () => const AccountUsernameSetupView(),
      binding: AccountSetupBinding(),
    ),
    GetPage(
      name: _Paths.ACCOUNT_AVATAR_SETUP,
      page: () => const AccountAvatarSetupView(),
      binding: AccountSetupBinding(),
    ),
  ];
}
