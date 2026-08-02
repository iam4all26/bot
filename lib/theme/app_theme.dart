import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color kainuwaPurple = Color(0xFF7C3AED);
  static const Color kainuwaGold = Color(0xFFF59E0B);
  
  // Semantic Helpers
  static Color success(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFF10B981) : const Color(0xFF34D399);
  static Color danger(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFEF4444) : const Color(0xFFF87171);
  static Color warning(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24);
  static Color info(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFF3B82F6) : const Color(0xFF60A5FA);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF7C3AED),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFFF59E0B),
        surface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0xFFF9FAFB), // Input fill
        onSurface: Color(0xFF111827), // Primary Text
        onSurfaceVariant: Color(0xFF6B7280), // Secondary Text
        outline: Color(0xFFE5E7EB), // Borders
        outlineVariant: Color(0xFFECEFF3), // Dividers
      ),
      // Restored Space Grotesk globally for Light Mode
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF111827)),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF8B5CF6),
      scaffoldBackgroundColor: const Color(0xFF0D0B18),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8B5CF6),
        secondary: Color(0xFFFBBF24),
        surface: Color(0xFF1A1B24), // Cards
        surfaceContainerHighest: Color(0xFF1D1F29), // Input fill
        onSurface: Color(0xFFFFFFFF), // Primary text
        onSurfaceVariant: Color(0xFFB7BBCB), // Secondary text
        outline: Color(0xFF2A2D38), // Borders
        outlineVariant: Color(0xFF313340), // Dividers
      ),
      // Restored Space Grotesk globally for Dark Mode
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFFFFFFFF)),
      ),
    );
  }
}
