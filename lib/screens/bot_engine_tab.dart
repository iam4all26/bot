import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class BotEngineTab extends StatefulWidget {
  const BotEngineTab({super.key});

  @override
  State<BotEngineTab> createState() => _BotEngineTabState();
}

class _BotEngineTabState extends State<BotEngineTab> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Toggles
  bool _liveMode = false;
  bool _paperMode = true;
  bool _telegramAlerts = true;

  // Text Controllers
  final _pollMinsCtrl = TextEditingController();
  final _liqFloorCtrl = TextEditingController();
  final _maxAlertsCtrl = TextEditingController();
  final _paperSizeCtrl = TextEditingController();
  final _tpCtrl = TextEditingController();
  final _slCtrl = TextEditingController();
  final _realBaseSizeCtrl = TextEditingController();
  final _realMaxTradeCtrl = TextEditingController();
  final _realDailyCapCtrl = TextEditingController();
  final _stablecoinsCtrl = TextEditingController();
  final _botUsernameCtrl = TextEditingController(); // NEW

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('admin_settings.php?action=fetch');

    if (mounted && res['status'] == 'success') {
      final data = res['data'] ?? {};
      setState(() {
        _liveMode = data['live_trading_enabled'] == '1';
        _paperMode = data['paper_trading_enabled'] == '1';
        _telegramAlerts = data['telegram_enabled'] == '1';

        final pollSecs = int.tryParse(data['poll_interval_seconds'] ?? '60') ?? 60;
        _pollMinsCtrl.text = (pollSecs / 60).toStringAsFixed(2);
        
        _liqFloorCtrl.text = data['liquidity_floor'] ?? '15000';
        _maxAlertsCtrl.text = data['max_alerts_per_cycle'] ?? '5';
        _paperSizeCtrl.text = data['copy_trade_virtual_usd'] ?? '100';
        _tpCtrl.text = data['default_tp_percent'] ?? '50';
        _slCtrl.text = data['default_sl_percent'] ?? '20';
        _realBaseSizeCtrl.text = data['real_trade_usd_amount'] ?? '5';
        _realMaxTradeCtrl.text = data['max_real_trade_usd'] ?? '25';
        _realDailyCapCtrl.text = data['max_daily_real_spend_usd'] ?? '100';
        _stablecoinsCtrl.text = data['stablecoin_mints'] ?? '';
        _botUsernameCtrl.text = data['telegram_bot_username'] ?? ''; // NEW
        
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    
    final pollMins = double.tryParse(_pollMinsCtrl.text) ?? 1.0;
    int pollSecs = (pollMins * 60).round();
    if (pollSecs < 15) pollSecs = 15;

    final payload = {
      'poll_interval_seconds': pollSecs.toString(),
      'liquidity_floor': _liqFloorCtrl.text,
      'max_alerts_per_cycle': _maxAlertsCtrl.text,
      'copy_trade_virtual_usd': _paperSizeCtrl.text,
      'default_tp_percent': _tpCtrl.text,
      'default_sl_percent': _slCtrl.text,
      'real_trade_usd_amount': _realBaseSizeCtrl.text,
      'max_real_trade_usd': _realMaxTradeCtrl.text,
      'max_daily_real_spend_usd': _realDailyCapCtrl.text,
      'stablecoin_mints': _stablecoinsCtrl.text,
      'telegram_bot_username': _botUsernameCtrl.text, // NEW
      'telegram_enabled': _telegramAlerts ? '1' : '0',
      'paper_trading_enabled': _paperMode ? '1' : '0',
      'live_trading_enabled': _liveMode ? '1' : '0',
    };

    final api = context.read<ApiService>();
    final res = await api.postEndpoint('admin_settings.php?action=save', payload);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Settings updated'), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isMultiLine = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(controller: controller, maxLines: isMultiLine ? 3 : 1, keyboardType: isMultiLine ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14), decoration: InputDecoration(prefixIcon: isMultiLine ? null : Icon(icon, color: theme.primaryColor, size: 18), filled: true, fillColor: theme.colorScheme.onSurface.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(PhosphorIcons.toggleLeftFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Master Engine Controls', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 16),
              SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Colors.amber, title: Text('Paper Trading (Simulated)', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text('Open virtual positions automatically', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)), value: _paperMode, onChanged: (val) => setState(() => _paperMode = val)),
              Container(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)),
              SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Colors.redAccent, title: const Row(children: [Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent, size: 16), SizedBox(width: 6), Text('Live REAL Trading', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14))]), subtitle: Text('Use real master wallet funds on Jupiter', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)), value: _liveMode, onChanged: (val) => setState(() => _liveMode = val)),
              Container(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)),
              SwitchListTile(contentPadding: EdgeInsets.zero, activeColor: Colors.blueAccent, title: Text('Telegram Alerts', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text('Broadcast updates to designated channel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)), value: _telegramAlerts, onChanged: (val) => setState(() => _telegramAlerts = val)),
              const SizedBox(height: 16),
              _buildTextField('OFFICIAL BOT USERNAME (@)', _botUsernameCtrl, PhosphorIcons.robot, isMultiLine: false),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(PhosphorIcons.shieldWarningFill, color: Colors.redAccent), SizedBox(width: 8), Text('Real Trading Risk Limits', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 20),
              _buildTextField('REAL BASE SIZE (\$)', _realBaseSizeCtrl, PhosphorIcons.currencyDollar),
              _buildTextField('MAX PER TRADE (\$)', _realMaxTradeCtrl, PhosphorIcons.prohibit),
              _buildTextField('DAILY SPEND CAP (\$)', _realDailyCapCtrl, PhosphorIcons.calendarX),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(PhosphorIcons.scanFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Scanning & Parameters', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 20),
              _buildTextField('POLL INTERVAL (MINS)', _pollMinsCtrl, PhosphorIcons.timer),
              _buildTextField('LIQUIDITY FLOOR (USD)', _liqFloorCtrl, PhosphorIcons.drop),
              _buildTextField('MAX ALERTS PER CYCLE', _maxAlertsCtrl, PhosphorIcons.bellRinging),
              const SizedBox(height: 16),
              Container(height: 1, color: theme.colorScheme.onSurface.withOpacity(0.1)),
              const SizedBox(height: 16),
              _buildTextField('VIRTUAL PAPER SIZE (\$)', _paperSizeCtrl, PhosphorIcons.stack),
              Row(children: [Expanded(child: _buildTextField('DEFAULT TP (%)', _tpCtrl, PhosphorIcons.trendUp)), const SizedBox(width: 12), Expanded(child: _buildTextField('DEFAULT SL (%)', _slCtrl, PhosphorIcons.trendDown))]),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(PhosphorIcons.listBulletsFill, color: theme.primaryColor), const SizedBox(width: 8), Text('Stablecoin Whitelist', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 8),
              Text('Comma-separated mints to skip automatically.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
              const SizedBox(height: 16),
              _buildTextField('', _stablecoinsCtrl, PhosphorIcons.hash, isMultiLine: true),
            ],
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, height: 56, child: ElevatedButton.icon(onPressed: _isSaving ? null : _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(PhosphorIcons.floppyDiskFill), label: Text(_isSaving ? 'SAVING...' : 'SAVE CONFIGURATION', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)))),
        const SizedBox(height: 40),
      ],
    );
  }
}
