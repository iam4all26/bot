import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';

enum ClosedFilterType { all, profit, loss, copy, manual }
enum DateRangeFilter { allTime, today, last7Days, last30Days }

class PositionsScreen extends StatefulWidget {
  const PositionsScreen({super.key});

  @override
  State<PositionsScreen> createState() => _PositionsScreenState();
}

class _PositionsScreenState extends State<PositionsScreen> {
  bool _isLoading = true;
  List<dynamic> _openPositions = [];
  List<dynamic> _closedPositions = [];

  // Filters for Closed Positions Tab
  String _closedSearchQuery = '';
  ClosedFilterType _selectedClosedType = ClosedFilterType.all;
  String? _selectedClosedBot; // null means 'All Bots'
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

  Future<void> _launchDexScreener(String address) async {
    final url = Uri.parse('https://dexscreener.com/solana/$address');
    try {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load internal webview.')));
      }
    }
  }

  String formatLagosTime(String? utcString) {
    if (utcString == null || utcString.isEmpty) return '-';
    try {
      String formattedStr = utcString.replaceAll(' ', 'T');
      if (!formattedStr.endsWith('Z')) formattedStr += 'Z';
      final utcDateTime = DateTime.parse(formattedStr);
      final lagosDateTime = utcDateTime.add(const Duration(hours: 1)); 
      
      final hour24 = lagosDateTime.hour;
      final hour12 = (hour24 % 12 == 0) ? 12 : hour24 % 12;
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final minute = lagosDateTime.minute.toString().padLeft(2, '0');
      
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = monthNames[lagosDateTime.month - 1];
      final day = lagosDateTime.day;

      return '$hour12:$minute $period, $month $day';
    } catch (e) {
      return utcString;
    }
  }

  String calculateTimeInTrade(String? openedAtStr, [String? closedAtStr]) {
    if (openedAtStr == null || openedAtStr.isEmpty) return '-';
    try {
      String startStr = openedAtStr.replaceAll(' ', 'T');
      if (!startStr.endsWith('Z')) startStr += 'Z';
      final start = DateTime.parse(startStr);

      DateTime end;
      if (closedAtStr != null && closedAtStr.isNotEmpty) {
        String endStr = closedAtStr.replaceAll(' ', 'T');
        if (!endStr.endsWith('Z')) endStr += 'Z';
        end = DateTime.parse(endStr);
      } else {
        end = DateTime.now().toUtc();
      }

      final diff = end.difference(start);
      if (diff.inMinutes < 1) return '< 1m';

      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final minutes = diff.inMinutes % 60;

      List<String> parts = [];
      if (days > 0) parts.add('${days}d');
      if (hours > 0) parts.add('${hours}h');
      if (minutes > 0) parts.add('${minutes}m');

      return parts.join(' ');
    } catch (e) {
      return '-';
    }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatAddress(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  Future<void> _closeSinglePosition(int id) async {
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': id});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Action complete'),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
      _fetchPositions();
    }
  }

  Future<void> _executeBatchClose(List<int> ids, String description) async {
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No open trades found for: $description')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: Row(
          children: [
            const Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('Close $description?', style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to close ${ids.length} open position(s)?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Close ${ids.length} Trade(s)', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.postEndpoint('trade.php?action=batch_close', {'ids': ids});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Batch close completed.'),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
      _fetchPositions();
    }
  }

  void _showBatchCloseSheet(CurrencyProvider currency) {
    double totalProfitUsd = 0.0;
    double totalLossUsd = 0.0;

    List<int> allIds = [];
    List<int> manualIds = [];
    List<int> copyIds = [];
    List<int> profitIds = [];
    List<int> lossIds = [];
    Map<String, List<int>> botToIdsMap = {};

    for (var p in _openPositions) {
      final id = (p['id'] is int) ? p['id'] : int.tryParse(p['id'].toString()) ?? 0;
      if (id <= 0) continue;

      allIds.add(id);

      final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
      final isCopy = p['wallet_label'] != null &&
          p['wallet_label'].toString().isNotEmpty &&
          p['wallet_label'].toString() != 'Manual';
      final botName = p['display_name'] ?? p['wallet_label'] ?? 'Manual';

      if (pnl > 0) {
        totalProfitUsd += pnl;
        profitIds.add(id);
      } else if (pnl < 0) {
        totalLossUsd += pnl;
        lossIds.add(id);
      }

      if (isCopy) {
        copyIds.add(id);
        botToIdsMap.putIfAbsent(botName, () => []).add(id);
      } else {
        manualIds.add(id);
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                        const Row(
                          children: [
                            Icon(PhosphorIcons.handPalmFill, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Batch Close Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(PhosphorIcons.xBold, color: Colors.white54, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Choose target group to close immediately (${allIds.length} active positions).', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 20),

                    // Option 1: Close All
                    _buildBatchTile(
                      title: 'Close All Open Trades',
                      subtitle: '${allIds.length} trade(s) active',
                      icon: PhosphorIcons.trashFill,
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _executeBatchClose(allIds, 'All Open Trades');
                      },
                    ),

                    // Option 2: Close Profit
                    _buildBatchTile(
                      title: 'Close All Profits Only',
                      subtitle: profitIds.isEmpty
                          ? 'No active profit trades'
                          : '+${totalProfitUsd.toStringAsFixed(2)}${currency.isNaira ? " (≈ +${currency.format(totalProfitUsd).replaceFirst('₦-', '-₦')})" : ""}',
                      icon: PhosphorIcons.trendUpFill,
                      color: Colors.greenAccent,
                      count: profitIds.length,
                      onTap: () {
                        Navigator.pop(ctx);
                        _executeBatchClose(profitIds, 'Profitable Trades');
                      },
                    ),

                    // Option 3: Close Loss
                    _buildBatchTile(
                      title: 'Close All Losses Only',
                      subtitle: lossIds.isEmpty
                          ? 'No active loss trades'
                          : '${totalLossUsd.toStringAsFixed(2)}${currency.isNaira ? " (≈ ${currency.format(totalLossUsd).replaceFirst('₦-', '-₦')})" : ""}',
                      icon: PhosphorIcons.trendDownFill,
                      color: Colors.amberAccent,
                      count: lossIds.length,
                      onTap: () {
                        Navigator.pop(ctx);
                        _executeBatchClose(lossIds, 'Loss Trades');
                      },
                    ),

                    // Option 4: Close Manual
                    _buildBatchTile(
                      title: 'Close All Manual Trades',
                      subtitle: '${manualIds.length} trade(s) placed manually',
                      icon: PhosphorIcons.userFill,
                      color: Colors.purpleAccent,
                      count: manualIds.length,
                      onTap: () {
                        Navigator.pop(ctx);
                        _executeBatchClose(manualIds, 'Manual Trades');
                      },
                    ),

                    // Option 5: Close Copy Trades
                    _buildBatchTile(
                      title: 'Close All Copy Trades',
                      subtitle: '${copyIds.length} trade(s) copied from bots',
                      icon: PhosphorIcons.robotFill,
                      color: Colors.blueAccent,
                      count: copyIds.length,
                      onTap: () {
                        Navigator.pop(ctx);
                        _executeBatchClose(copyIds, 'Copy Trades');
                      },
                    ),

                    // Option 6: Close By Specific Bot / Shark
                    if (botToIdsMap.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('CLOSE BY BOT / SHARK', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      ...botToIdsMap.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _executeBatchClose(entry.value, 'Bot ${entry.key}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 16),
                                      const SizedBox(width: 8),
                                      Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                    child: Text('Close ${entry.value.length}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBatchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mirrorRealTrade(int id, dynamic defaultAmount) async {
    final sizeCtrl = TextEditingController(text: defaultAmount?.toString() ?? '5.0');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: const Row(
            children: [
              Icon(PhosphorIcons.rocketLaunchFill, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text('Deploy Real Funds', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the USD amount to execute live on-chain using this paper signal.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: sizeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Trade Size (USD)',
                  prefixIcon: const Icon(PhosphorIcons.currencyDollar, color: Colors.greenAccent),
                  labelStyle: const TextStyle(color: Colors.greenAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final res = await this.context.read<ApiService>().postEndpoint(
                  'trade.php?action=mirror_real',
                  {'id': id, 'trade_usd': sizeCtrl.text.trim()},
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ));
                  _fetchPositions();
                }
              },
              child: isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Execute Trade', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditModal(int id, String currentTp, String currentSl) async {
    final tpCtrl = TextEditingController(text: currentTp == '0' ? '' : currentTp);
    final slCtrl = TextEditingController(text: currentSl == '0' ? '' : currentSl);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(
            children: [
              Icon(PhosphorIcons.slidersFill, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Edit Targets', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tpCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Take Profit (%)',
                  hintText: 'Enter 0 for No Limit',
                  hintStyle: const TextStyle(color: Colors.white38),
                  labelStyle: const TextStyle(color: Colors.greenAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: slCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Stop Loss (%)',
                  hintText: 'Enter 0 for No Limit',
                  hintStyle: const TextStyle(color: Colors.white38),
                  labelStyle: const TextStyle(color: Colors.redAccent),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final res = await this.context.read<ApiService>().postEndpoint(
                  'trade.php?action=update_tpsl',
                  {'id': id, 'tp_percent': '0', 'sl_percent': '0'},
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: const Text('Limits removed successfully'),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ));
                  _fetchPositions();
                }
              },
              child: const Text('Remove Limits', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final saveTp = tpCtrl.text.trim().isEmpty ? '0' : tpCtrl.text.trim();
                final saveSl = slCtrl.text.trim().isEmpty ? '0' : slCtrl.text.trim();
                
                final res = await this.context.read<ApiService>().postEndpoint(
                  'trade.php?action=update_tpsl',
                  {'id': id, 'tp_percent': saveTp, 'sl_percent': saveSl},
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ));
                  _fetchPositions();
                }
              },
              child: isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) 
                : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  List<dynamic> get _filteredClosedPositions {
    final now = DateTime.now();

    return _closedPositions.where((p) {
      // 1. Search Query Filter
      if (_closedSearchQuery.isNotEmpty) {
        final query = _closedSearchQuery.toLowerCase();
        final addr = (p['token_address'] ?? '').toString().toLowerCase();
        final label = (p['wallet_label'] ?? '').toString().toLowerCase();
        final display = (p['display_name'] ?? '').toString().toLowerCase();
        if (!addr.contains(query) && !label.contains(query) && !display.contains(query)) {
          return false;
        }
      }

      // 2. Type Filter
      final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
      final isCopy = p['wallet_label'] != null &&
          p['wallet_label'].toString().isNotEmpty &&
          p['wallet_label'].toString() != 'Manual';

      if (_selectedClosedType == ClosedFilterType.profit && pnl <= 0) return false;
      if (_selectedClosedType == ClosedFilterType.loss && pnl >= 0) return false;
      if (_selectedClosedType == ClosedFilterType.copy && !isCopy) return false;
      if (_selectedClosedType == ClosedFilterType.manual && isCopy) return false;

      // 3. Bot Filter
      if (_selectedClosedBot != null && _selectedClosedBot != 'All Bots') {
        final display = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
        if (display != _selectedClosedBot) return false;
      }

      // 4. Date Range Filter
      if (_selectedDateFilter != DateRangeFilter.allTime) {
        final closedAtStr = p['closed_at']?.toString();
        if (closedAtStr == null || closedAtStr.isEmpty) return false;

        DateTime? closedDate;
        try {
          String formattedStr = closedAtStr.replaceAll(' ', 'T');
          if (!formattedStr.endsWith('Z')) formattedStr += 'Z';
          closedDate = DateTime.parse(formattedStr);
        } catch (_) {}

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

  List<String> get _availableClosedBots {
    final Set<String> bots = {'All Bots'};
    for (var p in _closedPositions) {
      final display = p['display_name'] ?? p['wallet_label'] ?? 'Manual';
      if (display.toString().isNotEmpty) {
        bots.add(display.toString());
      }
    }
    return bots.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final filteredClosedList = _filteredClosedPositions;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 16, right: 8),
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)]),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: 'Open (${_openPositions.length})'),
                      Tab(text: 'Closed (${filteredClosedList.length})'),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: IconButton(
                  icon: const Icon(PhosphorIcons.arrowsClockwiseBold, color: Colors.white, size: 20),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refreshing market data...'), duration: Duration(seconds: 1)));
                    _fetchPositions();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
                          // Batch Actions Bar for Open Trades
                          if (_openPositions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    foregroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () => _showBatchCloseSheet(currency),
                                  icon: const Icon(PhosphorIcons.handPalmFill, size: 18),
                                  label: Text(
                                    'Batch Close Actions (${_openPositions.length})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            ),

                          Expanded(
                            child: _openPositions.isEmpty 
                              ? const Center(child: Text('No active open positions.', style: TextStyle(color: Colors.white54)))
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  itemCount: _openPositions.length,
                                  itemBuilder: (context, index) {
                                    final p = _openPositions[index];
                                    final pnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '0') ?? 0.0;
                                    final pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;
                                    final isProfit = pnl >= 0;
                                    final isReal = p['is_real'] == 1 || p['is_real'] == '1';

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () => _launchDexScreener(p['token_address'] ?? ''),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        _formatAddress(p['token_address'] ?? ''),
                                                        style: const TextStyle(color: Colors.blueAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 14),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    if (isReal)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: const EdgeInsets.only(right: 6),
                                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                                                        child: const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      )
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: const EdgeInsets.only(right: 6),
                                                        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
                                                        child: const Text('PAPER', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      ),
                                                    Text(
                                                      p['display_name'] ?? p['wallet_label'] ?? 'Manual',
                                                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('ENTRY MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(_formatMcap(p['entry_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('LIVE MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(_formatMcap(p['current_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('UNREALIZED P&L', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${isProfit ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${isProfit ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                                                        style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      if (currency.isNaira)
                                                        Text(
                                                          '≈ ${isProfit && pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}',
                                                          style: TextStyle(color: isProfit ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 10),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('TRADE SIZE', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '\$${double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      if (currency.isNaira)
                                                        Text(
                                                          '≈ ${currency.format(p['virtual_usd_amount'])}',
                                                          style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(PhosphorIcons.clock, color: Colors.purpleAccent, size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${calculateTimeInTrade(p['opened_at'])} • ${formatLagosTime(p['opened_at'])}',
                                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                                InkWell(
                                                  onTap: () => _openEditModal(p['id'], p['tp_percent']?.toString() ?? '50', p['sl_percent']?.toString() ?? '20'),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white10,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: Colors.white24),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(PhosphorIcons.pencilSimple, color: Colors.white54, size: 12),
                                                        const SizedBox(width: 6),
                                                        RichText(
                                                          text: TextSpan(
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                            children: [
                                                              TextSpan(
                                                                text: (p['tp_percent'] == null || p['tp_percent'].toString() == '0' || p['tp_percent'].toString() == '0.00') ? 'No TP' : '+${p['tp_percent']}%',
                                                                style: const TextStyle(color: Colors.greenAccent),
                                                              ),
                                                              const TextSpan(text: ' / ', style: TextStyle(color: Colors.white54)),
                                                              TextSpan(
                                                                text: (p['sl_percent'] == null || p['sl_percent'].toString() == '0' || p['sl_percent'].toString() == '0.00') ? 'No SL' : '-${p['sl_percent']}%',
                                                                style: const TextStyle(color: Colors.redAccent),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            
                                            Column(
                                              children: [
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(color: Colors.redAccent),
                                                      foregroundColor: Colors.redAccent,
                                                    ),
                                                    onPressed: () => _closeSinglePosition(p['id']),
                                                    icon: const Icon(PhosphorIcons.handPalm, size: 16),
                                                    label: const Text('Close Trade Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                  ),
                                                ),
                                                if (!isReal) ...[
                                                  const SizedBox(height: 8),
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.greenAccent.withOpacity(0.2),
                                                        foregroundColor: Colors.greenAccent,
                                                        elevation: 0,
                                                        side: BorderSide(color: Colors.greenAccent.withOpacity(0.5)),
                                                      ),
                                                      onPressed: () => _mirrorRealTrade(p['id'], p['virtual_usd_amount']),
                                                      icon: const Icon(PhosphorIcons.rocketLaunch, size: 16),
                                                      label: const Text('Deploy Real Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                    ),
                                                  ),
                                                ]
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

                    // ================== TAB 2: CLOSED POSITIONS (WITH SEARCH & FILTERS) ==================
                    RefreshIndicator(
                      onRefresh: _fetchPositions,
                      child: Column(
                        children: [
                          // 1. Search Bar for Closed Positions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search closed trades by token or bot...',
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  prefixIcon: const Icon(PhosphorIcons.magnifyingGlass, color: Colors.white54, size: 18),
                                  suffixIcon: _closedSearchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(PhosphorIcons.x, color: Colors.white54, size: 16),
                                          onPressed: () => setState(() => _closedSearchQuery = ''),
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: Colors.black.withOpacity(0.3),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor)),
                                ),
                                onChanged: (val) => setState(() => _closedSearchQuery = val),
                              ),
                            ),
                          ),

                          // 2. Filter Buttons Bar (Type, Bot, Date)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Row(
                              children: [
                                // Type Filter Chips
                                _buildFilterChip('All', _selectedClosedType == ClosedFilterType.all, () {
                                  setState(() => _selectedClosedType = ClosedFilterType.all);
                                }),
                                const SizedBox(width: 6),
                                _buildFilterChip('Profits', _selectedClosedType == ClosedFilterType.profit, () {
                                  setState(() => _selectedClosedType = ClosedFilterType.profit);
                                }, color: Colors.greenAccent),
                                const SizedBox(width: 6),
                                _buildFilterChip('Losses', _selectedClosedType == ClosedFilterType.loss, () {
                                  setState(() => _selectedClosedType = ClosedFilterType.loss);
                                }, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                _buildFilterChip('Copy', _selectedClosedType == ClosedFilterType.copy, () {
                                  setState(() => _selectedClosedType = ClosedFilterType.copy);
                                }, color: Colors.blueAccent),
                                const SizedBox(width: 6),
                                _buildFilterChip('Manual', _selectedClosedType == ClosedFilterType.manual, () {
                                  setState(() => _selectedClosedType = ClosedFilterType.manual);
                                }, color: Colors.purpleAccent),

                                const SizedBox(width: 12),
                                Container(height: 20, width: 1, color: Colors.white24),
                                const SizedBox(width: 12),

                                // Bot Filter Dropdown Button
                                DropdownButton<String>(
                                  value: _selectedClosedBot ?? 'All Bots',
                                  dropdownColor: const Color(0xFF13131A),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(PhosphorIcons.caretDownBold, color: Colors.white54, size: 12),
                                  items: _availableClosedBots.map((bot) {
                                    return DropdownMenuItem<String>(
                                      value: bot,
                                      child: Row(
                                        children: [
                                          const Icon(PhosphorIcons.robot, color: Colors.blueAccent, size: 14),
                                          const SizedBox(width: 6),
                                          Text(bot),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedClosedBot = (val == 'All Bots') ? null : val;
                                    });
                                  },
                                ),

                                const SizedBox(width: 12),
                                Container(height: 20, width: 1, color: Colors.white24),
                                const SizedBox(width: 12),

                                // Date Filter Dropdown
                                DropdownButton<DateRangeFilter>(
                                  value: _selectedDateFilter,
                                  dropdownColor: const Color(0xFF13131A),
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  underline: const SizedBox(),
                                  icon: const Icon(PhosphorIcons.calendarBlankBold, color: Colors.amberAccent, size: 12),
                                  items: const [
                                    DropdownMenuItem(value: DateRangeFilter.allTime, child: Text('All Time')),
                                    DropdownMenuItem(value: DateRangeFilter.today, child: Text('Today')),
                                    DropdownMenuItem(value: DateRangeFilter.last7Days, child: Text('7 Days')),
                                    DropdownMenuItem(value: DateRangeFilter.last30Days, child: Text('30 Days')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedDateFilter = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 3. Closed Trades List
                          Expanded(
                            child: filteredClosedList.isEmpty 
                              ? const Center(child: Text('No closed trades match your filter criteria.', style: TextStyle(color: Colors.white54)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredClosedList.length,
                                  itemBuilder: (context, index) {
                                    final p = filteredClosedList[index];
                                    final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                                    final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                                    final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                                    
                                    final isProfit = pnl >= 0;
                                    final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                                    
                                    String badgeText = p['close_reason'] == 'TP_HIT' ? 'TP Hit' : (p['close_reason'] == 'SL_HIT' ? 'SL Hit' : 'Manual');
                                    Color badgeColor = p['close_reason'] == 'TP_HIT' ? Colors.greenAccent : (p['close_reason'] == 'SL_HIT' ? Colors.redAccent : Colors.blueAccent);

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: GlassCard(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () => _launchDexScreener(p['token_address'] ?? ''),
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        _formatAddress(p['token_address'] ?? ''),
                                                        style: const TextStyle(color: Colors.blueAccent, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 14),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    if (isReal)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: const EdgeInsets.only(right: 6),
                                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                                                        child: const Text('LIVE', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      )
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        margin: const EdgeInsets.only(right: 6),
                                                        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orangeAccent.withOpacity(0.3))),
                                                        child: const Text('PAPER', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                                      ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      margin: const EdgeInsets.only(right: 6),
                                                      decoration: BoxDecoration(
                                                        color: badgeColor.withOpacity(0.1),
                                                        border: Border.all(color: badgeColor.withOpacity(0.3)),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                                    ),
                                                    Text(
                                                      p['display_name'] ?? p['wallet_label'] ?? 'Manual',
                                                      style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                )
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('ENTRY MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(_formatMcap(p['entry_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('EXIT MCAP', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(_formatMcap(p['close_mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('REALIZED P&L', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${isProfit ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${isProfit ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                                                        style: TextStyle(color: isProfit ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                                                      ),
                                                      if (currency.isNaira)
                                                        Text(
                                                          '≈ ${isProfit && pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}',
                                                          style: TextStyle(color: isProfit ? Colors.greenAccent.withOpacity(0.7) : Colors.redAccent.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 11),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('TRADE SIZE', style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '\$${size.toStringAsFixed(2)}',
                                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                      ),
                                                      if (currency.isNaira)
                                                        Text(
                                                          '≈ ${currency.format(p['virtual_usd_amount'])}',
                                                          style: TextStyle(color: Colors.greenAccent.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),

                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(PhosphorIcons.clock, color: Colors.white54, size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      formatLagosTime(p['closed_at']),
                                                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(PhosphorIcons.hourglassHigh, color: Colors.amberAccent, size: 12),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      calculateTimeInTrade(p['opened_at'], p['closed_at']),
                                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
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
                  ],
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.black26,
          border: Border.all(color: isSelected ? activeColor : Colors.white10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
