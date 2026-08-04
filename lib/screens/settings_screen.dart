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

  // Static chain list matching the chains seeded server-side. Each chain
  // has its own wallet row now — switching tabs re-fetches that chain's key.
  static const List<Map<String, String>> _chains = [
    {'id': 'solana', 'name': 'Solana', 'placeholder': 'Paste Solana Base58 Private Key'},
    {'id': 'bsc', 'name': 'BSC', 'placeholder': 'Paste EVM Private Key (0x...)'},
    {'id': 'robinhood', 'name': 'Robinhood', 'placeholder': 'Paste EVM Private Key (0x...)'},
  ];
  String _selectedChain = 'solana';

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('wallet.php?action=get&chain=$_selectedChain');
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

  void _onChainChanged(String chainId) {
    setState(() => _selectedChain = chainId);
    _fetchProfileData();
  }

  Future<void> _togglePushAlerts(bool value) async {
    setState(() => _allowPush = value);
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=toggle_push_alerts',
      {'allow_push_alerts': value ? '1' : '0'},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Settings updated'),
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
      ));
    }
  }

  Future<void> _saveTelegramId() async {
    if (_telegramCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=set_telegram',
      {'telegram_chat_id': _telegramCtrl.text.trim()},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
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

  Future<void> _showChangePasswordModal() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.lockKeyFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Change Password', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: oldCtrl, obscureText: true, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14), decoration: InputDecoration(labelText: 'Current Password', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: newCtrl, obscureText: true, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14), decoration: InputDecoration(labelText: 'New Password', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSubmitting ? null : () async {
                  if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
                  setStateDialog(() => isSubmitting = true);
                  final res = await this.context.read<ApiService>().postEndpoint('auth.php?action=change_password', {'old_password': oldCtrl.text, 'new_password': newCtrl.text});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
                  }
                },
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.keyFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Update ${_selectedChain.toUpperCase()} Private Key', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]),
            content: TextField(controller: ctrl, obscureText: true, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12), decoration: InputDecoration(hintText: _chains.firstWhere((c) => c['id'] == _selectedChain)['placeholder'], hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSubmitting ? null : () async {
                  if (ctrl.text.trim().isEmpty) return;
                  setStateDialog(() => isSubmitting = true);
                  final res = await this.context.read<ApiService>().postEndpoint('wallet.php?action=set_key', {'private_key': ctrl.text.trim(), 'chain': _selectedChain});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
                    if (res['status'] == 'success' && res['data'] != null) {
                      setState(() { _hasWallet = true; _publicAddress = res['data']['public_address']; });
                    }
                  }
                },
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Key', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showDeleteKeyModal() async {
    final theme = Theme.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [Icon(PhosphorIcons.warningCircleFill, color: AppTheme.danger(context)), const SizedBox(width: 8), Text('Remove ${_selectedChain.toUpperCase()} Wallet?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]), 
          content: Text('This will permanently delete your encrypted $_selectedChain private key from the server. You will not be able to execute trades on this chain until you add a new one.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)), 
          actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))), 
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Delete', style: TextStyle(fontWeight: FontWeight.bold)))
          ],
        );
      }
    );
    
    if (confirm == true && mounted) {
      final res = await context.read<ApiService>().postEndpoint('wallet.php?action=delete_key', {'chain': _selectedChain});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
      if (res['status'] == 'success') setState(() { _hasWallet = false; _publicAddress = null; });
    }
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            children: [
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.12), shape: BoxShape.circle), child: Icon(PhosphorIcons.shieldCheckFill, color: theme.primaryColor)),
                            const SizedBox(width: 16),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Account Security', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)), Text('Manage app access', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))]),
                          ],
                        ),
                        IconButton(icon: Icon(PhosphorIcons.pencilSimple, color: theme.colorScheme.onSurfaceVariant), onPressed: _showChangePasswordModal),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.fingerprint, color: theme.colorScheme.onSurfaceVariant, size: 20), const SizedBox(width: 8), Text('Biometric Quick-Lock', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold))]),
                        Switch(value: _biometricEnabled, activeColor: theme.primaryColor, onChanged: (v) => setState(() => _biometricEnabled = v)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.moneyFill, color: theme.colorScheme.onSurfaceVariant, size: 20), const SizedBox(width: 8), Text('Display in Naira (₦)', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold))]),
                        Switch(value: currency.isNaira, activeColor: theme.primaryColor, onChanged: (_) => currency.toggleCurrency()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.bellRingingFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Push Notifications', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                        Switch(value: _allowPush, activeColor: theme.primaryColor, onChanged: _togglePushAlerts),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Receive real-time push alerts on your phone whenever trades open, close, or hit targets.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [Icon(PhosphorIcons.walletFill, color: theme.primaryColor), const SizedBox(width: 12), Text('Execution Wallet', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                        if (_hasWallet) IconButton(icon: Icon(PhosphorIcons.trash, color: AppTheme.danger(context), size: 20), onPressed: _showDeleteKeyModal, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                                border: Border.all(color: selected ? theme.primaryColor : theme.dividerColor.withOpacity(0.3)),
                              ),
                              child: Text(c['name']!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: selected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant)),
                            ),
                          ),
                        );
                      }).toList(),
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
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: theme.colorScheme.outline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showUpdateKeyModal, icon: Icon(PhosphorIcons.key, color: theme.colorScheme.onSurface), label: Text(_hasWallet ? 'Update ${_selectedChain.toUpperCase()} Private Key' : 'Add ${_selectedChain.toUpperCase()} Private Key', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 24),

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

              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(PhosphorIcons.telegramLogoFill, color: AppTheme.info(context)), const SizedBox(width: 8), Text('Telegram Alerts', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 16),
                    if (!_allowTelegram)
                      Text('Admin has disabled personal alerts.', style: TextStyle(color: AppTheme.danger(context), fontSize: 13, fontWeight: FontWeight.bold))
                    else ...[
                      Text('Required Setup:', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 12),
                      Text('1. Start our official bot to get your ID:', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
                        decoration: BoxDecoration(color: AppTheme.info(context).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            Expanded(child: Text(_botUsername.isNotEmpty ? _botUsername : '(Ask Admin)', style: TextStyle(color: AppTheme.info(context), fontWeight: FontWeight.bold, fontSize: 14))),
                            if (_botUsername.isNotEmpty) ...[
                              IconButton(icon: Icon(PhosphorIcons.copy, color: AppTheme.info(context), size: 18), onPressed: () {
                                final cleanUsername = _botUsername.replaceAll('@', '');
                                Clipboard.setData(ClipboardData(text: 'https://t.me/$cleanUsername'));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bot URL copied to clipboard!')));
                              }),
                              IconButton(icon: Icon(PhosphorIcons.arrowUpRight, color: AppTheme.info(context), size: 18), onPressed: () async {
                                final cleanUsername = _botUsername.replaceAll('@', '');
                                final url = Uri.parse('https://t.me/$cleanUsername');
                                if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                              }),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('2. Paste the ID below.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _telegramCtrl, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: 'Chat ID', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                          const SizedBox(width: 12),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info(context).withOpacity(0.12), foregroundColor: AppTheme.info(context), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _saveTelegramId, child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
    );
  }
}
