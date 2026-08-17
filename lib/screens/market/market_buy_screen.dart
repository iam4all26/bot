import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';
import 'market_checkout_webview_screen.dart';

// Live-formats a numeric field with thousands separators as the user
// types (28000 -> 28,000). Cursor always lands at the end after a
// reformat — the standard, low-risk approach banking/finance apps use for
// amount fields, since people type/backspace from the end almost always.
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final raw = newValue.text.replaceAll(',', '');
    final parts = raw.split('.');
    String integerPart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    final String decimalPart = parts.length > 1 ? '.${parts[1].replaceAll(RegExp(r'[^0-9]'), '')}' : (raw.endsWith('.') ? '.' : '');

    integerPart = integerPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (integerPart.isEmpty) integerPart = '0';

    final buffer = StringBuffer();
    final reversedDigits = integerPart.split('').reversed.toList();
    for (int i = 0; i < reversedDigits.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write(',');
      buffer.write(reversedDigits[i]);
    }
    final formattedInt = buffer.toString().split('').reversed.join();
    final newText = formattedInt + decimalPart;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class MarketBuyScreen extends StatefulWidget {
  const MarketBuyScreen({super.key});

  @override
  State<MarketBuyScreen> createState() => _MarketBuyScreenState();
}

class _MarketBuyScreenState extends State<MarketBuyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  String _selectedAssetKey = 'USDT';
  List<dynamic> _assets = [];

  // false = user is typing a Naira amount. true = user is typing the
  // asset's own amount (e.g. how much USDT/SOL/BNB/ETH they want).
  bool _inputIsCrypto = false;

  static final NumberFormat _ngnFormat = NumberFormat('#,##0.00');
  static final NumberFormat _cryptoFormat = NumberFormat('#,##0.######');

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
    _fetchBuyInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchBuyInitialData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.fetchMarketHub();

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success' && res['data'] != null) {
          _assets = res['data']['assets'] ?? [];
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

  double get _typedValue => double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0.0;

  // Whichever mode the user is in, this always resolves to the actual
  // Naira amount that gets charged and sent to the backend.
  double _ngnAmount(double buyRate) {
    return _inputIsCrypto ? _typedValue * buyRate : _typedValue;
  }

  void _switchInputMode(bool toCrypto) {
    if (_inputIsCrypto == toCrypto) return;
    setState(() {
      _inputIsCrypto = toCrypto;
      _amountController.clear(); // a leftover number means something totally different in the other mode — don't carry it over
    });
  }

  Future<void> _handleBuyCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    final assetData = _getSelectedAssetData();
    final buyRate = double.tryParse(assetData?['ngn_buy_rate']?.toString() ?? '0') ?? 0.0;
    final ngnAmount = _ngnAmount(buyRate);

    if (ngnAmount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Minimum purchase amount is ₦500.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final api = context.read<ApiService>();

    final res = await api.buyCryptoInitiate(
      asset: _selectedAssetKey,
      ngnAmount: ngnAmount,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (res['status'] == 'success' && res['data'] != null && res['data']['redirect_url'] != null) {
        final String redirectUrl = res['data']['redirect_url'];
        final String reference = res['data']['reference']?.toString() ?? '';

        final result = await Navigator.of(context).push<CheckoutExit>(
          MaterialPageRoute(
            builder: (_) => MarketCheckoutWebviewScreen(checkoutUrl: redirectUrl, reference: reference),
          ),
        );

        if (result == CheckoutExit.completed && mounted) {
          await _pollTransactionStatus(reference);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Could not initialize payment checkout.', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppTheme.danger(context),
          ),
        );
      }
    }
  }

  // Polls the Bearer-authenticated status endpoint after the checkout
  // WebView hands back control. The provider webhook is usually instant,
  // but this gives it a few seconds of room before falling back to a
  // "still confirming" message instead of leaving the user guessing.
  Future<void> _pollTransactionStatus(String reference) async {
    if (reference.isEmpty || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: theme.primaryColor, strokeWidth: 2.5),
              const SizedBox(width: 20),
              const Expanded(child: Text('Confirming your payment...', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );
      },
    );

    final api = context.read<ApiService>();
    String txStatus = 'processing';

    for (int attempt = 0; attempt < 6; attempt++) {
      final res = await api.checkTransactionStatus(reference);
      if (res['status'] == 'success' && res['data'] != null) {
        txStatus = res['data']['tx_status']?.toString() ?? 'processing';
        if (txStatus == 'confirmed') break;
      }
      if (attempt < 5) await Future.delayed(const Duration(seconds: 2));
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the "confirming" dialog

    if (txStatus == 'confirmed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment confirmed — your balance has been credited.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.success(context),
        ),
      );
      Navigator.of(context).pop(); // back out to the market hub so balances refresh
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Still confirming with the payment provider. Your balance updates automatically once it settles — check your transaction history shortly.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: AppTheme.warning(context),
        ),
      );
    }
  }

  Widget _buildModeTab(String label, bool isCrypto, ThemeData theme) {
    final isSelected = _inputIsCrypto == isCrypto;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchInputMode(isCrypto),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Stacked label-above-value layout — this is the fix for the old
  // Row(spaceBetween) rows, where a long label sitting directly beside a
  // long comma-formatted number had nowhere to go but overlap on
  // narrower screens.
  Widget _buildSummaryRow(String label, String value, {Color? valueColor, bool big = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: big ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final assetData = _getSelectedAssetData();
    final double buyRate = double.tryParse(assetData?['ngn_buy_rate']?.toString() ?? '0') ?? 0.0;
    final bool isUsdt = _selectedAssetKey == 'USDT';

    final double ngnAmount = _ngnAmount(buyRate);
    final double estimatedCrypto = buyRate > 0
        ? (_inputIsCrypto ? _typedValue : ngnAmount / buyRate)
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'BUY CRYPTO WITH NAIRA',
          style: TextStyle(
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT ASSET TO BUY',
                        style: TextStyle(
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
                            final String? chainName = a['chain_name'];
                            final bool isSelected = symbol == _selectedAssetKey;
                            final double rate = double.tryParse(a['ngn_buy_rate']?.toString() ?? '0') ?? 0.0;
                            final String symbolInitial = symbol.isNotEmpty ? symbol.substring(0, 1).toUpperCase() : '?';

                            final Color assetColor = _getAssetColor(symbol);

                            return Column(
                              children: [
                                if (idx > 0)
                                  Divider(color: theme.colorScheme.outlineVariant, height: 1),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedAssetKey = symbol;
                                      _amountController.clear();
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSelected ? PhosphorIcons.checkCircleFill : PhosphorIcons.circle,
                                          color: isSelected ? theme.primaryColor : theme.colorScheme.outline,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 14),
                                        Container(
                                          width: 36,
                                          height: 36,
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: assetColor.withOpacity(0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: assetColor.withOpacity(0.2)),
                                          ),
                                          child: Image.network(
                                            'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/${symbol.toLowerCase()}.png',
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Text(
                                                  symbolInitial,
                                                  style: TextStyle(color: assetColor, fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        // Symbol + chain badge on top, rate
                                        // underneath — each on its own line
                                        // so nothing has to compete for
                                        // horizontal space with the rate.
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  Text(symbol, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
                                                  if (chainName != null)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                                                      child: Text(chainName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                rate > 0 ? '₦${_ngnFormat.format(rate)} / $symbol' : 'Rate unavailable',
                                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ],
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

                      Text(
                        'ENTER AMOUNT',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mode toggle: pay with Naira, or specify the
                            // exact amount of the asset itself.
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  _buildModeTab('Pay with ₦ Naira', false, theme),
                                  _buildModeTab('Enter $_selectedAssetKey Amount', true, theme),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            TextFormField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [_ThousandsSeparatorInputFormatter()],
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                              decoration: InputDecoration(
                                labelText: _inputIsCrypto ? 'Amount of $_selectedAssetKey to buy' : 'Amount in Naira',
                                hintText: _inputIsCrypto ? (isUsdt ? 'e.g. 10' : 'e.g. 0.05') : 'e.g. 5,000',
                                prefixText: _inputIsCrypto ? '' : '₦ ',
                                suffixText: _inputIsCrypto ? _selectedAssetKey : '',
                                prefixStyle: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 22),
                                suffixStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14),
                                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (val) {
                                if (_ngnAmount(buyRate) < 500) {
                                  return 'Minimum purchase is ₦500 worth';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            Container(height: 1, color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 4),

                            // "You pay" / "You receive" — always shown
                            // together regardless of which mode you're
                            // typing in, so there's never ambiguity about
                            // what the number you typed actually buys.
                            _buildSummaryRow(
                              'YOU PAY',
                              '₦${_ngnFormat.format(ngnAmount)}',
                            ),
                            _buildSummaryRow(
                              'YOU RECEIVE (ESTIMATED)',
                              '${_cryptoFormat.format(estimatedCrypto)} $_selectedAssetKey',
                              valueColor: AppTheme.success(context),
                              big: true,
                            ),
                            _buildSummaryRow(
                              'SETTLEMENT RATE',
                              buyRate > 0 ? '₦${_ngnFormat.format(buyRate)} / $_selectedAssetKey' : 'Unavailable',
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
                          onPressed: _isSubmitting ? null : _handleBuyCheckout,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(PhosphorIcons.creditCardFill, size: 20),
                          label: Text(
                            _isSubmitting ? 'INITIALIZING...' : 'PROCEED TO CHECKOUT',
                            style: const TextStyle(
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