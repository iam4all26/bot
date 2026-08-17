import 'dart:async';
import 'dart:math' as math;
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
import '../widgets/chain_icon.dart';
import '../theme/app_theme.dart';
import 'positions_screen.dart';
import 'admin_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';
import 'copy_bots_screen.dart';
import 'history_screen.dart';
import 'hidden_positions_screen.dart';
import 'market/market_dashboard_screen.dart';
import 'market/market_receive_screen.dart';
import 'market/market_send_crypto_screen.dart';
import 'market/market_cash_out_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  bool _isMarketMode = false;
  int _botTabIndex = 0;
  int _marketTabIndex = 0;
  final ValueNotifier<int> _adminViewIndex = ValueNotifier<int>(0);

  // Exchange-style "portal" mode switch: a colored circle expands from the
  // switch button and reveals the new mode underneath, instead of a plain
  // slide/fade. _pendingMarketMode is non-null only while the reveal is
  // mid-animation; the real _isMarketMode flips once it completes.
  final GlobalKey _switchButtonKey = GlobalKey();
  late final AnimationController _revealController;
  Offset? _revealOrigin;
  bool? _pendingMarketMode;
  bool _contentSwapped = false;

  bool _isLoading = true;
  bool _isRefreshing = false;
  String _solBalance = "0.00000";
  String _usdValue = "0.00";
  
  Map<String, String> _wallets = {'solana': '-', 'bsc': '-', 'robinhood': '-'};
  Map<String, bool> _copiedStates = {'solana': false, 'bsc': false, 'robinhood': false};
  
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
  
  Map<String, dynamic> _stats = {'open_count': 0, 'total_pnl': 0.0, 'today_pnl': 0.0, 'total_trades': 0, 'username': 'Loading...'};
  List<dynamic> _openPositions = [];
  Timer? _pollingTimer;
  final Set<int> _closingIds = {};

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _revealController.addListener(() {
      // The wipe fully covers the screen at t=0.5 (see _revealCoverage).
      // That's the one instant nothing is visible underneath it, so it's
      // the only safe moment to swap which mode's content is mounted —
      // swapping any earlier/later would let both layouts peek through
      // together, which is what caused the overlapping/merging look.
      if (!_contentSwapped && _pendingMarketMode != null && _revealController.value >= 0.5) {
        _contentSwapped = true;
        setState(() => _isMarketMode = _pendingMarketMode!);
      }
    });
    _fetchDashboardData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchDashboardData(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _adminViewIndex.dispose();
    _revealController.dispose();
    super.dispose();
  }

  // Captures the switch button's on-screen center, then wipes a solid
  // colored circle out from that point to fully cover the screen, swaps
  // the real content underneath while hidden, then shrinks the same
  // circle back down to reveal it — the same "portal" pattern used by
  // Binance/Coinbase Wallet's Web2⇄Web3 switch. The circle never contains
  // live page content itself, so Market's and Bot mode's very different
  // layouts never render on screen at the same time.
  void _triggerModeSwitch() {
    final renderBox = _switchButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.attached) {
      _revealOrigin = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    } else {
      final size = MediaQuery.of(context).size;
      _revealOrigin = Offset(size.width / 2, size.height - 90);
    }

    HapticFeedback.mediumImpact();
    _contentSwapped = false;
    setState(() => _pendingMarketMode = !_isMarketMode);

    _revealController.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _pendingMarketMode = null);
      _revealController.reset();
    });
  }

  double _revealMaxRadius(Size screenSize) {
    if (_revealOrigin == null) return screenSize.longestSide;
    final corners = [
      Offset.zero,
      Offset(screenSize.width, 0),
      Offset(0, screenSize.height),
      Offset(screenSize.width, screenSize.height),
    ];
    double maxDist = 0;
    for (final c in corners) {
      final d = (c - _revealOrigin!).distance;
      if (d > maxDist) maxDist = d;
    }
    return maxDist;
  }

  // 0 → 1 over the first half (circle grows to fully cover the screen),
  // then 1 → 0 over the second half (circle shrinks away again). The
  // content swap happens right at the t=0.5 peak, when this returns 1.0
  // and the whole screen is hidden behind the solid wipe.
  double _revealCoverage(double t) {
    if (t < 0.5) return Curves.easeOutCubic.transform(t / 0.5);
    return 1 - Curves.easeInCubic.transform((t - 0.5) / 0.5);
  }

  // "SWITCHING TO MARKET/BOT" badge — rises up from below and fades in
  // over the first 25% of the transition, holds center-screen through the
  // middle, then rises further and fades out over the last 25% as the
  // portal finishes covering the screen. Uses _revealController's own
  // value directly (this is built inside that controller's AnimatedBuilder).
  Widget _buildModeAnnouncement(bool targetIsMarket, Color color, ThemeData theme, Size size) {
    final t = _revealController.value;

    double opacity;
    double dy;
    if (t < 0.20) {
      final p = Curves.easeOutCubic.transform(t / 0.20);
      opacity = p;
      dy = 50 * (1 - p);
    } else if (t < 0.80) {
      opacity = 1.0;
      dy = 0.0;
    } else {
      final p = Curves.easeInCubic.transform((t - 0.80) / 0.20);
      opacity = 1 - p;
      dy = -40 * p;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, dy),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 30, spreadRadius: 4)],
                      border: Border.all(color: Colors.white.withOpacity(0.25), width: 3),
                    ),
                    child: Icon(
                      targetIsMarket ? PhosphorIcons.storefrontFill : PhosphorIcons.robotFill,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    targetIsMarket ? 'FIAT MARKET' : 'BOT MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 2,
                      shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 20)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    targetIsMarket ? 'Switching to Market...' : 'Switching to Bot Mode...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _markAsClosingOrHiding(Iterable<int> ids) {
    setState(() {
      _closingIds.addAll(ids);
      _openPositions.removeWhere((p) {
        int pid = int.tryParse(p['id'].toString()) ?? 0;
        return ids.contains(pid);
      });
      _stats['open_count'] = _openPositions.length;
    });
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
      api.getEndpoint('wallet.php?action=get&chain=bsc'),
      api.getEndpoint('wallet.php?action=get&chain=robinhood'),
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
          _chainBalances['solana'] = {'balance': _solBalance, 'usd': solUsd, 'symbol': 'SOL'};
        }

        if (responses[3]['status'] == 'success') {
          final bal = responses[3]['data']['native_balance'] ?? '0.00000';
          final usd = double.tryParse(responses[3]['data']['usd_value']?.toString() ?? '0') ?? 0.0;
          totalUsd += usd;
          _chainBalances['bsc'] = {'balance': bal, 'usd': usd, 'symbol': 'BNB'}; 
        }
        
        if (responses[4]['status'] == 'success') {
          final bal = responses[4]['data']['native_balance'] ?? '0.00000';
          final usd = double.tryParse(responses[4]['data']['usd_value']?.toString() ?? '0') ?? 0.0;
          totalUsd += usd;
          _chainBalances['robinhood'] = {'balance': bal, 'usd': usd, 'symbol': 'ETH'}; 
        }

        _usdValue = totalUsd.toStringAsFixed(2);
        
        if (responses[1]['status'] == 'success') {
          _stats = responses[1]['stats'] ?? _stats;
          
          List<dynamic> rawOpen = responses[1]['open_positions'] ?? [];
          
          _openPositions = rawOpen.where((p) {
            int id = int.tryParse(p['id'].toString()) ?? 0;
            return !_closingIds.contains(id);
          }).toList();
          
          _stats['open_count'] = _openPositions.length;
        }

        if (responses[2]['status'] == 'success') _wallets['solana'] = responses[2]['data']['has_wallet'] == true ? responses[2]['data']['public_address'] : '-';
        if (responses[5]['status'] == 'success') _wallets['bsc'] = responses[5]['data']['has_wallet'] == true ? responses[5]['data']['public_address'] : '-';
        if (responses[6]['status'] == 'success') _wallets['robinhood'] = responses[6]['data']['has_wallet'] == true ? responses[6]['data']['public_address'] : '-';
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

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatFullAddress(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  Future<void> _toggleLock(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;
    
    final isCurrentlyLocked = (p['is_locked'] == 1 || p['is_locked'] == '1');
    final newLockStatus = !isCurrentlyLocked;
    
    setState(() { p['is_locked'] = newLockStatus ? 1 : 0; });
    
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=toggle_lock', {'id': pId, 'is_locked': newLockStatus ? 1 : 0});
    
    if (mounted && res['status'] != 'success') {
      setState(() { p['is_locked'] = isCurrentlyLocked ? 1 : 0; });
      _showFloatingSnackbar(res['message'] ?? 'Failed to sync lock status', isError: true);
    }
  }

  Future<void> _hidePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;

    _markAsClosingOrHiding([pId]);
    await Future.delayed(const Duration(milliseconds: 350));

    final res = await context.read<ApiService>().postEndpoint('positions.php?action=toggle_hide', {'id': pId, 'is_hidden': 1});
    if (mounted) {
      if (res['status'] != 'success') {
        _showFloatingSnackbar(res['message'] ?? 'Failed to hide', isError: true);
        setState(() => _closingIds.remove(pId));
      }
      _fetchDashboardData(silent: true);
    }
  }

  Future<void> _quickClosePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (p['is_locked'] == 1 || p['is_locked'] == '1') {
      _showFloatingSnackbar('Trade is locked! 🔓 Unlock to close.', isError: true);
      return;
    }

    _markAsClosingOrHiding([pId]);
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

    _markAsClosingOrHiding(toClose);
    await Future.delayed(const Duration(milliseconds: 350));

    for (int id in toClose) {
      await api.postEndpoint('trade.php?action=close_position', {'id': id});
    }
    
    if (mounted) _fetchDashboardData(silent: true);
  }

  Future<void> _editLimits(Map<String, dynamic> p) async {
    final tpCtrl = TextEditingController(text: (p['tp_percent'] != null && double.tryParse(p['tp_percent'].toString()) != 0) ? p['tp_percent'].toString() : '');
    final slCtrl = TextEditingController(text: (p['sl_percent'] != null && double.tryParse(p['sl_percent'].toString()) != 0) ? p['sl_percent'].toString() : '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.slidersHorizontalBold, color: theme.primaryColor), const SizedBox(width: 12), Text('Edit Live Targets', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Leave a field blank (or 0) to remove that limit.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))),
                    TextButton.icon(
                      onPressed: () {
                        setStateDialog(() {
                          tpCtrl.clear();
                          slCtrl.clear();
                        });
                      },
                      icon: Icon(PhosphorIcons.trash, size: 14, color: AppTheme.danger(context)),
                      label: Text('Clear All', style: TextStyle(color: AppTheme.danger(context), fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                TextField(controller: tpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Take Profit (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: slCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Stop Loss (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  final tpVal = tpCtrl.text.trim().isEmpty ? '0' : tpCtrl.text.trim();
                  final slVal = slCtrl.text.trim().isEmpty ? '0' : slCtrl.text.trim();
                  final res = await this.context.read<ApiService>().postEndpoint('trade.php?action=update_tpsl', {'id': p['id'], 'tp_percent': tpVal, 'sl_percent': slVal});
                  if (this.mounted) {
                    Navigator.pop(ctx);
                    _showFloatingSnackbar(res['message'] ?? 'Updated', isError: res['status'] != 'success');
                    _fetchDashboardData(silent: true);
                  }
                },
                child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _goLive(Map<String, dynamic> p) async {
    final theme = Theme.of(context);
    final chainName = (p['chain'] ?? 'solana').toString().toUpperCase();
    final defaultAmount = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '20.00';
    
    final amountCtrl = TextEditingController(text: defaultAmount);
    bool removeLimits = false;
    bool isSubmitting = false;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [Icon(PhosphorIcons.lightningFill, color: AppTheme.danger(context)), const SizedBox(width: 8), Text('Go Live on $chainName?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Execute a REAL trade mirroring this token.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 16),
                Text('TRADE AMOUNT (\$)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: Icon(PhosphorIcons.currencyDollar, color: theme.colorScheme.onSurfaceVariant, size: 18),
                    filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 20, 50, 100].map((amt) => InkWell(
                    onTap: () => setStateDialog(() => amountCtrl.text = amt.toStringAsFixed(2)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: Text('\$$amt', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setStateDialog(() => removeLimits = !removeLimits),
                  child: Row(
                    children: [
                      Icon(removeLimits ? PhosphorIcons.checkSquareFill : PhosphorIcons.square, color: removeLimits ? AppTheme.danger(context) : theme.colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Remove all limits (No TP/SL)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                onPressed: isSubmitting ? null : () async {
                  setStateDialog(() => isSubmitting = true);
                  final payload = {
                    'id': p['id'],
                    'trade_usd': amountCtrl.text.trim(),
                  };
                  if (removeLimits) {
                    payload['tp_percent'] = '0';
                    payload['sl_percent'] = '0';
                  }
                  final res = await this.context.read<ApiService>().postEndpoint('trade.php?action=mirror_real', payload);
                  if (this.mounted) {
                    Navigator.pop(ctx, true);
                    final ok = res['status'] == 'success' || res['status'] == 'ok';
                    _showFloatingSnackbar(res['message'] ?? (ok ? 'Live trade executed.' : 'Failed to go live.'), isError: !ok);
                    _fetchDashboardData(silent: true);
                  }
                }, 
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Go Live', style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _launchDexScreener(String address, {String chain = 'solana'}) async {
    final url = Uri.parse('https://dexscreener.com/$chain/$address');
    try { await launchUrl(url, mode: LaunchMode.inAppWebView); } catch (_) {}
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
                  child: Text('Actions', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.storefrontFill, color: AppTheme.success(context)),
                  ),
                  title: Text('Fiat & Crypto Market', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text('Buy, Send, Receive and Cash Out', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isMarketMode = true;
                      _marketTabIndex = 0;
                    });
                  },
                ),
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
                    child: Icon(PhosphorIcons.calculatorFill, color: AppTheme.info(context)),
                  ),
                  title: Text('Exchange Calculator', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text('Calculate USD to Naira dynamically', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(context: context, builder: (ctx) => const CurrencyCalculatorDialog());
                  },
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                    child: Icon(PhosphorIcons.archiveTrayFill, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  title: Text('Hidden Positions', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
                  subtitle: Text('View or restore archived trades', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HiddenPositionsScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatShortAddress(String addr) {
    if (addr == '-') return '-';
    if (addr.length <= 6) return addr;
    return '${addr.substring(0, 3)}...${addr.substring(addr.length - 3)}';
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index, ThemeData theme, bool isMarketMode) {
    final isSelected = (isMarketMode ? _marketTabIndex : _botTabIndex) == index;
    final activeColor = isMarketMode ? AppTheme.success(context) : theme.primaryColor;

    return InkWell(
      onTap: () {
        setState(() {
          if (isMarketMode) {
            _marketTabIndex = index;
          } else {
            _botTabIndex = index;
          }
        });
      },
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
              color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.7), 
              size: 26
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant.withOpacity(0.7), 
              fontSize: 10, 
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
            )
          ),
        ],
      ),
    );
  }

  Widget _buildActionNavItem(ThemeData theme) {
    return InkWell(
      onTap: _pendingMarketMode == null ? _triggerModeSwitch : null,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            key: _switchButtonKey,
            duration: const Duration(milliseconds: 300),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_pendingMarketMode ?? _isMarketMode) ? theme.primaryColor : AppTheme.success(context),
              boxShadow: [
                BoxShadow(
                  color: ((_pendingMarketMode ?? _isMarketMode) ? theme.primaryColor : AppTheme.success(context)).withOpacity(0.4), 
                  blurRadius: 8, 
                  offset: const Offset(0, 2)
                )
              ],
              border: Border.all(color: theme.colorScheme.surface, width: 4),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns: Tween<double>(begin: 0.5, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
                  ),
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
              child: Icon(
                (_pendingMarketMode ?? _isMarketMode) ? PhosphorIcons.robotFill : PhosphorIcons.storefrontFill, 
                key: ValueKey<bool>(_pendingMarketMode ?? _isMarketMode),
                color: Colors.white, 
                size: 22
              ),
            ),
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

    final List<Widget> botPages = [
      _buildPremiumHome(theme, canTrade),
      const PositionsScreen(),
      const CopyBotsScreen(),
      isAdmin ? AdminScreen(viewIndexNotifier: _adminViewIndex) : const SettingsScreen(),
    ];

    final List<Widget> marketPages = [
      MarketDashboardScreen(onNavigate: (idx) => setState(() => _marketTabIndex = idx)),
      const MarketReceiveScreen(),
      const MarketSendCryptoScreen(),
      const MarketCashOutScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isMarketMode) {
          if (_marketTabIndex != 0) {
            setState(() => _marketTabIndex = 0);
          } else {
            setState(() => _isMarketMode = false);
          }
          return;
        } else {
          if (isAdmin && _botTabIndex == 3 && _adminViewIndex.value != 0) {
            _adminViewIndex.value = 0;
            return;
          }
          if (_botTabIndex != 0) {
            setState(() => _botTabIndex = 0);
            return;
          }
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true, 
        resizeToAvoidBottomInset: false,
        body: AnimatedCryptoBackground(
          child: SafeArea(
            bottom: false, 
            child: Stack(
              children: [
                // Base layer: whatever mode is currently active. This
                // flips mid-transition (see the _revealController listener
                // in initState) at the exact instant the wipe below fully
                // covers the screen, so the swap itself is never visible.
                IgnorePointer(
                  ignoring: _pendingMarketMode != null,
                  child: _isMarketMode 
                      ? IndexedStack(key: const ValueKey('market_mode'), index: _marketTabIndex, children: marketPages)
                      : IndexedStack(key: const ValueKey('bot_mode'), index: _botTabIndex, children: botPages),
                ),

                // Wipe layer: only present mid-transition. A solid colored
                // circle grows from the switch button to fully cover the
                // screen, then shrinks away again — it never contains live
                // page content, so Market's and Bot mode's very different
                // layouts are never rendered on screen at the same time.
                if (_pendingMarketMode != null)
                  AnimatedBuilder(
                    animation: _revealController,
                    builder: (context, _) {
                      final size = MediaQuery.of(context).size;
                      final maxRadius = _revealMaxRadius(size);
                      final coverage = _revealCoverage(_revealController.value);
                      final radius = maxRadius * coverage;
                      final targetColor = _pendingMarketMode! ? theme.primaryColor : AppTheme.success(context);

                      return IgnorePointer(
                        child: Stack(
                          children: [
                            ClipPath(
                              clipper: _CircleRevealClipper(center: _revealOrigin ?? Offset(size.width / 2, size.height), radius: radius),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [targetColor.withOpacity(0.92), theme.scaffoldBackgroundColor],
                                  ),
                                ),
                              ),
                            ),
                            // Glowing ring riding the edge of the wipe circle.
                            CustomPaint(
                              size: size,
                              painter: _RevealRingPainter(
                                center: _revealOrigin ?? Offset(size.width / 2, size.height),
                                radius: radius,
                                color: targetColor,
                                opacity: 1.0,
                              ),
                            ),
                            // "Switching to X" announcement: rises in, holds
                            // through the full-cover midpoint, rises out.
                            _buildModeAnnouncement(_pendingMarketMode!, targetColor, theme, size),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: theme.colorScheme.surface,
          elevation: isDark ? 10 : 0, 
          shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.0),
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: (_pendingMarketMode ?? _isMarketMode)
                  ? [
                      _buildNavItem(PhosphorIcons.squaresFour, PhosphorIcons.squaresFourFill, 'Hub', 0, theme, true),
                      _buildNavItem(PhosphorIcons.qrCode, PhosphorIcons.qrCodeFill, 'Receive', 1, theme, true),
                      _buildActionNavItem(theme),
                      _buildNavItem(PhosphorIcons.paperPlaneTilt, PhosphorIcons.paperPlaneTiltFill, 'Send', 2, theme, true),
                      _buildNavItem(PhosphorIcons.bank, PhosphorIcons.bankFill, 'Cash Out', 3, theme, true),
                    ]
                  : [
                      _buildNavItem(PhosphorIcons.squaresFour, PhosphorIcons.squaresFourFill, 'Home', 0, theme, false),
                      _buildNavItem(PhosphorIcons.chartLineUp, PhosphorIcons.chartLineUpFill, 'Trades', 1, theme, false),
                      _buildActionNavItem(theme),
                      _buildNavItem(PhosphorIcons.robot, PhosphorIcons.robotFill, 'Bots', 2, theme, false),
                      if (isAdmin) 
                        _buildNavItem(PhosphorIcons.shieldCheck, PhosphorIcons.shieldCheckFill, 'Admin', 3, theme, false)
                      else 
                        _buildNavItem(PhosphorIcons.gear, PhosphorIcons.gearFill, 'Settings', 3, theme, false),
                    ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHome(ThemeData theme, bool canTrade) {
    final currency = context.watch<CurrencyProvider>(); 
    final isDark = theme.brightness == Brightness.dark;
    final isAdmin = context.read<ApiService>().role == 'admin';

    final double dailyPnl = double.tryParse(_stats['today_pnl']?.toString() ?? '0') ?? 0.0;
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
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
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
                    icon: Icon(PhosphorIcons.dotsThreeCircleFill, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () => _showActionMenu(canTrade),
                  ),
                  IconButton(
                    icon: Icon(isDark ? PhosphorIcons.sunFill : PhosphorIcons.moonFill, color: theme.colorScheme.onSurfaceVariant), 
                    onPressed: () => context.read<ThemeProvider>().toggleTheme(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            children: ['solana', 'bsc', 'robinhood'].map((chain) {
              String addr = _wallets[chain] ?? '-';
              String display = _formatShortAddress(addr);
              Color cColor = _chainColors[chain] ?? theme.primaryColor;
              bool isCopied = _copiedStates[chain] ?? false;
              
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: chain == 'robinhood' ? 0 : 8),
                  child: InkWell(
                    onTap: () {
                      if (addr != '-') {
                        Clipboard.setData(ClipboardData(text: addr));
                        setState(() => _copiedStates[chain] = true);
                        Future.delayed(const Duration(milliseconds: 1500), () {
                          if (mounted) setState(() => _copiedStates[chain] = false);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isCopied ? cColor.withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isCopied ? cColor.withOpacity(0.5) : theme.colorScheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isCopied)
                            Container(
                              width: 14, height: 14,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: cColor.withOpacity(0.15), shape: BoxShape.circle),
                              child: ChainIcon(chain: chain, size: 9, color: cColor),
                            ),
                          if (!isCopied) const SizedBox(width: 6),
                          if (isCopied) Icon(PhosphorIcons.checkCircleFill, size: 14, color: cColor),
                          if (isCopied) const SizedBox(width: 4),
                          Text(
                            isCopied ? 'Copied!' : display, 
                            style: TextStyle(
                              fontFamily: isCopied ? null : 'monospace', 
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: isCopied ? cColor : theme.colorScheme.onSurface
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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
                    Row(
                      children: [
                        if (_isLoading && !_isRefreshing) 
                          Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                          child: Icon(PhosphorIcons.clockCounterClockwiseBold, color: theme.colorScheme.onSurfaceVariant, size: 20),
                        )
                      ],
                    )
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
                const SizedBox(height: 16),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ['solana', 'bsc', 'robinhood'].map((chainId) {
                        final cb = _chainBalances[chainId]!;
                        final rawBalance = double.tryParse(cb['balance'].toString()) ?? 0.0;
                        final usdValue = double.tryParse(cb['usd'].toString()) ?? 0.0;
                        final displaySymbol = {'solana': 'SOL', 'bsc': 'BNB', 'robinhood': 'ETH'}[chainId] ?? 'SOL';
                        
                        return Container(
                          width: cardWidth,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 28, height: 28,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: (_chainColors[chainId] ?? theme.primaryColor).withOpacity(0.12), shape: BoxShape.circle),
                                child: ChainIcon(chain: chainId, size: 16, color: _chainColors[chainId] ?? theme.primaryColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${rawBalance.toStringAsFixed(5)} $displaySymbol', style: TextStyle(color: _chainColors[chainId] ?? theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text('≈ \$${usdValue.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                  ]
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  }
                ),

                const SizedBox(height: 20),
                Container(height: 1, color: theme.colorScheme.outlineVariant),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.trendUpFill, color: isProfit ? AppTheme.success(context) : AppTheme.danger(context), size: 14),
                              const SizedBox(width: 6),
                              Text('DAILY PNL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${isProfit && dailyPnl > 0 ? '+' : ''}\$${dailyPnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? AppTheme.success(context) : AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 16)),
                          if (currency.isNaira)
                            Text('≈ ${isProfit && dailyPnl > 0 ? '+' : ''}${currency.format(dailyPnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: isProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                        ]
                      )
                    ),
                    Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.chartBarFill, color: AppTheme.info(context), size: 14),
                              const SizedBox(width: 6),
                              Text('OPEN TRADES', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('${_stats['open_count'] ?? 0}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                        ]
                      )
                    ),
                  ],
                ),
              ],
            ),
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
              padding: EdgeInsets.zero,
              child: Column(
                children: _openPositions.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var p = entry.value;
                  
                  final double? cpnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '');
                  final bool cpIsProfit = (cpnl ?? 0) >= 0;
                  final pId = int.tryParse(p['id'].toString()) ?? 0;
                  final bool isClosing = _closingIds.contains(pId);
                  final bool isLocked = p['is_locked'] == 1 || p['is_locked'] == '1';
                  
                  String botName = p['display_name'] ?? 'Manual';
                  if (isAdmin && botName != 'Manual') botName = botName.toUpperCase();

                  final String chainRaw = (p['chain'] ?? 'solana').toString().toLowerCase();
                  final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
                  final Color chainColor = _chainColors[chainRaw] ?? AppTheme.kainuwaPurple;
                  
                  final bool isReal = p['is_real'] == 1 || p['is_real'] == '1';
                  final double tp = double.tryParse(p['tp_percent']?.toString() ?? '0') ?? 0.0;
                  final double sl = double.tryParse(p['sl_percent']?.toString() ?? '0') ?? 0.0;
                  final double size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                  final double pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;

                  return Column(
                    children: [
                      if (idx > 0) Divider(color: theme.colorScheme.outlineVariant, height: 1),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: isClosing
                            ? const SizedBox(width: double.infinity, height: 0)
                            : AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: isClosing ? 0.0 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _toggleLock(p),
                                            child: Icon(isLocked ? PhosphorIcons.lockKeyFill : PhosphorIcons.lockKeyOpen, color: isLocked ? AppTheme.warning(context) : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(_formatFullAddress(p['token_address']), style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: chainColor.withOpacity(0.3))),
                                            child: Text(chainLabel, style: TextStyle(fontSize: 8, color: chainColor, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)), 
                                              child: Text(botName, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(isReal ? 'LIVE' : '📄', style: TextStyle(color: isReal ? AppTheme.danger(context) : theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      Text(
                                        cpnl != null ? '${cpIsProfit && cpnl > 0 ? '+' : ''}\$${cpnl.toStringAsFixed(2)} (${cpIsProfit && cpnl > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)' : '-',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cpIsProfit ? AppTheme.success(context) : AppTheme.danger(context)),
                                      ),
                                      if (currency.isNaira && cpnl != null)
                                        Text('≈ ${cpIsProfit && cpnl > 0 ? '+' : ''}${currency.format(cpnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: cpIsProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8))),
                                      const SizedBox(height: 8),

                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Size: \$${size.toStringAsFixed(2)} • Entry: ${_formatMcap(p['entry_mcap'])} • Live: ${_formatMcap(p['current_mcap'])}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                                const SizedBox(height: 2),
                                                Text('TP: ${tp > 0 ? "+$tp%" : "None"} • SL: ${sl > 0 ? "-$sl%" : "None"}', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _hidePosition(p),
                                                child: Icon(PhosphorIcons.eyeSlashFill, color: theme.colorScheme.onSurfaceVariant, size: 20),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _editLimits(p),
                                                child: Icon(PhosphorIcons.slidersHorizontalBold, color: theme.colorScheme.onSurface, size: 20),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _launchDexScreener(p['token_address'] ?? '', chain: p['chain'] ?? 'solana'),
                                                child: Icon(PhosphorIcons.arrowSquareOutBold, color: theme.colorScheme.onSurface, size: 20),
                                              ),
                                              if (!isReal) ...[
                                                const SizedBox(width: 16),
                                                GestureDetector(
                                                  onTap: () => _goLive(p),
                                                  child: Icon(PhosphorIcons.lightningFill, color: AppTheme.success(context), size: 22),
                                                ),
                                              ],
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _quickClosePosition(p),
                                                child: Icon(PhosphorIcons.xCircleFill, color: AppTheme.danger(context), size: 24),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
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

// Clips content to a circle centered at [center] with the given [radius].
// Used to grow the incoming mode's content out from the switch button.
class _CircleRevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _CircleRevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(_CircleRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

// Draws a soft glowing ring right at the edge of the expanding reveal
// circle — the little "energy" touch that sells the portal effect, fading
// out as the circle finishes covering the screen.
class _RevealRingPainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;
  final double opacity;

  _RevealRingPainter({required this.center, required this.radius, required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0 || radius <= 0) return;

    final glowPaint = Paint()
      ..color = color.withOpacity(0.5 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius, glowPaint);

    final ringPaint = Paint()
      ..color = color.withOpacity(0.9 * opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(_RevealRingPainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius || oldDelegate.opacity != opacity;
  }
}
