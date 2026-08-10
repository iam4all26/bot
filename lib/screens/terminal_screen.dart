import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _usdController = TextEditingController(text: '10');
  final _tpController = TextEditingController(text: '50');
  final _slController = TextEditingController(text: '20');

  double _expectedProfit = 5.00;
  bool _isLoading = false;

  bool _isFetchingToken = false;
  Map<String, dynamic>? _tokenData;
  String? _tokenError;
  Timer? _debounceTimer;

  static const List<Map<String, String>> _chains = [
    {'id': 'solana', 'name': 'Solana', 'placeholder': 'Paste Solana Token Address'},
    {'id': 'bsc', 'name': 'BSC', 'placeholder': 'Paste BSC Token Address (0x...)'},
    {'id': 'robinhood', 'name': 'Robinhood', 'placeholder': 'Paste Robinhood Token (0x...)'},
  ];
  
  String _selectedChain = 'solana';

  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

  bool _isValidAddressForChain(String address) {
    if (_selectedChain == 'solana') {
      return RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address);
    }
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
  }

  void _onChainSelected(String chainId) {
    setState(() {
      _selectedChain = chainId;
      _tokenData = null;
      _tokenError = null;
    });
    if (_tokenController.text.trim().isNotEmpty) _onAddressChanged();
  }

  @override
  void initState() {
    super.initState();
    _usdController.addListener(_updateCalc);
    _tpController.addListener(_updateCalc);
    _tokenController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tokenController.removeListener(_onAddressChanged);
    _usdController.removeListener(_updateCalc);
    _tpController.removeListener(_updateCalc);
    _tokenController.dispose();
    _usdController.dispose();
    _tpController.dispose();
    _slController.dispose();
    super.dispose();
  }

  void _updateCalc() {
    final tp = double.tryParse(_tpController.text.trim()) ?? 0;
    final size = double.tryParse(_usdController.text.trim()) ?? 0;
    setState(() => _expectedProfit = size * (tp / 100));
  }

  void _onAddressChanged() {
    final address = _tokenController.text.trim();
    _debounceTimer?.cancel();

    if (_isValidAddressForChain(address)) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _fetchTokenInfo(address);
      });
    } else {
      if (_tokenData != null || _tokenError != null || _isFetchingToken) {
        setState(() {
          _tokenData = null;
          _tokenError = null;
          _isFetchingToken = false;
        });
      }
    }
  }

  Future<void> _fetchTokenInfo(String address) async {
    setState(() {
      _isFetchingToken = true;
      _tokenError = null;
      _tokenData = null;
    });

    final api = context.read<ApiService>();
    final res = await api.getEndpoint('token_info.php?address=$address&chain=$_selectedChain');

    if (mounted) {
      setState(() {
        _isFetchingToken = false;
        if (res['status'] == 'success') {
          _tokenData = res['data'];
        } else {
          _tokenError = res['message'] ?? 'Unable to fetch token telemetry';
        }
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      _tokenController.text = data.text!.trim();
    }
  }

  String? _validateTokenAddress(String? value) {
    if (value == null || value.trim().isEmpty) return 'Token address required';
    if (!_isValidAddressForChain(value.trim())) {
      return _selectedChain == 'solana' ? 'Invalid Solana token address' : 'Invalid ${_selectedChain.toUpperCase()} address (expects 0x...)';
    }
    return null;
  }

  Future<void> _executeTrade() async {
    if (!_formKey.currentState!.validate()) return;
    
    final tradeUsd = double.tryParse(_usdController.text.trim()) ?? 0.0;
    if (tradeUsd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Enter a valid trade amount', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: AppTheme.danger(context)));
      return;
    }

    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    
    // Pass strictly sanitized numbers to bypass Node.js sanity check failures
    final res = await api.postEndpoint('trade.php?action=manual_snipe', {
      'chain': _selectedChain,
      'token_address': _tokenController.text.trim(),
      'trade_usd': tradeUsd.toString(),
      'tp_percent': (double.tryParse(_tpController.text.trim()) ?? 0.0).toString(),
      'sl_percent': (double.tryParse(_slController.text.trim()) ?? 0.0).toString(),
    });

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Trade submitted!', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
      ));
      if (res['status'] == 'success') {
        _tokenController.clear();
        setState(() {
          _tokenData = null;
          _tokenError = null;
        });
        Navigator.pop(context);
      }
    }
  }

  String _formatCurrency(dynamic v) {
    if (v == null) return '-';
    double val = double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final activeChainColor = _chainColors[_selectedChain] ?? theme.primaryColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('MANUAL TRADE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1, color: theme.colorScheme.onSurface)),
      ),
      body: AnimatedCryptoBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(PhosphorIcons.coinsFill, color: activeChainColor),
                          const SizedBox(width: 12),
                          Text('Token Target', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _chains.map((c) {
                            final selected = c['id'] == _selectedChain;
                            final cColor = _chainColors[c['id']] ?? theme.primaryColor;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () => _onChainSelected(c['id']!),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected ? cColor.withOpacity(0.12) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: selected ? cColor.withOpacity(0.5) : Colors.transparent),
                                  ),
                                  child: Text(c['name']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? cColor : theme.colorScheme.onSurfaceVariant)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tokenController,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontSize: 14),
                        decoration: InputDecoration(
                          labelText: _chains.firstWhere((c) => c['id'] == _selectedChain)['placeholder'],
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          suffixIcon: IconButton(
                            icon: Icon(PhosphorIcons.clipboard, color: activeChainColor),
                            onPressed: _pasteFromClipboard,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        validator: _validateTokenAddress,
                      ),
                    ],
                  ),
                ),

                if (_isFetchingToken) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: activeChainColor)),
                        const SizedBox(width: 12),
                        Text('Fetching live token metrics...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  ),
                ] else if (_tokenData != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (_tokenData!['image_url'] != null && _tokenData!['image_url'].toString().isNotEmpty)
                                    ClipOval(child: Image.network(_tokenData!['image_url'], width: 40, height: 40, fit: BoxFit.cover))
                                  else
                                    Container(width: 40, height: 40, decoration: BoxDecoration(color: activeChainColor.withOpacity(0.12), shape: BoxShape.circle), child: Center(child: Text(_tokenData!['symbol']?.toString().substring(0, 1).toUpperCase() ?? '?', style: TextStyle(color: activeChainColor, fontWeight: FontWeight.bold, fontSize: 18)))),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Text('${_tokenData!['name']} (${_tokenData!['symbol']})', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(color: activeChainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: activeChainColor.withOpacity(0.3))),
                                              child: Text(_selectedChain.toUpperCase(), style: TextStyle(fontSize: 9, color: activeChainColor, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('DEX: ${_tokenData!['dex']}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.success(context).withOpacity(0.3))),
                              child: Row(children: [Icon(PhosphorIcons.checkCircleFill, color: AppTheme.success(context), size: 14), const SizedBox(width: 6), Text('Verified', style: TextStyle(color: AppTheme.success(context), fontSize: 11, fontWeight: FontWeight.bold))]),
                            )
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(height: 1, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MARKET CAP', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatCurrency(_tokenData!['mcap']), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15))])),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('LIQUIDITY', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_formatCurrency(_tokenData!['liquidity']), style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 15))])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else if (_tokenError != null) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.warningCircleFill, color: AppTheme.warning(context), size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_tokenError!, style: TextStyle(color: AppTheme.warning(context), fontSize: 14))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TRADE EXECUTION SETTINGS', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
                      const SizedBox(height: 24),
                      
                      // Full width Trade Size input to fix UI squeeze
                      TextFormField(
                        controller: _usdController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Trade Size (\$)',
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                          filled: true, 
                          fillColor: theme.colorScheme.surfaceContainerHighest, 
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text('Executes instantly via ${_selectedChain == 'solana' ? 'Jupiter' : 'Uniswap router'}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontSize: 11)),
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _tpController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(labelText: 'Take Profit (%)', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _slController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: AppTheme.danger(context), fontWeight: FontWeight.bold, fontSize: 16),
                              decoration: InputDecoration(labelText: 'Stop Loss (%)', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Projected Profit:', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('+\$${_expectedProfit.toStringAsFixed(2)}', style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 16)),
                                if (currency.isNaira) Text('≈ +${currency.format(_expectedProfit).replaceFirst('₦-', '-₦')}', style: TextStyle(color: AppTheme.success(context).withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _executeTrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeChainColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                    icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(PhosphorIcons.shoppingCartSimpleFill, color: Colors.white, size: 24),
                    label: Text(_isLoading ? 'EXECUTING BUY...' : 'BUY TOKEN NOW', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
