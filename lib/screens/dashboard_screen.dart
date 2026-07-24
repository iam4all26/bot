import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'positions_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';
import 'copy_bots_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  String _solBalance = "0.00000";
  String _usdValue = "0.00";
  String _publicAddress = "Loading...";
  Map<String, dynamic> _stats = {'open_count': 0, 'total_pnl': 0.0, 'total_trades': 0};
  List<dynamic> _openPositions = [];
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

  Future<void> _panicCloseAll() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('PANIC SELL ALL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to market-sell ALL active open positions immediately?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('YES, CLOSE ALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Executing Panic Close...'), backgroundColor: Colors.amber));
      final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_all', {});
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

    // CORRECT ORDER: Home -> Positions -> Manual -> Copy Bots -> Admin -> Profile
    final List<Widget> pages = [
      _buildPremiumHome(theme),
      const PositionsScreen(),
      if (canTrade) const TerminalScreen(),
      const CopyBotsScreen(),
      if (isAdmin) const AdminScreen(),
      const SettingsScreen(),
    ];

    final List<NavigationDestination> navItems = [
      NavigationDestination(icon: Icon(PhosphorIcons.squaresFour), selectedIcon: Icon(PhosphorIcons.squaresFourFill, color: theme.primaryColor), label: 'Home'),
      NavigationDestination(icon: Icon(PhosphorIcons.chartLineUp), selectedIcon: Icon(PhosphorIcons.chartLineUpFill, color: theme.primaryColor), label: 'Positions'),
      if (canTrade) NavigationDestination(icon: Icon(PhosphorIcons.rocketLaunch), selectedIcon: Icon(PhosphorIcons.rocketLaunchFill, color: theme.primaryColor), label: 'Manual'),
      NavigationDestination(icon: Icon(PhosphorIcons.robot), selectedIcon: Icon(PhosphorIcons.robotFill, color: theme.primaryColor), label: 'Copy Bots'),
      if (isAdmin) NavigationDestination(icon: Icon(PhosphorIcons.shieldCheck), selectedIcon: Icon(PhosphorIcons.shieldCheckFill, color: theme.primaryColor), label: 'Admin'),
      NavigationDestination(icon: Icon(PhosphorIcons.userCircle), selectedIcon: Icon(PhosphorIcons.userCircleFill, color: theme.primaryColor), label: 'Profile'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedCryptoBackground(
        child: SafeArea(child: pages[_currentIndex > pages.length - 1 ? 0 : _currentIndex]),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface.withOpacity(0.8), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
        child: NavigationBar(
          backgroundColor: Colors.transparent, elevation: 0,
          selectedIndex: _currentIndex > navItems.length - 1 ? 0 : _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          indicatorColor: theme.primaryColor.withOpacity(0.3),
          destinations: navItems,
        ),
      ),
    );
  }

  Widget _buildPremiumHome(ThemeData theme) {
    final double pnl = _stats['total_pnl'] != null ? (_stats['total_pnl'] as num).toDouble() : 0.0;
    final bool isProfit = pnl >= 0;

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)])),
                    child: const CircleAvatar(radius: 22, backgroundColor: Color(0xFF13131A), child: Icon(PhosphorIcons.userFill, color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      Text('Osama Elguduwis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                ],
              ),
              IconButton(icon: Icon(PhosphorIcons.signOut, color: theme.colorScheme.onSurfaceVariant), onPressed: () => context.read<ApiService>().logout()),
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
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [Icon(PhosphorIcons.wallet, size: 16, color: theme.primaryColor), const SizedBox(width: 8), Text(_formatAddress(_publicAddress), style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white))]),
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
                    if (_isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  ],
                ),
                const SizedBox(height: 8),
                Text('\$$_usdValue', style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 40)),
                const SizedBox(height: 4),
                Text('$_solBalance SOL', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 24),
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('NET PNL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 4), Text('${isProfit ? '+' : ''}\$${pnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18))])),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.1)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('OPEN TRADES', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1)), const SizedBox(height: 4), Text('${_stats['open_count'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openPositions.isEmpty ? null : _panicCloseAll,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _openPositions.isEmpty ? Colors.white24 : Colors.redAccent.withOpacity(0.5)),
                backgroundColor: _openPositions.isEmpty ? Colors.transparent : Colors.redAccent.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(PhosphorIcons.warningOctagonFill, color: _openPositions.isEmpty ? Colors.white54 : Colors.redAccent),
              label: Text('CLOSE ALL TRADES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: _openPositions.isEmpty ? Colors.white54 : Colors.redAccent)),
            ),
          ),
          const SizedBox(height: 24),

          if (_openPositions.isNotEmpty) ...[
            Text('LIVE OPEN POSITIONS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: _openPositions.map((p) {
                  final double? cpnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '');
                  final bool cpIsProfit = (cpnl ?? 0) >= 0;
                  return ListTile(
                    dense: true,
                    leading: Icon(PhosphorIcons.trendUp, size: 16, color: theme.primaryColor),
                    title: Text(_formatAddress(p['token_address']), style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Size: \$${p['virtual_usd_amount']}  |  MCAP: ${_formatMcap(p['current_mcap'])}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                    trailing: Text(
                      cpnl != null ? '${cpIsProfit ? '+' : ''}\$${cpnl.toStringAsFixed(2)}' : '-',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cpIsProfit ? Colors.greenAccent : Colors.redAccent),
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
