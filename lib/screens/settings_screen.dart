import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _hasWallet = false;
  String? _publicAddress;
  bool _biometricEnabled = true;

  bool _allowTelegram = false;
  bool _allowPush = true;
  String _botUsername = '';
  final _telegramCtrl = TextEditingController();
  
  final _maxTradeCtrl = TextEditingController();
  final _dailyCapCtrl = TextEditingController();
  final _slippageCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('wallet.php?action=get');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success' && res['data'] != null) {
          _hasWallet = res['data']['has_wallet'] ?? false;
          _publicAddress = res['data']['public_address'];
          _allowTelegram = res['data']['allow_telegram_alerts'] ?? false;
          _allowPush = res['data']['allow_push_alerts'] ?? true;
          _telegramCtrl.text = res['data']['telegram_chat_id']?.toString() ?? '';
          _maxTradeCtrl.text = res['data']['user_max_per_trade_usd']?.toString() ?? '';
          _dailyCapCtrl.text = res['data']['user_daily_spend_cap']?.toString() ?? '';
          _botUsername = res['data']['telegram_bot_username']?.toString() ?? '';
          
          double slippageBps = (double.tryParse(res['data']['slippage_bps']?.toString() ?? '500') ?? 500);
          _slippageCtrl.text = (slippageBps / 100).toStringAsFixed(1);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTradeLimits() async {
    FocusScope.of(context).unfocus();
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=save_trade_limits',
      {'user_max_per_trade_usd': _maxTradeCtrl.text.trim(), 'user_daily_spend_cap': _dailyCapCtrl.text.trim()},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
    }
  }

  Future<void> _saveSlippage() async {
    FocusScope.of(context).unfocus();
    double pct = double.tryParse(_slippageCtrl.text.trim()) ?? 5.0;
    int bps = (pct * 100).round();
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=set_slippage',
      {'slippage_bps': bps},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Slippage updated'), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
    }
  }

  Future<void> _showUpdateKeyModal() async {
    final ctrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Row(children: [Icon(PhosphorIcons.keyFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Update Private Key', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16))]),
            content: TextField(controller: ctrl, obscureText: true, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12), decoration: InputDecoration(hintText: 'Paste Solana Base58 Private Key', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
                onPressed: isSubmitting ? null : () async {
                  if (ctrl.text.trim().isEmpty) return;
                  setStateDialog(() => isSubmitting = true);
                  final res = await this.context.read<ApiService>().postEndpoint('wallet.php?action=set_key', {'private_key': ctrl.text.trim()});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
                    if (res['status'] == 'success' && res['data'] != null) {
                      setState(() { _hasWallet = true; _publicAddress = res['data']['public_address']; });
                    }
                  }
                },
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Key'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('SETTINGS', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.signOut, color: theme.colorScheme.onSurfaceVariant),
            onPressed: () async {
              await context.read<ApiService>().logout();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.primaryColor)) 
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Execution Wallet
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.walletFill, color: theme.primaryColor), const SizedBox(width: 12), Text('Execution Wallet', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('PUBLIC ADDRESS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(child: Text(_hasWallet ? (_publicAddress ?? 'Error loading') : 'No wallet connected', style: TextStyle(color: _hasWallet ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace', fontSize: 13))),
                          if (_hasWallet) Icon(PhosphorIcons.checkCircleFill, color: AppTheme.success(context), size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: theme.colorScheme.outline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showUpdateKeyModal, icon: Icon(PhosphorIcons.key, color: theme.colorScheme.onSurface), label: Text(_hasWallet ? 'Update Private Key' : 'Add Private Key', style: TextStyle(color: theme.colorScheme.onSurface)))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Preferences
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(PhosphorIcons.slidersHorizontalFill, color: AppTheme.info(context)), const SizedBox(width: 12), Text('Preferences', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.moneyFill, color: theme.colorScheme.onSurfaceVariant, size: 20), const SizedBox(width: 12), Text('Display in Naira (₦)', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600))]),
                        Switch(value: currency.isNaira, activeColor: theme.primaryColor, onChanged: (_) => currency.toggleCurrency()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Trade Limits
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(PhosphorIcons.shieldCheckFill, color: AppTheme.warning(context)), const SizedBox(width: 12), Text('Risk Limits', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 16),
                    Text('Leave blank to use system defaults.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _maxTradeCtrl, keyboardType: TextInputType.number, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Max Per Trade (\$)', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: _dailyCapCtrl, keyboardType: TextInputType.number, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Daily Cap (\$)', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning(context).withOpacity(0.12), foregroundColor: AppTheme.warning(context), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), onPressed: _saveTradeLimits, icon: const Icon(PhosphorIcons.floppyDisk, size: 18), label: const Text('Save Risk Limits', style: TextStyle(fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Slippage
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(PhosphorIcons.activityFill, color: AppTheme.danger(context)), const SizedBox(width: 12), Text('DEX Execution Safety', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 16),
                    Text('Slippage protects trades during high volatility. Default for meme coins is 5.0%.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _slippageCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              labelText: 'Max Slippage Tolerance (%)',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              suffixText: '%',
                              suffixStyle: TextStyle(color: AppTheme.danger(context), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context).withOpacity(0.12), foregroundColor: AppTheme.danger(context), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          onPressed: _saveSlippage,
                          icon: const Icon(PhosphorIcons.floppyDisk, size: 18),
                          label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
    );
  }
}
