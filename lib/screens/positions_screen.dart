import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';

enum TradeEnvironment { all, real, paper }

class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  bool _isLoading = true;
  bool _isManualRefreshing = false;
  List<dynamic> _openPositions = [];
  Timer? _pollingTimer;
  final Set<int> _closingIds = {};

  TradeEnvironment _selectedEnv = TradeEnvironment.all;
  
  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

  @override
  void initState() {
    super.initState();
    _fetchPositions();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchPositions(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPositions({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _openPositions = res['open_positions'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  bool _passesEnvFilter(dynamic p) {
    final isReal = p['is_real'] == 1 || p['is_real'] == '1';
    if (_selectedEnv == TradeEnvironment.real && !isReal) return false;
    if (_selectedEnv == TradeEnvironment.paper && isReal) return false;
    return true;
  }

  Future<void> _launchDexScreener(String address, {String chain = 'solana'}) async {
    final url = Uri.parse('https://dexscreener.com/$chain/$address');
    try { await launchUrl(url, mode: LaunchMode.inAppWebView); } catch (_) {}
  }

  String formatLagosTime(String? utcString) {
    if (utcString == null || utcString.isEmpty) return '-';
    try {
      String formattedStr = utcString.replaceAll(' ', 'T');
      if (!formattedStr.endsWith('Z')) formattedStr += 'Z';
      final dt = DateTime.parse(formattedStr).add(const Duration(hours: 1)); 
      final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '$hour12:$min $period, ${months[dt.month - 1]} ${dt.day}';
    } catch (_) { return utcString; }
  }

  String calculateTimeInTrade(String? openedAtStr) {
    if (openedAtStr == null || openedAtStr.isEmpty) return '-';
    try {
      String startStr = openedAtStr.replaceAll(' ', 'T');
      if (!startStr.endsWith('Z')) startStr += 'Z';
      final start = DateTime.parse(startStr);
      DateTime end = DateTime.now().toUtc();

      final diff = end.difference(start);
      if (diff.inMinutes < 1) return '< 1m';

      List<String> parts = [];
      if (diff.inDays > 0) parts.add('${diff.inDays}d');
      if (diff.inHours % 24 > 0) parts.add('${diff.inHours % 24}h');
      if (diff.inMinutes % 60 > 0) parts.add('${diff.inMinutes % 60}m');
      return parts.join(' ');
    } catch (_) { return '-'; }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = double.tryParse(v.toString()) ?? 0.0;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to sync lock status', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
    }
  }

  Future<void> _closeSinglePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (p['is_locked'] == 1 || p['is_locked'] == '1') {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Trade is locked! 🔓 Unlock to close.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
      return;
    }
    
    setState(() => _closingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350));

    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': pId});
    if (mounted) {
      if (res['status'] != 'success' && res['status'] != 'closed') {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
         setState(() => _closingIds.remove(pId));
      }
      _fetchPositions(silent: true);
    }
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
                Text('Leave a field blank (or 0) to remove that limit.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
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
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Updated', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: res['status'] == 'success' ? AppTheme.success(this.context) : AppTheme.danger(this.context)));
                    _fetchPositions(silent: true);
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

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(PhosphorIcons.lightningFill, color: AppTheme.danger(context)), const SizedBox(width: 8), Text('Go Live on $chainName?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]),
        content: Text('This executes an instant REAL trade on this token using your master wallet, mirroring this paper position\'s size and TP/SL. Real funds — cannot be undone.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: const Text('Go Live Now', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final res = await context.read<ApiService>().postEndpoint('trade.php?action=mirror_real', {'id': p['id']});
    if (mounted) {
      final ok = res['status'] == 'success' || res['status'] == 'ok';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? (ok ? 'Live trade executed.' : 'Failed to go live.'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: ok ? AppTheme.success(context) : AppTheme.danger(context),
      ));
      _fetchPositions(silent: true);
    }
  }

  Future<void> _executeBatchClose(List<int> ids, String description) async {
    final api = context.read<ApiService>();
    List<int> unlockedIds = ids.where((id) {
      final item = _openPositions.firstWhere((p) => (int.tryParse(p['id'].toString()) ?? 0) == id, orElse: () => null);
      if (item == null) return true;
      return !(item['is_locked'] == 1 || item['is_locked'] == '1');
    }).toList();
    
    if (unlockedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('All selected trades are locked! 🔓', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
      return;
    }

    final theme = Theme.of(context);
    final dangerColor = AppTheme.danger(context);
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(children: [Icon(PhosphorIcons.warningCircleFill, color: dangerColor), const SizedBox(width: 8), Text('Close $description?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16))]),
        content: Text('Are you sure you want to close ${unlockedIds.length} open position(s)? Locked trades are ignored.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: dangerColor, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: Text('Close ${unlockedIds.length} Trade(s)', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    
    setState(() => _closingIds.addAll(unlockedIds));
    await Future.delayed(const Duration(milliseconds: 350));

    int successCount = 0;

    for (int id in unlockedIds) {
      try {
        final res = await api.postEndpoint('trade.php?action=close_position', {'id': id});
        if (res['status'] == 'success' || res['status'] == 'closed') successCount++;
      } catch (e) { print(e); }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully closed $successCount / ${unlockedIds.length} trades.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.success(context)));
      _fetchPositions(silent: true);
    }
  }

  void _showBatchCloseSheet(CurrencyProvider currency) {
    final theme = Theme.of(context);
    List<int> allIds = [], manualIds = [], copyIds = [], profitIds = [], lossIds = [], liveIds = [], paperIds = [];
    double totalProfitUsd = 0.0, totalLossUsd = 0.0;
    Map<String, List<int>> botToIdsMap = {};

    for (var p in _openPositions.where(_passesEnvFilter)) {
      final id = int.tryParse(p['id'].toString()) ?? 0;
      if (id <= 0) continue;
      
      if (p['is_locked'] == 1 || p['is_locked'] == '1') continue;

      allIds.add(id);
      final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
      final isReal = p['is_real'] == 1 || p['is_real'] == '1';
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';
      final botName = p['display_name'] ?? 'Manual';

      if (isReal) liveIds.add(id); else paperIds.add(id);
      if (pnl > 0) { totalProfitUsd += pnl; profitIds.add(id); } else if (pnl < 0) { totalLossUsd += pnl; lossIds.add(id); }
      if (isCopy) { copyIds.add(id); botToIdsMap.putIfAbsent(botName.toString(), () => []).add(id); } else { manualIds.add(id); }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [Icon(PhosphorIcons.handPalmFill, color: AppTheme.danger(context)), const SizedBox(width: 8), Text('Batch Close Manager', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18))]),
                    IconButton(icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
                const SizedBox(height: 24),

                _buildBatchTile(theme: theme, title: 'Close All Open Trades', subtitle: '${allIds.length} trade(s) active', icon: PhosphorIcons.trashFill, color: AppTheme.danger(context), count: allIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(allIds, 'All Open Trades'); }),
                if (liveIds.isNotEmpty) _buildBatchTile(theme: theme, title: 'Close All Live Trades', subtitle: 'Exits real money trades', icon: PhosphorIcons.lightningFill, color: AppTheme.warning(context), count: liveIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(liveIds, 'Live Trades'); }),
                if (paperIds.isNotEmpty) _buildBatchTile(theme: theme, title: 'Close All Paper Trades', subtitle: 'Exits paper simulation trades', icon: PhosphorIcons.newspaperFill, color: theme.colorScheme.onSurfaceVariant, count: paperIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(paperIds, 'Paper Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Profits Only', subtitle: profitIds.isEmpty ? 'No profit trades' : '+\$${totalProfitUsd.toStringAsFixed(2)}', icon: PhosphorIcons.trendUpFill, color: AppTheme.success(context), count: profitIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(profitIds, 'Profitable Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Losses Only', subtitle: lossIds.isEmpty ? 'No loss trades' : '-\$${totalLossUsd.abs().toStringAsFixed(2)}', icon: PhosphorIcons.trendDownFill, color: const Color(0xFFE11D48), count: lossIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(lossIds, 'Loss Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Manual Trades', subtitle: 'Trades placed by you', icon: PhosphorIcons.userFill, color: const Color(0xFF9333EA), count: manualIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(manualIds, 'Manual Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Copy Trades', subtitle: 'Automated mirror trades', icon: PhosphorIcons.robotFill, color: AppTheme.info(context), count: copyIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(copyIds, 'Copy Trades'); }),

                if (botToIdsMap.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('CLOSE BY BOT / SHARK', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  ...botToIdsMap.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      onTap: () { Navigator.pop(ctx); _executeBatchClose(entry.value, 'Bot ${entry.key}'); },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [Icon(PhosphorIcons.robot, color: AppTheme.info(context), size: 18), const SizedBox(width: 12), Text(entry.key, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text('Close ${entry.value.length}', style: TextStyle(color: AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 12)))
                        ]),
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchTile({required ThemeData theme, required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: count > 0 ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: count > 0 ? color.withOpacity(0.15) : theme.colorScheme.outlineVariant)
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10), 
                decoration: BoxDecoration(color: color.withOpacity(count > 0 ? 0.12 : 0.05), shape: BoxShape.circle), 
                child: Icon(icon, color: count > 0 ? color : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 20)
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Text(title, style: TextStyle(color: count > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14)), 
                    const SizedBox(height: 2), 
                    Text(subtitle, style: TextStyle(color: count > 0 ? color : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600))
                  ]
                )
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outlineVariant)), 
                child: Text('$count', style: TextStyle(color: count > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 12))
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnvChip(String label, TradeEnvironment env, ThemeData theme) {
    final isSelected = _selectedEnv == env;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedEnv = env),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : theme.colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final apiService = context.watch<ApiService>();
    final isAdmin = apiService.role == 'admin';

    final finalOpenList = _openPositions.where(_passesEnvFilter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('OPEN POSITIONS', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isManualRefreshing 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                : Icon(PhosphorIcons.arrowsClockwiseBold, color: theme.colorScheme.onSurfaceVariant, size: 20),
            onPressed: _isManualRefreshing ? null : () async {
              setState(() => _isManualRefreshing = true);
              await _fetchPositions(silent: true);
              if (mounted) setState(() => _isManualRefreshing = false);
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor.withOpacity(0.12),
                foregroundColor: theme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(PhosphorIcons.clockCounterClockwiseBold, size: 16),
              label: const Text('History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(children: [
              _buildEnvChip('All Open', TradeEnvironment.all, theme),
              const SizedBox(width: 12),
              _buildEnvChip('Real', TradeEnvironment.real, theme),
              const SizedBox(width: 12),
              _buildEnvChip('Paper', TradeEnvironment.paper, theme),
            ]),
          ),

          if (finalOpenList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.danger(context).withOpacity(0.5)), 
                    foregroundColor: AppTheme.danger(context), 
                    backgroundColor: AppTheme.danger(context).withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                  ),
                  onPressed: () => _showBatchCloseSheet(currency),
                  icon: const Icon(PhosphorIcons.handPalmFill, size: 18),
                  label: Text('Batch Close Manager (${finalOpenList.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),

          Expanded(
            child: _isLoading && finalOpenList.isEmpty
              ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
              : finalOpenList.isEmpty 
                ? Center(child: Text('No active open positions.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                    itemCount: finalOpenList.length,
                    itemBuilder: (context, index) {
                      final p = finalOpenList[index];
                      final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
                      final pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;
                      final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                      final pId = int.tryParse(p['id'].toString()) ?? 0;
                      final bool isClosing = _closingIds.contains(pId);
                      final bool isLocked = p['is_locked'] == 1 || p['is_locked'] == '1';

                      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
                      
                      String mainTitle = 'Manual Trade';
                      String? adminBadge;

                      if (isCopy) {
                         String label = p['wallet_label']?.toString() ?? '';
                         final botIdRaw = p['bot_id']?.toString();
                         final sysBotName = (botIdRaw != null && botIdRaw.isNotEmpty && botIdRaw != 'null') ? 'Bot ${botIdRaw.padLeft(2, '0')}' : 'Bot';

                         if (isAdmin && label.isNotEmpty && label != 'Manual') {
                            mainTitle = label.toUpperCase(); 
                            adminBadge = sysBotName;
                         } else {
                            mainTitle = sysBotName; 
                         }
                      }

                      final String chainRaw = (p['chain'] ?? 'solana').toString().toLowerCase();
                      final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
                      final Color chainColor = _chainColors[chainRaw] ?? AppTheme.kainuwaPurple;

                      return AnimatedSize(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        child: isClosing
                            ? const SizedBox(width: double.infinity, height: 0)
                            : AnimatedOpacity(
                                duration: const Duration(milliseconds: 250),
                                opacity: isClosing ? 0.0 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: GlassCard(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
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
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isReal ? AppTheme.danger(context).withOpacity(0.12) : AppTheme.warning(context).withOpacity(0.12), 
                                                borderRadius: BorderRadius.circular(8), 
                                                border: Border.all(color: isReal ? AppTheme.danger(context).withOpacity(0.3) : AppTheme.warning(context).withOpacity(0.3))
                                              ),
                                              child: isReal
                                                  ? Text('LIVE', style: TextStyle(color: AppTheme.danger(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
                                                  : const Text('📄', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            Text(_formatFullAddress(p['token_address'] ?? ''), style: TextStyle(color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: chainColor.withOpacity(0.3))),
                                              child: Text(chainLabel, style: TextStyle(fontSize: 9, color: chainColor, fontWeight: FontWeight.bold)),
                                            ),
                                            if (adminBadge != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)), 
                                                child: Text(adminBadge, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))
                                              ),
                                          ],
                                        ),
                                        
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8, bottom: 20),
                                          child: Text(mainTitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13)),
                                        ),
                                        
                                        Row(
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRY MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(p['entry_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('LIVE MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(p['current_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        Row(
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text('TP TARGET', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                              Text((double.tryParse(p['tp_percent']?.toString() ?? '0') ?? 0) > 0 ? '+${p['tp_percent']}%' : 'No limit', style: TextStyle(color: (double.tryParse(p['tp_percent']?.toString() ?? '0') ?? 0) > 0 ? AppTheme.success(context) : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14)),
                                            ])),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text('SL TARGET', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                              Text((double.tryParse(p['sl_percent']?.toString() ?? '0') ?? 0) > 0 ? '-${p['sl_percent']}%' : 'No limit', style: TextStyle(color: (double.tryParse(p['sl_percent']?.toString() ?? '0') ?? 0) > 0 ? AppTheme.danger(context) : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14)),
                                            ])),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        Row(
                                          children: [
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text('UNREALIZED P&L', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                              Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 14)),
                                              if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 11)),
                                            ])),
                                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text('TRADE SIZE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                              Text('\$${double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                                              if (currency.isNaira) Text('≈ ${currency.format(p['virtual_usd_amount'])}', style: TextStyle(color: AppTheme.success(context).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold)),
                                            ])),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Container(height: 1, color: theme.colorScheme.outlineVariant),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Icon(PhosphorIcons.clock, color: theme.colorScheme.onSurfaceVariant, size: 14),
                                            const SizedBox(width: 6),
                                            Text('${calculateTimeInTrade(p['opened_at'])} • ${formatLagosTime(p['opened_at'])}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        Row(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                              ),
                                              child: IconButton(
                                                onPressed: () => _editLimits(p),
                                                icon: Icon(PhosphorIcons.slidersHorizontalBold, color: theme.colorScheme.onSurface, size: 18),
                                                tooltip: 'Edit TP/SL',
                                                padding: const EdgeInsets.all(14),
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                              ),
                                              child: IconButton(
                                                onPressed: () => _launchDexScreener(p['token_address'] ?? '', chain: p['chain'] ?? 'solana'),
                                                icon: Icon(PhosphorIcons.arrowSquareOutBold, color: theme.colorScheme.onSurface, size: 18),
                                                tooltip: 'DexScreener',
                                                padding: const EdgeInsets.all(14),
                                                constraints: const BoxConstraints(),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            if (!isReal) ...[
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    side: BorderSide(color: AppTheme.success(context).withOpacity(0.5)),
                                                    foregroundColor: AppTheme.success(context),
                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                                  ),
                                                  onPressed: () => _goLive(p),
                                                  icon: const Icon(PhosphorIcons.lightningFill, size: 18),
                                                  label: const Text('Go Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                            ],
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(color: AppTheme.danger(context).withOpacity(0.5)), 
                                                  foregroundColor: AppTheme.danger(context),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                                ), 
                                                onPressed: () => _closeSinglePosition(p), 
                                                icon: const Icon(PhosphorIcons.handPalm, size: 18), 
                                                label: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
