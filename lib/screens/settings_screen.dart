import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';

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

  Future<void> _saveTelegramId() async {
    if (_telegramCtrl.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=set_telegram',
      {'telegram_chat_id': _telegramCtrl.text.trim()},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
    }
  }

  Future<void> _saveTradeLimits() async {
    FocusScope.of(context).unfocus();
    final res = await context.read<ApiService>().postEndpoint(
      'wallet.php?action=save_trade_limits',
      {'user_max_per_trade_usd': _maxTradeCtrl.text.trim(), 'user_daily_spend_cap': _dailyCapCtrl.text.trim()},
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Slippage updated'), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
    }
  }

  Future<void> _showChangePasswordModal() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(children: [Icon(PhosphorIcons.lockKeyFill, color: Theme.of(context).primaryColor), const SizedBox(width: 8), const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 16))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: oldCtrl, obscureText: true, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: 'Current Password', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: newCtrl, obscureText: true, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: 'New Password', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSubmitting ? null : () async {
                if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) return;
                setStateDialog(() => isSubmitting = true);
                final res = await this.context.read<ApiService>().postEndpoint('auth.php?action=change_password', {'old_password': oldCtrl.text, 'new_password': newCtrl.text});
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUpdateKeyModal() async {
    final ctrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(children: [Icon(PhosphorIcons.keyFill, color: Theme.of(context).primaryColor), const SizedBox(width: 8), const Text('Update Private Key', style: TextStyle(color: Colors.white, fontSize: 16))]),
          content: TextField(controller: ctrl, obscureText: true, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(hintText: 'Paste Solana Base58 Private Key', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSubmitting ? null : () async {
                if (ctrl.text.trim().isEmpty) return;
                setStateDialog(() => isSubmitting = true);
                final res = await this.context.read<ApiService>().postEndpoint('wallet.php?action=set_key', {'private_key': ctrl.text.trim()});
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
                  if (res['status'] == 'success' && res['data'] != null) {
                    setState(() { _hasWallet = true; _publicAddress = res['data']['public_address']; });
                  }
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Key', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteKeyModal() async {
    final bool? confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A), 
        title: const Row(children: [Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent), SizedBox(width: 8), Text('Remove Wallet?', style: TextStyle(color: Colors.white, fontSize: 16))]), 
        content: const Text('This will permanently delete your encrypted private key from the server. You will not be able to execute trades until you add a new one.', style: TextStyle(color: Colors.white70, fontSize: 13)), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))), 
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Delete', style: TextStyle(color: Colors.white)))
        ],
      ),
    );
    
    if (confirm == true && mounted) {
      final res = await context.read<ApiService>().postEndpoint('wallet.php?action=delete_key', {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
      if (res['status'] == 'success') setState(() { _hasWallet = false; _publicAddress = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();

    return _isLoading 
      ? const Center(child: CircularProgressIndicator()) 
      : ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 1. Account Credentials & Security
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(PhosphorIcons.shieldCheckFill, color: theme.primaryColor)),
                          const SizedBox(width: 16),
                          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Account Security', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text('Manage app access', style: TextStyle(color: Colors.white54, fontSize: 12))]),
                        ],
                      ),
                      IconButton(icon: const Icon(PhosphorIcons.pencilSimple, color: Colors.white54), onPressed: _showChangePasswordModal),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [Icon(PhosphorIcons.fingerprint, color: Colors.white54, size: 20), SizedBox(width: 8), Text('Biometric Quick-Lock', style: TextStyle(color: Colors.white))]),
                      Switch(value: _biometricEnabled, activeColor: theme.primaryColor, onChanged: (v) => setState(() => _biometricEnabled = v)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(children: [Icon(PhosphorIcons.moneyFill, color: Colors.white54, size: 20), SizedBox(width: 8), Text('Display in Naira (₦)', style: TextStyle(color: Colors.white))]),
                      Switch(value: currency.isNaira, activeColor: theme.primaryColor, onChanged: (_) => currency.toggleCurrency()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Execution Wallet
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [Icon(PhosphorIcons.walletFill, color: theme.primaryColor), const SizedBox(width: 8), const Text('Execution Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                      if (_hasWallet) IconButton(icon: const Icon(PhosphorIcons.trash, color: Colors.redAccent, size: 20), onPressed: _showDeleteKeyModal, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('PUBLIC ADDRESS', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Expanded(child: Text(_hasWallet ? (_publicAddress ?? 'Error loading') : 'No wallet connected', style: TextStyle(color: _hasWallet ? Colors.white : Colors.white38, fontFamily: 'monospace', fontSize: 13))),
                        if (_hasWallet) const Icon(PhosphorIcons.checkCircleFill, color: Colors.greenAccent, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: Colors.white.withOpacity(0.1)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showUpdateKeyModal, icon: const Icon(PhosphorIcons.key, color: Colors.white), label: Text(_hasWallet ? 'Update Key' : 'Add Private Key', style: const TextStyle(color: Colors.white)))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. DEX Execution Safety (Slippage)
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(PhosphorIcons.shieldWarningFill, color: Colors.amberAccent), SizedBox(width: 8), Text('DEX Execution Safety', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 12),
                  const Text(
                    'Slippage protects trades during high market volatility. Too low (e.g. 1%), and trades fail with 0x1771 errors. Default for meme coins is 5.0%.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _slippageCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Max Slippage Tolerance (%)',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixText: '%',
                            suffixStyle: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amberAccent.withOpacity(0.2),
                          foregroundColor: Colors.amberAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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

            // 4. Personal Trade Limits
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(PhosphorIcons.slidersHorizontalFill, color: Colors.amberAccent), SizedBox(width: 8), Text('Personal Trade Limits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 16),
                  const Text('Leave blank to use system defaults.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _maxTradeCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: 'Max Per Trade (\$)', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: _dailyCapCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(labelText: 'Daily Cap (\$)', labelStyle: const TextStyle(color: Colors.white54, fontSize: 11), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent.withOpacity(0.2), foregroundColor: Colors.amberAccent, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _saveTradeLimits, icon: const Icon(PhosphorIcons.floppyDisk, size: 18), label: const Text('Save Risk Limits', style: TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Telegram Alerts
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(PhosphorIcons.telegramLogoFill, color: Colors.blueAccent), SizedBox(width: 8), Text('Telegram Alerts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                  const SizedBox(height: 16),
                  if (!_allowTelegram)
                    const Text('Admin has disabled personal alerts.', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold))
                  else ...[
                    const Text('Required Setup:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    
                    // STEP 1: INTERACTIVE USERINFOBOT
                    const Text('1. Start @userinfobot to get your ID:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Expanded(child: Text('@userinfobot', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14))),
                          IconButton(
                            icon: const Icon(PhosphorIcons.copy, color: Colors.blueAccent, size: 18),
                            onPressed: () {
                              Clipboard.setData(const ClipboardData(text: 'https://t.me/userinfobot'));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('@userinfobot link copied!')));
                            },
                          ),
                          IconButton(
                            icon: const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 18),
                            onPressed: () async {
                              final url = Uri.parse('https://t.me/userinfobot');
                              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // STEP 2: OFFICIAL BOT
                    const Text('2. Start our official bot:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.only(left: 12, right: 6, top: 4, bottom: 4),
                      decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(child: Text(_botUsername.isNotEmpty ? _botUsername : '(Ask Admin)', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14))),
                          if (_botUsername.isNotEmpty) ...[
                            IconButton(icon: const Icon(PhosphorIcons.copy, color: Colors.blueAccent, size: 18), onPressed: () {
                              final cleanUsername = _botUsername.replaceAll('@', '');
                              Clipboard.setData(ClipboardData(text: 'https://t.me/$cleanUsername'));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bot URL copied to clipboard!')));
                            }),
                            IconButton(icon: const Icon(PhosphorIcons.arrowUpRight, color: Colors.blueAccent, size: 18), onPressed: () async {
                              final cleanUsername = _botUsername.replaceAll('@', '');
                              final url = Uri.parse('https://t.me/$cleanUsername');
                              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                            }),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // STEP 3: PASTE ID
                    const Text('3. Paste the ID below.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _telegramCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Chat ID', hintStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
                        const SizedBox(width: 12),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _saveTelegramId, child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
  }
}
