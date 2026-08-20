import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../theme/app_theme.dart';
import '../widgets/pnl_share_dialog.dart';

class WalletHistoryScreen extends StatefulWidget {
  final int walletId;
  const WalletHistoryScreen({super.key, required this.walletId});

  @override
  State<WalletHistoryScreen> createState() => _WalletHistoryScreenState();
}

class _WalletHistoryScreenState extends State<WalletHistoryScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _wallet;
  Map<String, dynamic>? _stats;
  List<dynamic> _positions = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('admin_wallets.php?action=fetch_history&id=${widget.walletId}');
    
    if (mounted) {
      if (res['status'] == 'success') {
        setState(() {
          _wallet = res['data']['wallet'];
          _stats = res['data']['stats'];
          _positions = res['data']['positions'] ?? [];
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error fetching data'), backgroundColor: AppTheme.danger(context)));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _launchDexScreener(String address, {String chain = 'solana'}) async {
    final url = Uri.parse('https://dexscreener.com/$chain/$address');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Failed to load DEX.'), backgroundColor: AppTheme.warning(context)));
    }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _maskAddress(String? address) {
    if (address == null || address.length < 10) return address ?? '';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTokenDisplay(dynamic symbol, dynamic address) {
    final s = symbol?.toString().trim();
    if (s != null && s.isNotEmpty && !['UNKNOWN', 'MANUAL', 'N/A'].contains(s.toUpperCase())) {
      return s.startsWith('\$') ? s : '\$$s';
    }
    return _maskAddress(address?.toString() ?? '');
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

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final theme = Theme.of(context);
    final isAdmin = context.read<ApiService>().role == 'admin';

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AnimatedCryptoBackground(
          child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
        ),
      );
    }

    int totalClosed = 0;
    int totalWins = 0;
    int totalLosses = 0;
    
    for (var p in _positions) {
      if (p['status'] == 'closed') {
        totalClosed++;
        double pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0;
        if (p['close_reason'] == 'TP_HIT' || p['close_reason'] == 'TRAILING_SL_HIT' || (p['close_reason'] == 'MANUAL' && pnl > 0)) {
          totalWins++;
        } else if (pnl < 0 || p['close_reason'] == 'SL_HIT') {
          totalLosses++;
        }
      }
    }

    final double winRate = totalClosed > 0 ? (totalWins / totalClosed) * 100 : 0;
    final double totalPnl = double.tryParse(_stats?['total_pnl']?.toString() ?? '0') ?? 0;
    final double totalVolume = double.tryParse(_stats?['total_volume']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeftBold, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Telemetry: ', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.info(context).withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.info(context).withOpacity(0.3))),
                  child: Text(_wallet?['label'] ?? '', style: TextStyle(color: AppTheme.info(context), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_maskAddress(_wallet?['address']), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
      ),
      body: AnimatedCryptoBackground(
        child: RefreshIndicator(
          onRefresh: _fetchHistory,
          color: theme.primaryColor,
          backgroundColor: theme.colorScheme.surface,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 120, 24, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TOTAL TRADES', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Icon(PhosphorIcons.hashBold, color: theme.primaryColor, size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('$totalClosed', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('W: $totalWins | L: $totalLosses', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('WIN RATE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              Icon(PhosphorIcons.targetFill, color: winRate >= 50 ? AppTheme.success(context) : AppTheme.warning(context), size: 20),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('${winRate.toStringAsFixed(1)}%', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Includes manual profit', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('TOTAL P&L', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(width: 8),
                              Icon(PhosphorIcons.currencyCircleDollarFill, color: AppTheme.success(context), size: 18),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('${totalPnl >= 0 ? '+' : ''}\$${totalPnl.toStringAsFixed(2)}', style: TextStyle(color: totalPnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context), fontSize: 24, fontWeight: FontWeight.bold)),
                          if (currency.isNaira)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '≈ ${totalPnl >= 0 ? '+' : ''}${currency.format(totalPnl).replaceFirst('₦-', '-₦')}',
                                style: TextStyle(color: totalPnl >= 0 ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(height: 60, width: 1, color: theme.colorScheme.outlineVariant),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('DEPLOYED', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                const SizedBox(width: 8),
                                Icon(PhosphorIcons.chartBarFill, color: AppTheme.info(context), size: 18),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('\$${totalVolume.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Total volume', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text('TRADE HISTORY', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 16),
              
              if (_positions.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No trades found for this wallet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                )
              else
                ..._positions.map((p) {
                  final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0;
                  final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0;
                  final pct = size > 0 ? (pnl / size) * 100 : 0.0;
                  final isOpen = p['status'] == 'open';
                  final isWin = p['close_reason'] == 'TP_HIT' || p['close_reason'] == 'TRAILING_SL_HIT' || (p['close_reason'] == 'MANUAL' && pnl > 0);
                  final isLoss = p['close_reason'] == 'SL_HIT' || (p['close_reason'] == 'MANUAL' && pnl < 0);
                  final String tokenDisplay = _formatTokenDisplay(p['symbol'], p['token_address']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => _launchDexScreener(p['token_address'], chain: p['chain'] ?? 'solana'),
                                child: Row(
                                  children: [
                                    Text(
                                      tokenDisplay,
                                      style: TextStyle(color: AppTheme.info(context), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(PhosphorIcons.arrowUpRightBold, color: AppTheme.info(context), size: 14),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOpen)
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.info(context).withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.info(context).withOpacity(0.3))), child: Text('OPEN', style: TextStyle(color: AppTheme.info(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)))
                                  else if (isWin)
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.success(context).withOpacity(0.3))), child: Text('WIN', style: TextStyle(color: AppTheme.success(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)))
                                  else if (isLoss)
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.12), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.danger(context).withOpacity(0.3))), child: Text('LOSS', style: TextStyle(color: AppTheme.danger(context), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)))
                                  else
                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.colorScheme.outlineVariant)), child: Text('MANUAL', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1))),
                                  
                                  const SizedBox(width: 8),
                                  
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (_) => PnlShareDialog(
                                          tradeData: p as Map<String, dynamic>, 
                                          isAdmin: isAdmin,
                                        ),
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
                                          Text('Share', style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          
                          Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ENTRY MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(p['entry_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isOpen ? 'LIVE MCAP' : 'EXIT MCAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatMcap(isOpen ? p['current_mcap'] : p['close_mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14))])),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(isOpen ? 'UNREALIZED P&L' : 'REALIZED P&L', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                Text(isOpen ? '-' : '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)', style: TextStyle(color: isOpen ? theme.colorScheme.onSurfaceVariant : (pnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context)), fontWeight: FontWeight.bold, fontSize: 15)),
                                if (currency.isNaira && !isOpen) Text('≈ ${pnl > 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(color: pnl >= 0 ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)),
                              ])),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('TRADE SIZE', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6),
                                Text('\$${size.toStringAsFixed(2)}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
                                if (currency.isNaira) Text('≈ ${currency.format(size)}', style: TextStyle(color: AppTheme.success(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ])),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(height: 1, color: theme.colorScheme.outlineVariant),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [Icon(PhosphorIcons.clock, color: theme.colorScheme.onSurfaceVariant, size: 14), const SizedBox(width: 6), Text(formatLagosTime(p['opened_at']), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500))]),
                              Row(children: [Icon(PhosphorIcons.hourglassHigh, color: AppTheme.warning(context), size: 14), const SizedBox(width: 6), Text(calculateTimeInTrade(p['opened_at'], p['closed_at']), style: TextStyle(color: AppTheme.warning(context), fontWeight: FontWeight.bold, fontSize: 12))]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
