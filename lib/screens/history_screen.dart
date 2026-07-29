import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

enum ClosedFilterType { all, profit, loss, copy, manual }
enum DateRangeFilter { allTime, today, last7Days, last30Days }
enum TradeEnvironment { all, real, paper }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<dynamic> _closedPositions = [];
  Timer? _pollingTimer;

  // Processed Data (Moved out of build method for Extreme Performance)
  List<Map<String, dynamic>> _flattenedHistory = [];
  Map<String, double> _winRates = {};
  
  // P&L Stats
  int _statsToday = 0, _statsWeek = 0, _statsMonth = 0, _statsAll = 0;
  double _profToday = 0, _profWeek = 0, _profMonth = 0, _profAll = 0;
  double _lossToday = 0, _lossWeek = 0, _lossMonth = 0, _lossAll = 0;

  // Filters
  TradeEnvironment _selectedEnv = TradeEnvironment.all;
  String _closedSearchQuery = '';
  ClosedFilterType _selectedClosedType = ClosedFilterType.all;
  String? _selectedClosedBot; 

  @override
  void initState() {
    super.initState();
    _fetchPositions();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchPositions(silent: true));
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
      if (res['status'] == 'success') {
        _closedPositions = res['closed_positions'] ?? [];
        _processData(); // Heavy lifting done off the build thread
      }
      setState(() => _isLoading = false);
    }
  }

  // --- Core Processing Engine (Fixes the LAG & App Crashing) --- //
  void _processData() {
    final isAdmin = context.read<ApiService>().role == 'admin';
    final now = DateTime.now();

    // 1. Calculate Win Rates O(N)
    Map<String, int> totals = {};
    Map<String, int> wins = {};
    for (var p in _closedPositions) {
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';
      String name = 'Manual Trade';
      
      if (isCopy) {
        if (isAdmin) {
          name = p['wallet_label']?.toString() ?? 'Unknown';
        } else {
          final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
          name = botIdRaw != null && botIdRaw.isNotEmpty ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';
        }
      }

      final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      final isWin = pnl > 0 || p['close_reason'] == 'TP_HIT';

      totals[name] = (totals[name] ?? 0) + 1;
      if (isWin) wins[name] = (wins[name] ?? 0) + 1;
    }
    
    _winRates.clear();
    totals.forEach((k, v) => _winRates[k] = (wins[k] ?? 0) / v * 100);

    // 2. Filter, Calculate Stats, and Group O(N)
    _statsToday = _statsWeek = _statsMonth = _statsAll = 0;
    _profToday = _profWeek = _profMonth = _profAll = 0;
    _lossToday = _lossWeek = _lossMonth = _lossAll = 0;
    Map<String, List<dynamic>> grouped = {};

    for (var p in _closedPositions) {
      // Apply Environment Filter
      final isReal = p['is_real'] == 1 || p['is_real'] == '1';
      if (_selectedEnv == TradeEnvironment.real && !isReal) continue;
      if (_selectedEnv == TradeEnvironment.paper && isReal) continue;

      // Calculate Dates & Stats (only for visible filtered items)
      double pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      bool isToday = false, isWeek = false, isMonth = false;
      
      try {
        DateTime dt = DateTime.parse(p['closed_at'].toString().replaceAll(' ', 'T') + 'Z').toLocal();
        int days = now.difference(dt).inDays;
        isToday = (days == 0 && now.day == dt.day);
        isWeek = days < 7;
        isMonth = days < 30;
      } catch (_) {}

      // Apply Search & Type Filters
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';
      bool passSearch = true;
      if (_closedSearchQuery.isNotEmpty) {
        final query = _closedSearchQuery.toLowerCase();
        final addr = (p['token_address'] ?? '').toString().toLowerCase();
        final label = (p['wallet_label'] ?? '').toString().toLowerCase();
        if (!addr.contains(query) && !label.contains(query)) passSearch = false;
      }

      bool passType = true;
      if (_selectedClosedType == ClosedFilterType.profit && pnl <= 0) passType = false;
      if (_selectedClosedType == ClosedFilterType.loss && pnl >= 0) passType = false;
      if (_selectedClosedType == ClosedFilterType.copy && !isCopy) passType = false;
      if (_selectedClosedType == ClosedFilterType.manual && isCopy) passType = false;

      bool passBot = true;
      if (_selectedClosedBot != null && _selectedClosedBot != 'All Bots') {
        String rawDisplay = 'Manual Trade';
        if (isCopy) {
           rawDisplay = isAdmin 
              ? (p['wallet_label']?.toString() ?? 'Unknown') 
              : ((p['tracked_wallet_id']?.toString() != null) ? 'System Bot ${p['tracked_wallet_id'].toString().padLeft(2, '0')}' : 'System Bot');
        }
        if (rawDisplay != _selectedClosedBot) passBot = false;
      }

      if (passSearch && passType && passBot) {
        _statsAll++;
        if (isToday) _statsToday++;
        if (isWeek) _statsWeek++;
        if (isMonth) _statsMonth++;

        if (pnl > 0) {
          _profAll += pnl;
          if (isToday) _profToday += pnl;
          if (isWeek) _profWeek += pnl;
          if (isMonth) _profMonth += pnl;
        } else if (pnl < 0) {
          _lossAll += pnl;
          if (isToday) _lossToday += pnl;
          if (isWeek) _lossWeek += pnl;
          if (isMonth) _lossMonth += pnl;
        }

        String monthKey = _formatMonthYear(p['closed_at']);
        grouped.putIfAbsent(monthKey, () => []).add(p);
      }
    }

    // 3. Flatten for True Lazy Loading (Zero Lag)
    _flattenedHistory.clear();
    grouped.forEach((month, trades) {
      _flattenedHistory.add({'isHeader': true, 'title': month});
      _flattenedHistory.addAll(trades.map((t) => {'isHeader': false, 'data': t}));
    });

    if (mounted) setState(() {});
  }

  // --- UI Helpers --- //
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

  Widget _buildEnvChip(String label, TradeEnvironment env, ThemeData theme) {
    final isSelected = _selectedEnv == env;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _selectedEnv = env;
          _processData();
        },
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

  Widget _buildPnLBox(String label, int totalTrades, double profitUsd, double lossUsd, CurrencyProvider currency, ThemeData theme) {
    double netPnl = profitUsd + lossUsd; // lossUsd is already negative
    bool isNetProfit = netPnl >= 0;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text('$totalTrades Trades', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 9, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Profit', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 2), Text('+\$${profitUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)), if (currency.isNaira) Text('≈ +${currency.format(profitUsd)}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
              Container(width: 1, height: 30, color: theme.colorScheme.onSurface.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Loss', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 2), Text('-\$${lossUsd.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)), if (currency.isNaira) Text('≈ -${currency.format(lossUsd.abs())}', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NET P&L:', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isNetProfit ? '+' : ''}\$${netPnl.toStringAsFixed(2)}', style: TextStyle(color: isNetProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                  if (currency.isNaira) Text('≈ ${isNetProfit ? '+' : ''}${currency.format(netPnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: isNetProfit ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color, required ThemeData theme}) {
    final activeColor = color ?? theme.primaryColor;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.2) : theme.colorScheme.onSurface.withOpacity(0.05), border: Border.all(color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(0.1)), borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final isAdmin = context.read<ApiService>().role == 'admin';

    final Set<String> uniqueBots = {'All Bots'};
    for (var p in _closedPositions) {
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
      if (isCopy) {
         if (isAdmin) {
             uniqueBots.add(p['wallet_label'].toString());
         } else {
             final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
             String display = botIdRaw != null && botIdRaw.isNotEmpty ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';
             uniqueBots.add(display);
         }
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('TRADE HISTORY', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: AnimatedCryptoBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                _buildEnvChip('All Positions', TradeEnvironment.all, theme),
                const SizedBox(width: 8),
                _buildEnvChip('Real Only', TradeEnvironment.real, theme),
                const SizedBox(width: 8),
                _buildEnvChip('Paper Only', TradeEnvironment.paper, theme),
              ]),
            ),
            Expanded(
              child: _isLoading && _flattenedHistory.isEmpty
                ? const Center(child: CircularProgressIndicator()) 
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildPnLBox('Today', _statsToday, _profToday, _lossToday, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('This Week', _statsWeek, _profWeek, _lossWeek, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('This Month', _statsMonth, _profMonth, _lossMonth, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('All Time', _statsAll, _profAll, _lossAll, currency, theme),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              SizedBox(
                                height: 44,
                                child: TextField(
                                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Search closed trades...', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass, color: theme.colorScheme.onSurfaceVariant, size: 18),
                                    filled: true, fillColor: theme.colorScheme.onSurface.withOpacity(0.05), contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  onChanged: (val) {
                                    _closedSearchQuery = val;
                                    _processData();
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', _selectedClosedType == ClosedFilterType.all, () { _selectedClosedType = ClosedFilterType.all; _processData(); }, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Profits', _selectedClosedType == ClosedFilterType.profit, () { _selectedClosedType = ClosedFilterType.profit; _processData(); }, color: Colors.greenAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Losses', _selectedClosedType == ClosedFilterType.loss, () { _selectedClosedType = ClosedFilterType.loss; _processData(); }, color: Colors.redAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Copy', _selectedClosedType == ClosedFilterType.copy, () { _selectedClosedType = ClosedFilterType.copy; _processData(); }, color: Colors.blueAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Manual', _selectedClosedType == ClosedFilterType.manual, () { _selectedClosedType = ClosedFilterType.manual; _processData(); }, color: Colors.purpleAccent, theme: theme),
                                    
                                    const SizedBox(width: 12), Container(height: 20, width: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)), const SizedBox(width: 12),
                                    
                                    DropdownButton<String>(
                                      value: _selectedClosedBot ?? 'All Bots', dropdownColor: theme.colorScheme.surface, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.bold), underline: const SizedBox(),
                                      icon: Icon(PhosphorIcons.caretDownBold, color: theme.colorScheme.onSurfaceVariant, size: 12),
                                      items: uniqueBots.map((bot) => DropdownMenuItem(value: bot, child: Row(children: [const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 14), const SizedBox(width: 6), Text(bot)]))).toList(),
                                      onChanged: (val) {
                                        _selectedClosedBot = (val == 'All Bots') ? null : val;
                                        _processData();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_flattenedHistory.isEmpty)
                        SliverFillRemaining(child: Center(child: Text('No closed trades match your filter.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))))
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _flattenedHistory[index];
                              
                              if (item['isHeader'] == true) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title'], style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(margin: const EdgeInsets.only(top: 8), height: 1, width: double.infinity, color: theme.colorScheme.onSurface.withOpacity(0.1)),
                                    ],
                                  ),
                                );
                              }

                              final p = item['data'];
                              final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                              final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                              final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                              final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                              String badgeText = p['close_reason'] == 'TP_HIT' ? 'TP Hit' : (p['close_reason'] == 'SL_HIT' ? 'SL Hit' : 'Manual');
                              Color badgeColor = p['close_reason'] == 'TP_HIT' ? Colors.greenAccent : (p['close_reason'] == 'SL_HIT' ? Colors.redAccent : Colors.blueAccent);

                              // PERFECTED BOT BADGE LOGIC
                              final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
                              
                              String mainTitle = 'Manual Trade';
                              String? adminBadge;
                              String winRateText = '';

                              if (isCopy) {
                                 String label = p['wallet_label']?.toString() ?? ''; // The real Shark Name
                                 final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
                                 final sysBotName = (botIdRaw != null && botIdRaw.isNotEmpty) ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';

                                 if (isAdmin && label.isNotEmpty && label != 'Manual') {
                                    mainTitle = label; // Admin sees Shark Name
                                    adminBadge = '🤖 $sysBotName'; // Admin sees Bot ID badge
                                    if (_winRates.containsKey(label)) {
                                       winRateText = ' • ${_winRates[label]!.toStringAsFixed(1)}% Win Rate';
                                    }
                                 } else {
                                    mainTitle = sysBotName; // Users only see "System Bot 02"
                                    if (_winRates.containsKey(sysBotName)) {
                                       winRateText = ' • ${_winRates[sysBotName]!.toStringAsFixed(1)}% Win Rate';
                                    }
                                 }
                              }

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: GlassCard(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Shark Name + System Bot Badge
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Text('$mainTitle$winRateText', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
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
                                      
                                      Row(
                                        children: [
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRY MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['entry_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13))])),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('EXIT MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text(_formatMcap(p['close_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13))])),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      Row(
                                        children: [
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('REALIZED P&L', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)), if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 11))])),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TRADE SIZE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 9, letterSpacing: 1)), const SizedBox(height: 4), Text('\$${size.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)), if (currency.isNaira) Text('≈ ${currency.format(size)}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold))])),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(children: [Icon(PhosphorIcons.clock, color: theme.colorScheme.onSurfaceVariant, size: 12), const SizedBox(width: 4), Text(formatLagosTime(p['closed_at']), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10))]),
                                          Row(children: [const Icon(PhosphorIcons.hourglassHigh, color: Colors.amberAccent, size: 12), const SizedBox(width: 4), Text(calculateTimeInTrade(p['opened_at'], p['closed_at']), style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11))]),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: _flattenedHistory.length,
                          ),
                        ),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
