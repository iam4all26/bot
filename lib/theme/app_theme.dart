import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color kainuwaPurple = Color(0xFF7C3AED);
  static const Color kainuwaGold = Color(0xFFF59E0B);
  
  // Semantic Helpers: Adapts for perfect contrast in both modes
  static Color success(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFF059669) : const Color(0xFF00E676); 
  static Color danger(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFDC2626) : const Color(0xFFFF0000); 
  static Color warning(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFFD97706) : const Color(0xFFFBBF24);
  static Color info(BuildContext context) => Theme.of(context).brightness == Brightness.light ? const Color(0xFF2563EB) : const Color(0xFF60A5FA);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF7C3AED),
      // Softer, premium cool-gray background to reduce eye strain
      scaffoldBackgroundColor: const Color(0xFFEEF2F6),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF7C3AED),
        secondary: Color(0xFFF59E0B),
        surface: Color(0xFFFFFFFF),
        surfaceContainerHighest: Color(0xFFE2E8F0),
        onSurface: Color(0xFF0F172A),
        onSurfaceVariant: Color(0xFF475569), // Darker gray for vastly improved readability
        outline: Color(0xFFCBD5E1),
        outlineVariant: Color(0xFFE2E8F0),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
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
        surface: Color(0xFF1A1B24),
        surfaceContainerHighest: Color(0xFF1D1F29),
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFB7BBCB),
        outline: Color(0xFF2A2D38),
        outlineVariant: Color(0xFF313340),
      ),
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
