import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool hasBubbles;
  
  const GlassCard({
    super.key, 
    required this.child, 
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 24,
    this.hasBubbles = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget cardContent;

    if (hasBubbles) {
      cardContent = Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.kainuwaPurple.withOpacity(isDark ? 0.3 : 0.12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.kainuwaGold.withOpacity(isDark ? 0.2 : 0.1),
                ),
              ),
            ),
          ),
          // FIX: Removing Positioned.fill so the Stack takes the height of the child!
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      );
    } else {
      cardContent = Padding(
        padding: padding,
        child: child,
      );
    }

    if (!isDark) {
      // Light Mode: Solid card with beautiful, natural Gradient Border
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000), 
              blurRadius: 20,
              offset: Offset(0, 8),
            )
          ],
          gradient: const LinearGradient(
            colors: [AppTheme.kainuwaPurple, AppTheme.kainuwaGold],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1.5),
            child: Container(
              color: theme.colorScheme.surface,
              child: cardContent,
            ),
          ),
        ),
      );
    }

    // Dark Mode: Luxurious Glassmorphism
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: cardContent,
        ),
      ),
    );
  }
}
