import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import 'set_pin_screen.dart';
import 'market_buy_screen.dart';

class MarketDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const MarketDashboardScreen({super.key, required this.onNavigate});

  @override
  State<MarketDashboardScreen> createState() => _MarketDashboardScreenState();
}

class _MarketDashboardScreenState extends State<MarketDashboardScreen> {
  bool _isLoading = true;
  double _totalPortfolioNaira = 0.0;
  double _totalPortfolioUsdt = 0.0;
  double _usdtSellRate = 1600.0;

  Map<String, dynamic> _balances = {};
  List<dynamic> _assets = [];
  List<dynamic> _transactions = [];

  Color _getAssetColor(String symbol) {
    switch (symbol.toUpperCase()) {
      case 'SOL': return const Color(0xFF10B981);
      case 'BNB': return const Color(0xFFF59E0B);
      case 'ETH': return const Color(0xFF3B82F6);
      case 'USDT': return const Color(0xFF14B8A6);
      default: return const Color(0xFF8B5CF6);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchHubData();
  }

  Future<void> _fetchHubData({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    final api = context.read<ApiService>();
    final res = await api.fetchMarketHub();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success' && res['data'] != null) {
          final data = res['data'];
          _balances = data['balances'] ?? {};
          _assets = data['assets'] ?? [];
          _transactions = data['transactions'] ?? [];
          _usdtSellRate = double.tryParse(data['usdt_sell_rate']?.toString() ?? '1600') ?? 1600.0;

          _calculatePortfolioTotals();
        }
      });
    }
  }

  void _calculatePortfolioTotals() {
    double totalNaira = 0.0;
    final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
    final double usdtTotal = double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;

    for (var asset in _assets) {
      final String symbol = asset['asset'] ?? 'USDT';
      final String? chain = asset['chain'];
      final double sellRate = double.tryParse(asset['ngn_sell_rate']?.toString() ?? '0') ?? 0.0;

      double balance = 0.0;
      if (chain == null || symbol == 'USDT') {
        balance = usdtTotal;
      } else {
        balance = double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0;
      }

      totalNaira += balance * sellRate;
    }

    _totalPortfolioNaira = totalNaira;
    _totalPortfolioUsdt = _usdtSellRate > 0 ? totalNaira / _usdtSellRate : 0.0;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      DateTime dt = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour12:$min $period';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Icon(icon, color: theme.colorScheme.onSurface, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent, // Let background show through
      appBar: AppBar(
        automaticallyImplyLeading: false, // NO BACK BUTTON
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success(context).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(PhosphorIcons.storefrontFill, color: AppTheme.success(context), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KAINUWA', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                Text('FIAT MARKET', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(theme.brightness == Brightness.dark ? PhosphorIcons.sunFill : PhosphorIcons.moonFill, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            icon: Icon(PhosphorIcons.lockKey, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetPinScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchHubData(),
        color: theme.primaryColor,
        backgroundColor: theme.colorScheme.surface,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                children: [
                  // Portfolio Card
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL PORTFOLIO BALANCE',
                          style: GoogleFonts.spaceGrotesk(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '\$${_totalPortfolioUsdt.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceGrotesk(
                            color: theme.colorScheme.onSurface,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '≈ ${currency.format(_totalPortfolioNaira / (currency.isNaira ? 1 : _usdtSellRate))}',
                          style: GoogleFonts.spaceGrotesk(
                            color: AppTheme.success(context),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildActionButton(
                              label: 'BUY',
                              icon: PhosphorIcons.plusBold,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const MarketBuyScreen()),
                                ).then((_) => _fetchHubData(silent: true));
                              },
                              theme: theme,
                            ),
                            _buildActionButton(
                              label: 'RECEIVE',
                              icon: PhosphorIcons.qrCodeBold,
                              onTap: () => widget.onNavigate(1),
                              theme: theme,
                            ),
                            _buildActionButton(
                              label: 'SEND',
                              icon: PhosphorIcons.paperPlaneTiltBold,
                              onTap: () => widget.onNavigate(2),
                              theme: theme,
                            ),
                            _buildActionButton(
                              label: 'CASH OUT',
                              icon: PhosphorIcons.bankBold,
                              onTap: () => widget.onNavigate(3),
                              theme: theme,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'ASSETS & MARKET RATES',
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_assets.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No assets available.',
                          style: GoogleFonts.spaceGrotesk(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: _assets.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var a = entry.value;

                          final String symbol = a['symbol'] ?? 'USDT';
                          final String? chain = a['chain'];
                          final String? chainName = a['chain_name'];
                          final bool isUsdt = chain == null || symbol == 'USDT';

                          final Color assetColor = _getAssetColor(symbol);

                          final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
                          final double usdtTotal = double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;
                          final double balance = isUsdt
                              ? usdtTotal
                              : (double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0);

                          final double sellRate = double.tryParse(a['ngn_sell_rate']?.toString() ?? '0') ?? 0.0;
                          final double nairaVal = balance * sellRate;
                          final double usdVal = _usdtSellRate > 0 ? nairaVal / _usdtSellRate : 0.0;

                          return Column(
                            children: [
                              if (idx > 0)
                                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: assetColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: assetColor.withOpacity(0.2)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          symbol.substring(0, 1).toUpperCase(),
                                          style: GoogleFonts.spaceGrotesk(
                                            color: assetColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                symbol,
                                                style: GoogleFonts.spaceGrotesk(
                                                  color: theme.colorScheme.onSurface,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              if (chainName != null) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.surfaceContainerHighest,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    chainName,
                                                    style: GoogleFonts.spaceGrotesk(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sellRate > 0
                                                ? 'Rate: ₦${sellRate.toStringAsFixed(2)}'
                                                : 'Rate Unavailable',
                                            style: GoogleFonts.spaceGrotesk(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '\$${usdVal.toStringAsFixed(2)}',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${balance.toStringAsFixed(isUsdt ? 2 : 4)} $symbol',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  const SizedBox(height: 28),

                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No recent transactions found.',
                          style: GoogleFonts.spaceGrotesk(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: _transactions.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var t = entry.value;

                          final String type = t['type'] ?? 'buy';
                          final String status = t['status'] ?? 'pending';
                          final double amount = double.tryParse(t['amount']?.toString() ?? '0') ?? 0.0;
                          final String asset = t['asset'] ?? 'USDT';
                          final double nairaVal = double.tryParse(t['naira_value']?.toString() ?? '0') ?? 0.0;

                          final bool isBuy = type == 'buy';
                          final bool isConfirmed = status == 'confirmed';

                          Color statusColor = AppTheme.warning(context);
                          if (isConfirmed) statusColor = AppTheme.success(context);
                          if (status == 'failed') statusColor = AppTheme.danger(context);

                          return Column(
                            children: [
                              if (idx > 0)
                                Divider(color: theme.colorScheme.outlineVariant, height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: (isBuy ? AppTheme.success(context) : theme.primaryColor).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isBuy ? PhosphorIcons.arrowDownLeftBold : PhosphorIcons.arrowUpRightBold,
                                        color: isBuy ? AppTheme.success(context) : theme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isBuy ? 'Bought $asset' : 'Sent / Cashed Out',
                                            style: GoogleFonts.spaceGrotesk(
                                              color: theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _formatDate(t['created_at']),
                                            style: GoogleFonts.spaceGrotesk(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${isBuy ? '+' : '-'}${amount.toStringAsFixed(4)} $asset',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: isBuy ? AppTheme.success(context) : theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '₦${nairaVal.toStringAsFixed(2)}',
                                              style: GoogleFonts.spaceGrotesk(
                                                color: theme.colorScheme.onSurfaceVariant,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
