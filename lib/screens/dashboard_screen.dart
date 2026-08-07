import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/solana_icon.dart';
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
  Map<String, Map<String, dynamic>> _chainBalances = {
    'solana': {'balance': '0.00000', 'usd': 0.0, 'symbol': 'SOL'},
    'bsc': {'balance': '0.00000', 'usd': 0.0, 'symbol': 'BNB'},
    'robinhood': {'balance': '0.00000', 'usd': 0.0, 'symbol': 'ETH'},
  };
  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };
  String _publicAddress = "Loading...";
  Map<String, dynamic> _stats = {'open_count': 0, 'total_pnl': 0.0, 'total_trades': 0, 'username': 'Loading...'};
  List<dynamic> _openPositions = [];
  List<dynamic> _closedPositions = [];
  Timer? _pollingTimer;
  final Set<int> _closingIds = {};

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
      api.getEndpoint('balance.php?chain=solana'),
      api.getEndpoint('positions.php?action=fetch'),
      api.getEndpoint('wallet.php?action=get&chain=solana'),
      api.getEndpoint('balance.php?chain=bsc'),
      api.getEndpoint('balance.php?chain=robinhood'),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        double totalUsd = 0.0;

        if (responses[0]['status'] == 'success') {
          _solBalance = responses[0]['data']['native_balance'] ?? responses[0]['data']['sol_balance'] ?? '0.00000';
          _usdValue = responses[0]['data']['usd_value'] ?? '0.00';
          final solUsd = double.tryParse(_usdValue) ?? 0.0;
          totalUsd += solUsd;
          _chainBalances['solana'] = {'balance': _solBalance, 'usd': solUsd, 'symbol': responses[0]['data']['native_symbol'] ?? 'SOL'};
        }

        if (responses[3]['status'] == 'success') {
          final bal = responses[3]['data']['native_balance'] ?? '0.00000';
          final usd = double.tryParse(responses[3]['data']['usd_value']?.toString() ?? '0') ?? 0.0;
          totalUsd += usd;
          _chainBalances['bsc'] = {'balance': bal, 'usd': usd, 'symbol': responses[3]['data']['native_symbol'] ?? 'BNB'};
        }
        if (responses[4]['status'] == 'success') {
          final bal = responses[4]['data']['native_balance'] ?? '0.00000';
          final usd = double.tryParse(responses[4]['data']['usd_value']?.toString() ?? '0') ?? 0.0;
          totalUsd += usd;
          _chainBalances['robinhood'] = {'balance': bal, 'usd': usd, 'symbol': responses[4]['data']['native_symbol'] ?? 'ETH'};
        }

        _usdValue = totalUsd.toStringAsFixed(2);
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

  void _showFloatingSnackbar(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isError ? AppTheme.danger(context) : theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _toggleLock(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;
    
    final isCurrentlyLocked = (p['is_locked'] == 1 || p['is_locked'] == '1');
    final newLockStatus = !isCurrentlyLocked;
    
    // Optimistic UI Update (Instant Feedback)
    setState(() {
      p['is_locked'] = newLockStatus ? 1 : 0;
    });
    
    final res = await context.read<ApiService>().postEndpoint(
      'trade.php?action=toggle_lock',
      {'id': pId, 'is_locked': newLockStatus ? 1 : 0},
    );
    
    if (mounted && res['status'] != 'success') {
      // Revert if API fails
      setState(() {
        p['is_locked'] = isCurrentlyLocked ? 1 : 0;
      });
      _showFloatingSnackbar(res['message'] ?? 'Failed to sync lock status', isError: true);
    }
  }

  Future<void> _quickClosePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (p['is_locked'] == 1 || p['is_locked'] == '1') {
      _showFloatingSnackbar('Trade is locked! 🔓 Unlock to close.', isError: true);
      return;
    }

    setState(() => _closingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350)); 

    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': pId});
    if (mounted) {
      if (res['status'] != 'success' && res['status'] != 'closed') {
         _showFloatingSnackbar(res['message'] ?? 'Failed to close', isError: true);
         setState(() => _closingIds.remove(pId)); 
      }
      _fetchDashboardData(silent: true);
    }
  }

  Future<void> _panicClose(String type) async {
    final api = context.read<ApiService>();
    List<int> toClose = [];
    
    for (var p in _openPositions) {
      int pId = int.tryParse(p['id'].toString()) ?? 0;
      if (p['is_locked'] == 1 || p['is_locked'] == '1') continue;
      
      bool isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
      if (type == 'manual' && isCopy) continue;
      if (type == 'copy' && !isCopy) continue;
      
      toClose.add(pId);
    }
    
    if (toClose.isEmpty) {
      _showFloatingSnackbar('No unlocked $type trades to close.', isError: true);
      return;
    }

    setState(() => _closingIds.addAll(toClose));
    await Future.delayed(const Duration(milliseconds: 350));

    for (int id in toClose) {
      await api.postEndpoint('trade.php?action=close_position', {'id': id});
    }
    
    if (mounted) _fetchDashboardData(silent: true);
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
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.calculatorFill, color: AppTheme.success(context)),
                  ),
                  title: Text('Exchange Calculator', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text('Calculate USD to Naira dynamically', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(context: context, builder: (ctx) => const CurrencyCalculatorDialog());
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

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, ThemeData theme) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(bottom: isSelected ? 2 : 0),
            child: Icon(
              isSelected ? activeIcon : icon, 
              color: isSelected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.7), 
              size: 26
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.7), 
              fontSize: 10, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
            )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = context.watch<ApiService>();
    final isAdmin = apiService.role == 'admin';
    final canTrade = isAdmin || apiService.allowManualTrade;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> pages = [
      _buildPremiumHome(theme, isAdmin ? 3 : 2),
      const PositionsScreen(),
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
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true, 
        resizeToAvoidBottomInset: false,
        body: AnimatedCryptoBackground(
          child: SafeArea(bottom: false, child: pages[_currentIndex > pages.length - 1 ? 0 : _currentIndex]),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showActionMenu(canTrade),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppTheme.kainuwaPurple, AppTheme.kainuwaGold],
                stops: [0.75, 1.0], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: const Icon(PhosphorIcons.arrowsLeftRightBold, color: Colors.white, size: 28),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: theme.colorScheme.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          elevation: isDark ? 10 : 0, 
          shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.0),
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(PhosphorIcons.squaresFour, PhosphorIcons.squaresFourFill, 'Home', 0, theme),
                _buildNavItem(PhosphorIcons.chartLineUp, PhosphorIcons.chartLineUpFill, 'Positions', 1, theme),
                const SizedBox(width: 48), 
                if (isAdmin) _buildNavItem(PhosphorIcons.shieldCheck, PhosphorIcons.shieldCheckFill, 'Admin', 2, theme),
                _buildNavItem(PhosphorIcons.gear, PhosphorIcons.gearFill, 'Settings', isAdmin ? 3 : 2, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHome(ThemeData theme, int profileIndex) {
    final currency = context.watch<CurrencyProvider>(); 
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = context.read<ApiService>().role == 'admin';

    double dailyPnl = 0.0;
    final now = DateTime.now();
    for (var p in _closedPositions) {
      try {
        DateTime dt = DateTime.parse(p['closed_at'].toString().replaceAll(' ', 'T') + 'Z').toLocal();
        if (now.difference(dt).inDays == 0 && now.day == dt.day) {
          dailyPnl += double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
        }
      } catch (_) {}
    }
    final bool isProfit = dailyPnl >= 0;

    return RefreshIndicator(
      onRefresh: () => _fetchDashboardData(),
      color: theme.primaryColor,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, 
                        gradient: LinearGradient(colors: [AppTheme.kainuwaPurple, AppTheme.kainuwaGold], stops: [0.75, 1.0])
                      ),
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
                _showFloatingSnackbar('Wallet address copied!');
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
                const SizedBox(height: 8),
                Text('COMBINED ACROSS SOLANA, BSC & ROBINHOOD', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 0.8, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['solana', 'bsc', 'robinhood'].map((chainId) {
                      final cb = _chainBalances[chainId]!;
                      final rawBalance = double.tryParse(cb['balance'].toString()) ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20, height: 20,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: (_chainColors[chainId] ?? theme.primaryColor).withOpacity(0.12), shape: BoxShape.circle),
                              child: chainId == 'solana'
                                  ? const SolanaIcon(size: 11, color: AppTheme.kainuwaPurple)
                                  : Text(chainId == 'bsc' ? 'B' : 'R', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _chainColors[chainId])),
                            ),
                            const SizedBox(width: 5),
                            Text('${rawBalance.toStringAsFixed(4)} ${cb['symbol']}', style: TextStyle(color: _chainColors[chainId] ?? theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.trendUpFill, color: isProfit ? AppTheme.success(context) : AppTheme.danger(context), size: 16),
                          const SizedBox(width: 8),
                          Text('DAILY PNL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${isProfit && dailyPnl > 0 ? '+' : ''}\$${dailyPnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? AppTheme.success(context) : AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 18)),
                      if (currency.isNaira)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('≈ ${isProfit && dailyPnl > 0 ? '+' : ''}${currency.format(dailyPnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: isProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ]
                  ),
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.chartBarFill, color: AppTheme.info(context), size: 16),
                          const SizedBox(width: 8),
                          Text('OPEN TRADES', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('${_stats['open_count'] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                    ]
                  ),
                )
              ),
            ],
          ),
          const SizedBox(height: 24),
          
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
          const SizedBox(height: 32),

          if (_openPositions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('LIVE OPEN POSITIONS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                InkWell(
                  onTap: _isRefreshing ? null : _manualRefresh,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                    child: _isRefreshing 
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onSurfaceVariant))
                        : Icon(PhosphorIcons.arrowsClockwiseBold, size: 14, color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: _openPositions.map((p) {
                  final double? cpnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '');
                  final bool cpIsProfit = (cpnl ?? 0) >= 0;
                  final pId = int.tryParse(p['id'].toString()) ?? 0;
                  final bool isClosing = _closingIds.contains(pId);
                  final bool isLocked = p['is_locked'] == 1 || p['is_locked'] == '1';
                  
                  String botName = p['display_name'] ?? 'Manual';
                  if (isAdmin && botName != 'Manual') botName = botName.toUpperCase();

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: isClosing
                        ? const SizedBox(width: double.infinity, height: 0)
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: isClosing ? 0.0 : 1.0,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleLock(p),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isLocked ? AppTheme.warning(context).withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isLocked ? PhosphorIcons.lockKeyFill : PhosphorIcons.lockKeyOpen,
                                        color: isLocked ? AppTheme.warning(context) : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                    child: Icon(PhosphorIcons.trendUp, size: 18, color: theme.primaryColor),
                                  ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Text(_formatAddress(p['token_address']), style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 6),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5), border: Border.all(color: theme.colorScheme.outlineVariant)), child: Text((p['chain'] ?? 'solana').toString().toUpperCase(), style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)), child: Text(botName, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Size: \$${p['virtual_usd_amount']}  •  MCAP: ${_formatMcap(p['current_mcap'])}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                                    if (currency.isNaira)
                                      Text('Size: ${currency.format(p['virtual_usd_amount'])}', style: TextStyle(fontSize: 11, color: AppTheme.success(context).withOpacity(0.8))),
                                  ],
                                ),
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
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cpIsProfit ? AppTheme.success(context) : AppTheme.danger(context)),
                                      ),
                                      if (currency.isNaira && cpnl != null)
                                        Text(
                                          '≈ ${cpIsProfit && cpnl > 0 ? '+' : ''}${currency.format(cpnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: cpIsProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () => _quickClosePosition(p),
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.1), shape: BoxShape.circle),
                                      child: Icon(PhosphorIcons.xBold, size: 14, color: AppTheme.danger(context)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String text = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    int dotCount = text.split('.').length - 1;
    if (dotCount > 1) return oldValue;
    
    List<String> parts = text.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    String whole = parts[0].replaceAllMapped(reg, mathFunc);
    String finalString = parts.length > 1 ? '$whole.${parts[1]}' : whole;
    
    int cursorOffset = newValue.selection.end + (finalString.length - newValue.text.length);
    if (cursorOffset < 0) cursorOffset = 0;
    if (cursorOffset > finalString.length) cursorOffset = finalString.length;
    
    return TextEditingValue(
      text: finalString,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

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

  String _usdWords = "";
  String _ngnWords = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      try {
        _activeRate = context.read<CurrencyProvider>().exchangeRate; 
      } catch (_) {
        _activeRate = 1500.0;
      }
      _isInitialized = true;
    }
  }

  String _numberToWords(int number) {
    if (number == 0) return "Zero";
    if (number < 0) return "Minus ${_numberToWords(number.abs())}";
    String words = "";
    if ((number / 1000000000).floor() > 0) {
      words += "${_numberToWords((number / 1000000000).floor())} Billion ";
      number %= 1000000000;
    }
    if ((number / 1000000).floor() > 0) {
      words += "${_numberToWords((number / 1000000).floor())} Million ";
      number %= 1000000;
    }
    if ((number / 1000).floor() > 0) {
      words += "${_numberToWords((number / 1000).floor())} Thousand ";
      number %= 1000;
    }
    if ((number / 100).floor() > 0) {
      words += "${_numberToWords((number / 100).floor())} Hundred ";
      number %= 100;
    }
    if (number > 0) {
      if (words != "") words += "and ";
      var unitsMap = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];
      var tensMap = ["Zero", "Ten", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];
      if (number < 20) {
        words += unitsMap[number];
      } else {
        words += tensMap[(number / 10).floor()];
        if ((number % 10) > 0) {
          words += "-${unitsMap[number % 10]}";
        }
      }
    }
    return words.trim();
  }

  String _formatWithCommas(String text) {
    List<String> parts = text.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]},';
    String whole = parts[0].replaceAllMapped(reg, mathFunc);
    return parts.length > 1 ? '$whole.${parts[1]}' : whole;
  }

  void _updateWords() {
    double usd = double.tryParse(_usdController.text.replaceAll(',', '')) ?? 0;
    double ngn = double.tryParse(_ngnController.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _usdWords = usd > 0 ? '${_numberToWords(usd.floor())} Dollars' : '';
      _ngnWords = ngn > 0 ? '${_numberToWords(ngn.floor())} Naira' : '';
    });
  }

  void _onUsdChanged(String value) {
    if (value.isEmpty) { 
      _ngnController.clear(); 
      _updateWords();
      return; 
    }
    double usd = double.tryParse(value.replaceAll(',', '')) ?? 0;
    _ngnController.text = _formatWithCommas((usd * _activeRate).toStringAsFixed(2));
    _updateWords();
  }

  void _onNgnChanged(String value) {
    if (value.isEmpty) { 
      _usdController.clear(); 
      _updateWords();
      return; 
    }
    double ngn = double.tryParse(value.replaceAll(',', '')) ?? 0;
    if (_activeRate > 0) _usdController.text = _formatWithCommas((ngn / _activeRate).toStringAsFixed(2));
    _updateWords();
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
                IconButton(icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints())
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Active Rate: 1 USD = ₦${_formatWithCommas(_activeRate.toStringAsFixed(2))}', style: TextStyle(color: AppTheme.success(context), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            
            Text('Amount in USD (\$)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _usdController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixIcon: Icon(PhosphorIcons.currencyDollar, color: theme.colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: '0.00',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              ),
              onChanged: _onUsdChanged,
            ),
            if (_usdWords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_usdWords, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontStyle: FontStyle.italic)),
              ),
            
            const SizedBox(height: 16),
            Center(child: Icon(PhosphorIcons.arrowsDownUp, color: theme.colorScheme.onSurfaceVariant, size: 24)),
            const SizedBox(height: 16),

            Text('Amount in Naira (₦)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _ngnController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, top: 11, right: 8),
                  child: Text('₦', style: TextStyle(color: AppTheme.success(context), fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                filled: true,
                fillColor: AppTheme.success(context).withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                hintText: '0.00',
                hintStyle: TextStyle(color: AppTheme.success(context).withOpacity(0.3)),
              ),
              onChanged: _onNgnChanged,
            ),
            if (_ngnWords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_ngnWords, style: TextStyle(color: AppTheme.success(context), fontSize: 11, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
