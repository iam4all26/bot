import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnimatedCryptoBackground extends StatefulWidget {
  final Widget child;
  const AnimatedCryptoBackground({super.key, required this.child});

  @override
  State<AnimatedCryptoBackground> createState() => _AnimatedCryptoBackgroundState();
}

class _AnimatedCryptoBackgroundState extends State<AnimatedCryptoBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -100 + (_controller.value * 40),
                    left: -50,
                    child: Container(
                      width: 350, height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: AppTheme.kainuwaPurple.withOpacity(isDark ? 0.15 : 0.08)
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -150 - (_controller.value * 40),
                    right: -100,
                    child: Container(
                      width: 400, height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, 
                        color: AppTheme.kainuwaGold.withOpacity(isDark ? 0.12 : 0.06)
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(color: Colors.transparent),
          ),
          widget.child,
        ],
      ),
    );
  }
}
