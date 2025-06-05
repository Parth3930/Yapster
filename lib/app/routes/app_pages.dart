// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';
import 'package:yapster/app/modules/account_setup/bindings/account_setup_binding.dart';
import 'package:yapster/app/modules/account_setup/views/account_avatar.dart';
import 'package:yapster/app/modules/account_setup/views/account_username_view.dart';
import 'package:yapster/app/modules/chat/bindings/chat_binding.dart';
import 'package:yapster/app/modules/chat/views/chat_view.dart';
import 'package:yapster/app/modules/chat/views/chat_window_view.dart';
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
import 'package:yapster/app/modules/profile/views/follow_list_view.dart';
import 'package:yapster/app/modules/profile/views/profile_view.dart';

import 'package:yapster/app/core/models/follow_type.dart';
import 'package:yapster/app/core/utils/supabase_service.dart';
import 'package:yapster/app/modules/stories/views/create_story_view.dart';
import 'package:yapster/app/modules/stories/views/story_viewer_view.dart';
import 'package:yapster/app/modules/stories/bindings/stories_binding.dart';
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
      page: () => SplashView(),
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
      name: _Paths.PROFILE, // Matches /profile
      page: () => ProfileView(), // For current user
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
      name: '${_Paths.PROFILE}/:id', // Matches /profile/:id
      page: () {
        final String? userId = Get.parameters['id'];
        return ProfileView(userId: userId); // For other users
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
      name: _Paths.CHAT_WINDOW,
      page: () => const ChatWindowView(),
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
    GetPage(
      name: _Paths.FOLLOWERS,
      page: () {
        final supabaseService = Get.find<SupabaseService>();
        final String? argUserId = Get.arguments?['userId'] as String?;
        final String userId =
            argUserId ?? supabaseService.currentUser.value?.id ?? '';
        return FollowListView(
          userId: userId,
          type: FollowType.followers,
          title: 'Followers',
        );
      },
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
    GetPage(
      name: _Paths.FOLLOWING,
      page: () {
        final supabaseService = Get.find<SupabaseService>();
        final String? argUserId = Get.arguments?['userId'] as String?;
        final String userId =
            argUserId ?? supabaseService.currentUser.value?.id ?? '';
        return FollowListView(
          userId: userId,
          type: FollowType.following,
          title: 'Following',
        );
      },
      binding: ProfileBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ),
    // Create story page
    GetPage(
      name: _Paths.CREATE_STORY,
      page: () => CreateStoryView(),
      binding: StoriesBinding(),
      transition: Transition.leftToRight,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: true,
      opaque: true,
      preventDuplicates: true,
      popGesture: true,
    ),
    // View stories page
    GetPage(
      name: _Paths.VIEW_STORIES,
      page: () => const StoryViewerView(),
      binding: StoriesBinding(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      fullscreenDialog: true,
      opaque: true,
      preventDuplicates: true,
      popGesture: true,
    ),
  ];
}
