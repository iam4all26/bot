import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'providers/currency_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KainuwaBotApp());
}

class KainuwaBotApp extends StatefulWidget {
  const KainuwaBotApp({super.key});

  @override
  State<KainuwaBotApp> createState() => _KainuwaBotAppState();
}

class _KainuwaBotAppState extends State<KainuwaBotApp> {
  late final ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    NotificationService.initialize(_apiService);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: _apiService),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()..fetchLiveRate(_apiService)),
      ],
      child: MaterialApp(
        title: 'Kainuwa Bot',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          primaryColor: const Color(0xFF8B5CF6),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8B5CF6),
            surface: Color(0xFF13131A),
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
