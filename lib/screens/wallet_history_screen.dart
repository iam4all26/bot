import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Error fetching data'), backgroundColor: Colors.red));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _launchDexScreener(String address) async {
    final url = Uri.parse('https://dexscreener.com/solana/$address');
    try {
      await launchUrl(url, mode: LaunchMode.inAppWebView);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load internal webview.')));
    }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF7351FF))),
      );
    }

    final int closedTrades = _stats?['closed_trades'] ?? 0;
    final int winningTrades = _stats?['winning_trades'] ?? 0;
    final double winRate = closedTrades > 0 ? (winningTrades / closedTrades) * 100 : 0;
    final double totalPnl = double.tryParse(_stats?['total_pnl']?.toString() ?? '0') ?? 0;
    final double totalVolume = double.tryParse(_stats?['total_volume']?.toString() ?? '0') ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIcons.arrowLeftBold, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Telemetry: ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                  child: Text(_wallet?['label'] ?? '', style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(_wallet?['address'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHistory,
        color: const Color(0xFF7351FF),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('WIN RATE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            Icon(PhosphorIcons.targetDuotone, color: winRate >= 50 ? Colors.greenAccent : Colors.amberAccent, size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${winRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Over $closedTrades trades', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ACTIVE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            Icon(PhosphorIcons.folderOpenDuotone, color: Color(0xFF7351FF), size: 20),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${_stats?['open_trades'] ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Currently holding', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('TOTAL P&L', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            SizedBox(width: 4),
                            Icon(PhosphorIcons.currencyCircleDollarDuotone, color: Colors.greenAccent, size: 16),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${totalPnl >= 0 ? '+' : ''}\$${totalPnl.toStringAsFixed(2)}', style: TextStyle(color: totalPnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                        if (currency.isNaira)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '≈ ${totalPnl >= 0 ? '+' : ''}${currency.format(totalPnl).replaceFirst('₦-', '-₦')}',
                              style: TextStyle(color: totalPnl >= 0 ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(height: 50, width: 1, color: Colors.white10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text('DEPLOYED', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              SizedBox(width: 4),
                              Icon(PhosphorIcons.chartBarDuotone, color: Colors.blueAccent, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('\$${totalVolume.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          const Text('Total volume', style: TextStyle(color: Colors.white54, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('RECENT COPY TRADES', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 12),
            if (_positions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No trades found for this wallet.', style: TextStyle(color: Colors.white54)),
                ),
              )
            else
              ..._positions.map((p) {
                final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0;
                final isOpen = p['status'] == 'open';
                final isWin = p['close_reason'] == 'TP_HIT';
                final isLoss = p['close_reason'] == 'SL_HIT';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _launchDexScreener(p['token_address']),
                                child: Row(
                                  children: [
                                    Text(
                                      '${p['token_address'].substring(0, 8)}...',
                                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(PhosphorIcons.arrowUpRightBold, color: Colors.white54, size: 12),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(_formatMcap(p['entry_mcap']), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  const Icon(PhosphorIcons.arrowRightBold, color: Colors.white38, size: 10),
                                  Text(isOpen ? ' Active' : _formatMcap(p['close_mcap']), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isOpen)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('OPEN', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)))
                            else if (isWin)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('WIN', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)))
                            else if (isLoss)
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('LOSS', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)))
                            else
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)), child: const Text('MANUAL', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold))),
                            
                            const SizedBox(height: 6),
                            if (!isOpen) ...[
                              Text(
                                '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
                                style: TextStyle(color: pnl >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (currency.isNaira)
                                Text(
                                  '≈ ${pnl >= 0 ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦')}',
                                  style: TextStyle(color: pnl >= 0 ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                            ] else 
                              const Text('-', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold))
                          ],
                        )
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
