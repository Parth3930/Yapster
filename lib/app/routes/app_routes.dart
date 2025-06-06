// ignore_for_file: constant_identifier_names

part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  static const SPLASH = _Paths.SPLASH;
  static const HOME = _Paths.HOME;
  static const LOGIN = _Paths.LOGIN;
  static const ACCOUNT_USERNAME_SETUP = _Paths.ACCOUNT_USERNAME_SETUP;
  static const ACCOUNT_AVATAR_SETUP = _Paths.ACCOUNT_AVATAR_SETUP;
  static const PROFILE = _Paths.PROFILE;
  static const CHAT = _Paths.CHAT;
  static const CHAT_WINDOW = _Paths.CHAT_WINDOW;
  static const GROUP_CHAT = _Paths.GROUP_CHAT;
  static const EXPLORE = _Paths.EXPLORE;
  static const CREATE = _Paths.CREATE;
  static const EDIT_PROFILE = _Paths.EDIT_PROFILE;
  static const NOTIFICATIONS = _Paths.NOTIFICATIONS;
  static const ERROR = _Paths.ERROR;
  static const FOLLOWERS = _Paths.FOLLOWERS;
  static const FOLLOWING = _Paths.FOLLOWING;
  static const CREATE_STORY = _Paths.CREATE_STORY;
  static const VIEW_STORIES = _Paths.VIEW_STORIES;
}

abstract class _Paths {
  _Paths._();
  static const SPLASH = '/splash';
  static const HOME = '/home';
  static const LOGIN = '/login';
  static const ACCOUNT_USERNAME_SETUP = '/account-setup-username';
  static const ACCOUNT_AVATAR_SETUP = '/account-setup-avatar';
  static const PROFILE = '/profile';
  static const CHAT = '/chat';
  static const CHAT_WINDOW = '/chat/window';
  static const GROUP_CHAT = '/group-chat';
  static const EXPLORE = '/explore';
  static const CREATE = '/create';
  static const EDIT_PROFILE = '/edit-profile';
  static const NOTIFICATIONS = '/notifications';
  static const ERROR = '/error';
  static const FOLLOWERS = '/followers';
  static const FOLLOWING = '/following';
  static const CREATE_STORY = '/create-story';
  static const VIEW_STORIES = '/view-stories';
}
