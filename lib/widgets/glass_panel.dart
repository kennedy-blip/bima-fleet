import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 22});
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .25)),
        ),
        child: child,
      ),
    ),
  );
}