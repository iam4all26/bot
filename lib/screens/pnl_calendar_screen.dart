import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

class PnlCalendarScreen extends StatefulWidget {
  const PnlCalendarScreen({super.key});

  @override
  State<PnlCalendarScreen> createState() => _PnlCalendarScreenState();
}

class _PnlCalendarScreenState extends State<PnlCalendarScreen> {
  bool _isLoading = true;
  List<dynamic> _allClosedPositions = [];
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchPositions();
  }

  Future<void> _fetchPositions() async {
    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch');
    if (mounted) {
      if (res['status'] == 'success') {
        _allClosedPositions = res['closed_positions'] ?? [];
      }
      setState(() => _isLoading = false);
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset, 1);
    });
  }

  Map<int, double> _calculateDailyPnl() {
    Map<int, double> dailyMap = {};
    for (var p in _allClosedPositions) {
      try {
        DateTime dt = DateTime.parse(p['closed_at'].toString().replaceAll(' ', 'T') + 'Z').toLocal();
        if (dt.year == _currentMonth.year && dt.month == _currentMonth.month) {
          double pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
          dailyMap[dt.day] = (dailyMap[dt.day] ?? 0.0) + pnl;
        }
      } catch (_) {}
    }
    return dailyMap;
  }

  void _shareStats(double total, int winDays, double winAmt, int lossDays, double lossAmt, CurrencyProvider currency) {
    String formattedTotal = currency.format(total);
    String monthName = DateFormat('MMM yyyy').format(_currentMonth);
    
    String message = "My Kainuwa Trading P&L for $monthName 📈\n\n"
        "Net Profit: $formattedTotal\n"
        "Profitable Days: $winDays (${currency.format(winAmt)})\n"
        "Loss Days: $lossDays (${currency.format(lossAmt)})\n\n"
        "Powered by @kainuwaafrica 🚀";
        
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    final dailyPnl = _calculateDailyPnl();
    
    double totalPnl = 0.0;
    int winDays = 0;
    double winAmount = 0.0;
    int lossDays = 0;
    double lossAmount = 0.0;

    dailyPnl.forEach((day, pnl) {
      totalPnl += pnl;
      if (pnl > 0) {
        winDays++;
        winAmount += pnl;
      } else if (pnl < 0) {
        lossDays++;
        lossAmount += pnl;
      }
    });

    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; 
    int prefixDays = firstWeekday == 7 ? 0 : firstWeekday; 

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('P&L CALENDAR', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeftBold, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.shareNetworkBold, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () => _shareStats(totalPnl, winDays, winAmount, lossDays, lossAmount, currency),
          ),
        ],
      ),
      body: AnimatedCryptoBackground(
        child: _isLoading 
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(PhosphorIcons.caretLeftBold, color: theme.colorScheme.onSurfaceVariant, size: 18),
                            onPressed: () => _changeMonth(-1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          Text(DateFormat('MMM yyyy').format(_currentMonth), style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(PhosphorIcons.caretRightBold, color: theme.colorScheme.onSurfaceVariant, size: 18),
                            onPressed: () => _changeMonth(1),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => currency.toggleCurrency(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.currencyCircleDollarFill, size: 16, color: theme.primaryColor),
                              const SizedBox(width: 6),
                              Text(currency.isNaira ? 'NGN' : 'USD', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Monthly PnL', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${totalPnl >= 0 ? '+' : ''}${currency.format(totalPnl)}', 
                              style: GoogleFonts.spaceGrotesk(color: totalPnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)
                            ),
                            if (currency.isNaira) ...[
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '≈ ${totalPnl >= 0 ? '+' : ''}\$${totalPnl.abs().toStringAsFixed(2)}', 
                                  style: GoogleFonts.spaceGrotesk(color: totalPnl >= 0 ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(height: 1, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(PhosphorIcons.trendUpBold, color: AppTheme.success(context), size: 14),
                                      const SizedBox(width: 6),
                                      Text('Profits ($winDays days)', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '+${currency.format(winAmount)}', 
                                    style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontSize: 15, fontWeight: FontWeight.bold)
                                  ),
                                ]
                              ),
                            ),
                            Container(width: 1, height: 30, color: theme.colorScheme.outlineVariant),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(PhosphorIcons.trendDownBold, color: AppTheme.danger(context), size: 14),
                                      const SizedBox(width: 6),
                                      Text('Losses ($lossDays days)', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    currency.format(lossAmount), 
                                    style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context), fontSize: 15, fontWeight: FontWeight.bold)
                                  ),
                                ]
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(day, style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: prefixDays + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < prefixDays) return const SizedBox();
                      
                      int currentDay = index - prefixDays + 1;
                      double dayPnl = dailyPnl[currentDay] ?? 0.0;
                      bool hasTrades = dailyPnl.containsKey(currentDay);
                      
                      Color bgColor = theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
                      Color textColor = theme.colorScheme.onSurfaceVariant;
                      String pnlStr = '';

                      if (hasTrades) {
                        if (dayPnl > 0) {
                          bgColor = AppTheme.success(context).withOpacity(0.12);
                          textColor = AppTheme.success(context);
                          pnlStr = '+${currency.format(dayPnl)}';
                        } else if (dayPnl < 0) {
                          bgColor = AppTheme.danger(context).withOpacity(0.12);
                          textColor = AppTheme.danger(context);
                          pnlStr = currency.format(dayPnl);
                        } else {
                          textColor = theme.colorScheme.onSurface;
                          pnlStr = currency.format(0);
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: hasTrades ? textColor.withOpacity(0.3) : Colors.transparent),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$currentDay', 
                              style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)
                            ),
                            if (hasTrades) ...[
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  pnlStr.replaceAll('₦', '').replaceAll('\$', ''), 
                                  style: GoogleFonts.spaceGrotesk(color: textColor, fontWeight: FontWeight.bold, fontSize: 10)
                                ),
                              ),
                            ]
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }
}
