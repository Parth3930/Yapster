import 'package:get/get.dart';
import 'package:yapster/app/modules/account_setup/bindings/account_setup_binding.dart';
import 'package:yapster/app/modules/account_setup/views/account_avatar.dart';
import 'package:yapster/app/modules/account_setup/views/account_username_view.dart';
import 'package:yapster/app/modules/chat/bindings/chat_binding.dart';
import 'package:yapster/app/modules/chat/views/chat_view.dart';
import 'package:yapster/app/modules/chat/views/chat_detail_view.dart';
import 'package:yapster/app/modules/create/bindings/create_binding.dart';
import 'package:yapster/app/modules/create/views/create_view.dart';
import 'package:yapster/app/modules/error/bindings/error_binding.dart';
import 'package:yapster/app/modules/error/views/error_view.dart';
import 'package:yapster/app/modules/explore/bindings/explore_binding.dart';
import 'package:yapster/app/modules/explore/views/explore_view.dart';
import 'package:yapster/app/modules/notifications/bindings/notifications_binding.dart';
import 'package:yapster/app/modules/notifications/views/notifications_view.dart';
import 'package:yapster/app/modules/profile/bindings/profile_binding.dart';
import 'package:yapster/app/modules/profile/views/edit_profile_view.dart';
import 'package:yapster/app/modules/profile/views/profile_view.dart';
import 'package:yapster/app/modules/profile/views/user_profile_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'package:flutter/material.dart' show Curves;

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
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.LOGIN,
      page: () => const LoginView(),
      binding: LoginBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.ACCOUNT_USERNAME_SETUP,
      page: () => const AccountUsernameSetupView(),
      binding: AccountSetupBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.ACCOUNT_AVATAR_SETUP,
      page: () => const AccountAvatarSetupView(),
      binding: AccountSetupBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => const ProfileView(),
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: '${_Paths.PROFILE}/:id',
      page: () {
        final args = Get.arguments;
        return UserProfileView(
          userData: args['userData'],
          posts: args['posts'],
        );
      },
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: _Paths.CHAT,
      page: () => const ChatView(),
      binding: ChatBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.CHAT_DETAIL,
      page: () => const ChatDetailView(),
      binding: ChatBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: _Paths.EXPLORE,
      page: () => const ExploreView(),
      binding: ExploreBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.CREATE,
      page: () => const CreateView(),
      binding: CreateBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.EDIT_PROFILE,
      page: () => const EditProfileView(),
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.NOTIFICATIONS,
      page: () => const NotificationsView(),
      binding: NotificationsBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: false,
      opaque: true,
      preventDuplicates: true,
      popGesture: false,
    ),
    GetPage(
      name: _Paths.ERROR,
      page: () => const ErrorView(),
      binding: ErrorBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
  ];
}
