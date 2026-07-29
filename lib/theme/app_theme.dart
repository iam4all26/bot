import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color kainuwaPurple = Color(0xFF7C3AED);
  static const Color kainuwaGold = Color(0xFFFFD700);
  static const Color darkBackground = Color(0xFF09090E);
  static const Color lightBackground = Color(0xFFF8F9FA);
  
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: kainuwaPurple,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.dark(
        primary: kainuwaPurple,
        secondary: kainuwaGold,
        surface: Color(0xFF13131A),
        onSurface: Colors.white,
        onSurfaceVariant: Color(0xFFA0A0B0),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: kainuwaPurple,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: kainuwaPurple,
        secondary: kainuwaGold,
        surface: Colors.white,
        onSurface: Color(0xFF111111),
        onSurfaceVariant: Color(0xFF666666),
      ),
      textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
    );
  }
}
