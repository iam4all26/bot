import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _isLoading = true;
  String _solBalance = "0.00000";
  String _usdValue = "0.00";
  String _nativeSymbol = "SOL";
  String _errorMessage = "";

  // Static chain list matching the chains seeded server-side (chains table).
  // There's no mobile endpoint yet that returns this dynamically — if a 4th
  // chain gets added later, add it here too or wire up a chains.php endpoint.
  static const List<Map<String, String>> _chains = [
    {'id': 'solana', 'name': 'Solana', 'symbol': 'SOL'},
    {'id': 'bsc', 'name': 'BSC', 'symbol': 'BNB'},
    {'id': 'robinhood', 'name': 'Robinhood', 'symbol': 'ETH'},
  ];
  String _selectedChain = 'solana';

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('balance.php?chain=$_selectedChain');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success') {
          // FIXED: backend field renamed from 'sol_balance' to
          // 'native_balance' when the API became chain-aware; kept
          // 'sol_balance' too server-side for compatibility, reading the
          // new key here since it's always present now.
          _solBalance = res['data']['native_balance'] ?? res['data']['sol_balance'] ?? '0.00000';
          _usdValue = res['data']['usd_value'] ?? '0.00';
          _nativeSymbol = res['data']['native_symbol'] ?? 'SOL';
        } else {
          _errorMessage = res['message'] ?? 'Failed to load balance';
        }
      });
    }
  }

  void _onChainChanged(String chainId) {
    setState(() {
      _selectedChain = chainId;
      _isLoading = true;
      _errorMessage = "";
    });
    _fetchBalance();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage.isNotEmpty
          ? Row(
              children: [
                const Icon(PhosphorIcons.warningCircleFill, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
                IconButton(
                  icon: const Icon(PhosphorIcons.arrowsClockwise),
                  onPressed: () {
                    setState(() { _isLoading = true; _errorMessage = ""; });
                    _fetchBalance();
                  },
                )
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chain selector — switches which chain's wallet is displayed
                Row(
                  children: _chains.map((c) {
                    final selected = c['id'] == _selectedChain;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _onChainChanged(c['id']!),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: selected ? theme.primaryColor.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? theme.primaryColor : theme.dividerColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            c['name']!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: selected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MASTER WALLET BALANCE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() => _isLoading = true);
                        _fetchBalance();
                      },
                      child: Icon(PhosphorIcons.arrowsClockwise, size: 16, color: theme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _solBalance,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _nativeSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Text(
                        '\$$_usdValue USD',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (currency.isNaira) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                        ),
                        child: Text(
                          '≈ ${currency.format(_usdValue)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
    );
  }
}
