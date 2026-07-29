import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import 'positions_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';
import 'copy_bots_screen.dart';
import 'login_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _solBalance = "0.00000";
  String _usdValue = "0.00";
  String _publicAddress = "Loading...";
  Map<String, dynamic> _stats = {'open_count': 0, 'total_pnl': 0.0, 'total_trades': 0, 'username': 'Loading...'};
  List<dynamic> _openPositions = [];
  List<dynamic> _closedPositions = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchDashboardData(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    
    final responses = await Future.wait([
      api.getEndpoint('balance.php'),
      api.getEndpoint('positions.php?action=fetch'),
      api.getEndpoint('wallet.php?action=get')
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        if (responses[0]['status'] == 'success') {
          _solBalance = responses[0]['data']['sol_balance'];
          _usdValue = responses[0]['data']['usd_value'];
        }
        if (responses[1]['status'] == 'success') {
          _stats = responses[1]['stats'] ?? _stats;
          _openPositions = responses[1]['open_positions'] ?? [];
          _closedPositions = responses[1]['closed_positions'] ?? [];
        }
        if (responses[2]['status'] == 'success') {
          _publicAddress = responses[2]['data']['public_address'] ?? 'No Wallet Connected';
        }
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchDashboardData(silent: true);
  }

  Future<void> _quickClosePosition(int id) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Closing trade...'), duration: Duration(seconds: 1)));
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': id});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action complete')));
      _fetchDashboardData(silent: true);
    }
  }

  Future<void> _panicClose(String type) async {
    String title = 'PANIC SELL ALL';
    String content = 'Are you sure you want to market-sell ALL active open positions immediately?';
    if (type == 'manual') {
      title = 'CLOSE MANUAL TRADES';
      content = 'Are you sure you want to market-sell all your MANUAL open positions?';
    } else if (type == 'copy') {
      title = 'CLOSE COPY TRADES';
      content = 'Are you sure you want to market-sell all COPY/BOT open positions?';
    }

    final theme = Theme.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(title, style: TextStyle(color: AppTheme.danger(context), fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, CLOSE TRADES'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<ApiService>().postEndpoint('trade.php?action=close_all', {'type': type});
      if (mounted) _fetchDashboardData();
    }
  }

  void _showActionMenu(bool canTrade) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('New Action', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                if (canTrade)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(PhosphorIcons.rocketLaunchFill, color: theme.primaryColor),
                    ),
                    title: Text('Manual Trade', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                    subtitle: Text('Snipe a specific token address', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminalScreen()));
                    },
                  ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.info(context).withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.robotFill, color: AppTheme.info(context)),
                  ),
                  title: Text('Copy Bots', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text('Manage your automated strategies', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CopyBotsScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatAddress(dynamic addr) {
    if (addr == null || addr == 'No Wallet Connected' || addr == 'Loading...') return addr.toString();
    String str = addr.toString();
    if (str.length <= 12) return str;
    return '${str.substring(0, 6)}...${str.substring(str.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService>();
    final isAdmin = apiService.role == 'admin';
    final canTrade = isAdmin || apiService.allowManualTrade;
    final theme = Theme.of(context);

    final List<NavigationDestination> navItems = [
      NavigationDestination(icon: const Icon(PhosphorIcons.squaresFour), selectedIcon: Icon(PhosphorIcons.squaresFourFill, color: theme.primaryColor), label: 'Home'),
      NavigationDestination(icon: const Icon(PhosphorIcons.chartLineUp), selectedIcon: Icon(PhosphorIcons.chartLineUpFill, color: theme.primaryColor), label: 'Positions'),
      if (isAdmin) NavigationDestination(icon: const Icon(PhosphorIcons.shieldCheck), selectedIcon: Icon(PhosphorIcons.shieldCheckFill, color: theme.primaryColor), label: 'Admin'),
      NavigationDestination(icon: const Icon(PhosphorIcons.gear), selectedIcon: Icon(PhosphorIcons.gearFill, color: theme.primaryColor), label: 'Settings'),
    ];

    final int profileIndex = navItems.length - 1;

    final List<Widget> pages = [
      _buildPremiumHome(theme, profileIndex),
      const PositionsScreen(),
      if (isAdmin) const AdminScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedCryptoBackground(
        child: SafeArea(child: pages[_currentIndex > pages.length - 1 ? 0 : _currentIndex]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showActionMenu(canTrade),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFC026D3)]),
            boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: const Icon(PhosphorIcons.arrowsLeftRightBold, color: Colors.white, size: 24),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        backgroundColor: theme.colorScheme.surface, 
        elevation: 10,
        shadowColor: Colors.black.withOpacity(0.1),
        selectedIndex: _currentIndex > navItems.length - 1 ? 0 : _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: theme.primaryColor.withOpacity(0.12),
        destinations: navItems,
      ),
    );
  }

  Widget _buildPremiumHome(ThemeData theme, int profileIndex) {
    final currency = context.watch<CurrencyProvider>(); 
    final isDark = theme.brightness == Brightness.dark;
    final isProfit = true; // Placeholder calculated later
    
    return RefreshIndicator(
      onRefresh: () => _fetchDashboardData(),
      color: theme.primaryColor,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _currentIndex = profileIndex),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFC026D3)])),
                      child: CircleAvatar(radius: 20, backgroundColor: theme.colorScheme.surface, child: Icon(PhosphorIcons.userFill, color: theme.colorScheme.onSurface, size: 20)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        Text(_stats['username'] ?? 'Loading...', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 15)),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(isDark ? PhosphorIcons.sunFill : PhosphorIcons.moonFill, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          InkWell(
            onTap: () {
              if (_publicAddress != 'No Wallet Connected' && _publicAddress != 'Loading...') {
                Clipboard.setData(ClipboardData(text: _publicAddress));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet address copied!')));
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [Icon(PhosphorIcons.wallet, size: 18, color: theme.primaryColor), const SizedBox(width: 12), Text(_formatAddress(_publicAddress), style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))]),
                  Icon(PhosphorIcons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('PORTFOLIO VALUE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                    if (_isLoading && !_isRefreshing) SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                  ],
                ),
                const SizedBox(height: 8),
                Text('\$$_usdValue', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, fontSize: 40, letterSpacing: -1)),
                if (currency.isNaira) ...[
                  const SizedBox(height: 4),
                  Text('≈ ${currency.format(_usdValue)}', style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 15)),
                ],
                const SizedBox(height: 4),
                Text('$_solBalance SOL', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openPositions.isEmpty ? null : () => _panicClose('all'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.outline : AppTheme.danger(context).withOpacity(0.5)),
                    backgroundColor: _openPositions.isEmpty ? Colors.transparent : AppTheme.danger(context).withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(PhosphorIcons.warningOctagonFill, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.danger(context)),
                  label: Text('CLOSE ALL TRADES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.danger(context))),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPositions.isEmpty ? null : () => _panicClose('copy'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.outline : AppTheme.warning(context).withOpacity(0.5)),
                        backgroundColor: _openPositions.isEmpty ? Colors.transparent : AppTheme.warning(context).withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Icon(PhosphorIcons.robotFill, size: 16, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.warning(context)),
                      label: Text('CLOSE COPY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.warning(context))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPositions.isEmpty ? null : () => _panicClose('manual'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.outline : AppTheme.info(context).withOpacity(0.5)),
                        backgroundColor: _openPositions.isEmpty ? Colors.transparent : AppTheme.info(context).withOpacity(0.08),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: Icon(PhosphorIcons.handPalmFill, size: 16, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.info(context)),
                      label: Text('CLOSE MANUAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : AppTheme.info(context))),
                    ),
                  ),
                ],
              ),
            ]
          ),
          const SizedBox(height: 80), // Padding for the FAB
        ],
      ),
    );
  }
}
