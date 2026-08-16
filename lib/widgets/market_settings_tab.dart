import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class MarketSettingsTab extends StatefulWidget {
  const MarketSettingsTab({super.key});

  @override
  State<MarketSettingsTab> createState() => _MarketSettingsTabState();
}

class _MarketSettingsTabState extends State<MarketSettingsTab> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _activeProvider = 'paystack';
  double _baseUsdtRate = 1500; // custom_ngn_rate, falling back to usd_ngn_rate — same base the web panel uses

  final _paystackSecretCtrl = TextEditingController();
  final _paystackPublicCtrl = TextEditingController();
  final _flwSecretCtrl = TextEditingController();
  final _flwPublicCtrl = TextEditingController();
  final _flwWebhookHashCtrl = TextEditingController();

  final _buyPctCtrl = TextEditingController();
  final _sellPctCtrl = TextEditingController();

  final _usdtMintCtrl = TextEditingController();
  String _solNetwork = 'devnet';
  String _bscNetwork = 'testnet';
  String _robinhoodNetwork = 'testnet';

  final _feeSolNativeCtrl = TextEditingController();
  final _feeSolUsdtCtrl = TextEditingController();
  final _feeBscNativeCtrl = TextEditingController();
  final _feeNairaFlatCtrl = TextEditingController();

  bool _showPaystackSecret = false;
  bool _showFlwSecret = false;
  bool _showFlwHash = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _paystackSecretCtrl.dispose();
    _paystackPublicCtrl.dispose();
    _flwSecretCtrl.dispose();
    _flwPublicCtrl.dispose();
    _flwWebhookHashCtrl.dispose();
    _buyPctCtrl.dispose();
    _sellPctCtrl.dispose();
    _usdtMintCtrl.dispose();
    _feeSolNativeCtrl.dispose();
    _feeSolUsdtCtrl.dispose();
    _feeBscNativeCtrl.dispose();
    _feeNairaFlatCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('admin.php?action=fetch_settings');

    if (mounted && res['status'] == 'success') {
      final data = Map<String, dynamic>.from(res['data'] ?? {});

      final customRate = double.tryParse(data['custom_ngn_rate']?.toString() ?? '0') ?? 0;
      _baseUsdtRate = customRate > 0 ? customRate : (double.tryParse(data['usd_ngn_rate']?.toString() ?? '1500') ?? 1500);

      final buyRate = double.tryParse(data['market_usdt_ngn_buy_rate']?.toString() ?? '1650') ?? 1650;
      final sellRate = double.tryParse(data['market_usdt_ngn_sell_rate']?.toString() ?? '1550') ?? 1550;

      setState(() {
        _activeProvider = (data['active_payment_provider'] == 'flutterwave') ? 'flutterwave' : 'paystack';

        _paystackSecretCtrl.text = data['paystack_secret_key'] ?? '';
        _paystackPublicCtrl.text = data['paystack_public_key'] ?? '';
        _flwSecretCtrl.text = data['flutterwave_secret_key'] ?? '';
        _flwPublicCtrl.text = data['flutterwave_public_key'] ?? '';
        _flwWebhookHashCtrl.text = data['flutterwave_webhook_secret_hash'] ?? '';

        _buyPctCtrl.text = _baseUsdtRate > 0 ? (((buyRate - _baseUsdtRate) / _baseUsdtRate) * 100).toStringAsFixed(2) : '0';
        _sellPctCtrl.text = _baseUsdtRate > 0 ? (((sellRate - _baseUsdtRate) / _baseUsdtRate) * 100).toStringAsFixed(2) : '0';

        _usdtMintCtrl.text = data['market_usdt_mint'] ?? 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB';
        _solNetwork = ['devnet', 'mainnet'].contains(data['market_solana_network']) ? data['market_solana_network'] : 'devnet';
        _bscNetwork = ['testnet', 'mainnet'].contains(data['bsc_market_solana_network']) ? data['bsc_market_solana_network'] : 'testnet';
        _robinhoodNetwork = ['testnet', 'mainnet'].contains(data['robinhood_market_solana_network']) ? data['robinhood_market_solana_network'] : 'testnet';

        _feeSolNativeCtrl.text = data['withdrawal_fee_solana_native'] ?? '0.001';
        _feeSolUsdtCtrl.text = data['withdrawal_fee_solana_usdt'] ?? '0.3';
        _feeBscNativeCtrl.text = data['withdrawal_fee_bsc_native'] ?? '0.0006';
        _feeNairaFlatCtrl.text = data['withdrawal_fee_naira_flat'] ?? '150';

        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get _exactBuyRate => _baseUsdtRate * (1 + ((double.tryParse(_buyPctCtrl.text) ?? 0) / 100));
  double get _exactSellRate => _baseUsdtRate * (1 + ((double.tryParse(_sellPctCtrl.text) ?? 0) / 100));

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    final payload = {
      'active_payment_provider': _activeProvider,
      'paystack_secret_key': _paystackSecretCtrl.text.trim(),
      'paystack_public_key': _paystackPublicCtrl.text.trim(),
      'flutterwave_secret_key': _flwSecretCtrl.text.trim(),
      'flutterwave_public_key': _flwPublicCtrl.text.trim(),
      'flutterwave_webhook_secret_hash': _flwWebhookHashCtrl.text.trim(),
      'market_usdt_ngn_buy_rate': _exactBuyRate.toStringAsFixed(2),
      'market_usdt_ngn_sell_rate': _exactSellRate.toStringAsFixed(2),
      'market_usdt_mint': _usdtMintCtrl.text.trim(),
      'market_solana_network': _solNetwork,
      'bsc_market_solana_network': _bscNetwork,
      'robinhood_market_solana_network': _robinhoodNetwork,
      'withdrawal_fee_solana_native': _feeSolNativeCtrl.text,
      'withdrawal_fee_solana_usdt': _feeSolUsdtCtrl.text,
      'withdrawal_fee_bsc_native': _feeBscNativeCtrl.text,
      'withdrawal_fee_naira_flat': _feeNairaFlatCtrl.text,
    };

    final api = context.read<ApiService>();
    final res = await api.postEndpoint('admin.php?action=save_market_settings', payload);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Settings updated', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
      ));
    }
  }

  Widget _sectionHeader(IconData icon, String title, {Color? color}) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(icon, color: color ?? theme.primaryColor, size: 18),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(color: color ?? theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    IconData icon = PhosphorIcons.textT,
    bool numeric = false,
    bool obscure = false,
    VoidCallback? toggleObscure,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: obscure || !numeric ? 'monospace' : null),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: theme.primaryColor, size: 18),
              suffixIcon: toggleObscure != null
                  ? IconButton(
                      icon: Icon(obscure ? PhosphorIcons.eyeSlashFill : PhosphorIcons.eye, color: theme.colorScheme.onSurfaceVariant, size: 18),
                      onPressed: toggleObscure,
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: theme.colorScheme.surface,
                style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                items: options.map((o) => DropdownMenuItem(value: o, child: Text(o.toUpperCase()))).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return Center(child: CircularProgressIndicator(color: theme.primaryColor));

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        // Payment Provider
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(PhosphorIcons.creditCardFill, 'Active Payment Provider'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _providerChip('Paystack', 'paystack', theme),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _providerChip('Flutterwave', 'flutterwave', theme),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('PAYSTACK KEYS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildTextField('SECRET KEY', _paystackSecretCtrl,
                  icon: PhosphorIcons.lockKeyFill, obscure: !_showPaystackSecret, toggleObscure: () => setState(() => _showPaystackSecret = !_showPaystackSecret)),
              _buildTextField('PUBLIC KEY', _paystackPublicCtrl, icon: PhosphorIcons.keyFill),
              const SizedBox(height: 8),
              Container(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 16),
              Text('FLUTTERWAVE KEYS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 12),
              _buildTextField('SECRET KEY', _flwSecretCtrl,
                  icon: PhosphorIcons.lockKeyFill, obscure: !_showFlwSecret, toggleObscure: () => setState(() => _showFlwSecret = !_showFlwSecret)),
              _buildTextField('PUBLIC KEY', _flwPublicCtrl, icon: PhosphorIcons.keyFill),
              _buildTextField('WEBHOOK SECRET HASH', _flwWebhookHashCtrl,
                  icon: PhosphorIcons.shieldCheckFill, obscure: !_showFlwHash, toggleObscure: () => setState(() => _showFlwHash = !_showFlwHash)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Buy/Sell Margins
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(PhosphorIcons.percentFill, 'Profit Margins', color: AppTheme.success(context)),
              const SizedBox(height: 4),
              Text('Set as a % over the base rate (₦${_baseUsdtRate.toStringAsFixed(2)}/USD).', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('BUY MARGIN (%)', _buyPctCtrl, icon: PhosphorIcons.trendUp, numeric: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('SELL MARGIN (%)', _sellPctCtrl, icon: PhosphorIcons.trendDown, numeric: true)),
                ],
              ),
              StatefulBuilder(
                builder: (context, setLocalState) {
                  // Rebuilds the preview as the user types without needing full setState.
                  return Row(
                    children: [
                      Expanded(
                        child: _ratePreview('Exact Buy Rate', _exactBuyRate, AppTheme.success(context)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ratePreview('Exact Sell Rate', _exactSellRate, AppTheme.danger(context)),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Network / Mint
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(PhosphorIcons.hashStraightFill, 'Asset & Network'),
              const SizedBox(height: 16),
              _buildTextField('USDT MINT ADDRESS', _usdtMintCtrl, icon: PhosphorIcons.hash),
              _buildNetworkDropdown('SOLANA NETWORK', _solNetwork, const ['devnet', 'mainnet'], (v) => setState(() => _solNetwork = v ?? 'devnet')),
              _buildNetworkDropdown('BSC NETWORK', _bscNetwork, const ['testnet', 'mainnet'], (v) => setState(() => _bscNetwork = v ?? 'testnet')),
              _buildNetworkDropdown('ROBINHOOD NETWORK', _robinhoodNetwork, const ['testnet', 'mainnet'], (v) => setState(() => _robinhoodNetwork = v ?? 'testnet')),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Withdrawal fees
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(PhosphorIcons.handArrowDownFill, 'Withdrawal Fees', color: AppTheme.warning(context)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTextField('SOL WITHDRAWAL FEE', _feeSolNativeCtrl, icon: PhosphorIcons.currencyDollar, numeric: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('USDT WITHDRAWAL FEE', _feeSolUsdtCtrl, icon: PhosphorIcons.currencyDollar, numeric: true)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField('BNB WITHDRAWAL FEE', _feeBscNativeCtrl, icon: PhosphorIcons.currencyDollar, numeric: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('NAIRA FLAT FEE (₦)', _feeNairaFlatCtrl, icon: PhosphorIcons.currencyNgn, numeric: true)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.info(context).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.info(context).withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.infoFill, color: AppTheme.info(context), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Treasury wallet setup (importing or generating private keys) stays on the web admin panel only, for safety.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20), elevation: 0),
            icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(PhosphorIcons.floppyDiskFill),
            label: Text(_isSaving ? 'SAVING...' : 'SAVE MARKET SETTINGS', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _providerChip(String label, String value, ThemeData theme) {
    final isSelected = _activeProvider == value;
    return InkWell(
      onTap: () => setState(() => _activeProvider = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? theme.primaryColor : theme.colorScheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _ratePreview(String label, double rate, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('₦${rate.toStringAsFixed(2)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}