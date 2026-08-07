import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final bool hasBubbles; // Kept to avoid breaking existing usages, but intentionally ignored
  
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Completely transparent!
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.08) 
              : Colors.black.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
