import 'package:flutter/material.dart';

/// Spacing constants (vertical & horizontal)
class Gaps {
  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h30 = SizedBox(height: 30);
  static const h40 = SizedBox(height: 40);

  static const w4 = SizedBox(width: 4);
  static const w8 = SizedBox(width: 8);
  static const w10 = SizedBox(width: 10);
  static const w12 = SizedBox(width: 12);
  static const w16 = SizedBox(width: 16);
  static const w24 = SizedBox(width: 24);
}

/// Layout dimensions used across home UI
class AppLayout {
  static const double cardWidth = 370;
  static const double ongoingCardHeight = 250;
  static const double exerciseCardHeight = 70;
  static const double searchBarHeight = 50;
  static const double thumbnailSize = 70;
  static const double avatarRadius = 22;
  static const double exerciseImageSize = 50;
}

/// Common border radii
class Radii {
  static const BorderRadius card = BorderRadius.all(Radius.circular(20));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(70));
}

/// Shadows (can expand later)
class Shadows {
  static final soft = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Reusable decorations
class AppDecorations {
  static BoxDecoration card({Color color = Colors.white}) => BoxDecoration(
    color: color,
    borderRadius: Radii.card,
    border: Border.all(color: Colors.grey.shade300),
  );

  static BoxDecoration subtleSurface() => BoxDecoration(
    color: Colors.blueGrey.withOpacity(0.1),
    borderRadius: Radii.card,
    border: Border.all(color: Colors.grey.shade300),
  );

  static BoxDecoration searchBar() => BoxDecoration(
    color: Colors.white,
    borderRadius: Radii.pill,
    border: Border.all(color: Colors.grey.shade300),
  );
}
