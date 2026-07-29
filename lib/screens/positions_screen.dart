import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
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

  // Global Filter
  TradeEnvironment _selectedEnv = TradeEnvironment.all;

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

  Future<void> _launchDexScreener(String address) async {
    final url = Uri.parse('https://dexscreener.com/solana/$address');
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

  String _formatAddress(String addr) => addr.length <= 12 ? addr : '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';

  Future<void> _closeSinglePosition(int id) async {
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': id});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action complete')));
      _fetchPositions(silent: true);
    }
  }

  Future<void> _executeBatchClose(List<int> ids, String description) async {
    if (ids.isEmpty) return;

    final theme = Theme.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(children: [const Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent), const SizedBox(width: 8), Text('Close $description?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16))]),
        content: Text('Are you sure you want to close ${ids.length} open position(s)?', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx, true), child: Text('Close ${ids.length} Trade(s)', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);

    int successCount = 0;
    final api = context.read<ApiService>();

    for (int id in ids) {
      try {
        final res = await api.postEndpoint('trade.php?action=close_position', {'id': id});
        if (res['status'] == 'success' || res['status'] == 'closed') successCount++;
      } catch (e) { print(e); }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully closed $successCount / ${ids.length} trades.'), backgroundColor: Colors.green));
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

      allIds.add(id);
      final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
      final isReal = p['is_real'] == 1 || p['is_real'] == '1';
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';
      final botName = p['wallet_label'] ?? 'Manual';

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
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [const Icon(PhosphorIcons.handPalmFill, color: Colors.redAccent), const SizedBox(width: 8), Text('Batch Close Manager', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18))]),
                    IconButton(icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 18), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
                const SizedBox(height: 20),

                _buildBatchTile(theme: theme, title: 'Close All Open Trades', subtitle: '${allIds.length} trade(s) active', icon: PhosphorIcons.trashFill, color: Colors.redAccent, count: allIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(allIds, 'All Open Trades'); }),
                if (liveIds.isNotEmpty) _buildBatchTile(theme: theme, title: 'Close All Live Trades', subtitle: 'Exits real money trades', icon: PhosphorIcons.lightningFill, color: Colors.amberAccent, count: liveIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(liveIds, 'Live Trades'); }),
                if (paperIds.isNotEmpty) _buildBatchTile(theme: theme, title: 'Close All Paper Trades', subtitle: 'Exits paper simulation trades', icon: PhosphorIcons.newspaperFill, color: Colors.orangeAccent, count: paperIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(paperIds, 'Paper Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Profits Only', subtitle: profitIds.isEmpty ? 'No profit trades' : '+\$${totalProfitUsd.toStringAsFixed(2)}', icon: PhosphorIcons.trendUpFill, color: Colors.greenAccent, count: profitIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(profitIds, 'Profitable Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Losses Only', subtitle: lossIds.isEmpty ? 'No loss trades' : '-\$${totalLossUsd.abs().toStringAsFixed(2)}', icon: PhosphorIcons.trendDownFill, color: Colors.pinkAccent, count: lossIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(lossIds, 'Loss Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Manual Trades', subtitle: 'Trades placed by you', icon: PhosphorIcons.userFill, color: Colors.purpleAccent, count: manualIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(manualIds, 'Manual Trades'); }),
                _buildBatchTile(theme: theme, title: 'Close All Copy Trades', subtitle: 'Automated mirror trades', icon: PhosphorIcons.robotFill, color: Colors.blueAccent, count: copyIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(copyIds, 'Copy Trades'); }),

                if (botToIdsMap.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('CLOSE BY BOT / SHARK', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ...botToIdsMap.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () { Navigator.pop(ctx); _executeBatchClose(entry.value, 'Bot ${entry.key}'); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 16), const SizedBox(width: 8), Text(entry.key, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Text('Close ${entry.value.length}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)))
                        ]),
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBatchTile({required ThemeData theme, required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: count > 0 ? theme.colorScheme.onSurface.withOpacity(0.05) : theme.colorScheme.onSurface.withOpacity(0.02), borderRadius: BorderRadius.circular(14), border: Border.all(color: count > 0 ? color.withOpacity(0.2) : Colors.transparent)),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(count > 0 ? 0.15 : 0.05), shape: BoxShape.circle), child: Icon(icon, color: count > 0 ? color : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: count > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: count > 0 ? color : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text('$count', style: TextStyle(color: count > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontWeight: FontWeight.bold, fontSize: 11))),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : theme.colorScheme.onSurface.withOpacity(0.1)),
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
    final isAdmin = context.read<ApiService>().role == 'admin';

    final finalOpenList = _openPositions.where(_passesEnvFilter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent, // Background handled by Dashboard
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('OPEN POSITIONS', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isManualRefreshing 
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor))
                : Icon(PhosphorIcons.arrowsClockwiseBold, color: theme.colorScheme.onSurface, size: 20),
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
                backgroundColor: theme.primaryColor.withOpacity(0.15),
                foregroundColor: theme.primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
              icon: const Icon(PhosphorIcons.clockCounterClockwiseBold, size: 18),
              label: const Text('Trade History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              _buildEnvChip('All Open', TradeEnvironment.all, theme),
              const SizedBox(width: 8),
              _buildEnvChip('Real', TradeEnvironment.real, theme),
              const SizedBox(width: 8),
              _buildEnvChip('Paper', TradeEnvironment.paper, theme),
            ]),
          ),

          if (finalOpenList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _showBatchCloseSheet(currency),
                  icon: const Icon(PhosphorIcons.handPalmFill, size: 18),
                  label: Text('Batch Close Manager (${finalOpenList.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ),

          Expanded(
            child: _isLoading && finalOpenList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : finalOpenList.isEmpty 
                ? Center(child: Text('No active open positions.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: finalOpenList.length,
                    itemBuilder: (context, index) {
                      final p = finalOpenList[index];
                      final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
                      final pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;
                      final isReal = p['is_real'] == 1 || p['is_real'] == '1';

                      // PERFECTED BOT BADGE LOGIC
                      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
                      
                      String mainTitle = 'Manual Trade';
                      String? adminBadge;

                      if (isCopy) {
                         String label = p['wallet_label']?.toString() ?? ''; // The real Shark Name
                         final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
                         final sysBotName = (botIdRaw != null && botIdRaw.isNotEmpty) ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';

                         if (isAdmin && label.isNotEmpty && label != 'Manual') {
                            mainTitle = label; // Admin sees Shark Name
                            adminBadge = '🤖 $sysBotName'; // Admin sees Bot ID badge
                         } else {
                            mainTitle = sysBotName; // Users only see "System Bot 02"
                            // Users see NO adminBadge
                         }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Identity & Badges
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(mainTitle, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (adminBadge != null)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blueAccent.withOpacity(0.2))),
                                        child: Text(adminBadge, style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => _launchDexScreener(p['token_address'] ?? ''),
                                    child: Row(children: [Text(_formatAddress(p['token_address'] ?? ''), style: const TextStyle(color: Colors.blueAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 4), const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 14)]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isReal ? Colors.redAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: isReal ? Colors.redAccent.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.3))),
                                    child: Text(isReal ? 'LIVE' : 'PAPER', style: TextStyle(color: isReal ? Colors.redAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              Row(
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRY MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['entry_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13))])),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('LIVE MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['current_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13))])),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('UNREALIZED P&L', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4),
                                    Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 10)),
                                  ])),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('TRADE SIZE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4),
                                    Text('\$${double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                                    if (currency.isNaira) Text('≈ ${currency.format(p['virtual_usd_amount'])}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ])),
                                ],
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  Icon(PhosphorIcons.clock, color: theme.primaryColor, size: 12),
                                  const SizedBox(width: 4),
                                  Text('${calculateTimeInTrade(p['opened_at'])} • ${formatLagosTime(p['opened_at'])}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Column(
                                children: [
                                  SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), foregroundColor: Colors.redAccent), onPressed: () => _closeSinglePosition(p['id']), icon: const Icon(PhosphorIcons.handPalm, size: 16), label: const Text('Close Trade Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                                ],
                              )
                            ],
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
