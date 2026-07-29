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

    Widget cardContent = child;

    // Premium internal bubbles for highlighting specific cards
    if (hasBubbles) {
      cardContent = Stack(
        children: [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.kainuwaPurple.withOpacity(isDark ? 0.15 : 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.kainuwaGold.withOpacity(isDark ? 0.10 : 0.04),
              ),
            ),
          ),
          child,
        ],
      );
    }

    if (!isDark) {
      // Light Mode: Solid card with balanced 90/10 Gradient Border
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
            stops: [0.0, 0.9], // Dominantly Purple
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1.5),
            child: Container(
              padding: padding,
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
          padding: padding,
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
