import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme/app_theme.dart';
import '../widgets/pnl_share_dialog.dart';
import 'pnl_calendar_screen.dart';

enum ClosedFilterType { all, profit, loss, copy, manual }
enum TradeEnvironment { all, real, paper }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<dynamic> _closedPositions = [];
  bool _hasMore = false;
  int _totalCount = 0;
  Timer? _pollingTimer;
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _flattenedHistory = [];
  Map<String, double> _winRates = {};
  final Set<int> _hidingIds = {};

  int _statsToday = 0, _statsWeek = 0, _statsMonth = 0, _statsAll = 0;
  double _profToday = 0, _profWeek = 0, _profMonth = 0, _profAll = 0;
  double _lossToday = 0, _lossWeek = 0, _lossMonth = 0, _lossAll = 0;

  TradeEnvironment _selectedEnv = TradeEnvironment.all;
  String _closedSearchQuery = '';
  ClosedFilterType _selectedClosedType = ClosedFilterType.all;
  String? _selectedClosedBot;
  String _selectedChainFilter = 'All Chains';

  static const int _pageSize = 40;

  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

  @override
  void initState() {
    super.initState();
    _refetchAll();
    // Closed trades don't move like open ones do — this just catches newly
    // closed trades while the screen is open. Far lighter than before:
    // paginated + trimmed payload, and only every 20s instead of every 5s.
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refetchAll(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Map<String, String> _currentFilterParams() {
    return {
      'search': _closedSearchQuery,
      'type': _selectedClosedType.name,
      'bot': _selectedClosedBot ?? 'all',
      'chain': _selectedChainFilter,
      'env': _selectedEnv.name,
    };
  }

  String _buildQuery(Map<String, String> params) {
    return params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
  }

  Future<void> _fetchHistoryPage({bool reset = true, bool silent = false}) async {
    if (reset && !silent && mounted) setState(() => _isLoading = true);
    if (!reset) setState(() => _isLoadingMore = true);

    final offset = reset ? 0 : _closedPositions.length;
    final limit = reset ? _pageSize : _pageSize;
    final params = _currentFilterParams()
      ..addAll({'offset': '$offset', 'limit': '$limit'});

    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch_history&${_buildQuery(params)}');

    if (mounted) {
      if (res['status'] == 'success') {
        final List<dynamic> rows = res['data'] ?? [];
        setState(() {
          if (reset) {
            _closedPositions = rows;
          } else {
            _closedPositions = [..._closedPositions, ...rows];
          }
          _hasMore = res['has_more'] == true;
          _totalCount = (res['total_count'] as num?)?.toInt() ?? _closedPositions.length;
        });
        _processData();
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _fetchHistoryStats() async {
    final params = _currentFilterParams();
    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch_history_stats&${_buildQuery(params)}');
    if (mounted && res['status'] == 'success') {
      final periods = res['periods'] ?? {};
      setState(() {
        _statsToday = (periods['today']?['count'] as num?)?.toInt() ?? 0;
        _profToday = (periods['today']?['profit'] as num?)?.toDouble() ?? 0;
        _lossToday = (periods['today']?['loss'] as num?)?.toDouble() ?? 0;

        _statsWeek = (periods['week']?['count'] as num?)?.toInt() ?? 0;
        _profWeek = (periods['week']?['profit'] as num?)?.toDouble() ?? 0;
        _lossWeek = (periods['week']?['loss'] as num?)?.toDouble() ?? 0;

        _statsMonth = (periods['month']?['count'] as num?)?.toInt() ?? 0;
        _profMonth = (periods['month']?['profit'] as num?)?.toDouble() ?? 0;
        _lossMonth = (periods['month']?['loss'] as num?)?.toDouble() ?? 0;

        _statsAll = (periods['all']?['count'] as num?)?.toInt() ?? 0;
        _profAll = (periods['all']?['profit'] as num?)?.toDouble() ?? 0;
        _lossAll = (periods['all']?['loss'] as num?)?.toDouble() ?? 0;

        _winRates = Map<String, double>.from(
          (res['bot_win_rates'] ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        );
      });
    }
  }

  Future<void> _refetchAll({bool silent = false}) async {
    await Future.wait([
      _fetchHistoryPage(reset: true, silent: silent),
      _fetchHistoryStats(),
    ]);
  }

  void _onFilterChanged() {
    _refetchAll();
  }

  void _onSearchChanged(String val) {
    _closedSearchQuery = val;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _refetchAll());
  }

  Future<void> _hidePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;

    setState(() => _hidingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350));

    final res = await context.read<ApiService>().postEndpoint('positions.php?action=toggle_hide', {'id': pId, 'is_hidden': 1});
    if (mounted) {
      if (res['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to hide', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
        setState(() => _hidingIds.remove(pId));
        return;
      }
      // No need to hit the network again for this — just drop it locally.
      setState(() {
        _closedPositions.removeWhere((item) => (int.tryParse(item['id'].toString()) ?? 0) == pId);
        _totalCount = _totalCount > 0 ? _totalCount - 1 : 0;
        _hidingIds.remove(pId);
      });
      _processData();
    }
  }

  // Groups the currently-loaded page(s) by month for display. Filtering and
  // stats are already done server-side (see _fetchHistoryPage / _fetchHistoryStats) —
  // this only handles presentation grouping.
  void _processData() {
    Map<String, List<dynamic>> grouped = {};
    for (var p in _closedPositions) {
      String monthKey = _formatMonthYear(p['closed_at']);
      grouped.putIfAbsent(monthKey, () => []).add(p);
    }

    _flattenedHistory.clear();
    grouped.forEach((month, trades) {
      _flattenedHistory.add({'isHeader': true, 'title': month});
      _flattenedHistory.addAll(trades.map((t) => {'isHeader': false, 'data': t}));
    });

    if (mounted) setState(() {});
  }

  String _formatMonthYear(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown Date';
    try {
      DateTime dt = DateTime.parse(dateStr.replaceAll(' ', 'T') + (dateStr.endsWith('Z') ? '' : 'Z')).toLocal();
      const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return 'Unknown Date'; }
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
      return '$hour12:$min $period, ${months[dt.month - 1]}, ${dt.day}';
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
          setState(() => _selectedEnv = env);
          _onFilterChanged();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? theme.primaryColor.withOpacity(0.5) : theme.colorScheme.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.spaceGrotesk(color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildPnLBox(String label, int totalTrades, double profitUsd, double lossUsd, CurrencyProvider currency, ThemeData theme) {
    double netPnl = profitUsd + lossUsd; 
    bool isNetProfit = netPnl >= 0;

    return SizedBox(
      width: 300,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(), style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Text('$totalTrades Trades', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Profit', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)), const SizedBox(height: 4), Text('+\$${profitUsd.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ +${currency.format(profitUsd)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold))])),
                Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total Loss', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)), const SizedBox(height: 4), Text('-\$${lossUsd.abs().toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 15)), if (currency.isNaira) Text('≈ -${currency.format(lossUsd.abs())}', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold))])),
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NET P&L:', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${isNetProfit ? '+' : ''}\$${netPnl.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: isNetProfit ? AppTheme.success(context) : AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 15)),
                    if (currency.isNaira) Text('≈ ${isNetProfit ? '+' : ''}${currency.format(netPnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: GoogleFonts.spaceGrotesk(color: isNetProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold))
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, {Color? color, required ThemeData theme}) {
    final activeColor = color ?? theme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: isSelected ? activeColor.withOpacity(0.15) : theme.colorScheme.surfaceContainerHighest, border: Border.all(color: isSelected ? activeColor.withOpacity(0.3) : theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
        child: Text(label, style: GoogleFonts.spaceGrotesk(color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final isAdmin = context.read<ApiService>().role == 'admin';

    // Built from server-computed win rates (global, always complete) instead
    // of scanning whatever page happens to be loaded on the phone.
    final Set<String> uniqueBots = {'All Bots', ..._winRates.keys};

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('TRADE HISTORY', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.calendarBlank, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PnlCalendarScreen())),
          ),
        ],
      ),
      body: AnimatedCryptoBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(children: [
                _buildEnvChip('All', TradeEnvironment.all, theme),
                const SizedBox(width: 12),
                _buildEnvChip('Real', TradeEnvironment.real, theme),
                const SizedBox(width: 12),
                _buildEnvChip('Paper', TradeEnvironment.paper, theme),
              ]),
            ),
            Expanded(
              child: _isLoading && _flattenedHistory.isEmpty
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor)) 
                : RefreshIndicator(
                    onRefresh: () => _refetchAll(),
                    color: theme.primaryColor,
                    child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  children: [
                                    _buildPnLBox('Today', _statsToday, _profToday, _lossToday, currency, theme), const SizedBox(width: 16),
                                    _buildPnLBox('This Week', _statsWeek, _profWeek, _lossWeek, currency, theme), const SizedBox(width: 16),
                                    _buildPnLBox('This Month', _statsMonth, _profMonth, _lossMonth, currency, theme), const SizedBox(width: 16),
                                    _buildPnLBox('All Time', _statsAll, _profAll, _lossAll, currency, theme),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: SizedBox(
                                  height: 56,
                                  child: TextField(
                                    style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Search closed trades...', hintStyle: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                                      prefixIcon: Icon(PhosphorIcons.magnifyingGlass, color: theme.colorScheme.onSurfaceVariant, size: 20),
                                      filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: theme.colorScheme.outlineVariant),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(PhosphorIcons.robot, size: 16, color: AppTheme.info(context)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _selectedClosedBot ?? 'All Bots', 
                                                  dropdownColor: theme.colorScheme.surface, 
                                                  style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold), 
                                                  icon: Icon(PhosphorIcons.caretDownBold, color: theme.colorScheme.onSurfaceVariant, size: 14),
                                                  items: uniqueBots.map((bot) => DropdownMenuItem(value: bot, child: Text(bot, style: GoogleFonts.spaceGrotesk(), overflow: TextOverflow.ellipsis))).toList(),
                                                  onChanged: (val) {
                                                    setState(() => _selectedClosedBot = (val == 'All Bots') ? null : val);
                                                    _onFilterChanged();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: theme.colorScheme.outlineVariant),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(PhosphorIcons.link, size: 16, color: theme.primaryColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isExpanded: true,
                                                  value: _selectedChainFilter, 
                                                  dropdownColor: theme.colorScheme.surface, 
                                                  style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold), 
                                                  icon: Icon(PhosphorIcons.caretDownBold, color: theme.colorScheme.onSurfaceVariant, size: 14),
                                                  items: ['All Chains', 'Solana', 'BSC', 'Robinhood'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.spaceGrotesk(), overflow: TextOverflow.ellipsis))).toList(),
                                                  onChanged: (val) {
                                                    setState(() => _selectedChainFilter = val ?? 'All Chains');
                                                    _onFilterChanged();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  children: [
                                    _buildFilterChip('All', _selectedClosedType == ClosedFilterType.all, () { setState(() => _selectedClosedType = ClosedFilterType.all); _onFilterChanged(); }, theme: theme), const SizedBox(width: 8),
                                    _buildFilterChip('Profits', _selectedClosedType == ClosedFilterType.profit, () { setState(() => _selectedClosedType = ClosedFilterType.profit); _onFilterChanged(); }, color: AppTheme.success(context), theme: theme), const SizedBox(width: 8),
                                    _buildFilterChip('Losses', _selectedClosedType == ClosedFilterType.loss, () { setState(() => _selectedClosedType = ClosedFilterType.loss); _onFilterChanged(); }, color: AppTheme.danger(context), theme: theme), const SizedBox(width: 8),
                                    _buildFilterChip('Copy', _selectedClosedType == ClosedFilterType.copy, () { setState(() => _selectedClosedType = ClosedFilterType.copy); _onFilterChanged(); }, color: AppTheme.info(context), theme: theme), const SizedBox(width: 8),
                                    _buildFilterChip('Manual', _selectedClosedType == ClosedFilterType.manual, () { setState(() => _selectedClosedType = ClosedFilterType.manual); _onFilterChanged(); }, color: const Color(0xFF9333EA), theme: theme),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_flattenedHistory.isEmpty)
                        SliverFillRemaining(child: Center(child: Text('No closed trades match your filter.', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant))))
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _flattenedHistory[index];
                              
                              if (item['isHeader'] == true) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item['title'], style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Container(margin: const EdgeInsets.only(top: 8), height: 1, width: double.infinity, color: theme.colorScheme.outlineVariant),
                                    ],
                                  ),
                                );
                              }

                              final p = item['data'];
                              final pId = int.tryParse(p['id'].toString()) ?? 0;
                              final isHiding = _hidingIds.contains(pId);
                              
                              final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                              final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                              final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                              final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                              
                              String closeReasonBadge = '';
                              Color closeReasonColor = AppTheme.info(context);
                              switch (p['close_reason']) {
                                case 'TP_HIT':
                                  closeReasonBadge = 'TP';
                                  closeReasonColor = AppTheme.success(context);
                                  break;
                                case 'SL_HIT':
                                  closeReasonBadge = 'SL';
                                  closeReasonColor = AppTheme.danger(context);
                                  break;
                                case 'TRAILING_SL_HIT':
                                  closeReasonBadge = 'T-SL';
                                  closeReasonColor = Colors.purple;
                                  break;
                                case 'MANUAL':
                                  closeReasonBadge = 'Manual';
                                  closeReasonColor = AppTheme.info(context);
                                  break;
                                case 'ZERO_BALANCE':
                                  closeReasonBadge = '0-Bal';
                                  closeReasonColor = theme.colorScheme.onSurfaceVariant;
                                  break;
                                default:
                                  closeReasonBadge = p['close_reason']?.toString() ?? 'Closed';
                                  closeReasonColor = theme.colorScheme.onSurfaceVariant;
                              }

                              final isCopy = p['wallet_label'] != null && p['wallet_label'].toString() != 'Manual' && p['wallet_label'].toString().isNotEmpty;
                              
                              String mainTitle = 'Manual Trade';
                              String subTitle = '';

                              if (isCopy) {
                                  String label = p['wallet_label']?.toString() ?? 'Unknown';
                                  final botIdRaw = p['bot_id']?.toString();
                                  final sysBotName = (botIdRaw != null && botIdRaw.isNotEmpty && botIdRaw != 'null') ? 'Bot ${botIdRaw.padLeft(2, '0')}' : 'Bot';

                                  if (isAdmin && label.toUpperCase() != 'MANUAL') {
                                      mainTitle = label.toUpperCase();
                                      subTitle = sysBotName; 
                                  } else {
                                      mainTitle = sysBotName; 
                                  }
                              }

                              final String chainRaw = (p['chain'] ?? 'solana').toString().toLowerCase();
                              final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
                              final Color chainColor = _chainColors[chainRaw] ?? AppTheme.kainuwaPurple;
                              
                              String winRateText = '';
                              if (_winRates.containsKey(mainTitle)) {
                                  winRateText = ' • ${_winRates[mainTitle]!.toStringAsFixed(1)}%';
                              }

                              return AnimatedSize(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                child: isHiding
                                    ? const SizedBox(width: double.infinity, height: 0)
                                    : AnimatedOpacity(
                                        duration: const Duration(milliseconds: 250),
                                        opacity: isHiding ? 0.0 : 1.0,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                                          child: GlassCard(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Wrap(
                                                            crossAxisAlignment: WrapCrossAlignment.center,
                                                            spacing: 6,
                                                            runSpacing: 6,
                                                            children: [
                                                              Text(_formatAddress(p['token_address'] ?? ''), style: TextStyle(color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15)),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: chainColor.withOpacity(0.3))),
                                                                child: Text(chainLabel, style: TextStyle(fontSize: 9, color: chainColor, fontWeight: FontWeight.bold)),
                                                              ),
                                                              if (subTitle.isNotEmpty)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                                                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)), 
                                                                  child: Text(subTitle, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))
                                                                ),
                                                            ],
                                                          ),
                                                          Padding(
                                                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                                                            child: Row(
                                                              children: [
                                                                Flexible(child: Text(mainTitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                                                if (winRateText.isNotEmpty)
                                                                  Text(winRateText, style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 12)),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () => _hidePosition(p),
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: theme.colorScheme.surfaceContainerHighest,
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(PhosphorIcons.eyeSlashFill, color: theme.colorScheme.onSurfaceVariant, size: 14), 
                                                                const SizedBox(width: 4), 
                                                                Text('Hide', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        InkWell(
                                                          onTap: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (_) => PnlShareDialog(tradeData: p, isAdmin: isAdmin),
                                                            );
                                                          },
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            decoration: BoxDecoration(
                                                              color: theme.primaryColor.withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(8),
                                                              border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(PhosphorIcons.shareNetworkBold, color: theme.primaryColor, size: 14), 
                                                                const SizedBox(width: 4), 
                                                                Text('Share', style: GoogleFonts.spaceGrotesk(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),

                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    InkWell(
                                                      onTap: () => _launchDexScreener(p['token_address'] ?? '', chain: p['chain'] ?? 'solana'), 
                                                      child: Row(children: [Text('View Chart', style: GoogleFonts.spaceGrotesk(color: AppTheme.info(context), fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(width: 4), Icon(PhosphorIcons.arrowSquareOutBold, color: AppTheme.info(context), size: 14)])
                                                    ),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          margin: const EdgeInsets.only(right: 8),
                                                          decoration: BoxDecoration(color: isReal ? AppTheme.danger(context).withOpacity(0.15) : AppTheme.warning(context).withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: isReal ? AppTheme.danger(context).withOpacity(0.3) : AppTheme.warning(context).withOpacity(0.3))),
                                                          child: isReal
                                                              ? Text('LIVE', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))
                                                              : const Text('📄', style: TextStyle(fontSize: 12)),
                                                        ),
                                                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: closeReasonColor.withOpacity(0.15), border: Border.all(color: closeReasonColor.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)), child: Text(closeReasonBadge, style: GoogleFonts.spaceGrotesk(color: closeReasonColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                                const SizedBox(height: 20),
                                                
                                                Row(
                                                  children: [
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRY MCAP', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(p['entry_mcap']), style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('EXIT MCAP', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(p['close_mcap']), style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),

                                                Row(
                                                  children: [
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                      Text('REALIZED P&L', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), 
                                                      Text('${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: GoogleFonts.spaceGrotesk(color: pnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 15)), 
                                                      if (currency.isNaira) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: GoogleFonts.spaceGrotesk(color: pnl >= 0 ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12))
                                                    ])),
                                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                      Text('TRADE SIZE', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), 
                                                      Text('\$${size.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)), 
                                                      if (currency.isNaira) Text('≈ ${currency.format(size)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold))
                                                    ])),
                                                  ],
                                                ),
                                                const SizedBox(height: 20),
                                                Container(height: 1, color: theme.colorScheme.outlineVariant),
                                                const SizedBox(height: 16),

                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(children: [Icon(PhosphorIcons.clock, color: theme.colorScheme.onSurfaceVariant, size: 14), const SizedBox(width: 6), Text(formatLagosTime(p['closed_at']), style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500))]),
                                                    Row(children: [Icon(PhosphorIcons.hourglassHigh, color: AppTheme.warning(context), size: 14), const SizedBox(width: 6), Text(calculateTimeInTrade(p['opened_at'], p['closed_at']), style: GoogleFonts.spaceGrotesk(color: AppTheme.warning(context), fontWeight: FontWeight.bold, fontSize: 12))]),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                              );
                            },
                            childCount: _flattenedHistory.length,
                          ),
                        ),

                      if (_hasMore)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            child: Center(
                              child: _isLoadingMore
                                  ? SizedBox(height: 44, child: Center(child: CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2)))
                                  : OutlinedButton(
                                      onPressed: () => _fetchHistoryPage(reset: false),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                                      ),
                                      child: Text(
                                        'Load older trades (${_closedPositions.length} of $_totalCount)',
                                        style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
