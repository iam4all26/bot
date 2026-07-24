import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

import 'home_screen.dart';
import 'positions_screen.dart';
import 'terminal_screen.dart'; // We use this for "Manual"
import 'copy_bots_screen.dart'; // The new Copy Bots Screen
import 'admin_screen.dart'; // Assuming your admin screen is here
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('wallet.php?action=get'); // Or any endpoint that returns role
    if (mounted && res['status'] == 'success') {
      // Assuming your backend sends admin signals. If not, it safely defaults to false.
      setState(() {
        _isAdmin = res['data']?['is_admin'] == true || res['is_admin'] == true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // NEW ORDER: Home -> Positions -> Manual -> Copy Bots -> Admin (if admin) -> Profile
    final List<Widget> screens = [
      const HomeScreen(),
      const PositionsScreen(),
      const TerminalScreen(), // Label will be "Manual"
      const CopyBotsScreen(),
      if (_isAdmin) const AdminScreen(),
      const SettingsScreen(),
    ];

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(PhosphorIcons.robotFill, color: theme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Kainuwa Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          color: const Color(0xFF13131A),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed, // Forces all labels to show
          selectedItemColor: theme.primaryColor,
          unselectedItemColor: Colors.white38,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(icon: Icon(PhosphorIcons.squaresFour), activeIcon: Icon(PhosphorIcons.squaresFourFill), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(PhosphorIcons.chartLineUp), activeIcon: Icon(PhosphorIcons.chartLineUpFill), label: 'Positions'),
            const BottomNavigationBarItem(icon: Icon(PhosphorIcons.rocketLaunch), activeIcon: Icon(PhosphorIcons.rocketLaunchFill), label: 'Manual'),
            const BottomNavigationBarItem(icon: Icon(PhosphorIcons.robot), activeIcon: Icon(PhosphorIcons.robotFill), label: 'Copy Bots'),
            if (_isAdmin) const BottomNavigationBarItem(icon: Icon(PhosphorIcons.shieldCheck), activeIcon: Icon(PhosphorIcons.shieldCheckFill), label: 'Admin'),
            const BottomNavigationBarItem(icon: Icon(PhosphorIcons.user), activeIcon: Icon(PhosphorIcons.userFill), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
