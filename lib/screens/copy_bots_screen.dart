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

  Future<void> _saveBotConfig(Map<String, dynamic> payload) async {
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_bots.isEmpty) return const Center(child: Text('No active copy bots available.', style: TextStyle(color: Colors.white54)));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _bots.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BotConfigCard(
            bot: _bots[index],
            onSave: _saveBotConfig,
          ),
        );
      },
    );
  }
}

// FIXED: Isolated Stateful Widget ensures calculators work perfectly without ListView recycling bugs
class BotConfigCard extends StatefulWidget {
  final dynamic bot;
  final Function(Map<String, dynamic>) onSave;

  const BotConfigCard({super.key, required this.bot, required this.onSave});

  @override
  State<BotConfigCard> createState() => _BotConfigCardState();
}

class _BotConfigCardState extends State<BotConfigCard> {
  late bool isEnabled;
  late TextEditingController tradeCtrl;
  late TextEditingController tpCtrl;
  late TextEditingController slCtrl;
  late TextEditingController concCtrl;
  late TextEditingController xCtrl;
  
  double expectedProfit = 0.0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    isEnabled = widget.bot['enabled'] == true;
    tradeCtrl = TextEditingController(text: widget.bot['trade_usd_amount']?.toString() ?? '');
    tpCtrl = TextEditingController(text: widget.bot['tp_percent']?.toString() ?? '');
    slCtrl = TextEditingController(text: widget.bot['sl_percent']?.toString() ?? '');
    concCtrl = TextEditingController(text: widget.bot['max_concurrent']?.toString() ?? '');
    xCtrl = TextEditingController();

    _calculateFromTp();

    tradeCtrl.addListener(_calculateProfit);
    tpCtrl.addListener(_calculateFromTp);
    xCtrl.addListener(_calculateFromX);
  }

  @override
  void dispose() {
    tradeCtrl.dispose();
    tpCtrl.dispose();
    slCtrl.dispose();
    concCtrl.dispose();
    xCtrl.dispose();
    super.dispose();
  }

  void _calculateFromTp() {
    if (_isUpdating) return;
    _isUpdating = true;
    double tp = double.tryParse(tpCtrl.text) ?? 0;
    if (tpCtrl.text.isNotEmpty) {
      xCtrl.text = (1 + (tp / 100)).toStringAsFixed(2);
    } else {
      xCtrl.text = '';
    }
    _calculateProfit();
    _isUpdating = false;
  }

  void _calculateFromX() {
    if (_isUpdating) return;
    _isUpdating = true;
    double x = double.tryParse(xCtrl.text) ?? 0;
    if (xCtrl.text.isNotEmpty) {
      tpCtrl.text = ((x - 1) * 100).toStringAsFixed(2);
    } else {
      tpCtrl.text = '';
    }
    _calculateProfit();
    _isUpdating = false;
  }

  void _calculateProfit() {
    double tp = double.tryParse(tpCtrl.text) ?? 0;
    double size = double.tryParse(tradeCtrl.text) ?? 0;
    setState(() {
      expectedProfit = size * (tp / 100);
    });
  }

  void _handleSave() {
    FocusScope.of(context).unfocus();
    widget.onSave({
      'bot_id': widget.bot['bot_id'],
      'enabled': isEnabled,
      'trade_usd_amount': tradeCtrl.text.trim(),
      'tp_percent': tpCtrl.text.trim(),
      'sl_percent': slCtrl.text.trim(),
      'max_concurrent': concCtrl.text.trim()
    });
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, IconData icon, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: iconColor, size: 16),
              filled: true,
              fillColor: Colors.black26,
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          collapsedIconColor: Colors.white54,
          iconColor: theme.primaryColor,
          title: Row(
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
                  Text(widget.bot['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(isEnabled ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: isEnabled ? Colors.greenAccent : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 1, color: Colors.white.withOpacity(0.05)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildInput('TRADE \$', '5.00', tradeCtrl, PhosphorIcons.currencyDollar, Colors.white)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInput('TP %', '100.00', tpCtrl, PhosphorIcons.trendUp, Colors.greenAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput('TARGET XS', '2.00', xCtrl, PhosphorIcons.x, theme.primaryColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInput('SL %', '90.00', slCtrl, PhosphorIcons.trendDown, Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput('MAX OPEN', '∞', concCtrl, PhosphorIcons.infinity, Colors.white54)),
                      const SizedBox(width: 12),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Expected Profit Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.05),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(PhosphorIcons.calculatorFill, size: 16, color: Colors.white54),
                            SizedBox(width: 8),
                            Text('EXPECTED PROFIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text('+\$${expectedProfit.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: isEnabled,
                            activeColor: theme.primaryColor,
                            onChanged: (val) {
                              setState(() => isEnabled = val);
                              _handleSave();
                            },
                          ),
                          const Text('Strategy Active', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _handleSave,
                        icon: const Icon(PhosphorIcons.floppyDiskFill, size: 16),
                        label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
