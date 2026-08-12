import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/withdrawal_pin_modal.dart';
import 'set_pin_screen.dart';

class MarketSendCryptoScreen extends StatefulWidget {
  const MarketSendCryptoScreen({super.key});

  @override
  State<MarketSendCryptoScreen> createState() => _MarketSendCryptoScreenState();
}

class _MarketSendCryptoScreenState extends State<MarketSendCryptoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasPin = false;

  String _selectedAssetKey = 'USDT';
  List<dynamic> _assets = [];
  Map<String, dynamic> _balances = {};
  double _usdtSellRate = 1600.0;

  @override
  void initState() {
    super.initState();
    _fetchSendInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchSendInitialData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    final results = await Future.wait([
      api.checkPinStatus(),
      api.fetchMarketHub(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['status'] == 'success' && results[0]['data'] != null) {
          _hasPin = results[0]['data']['has_pin'] ?? false;
        }
        if (results[1]['status'] == 'success' && results[1]['data'] != null) {
          _assets = results[1]['data']['assets'] ?? [];
          _balances = results[1]['data']['balances'] ?? {};
          _usdtSellRate = double.tryParse(results[1]['data']['usdt_sell_rate']?.toString() ?? '1600') ?? 1600.0;
        }
      });
    }
  }

  Map<String, dynamic>? _getSelectedAssetData() {
    for (var a in _assets) {
      if (a['asset'] == _selectedAssetKey) return a;
    }
    return _assets.isNotEmpty ? _assets.first : null;
  }

  double _getAvailableBalance() {
    final assetData = _getSelectedAssetData();
    if (assetData == null) return 0.0;

    final String? chain = assetData['chain'];
    final bool isUsdt = chain == null || _selectedAssetKey == 'USDT';

    if (isUsdt) {
      return double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;
    }

    final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
    return double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0;
  }

  void _setMaxAmount() {
    final balance = _getAvailableBalance();
    setState(() {
      _amountController.text = balance.toString();
    });
  }

  bool _validateAddressFormat(String address) {
    final assetData = _getSelectedAssetData();
    final String? chain = assetData?['chain'];

    if (chain == 'bsc' || chain == 'robinhood') {
      return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
    }
    return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);
  }

  Future<void> _handleSendClick() async {
    if (!_hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please set up a withdrawal PIN first.',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppTheme.warning(context),
        ),
      );

      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetPinScreen()),
      );
      if (result == true) _fetchSendInitialData();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final address = _addressController.text.trim();
    if (!_validateAddressFormat(address)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Invalid wallet address format for this network.',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final balance = _getAvailableBalance();

    if (amount <= 0 || amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Amount exceeds available balance.',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    final String? pin = await WithdrawalPinModal.show(
      context,
      title: 'Authorize Send',
      subtitle: 'Enter your 4-digit PIN to send $amount $_selectedAssetKey.',
    );

    if (pin == null || pin.length != 4) return;

    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();

    final res = await api.withdrawCrypto(
      asset: _selectedAssetKey,
      amount: amount,
      destinationAddress: address,
      pin: pin,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      final bool isSuccess = res['status'] == 'success';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? (isSuccess ? 'Crypto dispatched!' : 'Send failed'),
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: isSuccess ? AppTheme.success(context) : AppTheme.danger(context),
        ),
      );

      if (isSuccess) {
        _amountController.clear();
        _addressController.clear();
        _fetchSendInitialData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    final double availableBalance = _getAvailableBalance();
    final double typedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final assetData = _getSelectedAssetData();
    final double sellRate = double.tryParse(assetData?['ngn_sell_rate']?.toString() ?? '0') ?? 0.0;
    final double estimatedNaira = typedAmount * sellRate;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'SEND CRYPTO ON-CHAIN',
          style: GoogleFonts.spaceGrotesk(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeftBold, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedCryptoBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT ASSET TO SEND',
                        style: GoogleFonts.spaceGrotesk(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: _assets.asMap().entries.map((entry) {
                            int idx = entry.key;
                            var a = entry.value;

                            final String symbol = a['symbol'] ?? 'USDT';
                            final String? chain = a['chain'];
                            final bool isSelected = symbol == _selectedAssetKey;
                            final bool isUsdt = chain == null || symbol == 'USDT';

                            final Map<String, dynamic> nativeBals = _balances['native'] ?? {};
                            final double usdtTotal = double.tryParse(_balances['usdt_total']?.toString() ?? '0') ?? 0.0;
                            final double balance = isUsdt
                                ? usdtTotal
                                : (double.tryParse(nativeBals[chain]?.toString() ?? '0') ?? 0.0);

                            return Column(
                              children: [
                                if (idx > 0)
                                  Divider(color: theme.colorScheme.outlineVariant, height: 1),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedAssetKey = symbol;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected ? PhosphorIcons.checkCircleFill : PhosphorIcons.circle,
                                          color: isSelected ? theme.primaryColor : theme.colorScheme.outline,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          symbol,
                                          style: GoogleFonts.spaceGrotesk(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          '${balance.toStringAsFixed(isUsdt ? 2 : 4)} $symbol',
                                          style: GoogleFonts.spaceGrotesk(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'AVAILABLE BALANCE',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    side: BorderSide(color: theme.primaryColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: _setMaxAmount,
                                  child: Text(
                                    'USE MAX',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: theme.primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${availableBalance.toStringAsFixed(4)} $_selectedAssetKey',
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Amount ($_selectedAssetKey)',
                                labelStyle: GoogleFonts.spaceGrotesk(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                final amt = double.tryParse(val?.trim() ?? '');
                                if (amt == null || amt <= 0) {
                                  return 'Enter a valid amount';
                                }
                                if (amt > availableBalance) {
                                  return 'Exceeds balance';
                                }
                                return null;
                              },
                            ),
                            if (typedAmount > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                '≈ ${currency.format(estimatedNaira / _usdtSellRate)} (Estimated Value)',
                                style: GoogleFonts.spaceGrotesk(
                                  color: AppTheme.success(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _addressController,
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Recipient Address',
                                hintText: 'Paste destination wallet address',
                                labelStyle: GoogleFonts.spaceGrotesk(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Address required';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSubmitting ? null : _handleSendClick,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(PhosphorIcons.paperPlaneTiltFill, size: 20),
                          label: Text(
                            _isSubmitting ? 'DISPATCHING...' : 'AUTHORIZE & SEND',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
