import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';

class MarketReceiveScreen extends StatefulWidget {
  const MarketReceiveScreen({super.key});

  @override
  State<MarketReceiveScreen> createState() => _MarketReceiveScreenState();
}

class _MarketReceiveScreenState extends State<MarketReceiveScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _addresses = {};
  List<dynamic> _assets = [];
  Map<String, dynamic> _balances = {};

  String _selectedAssetKey = 'USDT';
  String _selectedNetwork = 'solana';
  bool _isCopied = false;

  static const Map<String, String> _networkNames = {
    'solana': 'Solana (SPL)',
    'bsc': 'BNB Chain (BEP-20)',
    'robinhood': 'Robinhood Chain (EVM)',
  };

  @override
  void initState() {
    super.initState();
    _fetchDepositData();
  }

  Future<void> _fetchDepositData() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    final results = await Future.wait([
      api.fetchDepositAddresses(),
      api.fetchMarketHub(),
    ]);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (results[0]['status'] == 'success' && results[0]['data'] != null) {
          _addresses = results[0]['data'] ?? {};
        }
        if (results[1]['status'] == 'success' && results[1]['data'] != null) {
          _assets = results[1]['data']['assets'] ?? [];
          _balances = results[1]['data']['balances'] ?? {};
        }
      });
    }
  }

  void _copyToClipboard(String address) {
    if (address.isEmpty || address.contains('Pending')) return;
    Clipboard.setData(ClipboardData(text: address));
    setState(() => _isCopied = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Address copied to clipboard!',
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.success(context),
        duration: const Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  String _getQrCodeUrl(String address) {
    if (address.isEmpty || address.contains('Pending')) {
      return '';
    }
    return 'https://api.qrserver.com/v1/create-qr-code/?size=240x240&margin=10&data=${Uri.encodeComponent(address)}';
  }

  List<String> _getAvailableNetworksForAsset(String symbol) {
    if (symbol == 'USDT') {
      return ['solana', 'bsc', 'robinhood'];
    }
    for (var a in _assets) {
      if (a['asset'] == symbol && a['chain'] != null) {
        return [a['chain'].toString()];
      }
    }
    return ['solana'];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableNetworks = _getAvailableNetworksForAsset(_selectedAssetKey);

    if (!availableNetworks.contains(_selectedNetwork)) {
      _selectedNetwork = availableNetworks.first;
    }

    final String currentAddress = _addresses[_selectedNetwork]?.toString() ?? 'Pending address generation...';
    final String qrUrl = _getQrCodeUrl(currentAddress);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'RECEIVE CRYPTO',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SELECT ASSET TO DEPOSIT',
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
                                    _selectedNetwork = _getAvailableNetworksForAsset(symbol).first;
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

                    if (availableNetworks.length > 1) ...[
                      Text(
                        'SELECT NETWORK',
                        style: GoogleFonts.spaceGrotesk(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: availableNetworks.map((net) {
                          final isSelected = net == _selectedNetwork;
                          final name = _networkNames[net] ?? net.toUpperCase();

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: InkWell(
                                onTap: () => setState(() => _selectedNetwork = net),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.primaryColor.withOpacity(0.15)
                                        : theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name.split(' ').first,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: isSelected
                                          ? theme.primaryColor
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.success(context).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.success(context).withOpacity(0.3)),
                            ),
                            child: Text(
                              _networkNames[_selectedNetwork] ?? _selectedNetwork.toUpperCase(),
                              style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.success(context),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (qrUrl.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                              ),
                              child: Image.network(
                                qrUrl,
                                width: 180,
                                height: 180,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  PhosphorIcons.qrCodeBold,
                                  size: 100,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          else
                            const Icon(PhosphorIcons.qrCodeBold, size: 100, color: Colors.grey),

                          const SizedBox(height: 24),
                          Text(
                            'YOUR DEPOSIT ADDRESS',
                            style: GoogleFonts.spaceGrotesk(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: SelectableText(
                              currentAddress,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isCopied ? AppTheme.success(context) : theme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _copyToClipboard(currentAddress),
                              icon: Icon(_isCopied ? PhosphorIcons.checkBold : PhosphorIcons.copyBold, size: 18),
                              label: Text(
                                _isCopied ? 'COPIED TO CLIPBOARD' : 'COPY DEPOSIT ADDRESS',
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning(context).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.warning(context).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.warningOctagonFill, color: AppTheme.warning(context), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Send only $_selectedAssetKey via ${_networkNames[_selectedNetwork]} to this address. Sending on the wrong network will cause permanent loss of funds.',
                              style: GoogleFonts.spaceGrotesk(
                                color: AppTheme.warning(context),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
