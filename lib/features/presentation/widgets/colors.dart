import 'package:flutter/material.dart';

/// Centralized app color palette.
///
/// Only use these constants for colors across the app.
/// Avoid using `Color(...)`, `Colors.*`, or hex literals directly in widgets.
class AppColors {
  // Base / Background
  // Dark surfaces
  static const Color white = Color(
    0xFF0D0D0D,
  ); // Dark primary background (renamed value, kept key for compatibility)
  static const Color lightGray = Color(
    0xFF1C1C1E,
  ); // Dark secondary surface (cards, sections)

  // Text
  static const Color primaryBlack = Color(0xFFE5E5EA); // Primary text on dark
  static const Color secondaryGray = Color(
    0xFF8E8E93,
  ); // Secondary text on dark (hints, descriptions)

  // Accent Colors (keep usage focused for an iOS feel)
  static const Color fitnessBlue = Color(
    0xFF0A84FF,
  ); // iOS dark blue — actions, buttons, links
  static const Color healthGreen = Color(
    0xFF32D74B,
  ); // iOS dark green — success, progress, completed
  static const Color energyOrange = Color(
    0xFFFF9F0A,
  ); // iOS dark orange — warnings, calories, active highlights
  static const Color vibrantRed = Color.fromARGB(
    255,
    205,
    60,
    52,
  ); // iOS dark red — errors, alerts, stop

  // Optional Pastels (for charts / soft UI areas)
  // Muted accents for dark charts / soft UI areas
  static const Color pastelBlue = Color(0xFF0F6FCF);
  static const Color pastelGreen = Color(0xFF0B8A44);
  static const Color pastelPurple = Color(0xFF6E3FA5);

  const AppColors._();
}
