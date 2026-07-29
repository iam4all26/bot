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
  Timer? _pollingTimer;
  DateTime? _lastPressedAt;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action complete'), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
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

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, CLOSE TRADES'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executing...'), backgroundColor: Colors.amber));
      final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_all', {'type': type});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action completed'), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
        _fetchDashboardData();
      }
    }
  }

  String _formatAddress(dynamic addr) {
    if (addr == null || addr == 'No Wallet Connected' || addr == 'Loading...') return addr.toString();
    String str = addr.toString();
    if (str.length <= 12) return str;
    return '${str.substring(0, 6)}...${str.substring(str.length - 4)}';
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
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
      if (canTrade) NavigationDestination(icon: const Icon(PhosphorIcons.rocketLaunch), selectedIcon: Icon(PhosphorIcons.rocketLaunchFill, color: theme.primaryColor), label: 'Manual'),
      NavigationDestination(icon: const Icon(PhosphorIcons.robot), selectedIcon: Icon(PhosphorIcons.robotFill, color: theme.primaryColor), label: 'Bots'),
      if (isAdmin) NavigationDestination(icon: const Icon(PhosphorIcons.shieldCheck), selectedIcon: Icon(PhosphorIcons.shieldCheckFill, color: theme.primaryColor), label: 'Admin'),
      NavigationDestination(icon: const Icon(PhosphorIcons.userCircle), selectedIcon: Icon(PhosphorIcons.userCircleFill, color: theme.primaryColor), label: 'Profile'),
    ];

    final int profileIndex = navItems.length - 1;

    final List<Widget> pages = [
      _buildPremiumHome(theme, profileIndex),
      const PositionsScreen(),
      if (canTrade) const TerminalScreen(),
      const CopyBotsScreen(),
      if (isAdmin) const AdminScreen(),
      const SettingsScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tap back again to exit', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
              backgroundColor: theme.colorScheme.surface,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedCryptoBackground(
          child: SafeArea(child: pages[_currentIndex > pages.length - 1 ? 0 : _currentIndex]),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: theme.colorScheme.surface.withOpacity(0.9), border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.05)))),
          child: NavigationBar(
            backgroundColor: Colors.transparent, elevation: 0,
            selectedIndex: _currentIndex > navItems.length - 1 ? 0 : _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            indicatorColor: theme.primaryColor.withOpacity(0.2),
            destinations: navItems,
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHome(ThemeData theme, int profileIndex) {
    final currency = context.watch<CurrencyProvider>(); 
    final double pnl = _stats['total_pnl'] != null ? (_stats['total_pnl'] as num).toDouble() : 0.0;
    final bool isProfit = pnl >= 0;
    final isDark = theme.brightness == Brightness.dark;

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
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)])),
                      child: CircleAvatar(radius: 22, backgroundColor: theme.colorScheme.surface, child: Icon(PhosphorIcons.userFill, color: theme.colorScheme.onSurface)),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        Text(_stats['username'] ?? 'Loading...', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(PhosphorIcons.calculatorFill, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const CurrencyCalculatorDialog(),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(isDark ? PhosphorIcons.sunFill : PhosphorIcons.moonFill, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.signOut, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () async {
                      await context.read<ApiService>().logout();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          InkWell(
            onTap: () {
              if (_publicAddress != 'No Wallet Connected' && _publicAddress != 'Loading...') {
                Clipboard.setData(ClipboardData(text: _publicAddress));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet address copied!'), backgroundColor: Colors.green));
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [Icon(PhosphorIcons.wallet, size: 16, color: theme.primaryColor), const SizedBox(width: 8), Text(_formatAddress(_publicAddress), style: TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))]),
                  Icon(PhosphorIcons.copy, size: 16, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL PORTFOLIO VALUE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    if (_isLoading && !_isRefreshing) SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                  ],
                ),
                const SizedBox(height: 8),
                Text('\$$_usdValue', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, fontSize: 40)),
                if (currency.isNaira) ...[
                  const SizedBox(height: 2),
                  Text('≈ ${currency.format(_usdValue)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
                const SizedBox(height: 4),
                Text('$_solBalance SOL', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                Container(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          Text('DAILY PNL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1)), 
                          const SizedBox(height: 4), 
                          Text('${isProfit && pnl > 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                          if (currency.isNaira)
                            Text('≈ ${isProfit && pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: isProfit ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 11)),
                        ]
                      )
                    ),
                    Container(width: 1, height: 40, color: theme.colorScheme.onSurface.withOpacity(0.1)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('OPEN TRADES', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 4), Text('${_stats['open_count'] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18))])),
                  ],
                ),
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
                    side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.onSurface.withOpacity(0.2) : Colors.redAccent.withOpacity(0.5)),
                    backgroundColor: _openPositions.isEmpty ? Colors.transparent : Colors.redAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(PhosphorIcons.warningOctagonFill, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.redAccent),
                  label: Text('CLOSE ALL TRADES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.redAccent)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPositions.isEmpty ? null : () => _panicClose('copy'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.onSurface.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.5)),
                        backgroundColor: _openPositions.isEmpty ? Colors.transparent : Colors.orangeAccent.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(PhosphorIcons.robotFill, size: 16, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.orangeAccent),
                      label: Text('CLOSE COPY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.orangeAccent)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openPositions.isEmpty ? null : () => _panicClose('manual'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _openPositions.isEmpty ? theme.colorScheme.onSurface.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.5)),
                        backgroundColor: _openPositions.isEmpty ? Colors.transparent : Colors.blueAccent.withOpacity(0.1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(PhosphorIcons.handPalmFill, size: 16, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.blueAccent),
                      label: Text('CLOSE MANUAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _openPositions.isEmpty ? theme.colorScheme.onSurfaceVariant : Colors.blueAccent)),
                    ),
                  ),
                ],
              ),
            ]
          ),
          const SizedBox(height: 24),

          if (_openPositions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LIVE OPEN POSITIONS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                InkWell(
                  onTap: _isRefreshing ? null : _manualRefresh,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), shape: BoxShape.circle),
                    child: _isRefreshing 
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onSurfaceVariant))
                        : Icon(PhosphorIcons.arrowsClockwiseBold, size: 14, color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: _openPositions.map((p) {
                  final double? cpnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '');
                  final bool cpIsProfit = (cpnl ?? 0) >= 0;
                  final botName = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
                  final pId = int.tryParse(p['id'].toString()) ?? 0;

                  return ListTile(
                    dense: true,
                    leading: Icon(PhosphorIcons.trendUp, size: 16, color: theme.primaryColor),
                    title: Row(
                      children: [
                        Text(_formatAddress(p['token_address']), style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(botName, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Size: \$${p['virtual_usd_amount']}  |  MCAP: ${_formatMcap(p['current_mcap'])}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                        if (currency.isNaira)
                          Text('Size: ${currency.format(p['virtual_usd_amount'])}', style: TextStyle(fontSize: 10, color: Colors.greenAccent.withOpacity(0.7))),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              cpnl != null ? '${cpIsProfit && cpnl > 0 ? '+' : ''}\$${cpnl.toStringAsFixed(2)}' : '-',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cpIsProfit ? Colors.greenAccent : Colors.redAccent),
                            ),
                            if (currency.isNaira && cpnl != null)
                              Text(
                                '≈ ${cpIsProfit && cpnl > 0 ? '+' : ''}${currency.format(cpnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: cpIsProfit ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7)),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _quickClosePosition(pId),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                            child: const Icon(PhosphorIcons.xBold, size: 14, color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// CURRENCY CALCULATOR DIALOG WIDGET
// ----------------------------------------------------------------------
class CurrencyCalculatorDialog extends StatefulWidget {
  const CurrencyCalculatorDialog({super.key});

  @override
  State<CurrencyCalculatorDialog> createState() => _CurrencyCalculatorDialogState();
}

class _CurrencyCalculatorDialogState extends State<CurrencyCalculatorDialog> {
  final TextEditingController _usdController = TextEditingController();
  final TextEditingController _ngnController = TextEditingController();
  
  double _activeRate = 1500.0;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeRate();
      _isInitialized = true;
    }
  }

  void _initializeRate() {
    try {
      final currency = context.read<CurrencyProvider>();
      // FIXED: Pulling the exact unformatted double rate directly from the provider
      _activeRate = currency.exchangeRate; 
    } catch (_) {
      _activeRate = 1500.0;
    }
  }

  void _onUsdChanged(String value) {
    if (value.isEmpty) {
      _ngnController.clear();
      return;
    }
    double usd = double.tryParse(value) ?? 0;
    _ngnController.text = (usd * _activeRate).toStringAsFixed(2);
  }

  void _onNgnChanged(String value) {
    if (value.isEmpty) {
      _usdController.clear();
      return;
    }
    double ngn = double.tryParse(value) ?? 0;
    if (_activeRate > 0) {
      _usdController.text = (ngn / _activeRate).toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _usdController.dispose();
    _ngnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.calculatorFill, color: theme.primaryColor, size: 24),
                    const SizedBox(width: 8),
                    Text('Calculator', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('Active Rate: 1 USD = ₦${_activeRate.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            
            Text('Amount in USD (\$)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _usdController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixIcon: Icon(PhosphorIcons.currencyDollar, color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.onSurface.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: '0.00',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ),
              onChanged: _onUsdChanged,
            ),
            
            const SizedBox(height: 16),
            Center(child: Icon(PhosphorIcons.arrowsDownUp, color: theme.colorScheme.onSurfaceVariant, size: 24)),
            const SizedBox(height: 16),

            Text('Amount in Naira (₦)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _ngnController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, top: 11, right: 8),
                  child: Text('₦', style: TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                filled: true,
                fillColor: Colors.greenAccent.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              onChanged: _onNgnChanged,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
