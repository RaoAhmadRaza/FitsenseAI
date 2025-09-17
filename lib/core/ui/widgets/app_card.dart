import 'package:flutter/material.dart';
import '../design_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? width;
  final GestureTapCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: width ?? AppLayout.cardWidth,
      padding: padding,
      decoration: AppDecorations.card(color: color ?? Colors.white),
      child: child,
    );
    if (onTap != null) {
      return InkWell(borderRadius: Radii.card, onTap: onTap, child: content);
    }
    return content;
  }
}
