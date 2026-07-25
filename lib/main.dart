import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'providers/currency_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: const KainuwaApp(),
    ),
  );
}

class KainuwaApp extends StatelessWidget {
  const KainuwaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kainuwa Academy Trading',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Consumer<ApiService>(
        builder: (context, apiService, child) {
          if (!apiService.isInitialized) {
            return const Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: CircularProgressIndicator()));
          }
          if (apiService.isAuthenticated) {
            // Fetch rate when logged in
            context.read<CurrencyProvider>().fetchLiveRate(apiService);
            return const DashboardScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
