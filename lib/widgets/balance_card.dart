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
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('balance.php');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success') {
          _solBalance = res['data']['sol_balance'];
          _usdValue = res['data']['usd_value'];
        } else {
          _errorMessage = res['message'] ?? 'Failed to load balance';
        }
      });
    }
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage.isNotEmpty
          ? Row(
              children: [
                const Icon(PhosphorIcons.warningCircleFill, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
                IconButton(icon: const Icon(PhosphorIcons.arrowsClockwise), onPressed: () { setState(() { _isLoading = true; _errorMessage = ""; }); _fetchBalance(); })
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('MASTER WALLET BALANCE', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.onSurfaceVariant)),
                    InkWell(onTap: () { setState(() => _isLoading = true); _fetchBalance(); }, child: Icon(PhosphorIcons.arrowsClockwise, size: 16, color: theme.primaryColor)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_solBalance, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                    const SizedBox(width: 6),
                    Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text('SOL', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.primaryColor))),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.withOpacity(0.2))),
                  // APPLIED MASK HERE
                  child: Text(
                    currency.format(_usdValue),
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }
}
