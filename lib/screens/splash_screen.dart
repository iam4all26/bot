import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // 1. Give the UI animation time to play
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    
    final apiService = context.read<ApiService>();

    // 2. FIX: The Race Condition.
    // If the API service is still loading the token from SharedPreferences, 
    // wait in a loop for up to 3 seconds before assuming we are logged out.
    int retries = 0;
    while (!apiService.isAuthenticated && retries < 15) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }

    if (!mounted) return;

    // Route based on verified authentication state
    if (apiService.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B5CF6), width: 2),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF8B5CF6), size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'KAINUWA BOT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enterprise Trading Terminal',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF8B5CF6)),
            ),
          ],
        ),
      ),
    );
  }
}
