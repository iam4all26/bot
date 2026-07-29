import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  
  const GlassCard({
    super.key, 
    required this.child, 
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
