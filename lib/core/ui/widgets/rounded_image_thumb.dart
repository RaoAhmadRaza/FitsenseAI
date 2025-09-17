import 'package:flutter/material.dart';
import '../design_tokens.dart';

class RoundedImageThumb extends StatelessWidget {
  final String imagePath;
  final double? size;
  final BorderRadius? borderRadius;

  const RoundedImageThumb({
    super.key,
    required this.imagePath,
    this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final dim = size ?? AppLayout.thumbnailSize;
    return SizedBox(
      height: dim,
      width: dim,
      child: ClipRRect(
        borderRadius: borderRadius ?? Radii.card,
        child: Image.asset(imagePath, fit: BoxFit.cover),
      ),
    );
  }
}
