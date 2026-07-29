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

  // Filters
  TradeEnvironment _selectedEnv = TradeEnvironment.all;
  String _closedSearchQuery = '';
  ClosedFilterType _selectedClosedType = ClosedFilterType.all;
  String? _selectedClosedBot; 
  DateRangeFilter _selectedDateFilter = DateRangeFilter.allTime;

  @override
  void initState() {
    super.initState();
    _fetchPositions();
    // Silent auto-polling every 5 seconds for history updates
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
      setState(() {
        if (res['status'] == 'success') {
          _closedPositions = res['closed_positions'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  // --- Helpers & Logic --- //

  Map<String, double> get _botWinRates {
    final isAdmin = context.read<ApiService>().role == 'admin';
    Map<String, int> totals = {};
    Map<String, int> wins = {};

    for (var p in _closedPositions) {
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual';
      String name = 'Manual Trade';
      
      if (isCopy) {
        if (isAdmin) {
          name = p['wallet_label']?.toString() ?? 'Unknown';
        } else {
          name = p['display_name']?.toString() ?? '';
          if (name.isEmpty) {
             final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
             name = botIdRaw != null && botIdRaw.isNotEmpty ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';
          }
        }
      }

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
        final isAdmin = context.read<ApiService>().role == 'admin';
        String rawDisplay = 'Manual Trade';
        if (isCopy) {
           rawDisplay = isAdmin 
              ? (p['wallet_label']?.toString() ?? 'Unknown') 
              : (p['display_name']?.toString() ?? '');
           if (rawDisplay.isEmpty && !isAdmin) {
             final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
             rawDisplay = botIdRaw != null && botIdRaw.isNotEmpty ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';
           }
        }
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

  Widget _buildPnLBox(String label, int totalTrades, double profitUsd, double lossUsd, CurrencyProvider currency, ThemeData theme) {
    return Container(
      width: 260,
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Profit', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 2), Text('+\$${profitUsd.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ +${currency.format(profitUsd)}', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
              Container(width: 1, height: 30, color: theme.colorScheme.onSurface.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Loss', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)), const SizedBox(height: 2), Text('-\$${lossUsd.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ -${currency.format(lossUsd.abs())}', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))])),
            ],
          ),
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

    final finalClosedList = _filteredClosedPositions;

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

      String monthKey = _formatMonthYear(p['closed_at']);
      monthlyGroupedTrades.putIfAbsent(monthKey, () => []).add(p);
    }

    final Set<String> uniqueBots = {'All Bots'};
    for (var p in _closedPositions) {
      final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
      if (isCopy) {
         if (isAdmin) {
             uniqueBots.add(p['wallet_label'].toString());
         } else {
             String display = p['display_name']?.toString() ?? '';
             if (display.isEmpty) {
                 final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
                 display = botIdRaw != null && botIdRaw.isNotEmpty ? 'System Bot ${botIdRaw.padLeft(2, '0')}' : 'System Bot';
             }
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
              child: _isLoading 
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
                                    _buildPnLBox('Today', statsToday, profToday, lossToday, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('This Week', statsWeek, profWeek, lossWeek, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('This Month', statsMonth, profMonth, lossMonth, currency, theme), const SizedBox(width: 12),
                                    _buildPnLBox('All Time', finalClosedList.length, profAll, lossAll, currency, theme),
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
                                  onChanged: (val) => setState(() => _closedSearchQuery = val),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', _selectedClosedType == ClosedFilterType.all, () => setState(() => _selectedClosedType = ClosedFilterType.all), theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Profits', _selectedClosedType == ClosedFilterType.profit, () => setState(() => _selectedClosedType = ClosedFilterType.profit), color: Colors.greenAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Losses', _selectedClosedType == ClosedFilterType.loss, () => setState(() => _selectedClosedType = ClosedFilterType.loss), color: Colors.redAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Copy', _selectedClosedType == ClosedFilterType.copy, () => setState(() => _selectedClosedType = ClosedFilterType.copy), color: Colors.blueAccent, theme: theme), const SizedBox(width: 6),
                                    _buildFilterChip('Manual', _selectedClosedType == ClosedFilterType.manual, () => setState(() => _selectedClosedType = ClosedFilterType.manual), color: Colors.purpleAccent, theme: theme),
                                    
                                    const SizedBox(width: 12), Container(height: 20, width: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)), const SizedBox(width: 12),
                                    
                                    DropdownButton<String>(
                                      value: _selectedClosedBot ?? 'All Bots', dropdownColor: theme.colorScheme.surface, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.bold), underline: const SizedBox(),
                                      icon: Icon(PhosphorIcons.caretDownBold, color: theme.colorScheme.onSurfaceVariant, size: 12),
                                      items: uniqueBots.map((bot) => DropdownMenuItem(value: bot, child: Row(children: [const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 14), const SizedBox(width: 6), Text(bot)]))).toList(),
                                      onChanged: (val) => setState(() => _selectedClosedBot = (val == 'All Bots') ? null : val),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (monthlyGroupedTrades.isEmpty)
                        SliverFillRemaining(child: Center(child: Text('No closed trades match your filter.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))))
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
                                  iconColor: theme.primaryColor, collapsedIconColor: theme.colorScheme.onSurfaceVariant,
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(monthKey, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(margin: const EdgeInsets.only(top: 8), height: 1, width: double.infinity, color: theme.colorScheme.onSurface.withOpacity(0.1)),
                                    ],
                                  ),
                                  children: trades.map((p) {
                                    final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                                    final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                                    final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                                    final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                                    String badgeText = p['close_reason'] == 'TP_HIT' ? 'TP Hit' : (p['close_reason'] == 'SL_HIT' ? 'SL Hit' : 'Manual');
                                    Color badgeColor = p['close_reason'] == 'TP_HIT' ? Colors.greenAccent : (p['close_reason'] == 'SL_HIT' ? Colors.redAccent : Colors.blueAccent);

                                    // SHARK NAME & BOT BADGE LOGIC
                                    final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
                                    
                                    String mainTitle = 'Manual Trade';
                                    String? adminBadge;
                                    String winRateText = '';

                                    if (isCopy) {
                                       String display = p['display_name']?.toString() ?? '';
                                       String label = p['wallet_label']?.toString() ?? '';
                                       
                                       if (display.isEmpty) {
                                          final botIdRaw = p['tracked_wallet_id']?.toString() ?? p['bot_id']?.toString();
                                          if (botIdRaw != null && botIdRaw.isNotEmpty) {
                                             display = 'System Bot ${botIdRaw.padLeft(2, '0')}';
                                          } else {
                                             display = 'System Bot';
                                          }
                                       }

                                       if (isAdmin && label.isNotEmpty && label != 'Manual') {
                                          mainTitle = label;
                                          adminBadge = '🤖 $display';
                                          if (_botWinRates.containsKey(label)) {
                                             winRateText = ' • ${_botWinRates[label]!.toStringAsFixed(1)}% Win Rate';
                                          }
                                       } else {
                                          mainTitle = display; // Users only see "System Bot 02"
                                          if (_botWinRates.containsKey(display)) {
                                             winRateText = ' • ${_botWinRates[display]!.toStringAsFixed(1)}% Win Rate';
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
                                            
                                            // RESTORED METRICS: Entry / Exit Mcap
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

                                            // RESTORED METRICS: Time and Date
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
    );
  }
}
