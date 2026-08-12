import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';

class MarketBuyScreen extends StatefulWidget {
  const MarketBuyScreen({super.key});

  @override
  State<MarketBuyScreen> createState() => _MarketBuyScreenState();
}

class _MarketBuyScreenState extends State<MarketBuyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ngnAmountController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;

  String _selectedAssetKey = 'USDT';
  List<dynamic> _assets = [];

  @override
  void initState() {
    super.initState();
    _fetchBuyInitialData();
  }

  @override
  void dispose() {
    _ngnAmountController.dispose();
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

  Future<void> _handleBuyCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    final ngnAmount = double.tryParse(_ngnAmountController.text.trim()) ?? 0.0;
    if (ngnAmount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum purchase amount is ₦500.', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
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
        final Uri url = Uri.parse(redirectUrl);

        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Redirecting to secure gateway checkout...', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: AppTheme.success(context),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch payment gateway URL.', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
              backgroundColor: AppTheme.danger(context),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Could not initialize payment checkout.', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: AppTheme.danger(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final assetData = _getSelectedAssetData();
    final double buyRate = double.tryParse(assetData?['ngn_buy_rate']?.toString() ?? '0') ?? 0.0;
    final double typedNgn = double.tryParse(_ngnAmountController.text.trim()) ?? 0.0;
    final double estimatedCrypto = buyRate > 0 ? typedNgn / buyRate : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'BUY CRYPTO WITH NAIRA',
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
                        'SELECT ASSET TO BUY',
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
                            final String? chainName = a['chain_name'];
                            final bool isSelected = symbol == _selectedAssetKey;
                            final double rate = double.tryParse(a['ngn_buy_rate']?.toString() ?? '0') ?? 0.0;

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
                                        const Spacer(),
                                        Text(
                                          rate > 0 ? '₦${rate.toStringAsFixed(2)}' : 'Unavailable',
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
                            TextFormField(
                              controller: _ngnAmountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Purchase Amount in Naira (₦)',
                                hintText: 'e.g. 5000',
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
                                if (amt == null || amt < 500) {
                                  return 'Minimum purchase amount is ₦500';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Estimated Asset Credit:',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '${estimatedCrypto.toStringAsFixed(6)} $_selectedAssetKey',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: AppTheme.success(context),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Settlement Rate:',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '₦${buyRate.toStringAsFixed(2)} / $_selectedAssetKey',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
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
