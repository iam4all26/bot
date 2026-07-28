import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';

enum ClosedFilterType { all, profit, loss, copy, manual }
enum DateRangeFilter { allTime, today, last7Days, last30Days }
enum TradeEnvironment { all, real, paper }

class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  bool _isLoading = true;
  List<dynamic> _openPositions = [];
  List<dynamic> _closedPositions = [];

  // Global Filter
  TradeEnvironment _selectedEnv = TradeEnvironment.all;

  // Filters for Closed Positions Tab
  String _closedSearchQuery = '';
  ClosedFilterType _selectedClosedType = ClosedFilterType.all;
  String? _selectedClosedBot; 
  DateRangeFilter _selectedDateFilter = DateRangeFilter.allTime;

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  Future<void> _fetchPositions() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _openPositions = res['open_positions'] ?? [];
          _closedPositions = res['closed_positions'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  // --- Helpers & Logic --- //

  Map<String, double> get _botWinRates {
    Map<String, int> totals = {};
    Map<String, int> wins = {};

    for (var p in _closedPositions) {
      final name = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
      final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      final isWin = pnl > 0 || p['close_reason'] == 'TP_HIT';

      totals[name] = (totals[name] ?? 0) + 1;
      if (isWin) wins[name] = (wins[name] ?? 0) + 1;
    }

    Map<String, double> rates = {};
    totals.forEach((name, total) {
      rates[name] = ((wins[name] ?? 0) / total) * 100;
    });
    return rates;
  }

  String _getBotDisplayName(dynamic p) {
    String rawName = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
    if (rawName == 'Manual') return rawName;
    if (_botWinRates.containsKey(rawName)) {
      return '$rawName • ${_botWinRates[rawName]!.toStringAsFixed(1)}% Win Rate';
    }
    return rawName;
  }

  bool _passesEnvFilter(dynamic p) {
    final isReal = p['is_real'] == 1 || p['is_real'] == '1';
    if (_selectedEnv == TradeEnvironment.real && !isReal) return false;
    if (_selectedEnv == TradeEnvironment.paper && isReal) return false;
    return true;
  }

  String _formatMonthYear(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown Date';
    try {
      DateTime dt = DateTime.parse(dateStr.replaceAll(' ', 'T') + (dateStr.endsWith('Z') ? '' : 'Z')).toLocal();
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return 'Unknown Date'; }
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

  String calculateTimeInTrade(String? openedAtStr, [String? closedAtStr]) {
    if (openedAtStr == null || openedAtStr.isEmpty) return '-';
    try {
      String startStr = openedAtStr.replaceAll(' ', 'T');
      if (!startStr.endsWith('Z')) startStr += 'Z';
      final start = DateTime.parse(startStr);
      DateTime end = closedAtStr != null && closedAtStr.isNotEmpty 
          ? DateTime.parse(closedAtStr.replaceAll(' ', 'T') + (closedAtStr.endsWith('Z') ? '' : 'Z')) 
          : DateTime.now().toUtc();

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

  // --- API Handlers --- //

  Future<void> _closeSinglePosition(int id) async {
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': id});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Action complete')));
      _fetchPositions();
    }
  }

  Future<void> _executeBatchClose(List<int> ids, String description) async {
    if (ids.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: Row(children: [const Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent), const SizedBox(width: 8), Text('Close $description?', style: const TextStyle(color: Colors.white, fontSize: 16))]),
        content: Text('Are you sure you want to close ${ids.length} open position(s)?', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: Text('Close ${ids.length} Trade(s)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
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
      _fetchPositions();
    }
  }

  void _showBatchCloseSheet(CurrencyProvider currency) {
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
      final botName = p['display_name'] ?? p['wallet_label'] ?? 'Manual';

      if (isReal) liveIds.add(id); else paperIds.add(id);
      if (pnl > 0) { totalProfitUsd += pnl; profitIds.add(id); } else if (pnl < 0) { totalLossUsd += pnl; lossIds.add(id); }
      if (isCopy) { copyIds.add(id); botToIdsMap.putIfAbsent(botName, () => []).add(id); } else { manualIds.add(id); }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
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
                    const Row(children: [Icon(PhosphorIcons.handPalmFill, color: Colors.redAccent), SizedBox(width: 8), Text('Batch Close Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
                    IconButton(icon: const Icon(PhosphorIcons.xBold, color: Colors.white54, size: 18), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
                const SizedBox(height: 20),

                _buildBatchTile(title: 'Close All Open Trades', subtitle: '${allIds.length} trade(s) active', icon: PhosphorIcons.trashFill, color: Colors.redAccent, count: allIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(allIds, 'All Open Trades'); }),
                if (liveIds.isNotEmpty) _buildBatchTile(title: 'Close All Live Trades', subtitle: 'Exits real money trades', icon: PhosphorIcons.lightningFill, color: Colors.amberAccent, count: liveIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(liveIds, 'Live Trades'); }),
                if (paperIds.isNotEmpty) _buildBatchTile(title: 'Close All Paper Trades', subtitle: 'Exits paper simulation trades', icon: PhosphorIcons.newspaperFill, color: Colors.orangeAccent, count: paperIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(paperIds, 'Paper Trades'); }),
                _buildBatchTile(title: 'Close All Profits Only', subtitle: profitIds.isEmpty ? 'No profit trades' : '+\$${totalProfitUsd.toStringAsFixed(2)}', icon: PhosphorIcons.trendUpFill, color: Colors.greenAccent, count: profitIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(profitIds, 'Profitable Trades'); }),
                _buildBatchTile(title: 'Close All Losses Only', subtitle: lossIds.isEmpty ? 'No loss trades' : '-\$${totalLossUsd.abs().toStringAsFixed(2)}', icon: PhosphorIcons.trendDownFill, color: Colors.pinkAccent, count: lossIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(lossIds, 'Loss Trades'); }),
                _buildBatchTile(title: 'Close All Manual Trades', subtitle: 'Trades placed by you', icon: PhosphorIcons.userFill, color: Colors.purpleAccent, count: manualIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(manualIds, 'Manual Trades'); }),
                _buildBatchTile(title: 'Close All Copy Trades', subtitle: 'Automated mirror trades', icon: PhosphorIcons.robotFill, color: Colors.blueAccent, count: copyIds.length, onTap: () { Navigator.pop(ctx); _executeBatchClose(copyIds, 'Copy Trades'); }),

                if (botToIdsMap.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('CLOSE BY BOT / SHARK', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  ...botToIdsMap.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () { Navigator.pop(ctx); _executeBatchClose(entry.value, 'Bot ${entry.key}'); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 16), const SizedBox(width: 8), Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))]),
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

  Widget _buildBatchTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, required int count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: count > 0 ? Colors.black38 : Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(14), border: Border.all(color: count > 0 ? color.withOpacity(0.2) : Colors.transparent)),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(count > 0 ? 0.15 : 0.05), shape: BoxShape.circle), child: Icon(icon, color: count > 0 ? color : Colors.white24, size: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: count > 0 ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 14)), const SizedBox(height: 2), Text(subtitle, style: TextStyle(color: count > 0 ? color : Colors.white24, fontSize: 11, fontWeight: FontWeight.bold))])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)), child: Text('$count', style: TextStyle(color: count > 0 ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> get _filteredClosedPositions {
    final now = DateTime.now();

    return _closedPositions.where((p) {
      if (!_passesEnvFilter(p)) return false;

      if (_closedSearchQuery.isNotEmpty) {
        final query = _closedSearchQuery.toLowerCase();
        final addr = (p['token_address'] ?? '').toString().toLowerCase();
        final label = (p['wallet_label'] ?? '').toString().toLowerCase();
        final display = (p['display_name'] ?? '').toString().toLowerCase();
        if (!addr.contains(query) && !label.contains(query) && !display.contains(query)) return false;
      }

      final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';

      if (_selectedClosedType == ClosedFilterType.profit && pnl <= 0) return false;
      if (_selectedClosedType == ClosedFilterType.loss && pnl >= 0) return false;
      if (_selectedClosedType == ClosedFilterType.copy && !isCopy) return false;
      if (_selectedClosedType == ClosedFilterType.manual && isCopy) return false;

      if (_selectedClosedBot != null && _selectedClosedBot != 'All Bots') {
        final rawDisplay = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
        if (rawDisplay != _selectedClosedBot) return false;
      }

      if (_selectedDateFilter != DateRangeFilter.allTime) {
        final closedAtStr = p['closed_at']?.toString();
        if (closedAtStr == null || closedAtStr.isEmpty) return false;
        DateTime? closedDate;
        try { closedDate = DateTime.parse(closedAtStr.replaceAll(' ', 'T') + (closedAtStr.endsWith('Z') ? '' : 'Z')).toLocal(); } catch (_) {}
        if (closedDate != null) {
          final diff = now.difference(closedDate);
          if (_selectedDateFilter == DateRangeFilter.today && diff.inHours >= 24) return false;
          if (_selectedDateFilter == DateRangeFilter.last7Days && diff.inDays >= 7) return false;
          if (_selectedDateFilter == DateRangeFilter.last30Days && diff.inDays >= 30) return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildEnvChip(String label, TradeEnvironment env) {
    final isSelected = _selectedEnv == env;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedEnv = env),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.5) : Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    final finalOpenList = _openPositions.where(_passesEnvFilter).toList();
    final finalClosedList = _filteredClosedPositions;

    // Calculate Comprehensive P&L & Stats dynamically based on Filtered List
    int statsToday = 0, statsWeek = 0, statsMonth = 0;
    double profToday = 0, profWeek = 0, profMonth = 0, profAll = 0;
    double lossToday = 0, lossWeek = 0, lossMonth = 0, lossAll = 0;
    final now = DateTime.now();

    Map<String, List<dynamic>> monthlyGroupedTrades = {};

    for (var p in finalClosedList) {
      double pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      
      bool isToday = false, isWeek = false, isMonth = false;
      try {
        DateTime dt = DateTime.parse(p['closed_at'].toString().replaceAll(' ', 'T') + 'Z').toLocal();
        int days = now.difference(dt).inDays;
        isToday = (days == 0 && now.day == dt.day);
        isWeek = days < 7;
        isMonth = days < 30;

        if (isToday) statsToday++;
        if (isWeek) statsWeek++;
        if (isMonth) statsMonth++;
      } catch (_) {}

      if (pnl > 0) {
        profAll += pnl;
        if (isToday) profToday += pnl;
        if (isWeek) profWeek += pnl;
        if (isMonth) profMonth += pnl;
      } else if (pnl < 0) {
        lossAll += pnl;
        if (isToday) lossToday += pnl;
        if (isWeek) lossWeek += pnl;
        if (isMonth) lossMonth += pnl;
      }

      // Group for Monthly View
      String monthKey = _formatMonthYear(p['closed_at']);
      monthlyGroupedTrades.putIfAbsent(monthKey, () => []).add(p);
    }

    final Set<String> uniqueBots = {'All Bots'};
    for (var p in _closedPositions) {
      final name = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
      if (name.toString().isNotEmpty) uniqueBots.add(name);
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // 1. Global Position Type Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _buildEnvChip('All Positions', TradeEnvironment.all),
              const SizedBox(width: 8),
              _buildEnvChip('Real Only', TradeEnvironment.real),
              const SizedBox(width: 8),
              _buildEnvChip('Paper Only', TradeEnvironment.paper),
            ]),
          ),

          // 2. Tab Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 8),
                  height: 48,
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)])),
                    labelColor: Colors.white, unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [Tab(text: 'Open (${finalOpenList.length})'), Tab(text: 'Closed (${finalClosedList.length})')],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05))),
                child: IconButton(icon: const Icon(PhosphorIcons.arrowsClockwiseBold, color: Colors.white, size: 20), onPressed: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing...'), duration: Duration(seconds: 1))); _fetchPositions(); }),
              ),
            ],
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : TabBarView(
                  children: [
                    // ================== TAB 1: OPEN POSITIONS ==================
                    RefreshIndicator(
                      onRefresh: _fetchPositions,
                      child: Column(
                        children: [
                          if (finalOpenList.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                            child: finalOpenList.isEmpty 
                              ? const Center(child: Text('No active open positions for selected filter.', style: TextStyle(color: Colors.white54)))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: finalOpenList.length,
                                  itemBuilder: (context, index) {
                                    final p = finalOpenList[index];
                                    final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
                                    final pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;
                                    final isReal = p['is_real'] == 1 || p['is_real'] == '1';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Top Level: Bot Name & Win Rate (Full Width to avoid cutting)
                                            Text(_getBotDisplayName(p), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
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
                                            
                                            // RESTORED METRICS: Entry / Exit Mcap
                                            Row(
                                              children: [
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ENTRY MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['entry_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('LIVE MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['current_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              children: [
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  const Text('UNREALIZED P&L', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4),
                                                  Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 10)),
                                                ])),
                                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                  const Text('TRADE SIZE', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4),
                                                  Text('\$${double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  if (currency.isNaira) Text('≈ ${currency.format(p['virtual_usd_amount'])}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                                                ])),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            // RESTORED METRICS: Time and Date
                                            Row(
                                              children: [
                                                const Icon(PhosphorIcons.clock, color: Colors.purpleAccent, size: 12),
                                                const SizedBox(width: 4),
                                                Text('${calculateTimeInTrade(p['opened_at'])} • ${formatLagosTime(p['opened_at'])}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
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
                    ),

                    // ================== TAB 2: CLOSED POSITIONS (STATS & MONTHLY GROUPS) ==================
                    RefreshIndicator(
                      onRefresh: _fetchPositions,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                                children: [
                                  // Comprehensive P&L Summary Matrix
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildPnLBox('Today', statsToday, profToday, lossToday, currency), const SizedBox(width: 12),
                                        _buildPnLBox('This Week', statsWeek, profWeek, lossWeek, currency), const SizedBox(width: 12),
                                        _buildPnLBox('This Month', statsMonth, profMonth, lossMonth, currency), const SizedBox(width: 12),
                                        _buildPnLBox('All Time', finalClosedList.length, profAll, lossAll, currency),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Search Bar
                                  SizedBox(
                                    height: 44,
                                    child: TextField(
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Search closed trades...', hintStyle: const TextStyle(color: Colors.white38),
                                        prefixIcon: const Icon(PhosphorIcons.magnifyingGlass, color: Colors.white54, size: 18),
                                        filled: true, fillColor: Colors.black.withOpacity(0.3), contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                      ),
                                      onChanged: (val) => setState(() => _closedSearchQuery = val),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Filters (RESTORED MANUAL & COPY)
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildFilterChip('All', _selectedClosedType == ClosedFilterType.all, () => setState(() => _selectedClosedType = ClosedFilterType.all)), const SizedBox(width: 6),
                                        _buildFilterChip('Profits', _selectedClosedType == ClosedFilterType.profit, () => setState(() => _selectedClosedType = ClosedFilterType.profit), color: Colors.greenAccent), const SizedBox(width: 6),
                                        _buildFilterChip('Losses', _selectedClosedType == ClosedFilterType.loss, () => setState(() => _selectedClosedType = ClosedFilterType.loss), color: Colors.redAccent), const SizedBox(width: 6),
                                        _buildFilterChip('Copy', _selectedClosedType == ClosedFilterType.copy, () => setState(() => _selectedClosedType = ClosedFilterType.copy), color: Colors.blueAccent), const SizedBox(width: 6),
                                        _buildFilterChip('Manual', _selectedClosedType == ClosedFilterType.manual, () => setState(() => _selectedClosedType = ClosedFilterType.manual), color: Colors.purpleAccent),
                                        
                                        const SizedBox(width: 12), Container(height: 20, width: 1, color: Colors.white24), const SizedBox(width: 12),
                                        
                                        DropdownButton<String>(
                                          value: _selectedClosedBot ?? 'All Bots', dropdownColor: const Color(0xFF13131A), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), underline: const SizedBox(),
                                          icon: const Icon(PhosphorIcons.caretDownBold, color: Colors.white54, size: 12),
                                          items: uniqueBots.map((bot) => DropdownMenuItem(value: bot, child: Row(children: [const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 14), const SizedBox(width: 6), Text(bot == 'All Bots' ? bot : _getBotDisplayName({'display_name': bot}))]))).toList(),
                                          onChanged: (val) => setState(() => _selectedClosedBot = (val == 'All Bots') ? null : val),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Monthly Grouped ListView
                          if (monthlyGroupedTrades.isEmpty)
                            const SliverFillRemaining(child: Center(child: Text('No closed trades match your filter.', style: TextStyle(color: Colors.white54))))
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  String monthKey = monthlyGroupedTrades.keys.elementAt(index);
                                  List<dynamic> trades = monthlyGroupedTrades[monthKey]!;
                                  return Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: index == 0,
                                      iconColor: theme.primaryColor, collapsedIconColor: Colors.white54,
                                      title: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(monthKey, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                          Container(margin: const EdgeInsets.only(top: 8), height: 1, width: double.infinity, color: Colors.white.withOpacity(0.1)),
                                        ],
                                      ),
                                      children: trades.map((p) {
                                        final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                                        final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                                        final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                                        final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                                        String badgeText = p['close_reason'] == 'TP_HIT' ? 'TP Hit' : (p['close_reason'] == 'SL_HIT' ? 'SL Hit' : 'Manual');
                                        Color badgeColor = p['close_reason'] == 'TP_HIT' ? Colors.greenAccent : (p['close_reason'] == 'SL_HIT' ? Colors.redAccent : Colors.blueAccent);

                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                          child: GlassCard(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Top Level: Bot Name & Win Rate
                                                Text(_getBotDisplayName(p), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                                const SizedBox(height: 8),

                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    InkWell(onTap: () => _launchDexScreener(p['token_address'] ?? ''), child: Row(children: [Text(_formatAddress(p['token_address'] ?? ''), style: const TextStyle(color: Colors.blueAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 4), const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 14)])),
                                                    Row(
                                                      children: [
                                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), margin: const EdgeInsets.only(right: 6), decoration: BoxDecoration(color: isReal ? Colors.redAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: isReal ? Colors.redAccent.withOpacity(0.3) : Colors.orangeAccent.withOpacity(0.3))), child: Text(isReal ? 'LIVE' : 'PAPER', style: TextStyle(color: isReal ? Colors.redAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                                                        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), border: Border.all(color: badgeColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(4)), child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold))),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                
                                                // RESTORED METRICS: Entry / Exit Mcap
                                                Row(
                                                  children: [
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ENTRY MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['entry_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('EXIT MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['close_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))])),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),

                                                Row(
                                                  children: [
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('REALIZED P&L', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)), if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 11))])),
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('TRADE SIZE', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text('\$${size.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), if (currency.isNaira) Text('≈ ${currency.format(size)}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold))])),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),

                                                // RESTORED METRICS: Time and Date
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(children: [const Icon(PhosphorIcons.clock, color: Colors.white54, size: 12), const SizedBox(width: 4), Text(formatLagosTime(p['closed_at']), style: const TextStyle(color: Colors.white54, fontSize: 10))]),
                                                    Row(children: [const Icon(PhosphorIcons.hourglassHigh, color: Colors.amberAccent, size: 12), const SizedBox(width: 4), Text(calculateTimeInTrade(p['opened_at'], p['closed_at']), style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11))]),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  );
                                },
                                childCount: monthlyGroupedTrades.length,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPnLBox(String label, int totalTrades, double profitUsd, double lossUsd, CurrencyProvider currency) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(6)), child: Text('$totalTrades Trades', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Profit', style: TextStyle(color: Colors.white38, fontSize: 10)), const SizedBox(height: 2), Text('+\$${profitUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ +${currency.format(profitUsd)}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
              Container(width: 1, height: 30, color: Colors.white10, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total Loss', style: TextStyle(color: Colors.white38, fontSize: 10)), const SizedBox(height: 2), Text('-\$${lossUsd.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ -${currency.format(lossUsd.abs())}', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color}) {
    final activeColor = color ?? Theme.of(context).primaryColor;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.2) : Colors.black26, border: Border.all(color: isSelected ? activeColor : Colors.white10), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: isSelected ? activeColor : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
