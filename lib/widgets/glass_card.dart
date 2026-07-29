import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  
  const GlassCard({
    super.key, 
    required this.child, 
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!isDark) {
      // Light Mode: Solid, elevated, crisp card
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14111827), // rgba(17,24,39,0.08)
              blurRadius: 16,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: child,
      );
    }

    // Dark Mode: Luxurious Glassmorphism
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: child,
        ),
      ),
    );
  }
}
