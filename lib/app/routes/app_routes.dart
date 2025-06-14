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
  static const IMAGE_EDIT = _Paths.IMAGE_EDIT;
  static const VIDEO_EDIT = _Paths.VIDEO_EDIT;
  static const CREATE_POST = _Paths.CREATE_POST;
  static const VIDEOS = _Paths.VIDEOS;
  static const EDIT_PROFILE = _Paths.EDIT_PROFILE;
  static const NOTIFICATIONS = _Paths.NOTIFICATIONS;
  static const ERROR = _Paths.ERROR;
  static const FOLLOWERS = _Paths.FOLLOWERS;
  static const FOLLOWING = _Paths.FOLLOWING;
  static const VIEW_STORIES = _Paths.VIEW_STORIES;
  static const POST_DETAIL = _Paths.POST_DETAIL;
  static const STORY_EDIT = _Paths.STORY_EDIT;
  static const SETTINGS = _Paths.SETTINGS;
  static const SETTINGS_LIKES = _Paths.SETTINGS_LIKES;
  static const SETTINGS_COMMENTS = _Paths.SETTINGS_COMMENTS;
  static const SETTINGS_FAVOURITES = _Paths.SETTINGS_FAVOURITES;
  static const SETTINGS_PRIVACY = _Paths.SETTINGS_PRIVACY;
  static const SETTINGS_ABOUT = _Paths.SETTINGS_ABOUT;
  static const SETTINGS_NOTIFICATIONS = _Paths.SETTINGS_NOTIFICATIONS;
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
  static const IMAGE_EDIT = '/image-edit';
  static const VIDEO_EDIT = '/video-edit';
  static const CREATE_POST = '/create-post';
  static const VIDEOS = '/videos';
  static const EDIT_PROFILE = '/edit-profile';
  static const NOTIFICATIONS = '/notifications';
  static const ERROR = '/error';
  static const FOLLOWERS = '/followers';
  static const FOLLOWING = '/following';
  static const VIEW_STORIES = '/view-stories';
  static const POST_DETAIL = '/post';
  static const STORY_EDIT = '/story-edit';
  static const SETTINGS = '/settings';
  static const SETTINGS_LIKES = '/settings/likes';
  static const SETTINGS_COMMENTS = '/settings/comments';
  static const SETTINGS_FAVOURITES = '/settings/favourites';
  static const SETTINGS_PRIVACY = '/settings/privacy';
  static const SETTINGS_ABOUT = '/settings/about';
  static const SETTINGS_NOTIFICATIONS = '/settings/notifications';
}
