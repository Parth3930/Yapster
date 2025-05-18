import 'package:flutter/material.dart';

/// Constants used in the profile module
class ProfileConstants {
  // Colors
  static const Color primaryBlue = Color(0xff0060FF);
  static const Color darkBackground = Color(0xff111111);
  static const Color textGrey = Color(0xff727272);
  static const Color textLightGrey = Color(0xffC1C1C1);

  // Text styles
  static const TextStyle sectionTitleStyle = TextStyle(
    color: textLightGrey,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle hintTextStyle = TextStyle(
    fontSize: 12,
    color: textGrey,
  );

  // Dimensions
  static const double defaultPadding = 20.0;
  static const double defaultSpacing = 20.0;
  static const double smallSpacing = 10.0;
  static const double avatarRadius = 50.0;

  // Messages
  static const String usernameRestrictionMessage =
      "Username can only be changed once every 14 days";
  static const String tapToChangeAvatarMessage = "Tap to change profile image";
  static const String profileInfoTitle = "Profile Information";
}
