import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';

class CopyBotsScreen extends StatefulWidget {
  const CopyBotsScreen({super.key});

  @override
  State<CopyBotsScreen> createState() => _CopyBotsScreenState();
}

class _CopyBotsScreenState extends State<CopyBotsScreen> {
  bool _isLoading = true;
  List<dynamic> _bots = [];
  final Set<int> _selectedBotIds = {};

  String _selectedChain = 'all';
  String _statusFilter = 'all';

  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

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

  List<dynamic> get _filteredBots {
    return _bots.where((b) {
      final chain = (b['chain'] ?? 'solana').toString().toLowerCase();
      final enabled = b['enabled'] == true;

      if (_selectedChain != 'all' && chain != _selectedChain) return false;
      if (_statusFilter == 'active' && !enabled) return false;
      if (_statusFilter == 'inactive' && enabled) return false;

      return true;
    }).toList();
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedBotIds.length == _filteredBots.length) {
        _selectedBotIds.clear();
      } else {
        _selectedBotIds.clear();
        for (var b in _filteredBots) {
          _selectedBotIds.add(b['bot_id']);
        }
      }
    });
  }

  Future<void> _editBotModal(Map<String, dynamic> b) async {
    final tradeCtrl = TextEditingController(text: b['trade_usd_amount']?.toString() ?? '');
    final tpCtrl = TextEditingController(text: b['tp_percent']?.toString() ?? '');
    final slCtrl = TextEditingController(text: b['sl_percent']?.toString() ?? '');
    final maxCtrl = TextEditingController(text: b['max_concurrent']?.toString() ?? '');
    final minMcapCtrl = TextEditingController(text: b['min_mcap']?.toString() ?? '');
    final maxMcapCtrl = TextEditingController(text: b['max_mcap']?.toString() ?? '');
    bool enabled = b['enabled'] == true;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text('Configure ${b['name']}', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: tradeCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Trade Size (\$)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: tpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'TP (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: slCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'SL (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: maxCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Max Open Trades', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: minMcapCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Min MCAP (\$)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Expanded(child: TextField(controller: maxMcapCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Max MCAP (\$)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: enabled,
                    activeColor: theme.primaryColor,
                    onChanged: (val) => setStateDialog(() => enabled = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  final res = await this.context.read<ApiService>().postEndpoint('copy_bots.php?action=save', {
                    'bot_id': b['bot_id'],
                    'enabled': enabled,
                    'trade_usd_amount': tradeCtrl.text.trim(),
                    'tp_percent': tpCtrl.text.trim(),
                    'sl_percent': slCtrl.text.trim(),
                    'max_concurrent': maxCtrl.text.trim(),
                    'min_mcap': minMcapCtrl.text.trim(),
                    'max_mcap': maxMcapCtrl.text.trim(),
                  });
                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchBots();
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredBots;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('COPY BOTS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface)),
        actions: [
          IconButton(icon: const Icon(PhosphorIcons.arrowsClockwiseBold), onPressed: _fetchBots),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${filtered.length} Bots Available', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
                    TextButton(onPressed: _toggleSelectAll, child: Text(_selectedBotIds.length == filtered.length ? 'Deselect All' : 'Select All', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    final int botId = b['bot_id'];
                    final bool isSelected = _selectedBotIds.contains(botId);
                    final String chain = (b['chain'] ?? 'solana').toString().toLowerCase();
                    final Color chainColor = _chainColors[chain] ?? theme.primaryColor;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Checkbox(
                            value: isSelected,
                            activeColor: theme.primaryColor,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedBotIds.add(botId); else _selectedBotIds.remove(botId);
                              });
                            },
                          ),
                          title: Row(
                            children: [
                              Text(b['name'], style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: chainColor.withOpacity(0.3))),
                                child: Text(chain.toUpperCase(), style: TextStyle(fontSize: 8, color: chainColor, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          subtitle: Text('Trade \$${b['trade_usd_amount'] ?? '20'} • TP: +${b['tp_percent'] ?? '50'}% • SL: -${b['sl_percent'] ?? '20'}%', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                          trailing: IconButton(
                            icon: Icon(PhosphorIcons.slidersHorizontalBold, color: theme.colorScheme.onSurface),
                            onPressed: () => _editBotModal(b),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}
