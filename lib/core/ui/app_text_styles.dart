import 'package:flutter/material.dart';

/// Centralized text styles. Prefer using these instead of ad-hoc TextStyle.
class AppText {
  static const String primaryFont = 'Sora';

  static const TextStyle title16Bold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle title18Semi = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle metricValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle metricLabel = TextStyle(
    fontSize: 12,
    fontFamily: primaryFont,
    color: Colors.grey,
  );

  static const TextStyle subtitleGray12 = TextStyle(
    fontSize: 12,
    fontFamily: primaryFont,
    color: Colors.grey,
  );

  static const TextStyle body14 = TextStyle(
    fontSize: 14,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle body14Gray = TextStyle(
    fontSize: 14,
    fontFamily: primaryFont,
    color: Colors.grey,
  );

  static const TextStyle hero33 = TextStyle(
    fontSize: 33,
    fontWeight: FontWeight.bold,
    letterSpacing: -1,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle greeting20 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -1,
    fontFamily: primaryFont,
    color: Colors.black,
  );

  static const TextStyle greetingLabel20 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    letterSpacing: -1,
    fontFamily: primaryFont,
    color: Colors.grey,
  );

  static const TextStyle button14BoldWhite = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    fontFamily: primaryFont,
    color: Colors.white,
  );

  static const TextStyle smallLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    fontFamily: primaryFont,
    color: Colors.black,
  );
}
