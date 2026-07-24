import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

class CopyBotsScreen extends StatefulWidget {
  const CopyBotsScreen({super.key});

  @override
  State<CopyBotsScreen> createState() => _CopyBotsScreenState();
}

class _CopyBotsScreenState extends State<CopyBotsScreen> {
  bool _isLoading = true;
  List<dynamic> _bots = [];

  @override
  void initState() {
    super.initState();
    _fetchBots();
  }

  Future<void> _fetchBots() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('copy_bots.php?action=fetch');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _bots = res['data'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveBotConfig(Map<String, dynamic> botData, TextEditingController tradeCtrl, TextEditingController tpCtrl, TextEditingController slCtrl, TextEditingController concCtrl) async {
    FocusScope.of(context).unfocus();
    
    final payload = {
      'bot_id': botData['bot_id'],
      'enabled': botData['enabled'],
      'trade_usd_amount': tradeCtrl.text.trim(),
      'tp_percent': tpCtrl.text.trim(),
      'sl_percent': slCtrl.text.trim(),
      'max_concurrent': concCtrl.text.trim()
    };

    final res = await context.read<ApiService>().postEndpoint('copy_bots.php?action=save', payload);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Saved'),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bots.isEmpty) {
      return const Center(child: Text('No active copy bots available.', style: TextStyle(color: Colors.white54)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bots.length,
      itemBuilder: (context, index) {
        final bot = _bots[index];
        final isEnabled = bot['enabled'] == true;

        final tradeCtrl = TextEditingController(text: bot['trade_usd_amount']?.toString() ?? '');
        final tpCtrl = TextEditingController(text: bot['tp_percent']?.toString() ?? '');
        final slCtrl = TextEditingController(text: bot['sl_percent']?.toString() ?? '');
        final concCtrl = TextEditingController(text: bot['max_concurrent']?.toString() ?? '');

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isEnabled ? theme.primaryColor.withOpacity(0.2) : Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(PhosphorIcons.robotFill, color: isEnabled ? theme.primaryColor : Colors.white54),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bot['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(isEnabled ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: isEnabled ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: isEnabled,
                      activeColor: theme.primaryColor,
                      onChanged: (val) {
                        setState(() {
                          bot['enabled'] = val;
                        });
                        // Auto-save toggle state immediately
                        _saveBotConfig(bot, tradeCtrl, tpCtrl, slCtrl, concCtrl);
                      },
                    ),
                  ],
                ),
                
                if (isEnabled) ...[
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  const Text('Leave fields blank to use system defaults. Enter 0 in TP/SL for no limits.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tradeCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(labelText: 'Trade Size (\$)', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: concCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(labelText: 'Max Concurrent', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tpCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(labelText: 'Take Profit (%)', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: slCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(labelText: 'Stop Loss (%)', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: theme.primaryColor.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _saveBotConfig(bot, tradeCtrl, tpCtrl, slCtrl, concCtrl),
                      icon: Icon(PhosphorIcons.floppyDiskFill, color: theme.primaryColor, size: 18),
                      label: Text('Save Configuration', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }
}
