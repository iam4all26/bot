import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

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

  // Live Token Lookup States
  bool _isFetchingToken = false;
  Map<String, dynamic>? _tokenData;
  String? _tokenError;
  Timer? _debounceTimer;

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
    final tp = double.tryParse(_tpController.text) ?? 0;
    final size = double.tryParse(_usdController.text) ?? 0;
    setState(() => _expectedProfit = size * (tp / 100));
  }

  void _onAddressChanged() {
    final address = _tokenController.text.trim();
    _debounceTimer?.cancel();

    if (address.length >= 32 && RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(address)) {
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
    final res = await api.getEndpoint('token_info.php?address=$address');

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

  String? _validateSolanaAddress(String? value) {
    if (value == null || value.trim().isEmpty) return 'Token address required';
    if (!RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$').hasMatch(value.trim())) {
      return 'Invalid Solana token address';
    }
    return null;
  }

  Future<void> _executeTrade() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.postEndpoint('trade.php?action=manual_snipe', {
      'token_address': _tokenController.text.trim(),
      'trade_usd': _usdController.text,
      'tp_percent': _tpController.text,
      'sl_percent': _slController.text,
    });

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Trade submitted!'),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
      if (res['status'] == 'success') {
        _tokenController.clear();
        setState(() {
          _tokenData = null;
          _tokenError = null;
        });
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('MANUAL TRADE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 2, color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Token Address Input Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(PhosphorIcons.coinsFill, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('Token Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tokenController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Paste Solana Token Address',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        suffixIcon: IconButton(
                          icon: Icon(PhosphorIcons.clipboard, color: theme.primaryColor),
                          onPressed: _pasteFromClipboard,
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      validator: _validateSolanaAddress,
                    ),
                  ],
                ),
              ),

              // LIVE TOKEN TELEMETRY CARD (Auto-displays below address input)
              if (_isFetchingToken) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
                      const SizedBox(width: 12),
                      const Text('Fetching live token metrics...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ] else if (_tokenData != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_tokenData!['name']} (${_tokenData!['symbol']})',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'DEX: ${_tokenData!['dex']}',
                                  style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(PhosphorIcons.checkCircleFill, color: Colors.greenAccent, size: 12),
                                SizedBox(width: 4),
                                Text('Verified Pair', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: Colors.white.withOpacity(0.05)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('MARKET CAP', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text(_formatCurrency(_tokenData!['mcap']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('LIQUIDITY', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text(_formatCurrency(_tokenData!['liquidity']), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (_tokenError != null) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(PhosphorIcons.warningCircleFill, color: Colors.amber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_tokenError!, style: const TextStyle(color: Colors.amber, fontSize: 12))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Trade Settings Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TRADE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _usdController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Trade Size (\$)',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tpController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Take Profit (%)',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _slController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Stop Loss (%)',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Projected Profit:', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                          Text('+\$${_expectedProfit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)]),
                    boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _executeTrade,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 18)),
                    icon: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(PhosphorIcons.shoppingCartSimpleFill, color: Colors.white),
                    label: Text(
                      _isLoading ? 'EXECUTING BUY...' : 'BUY TOKEN NOW',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
