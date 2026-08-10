import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';

class CopyBotsScreen extends StatefulWidget {
  const CopyBotsScreen({super.key});

  @override
  State<CopyBotsScreen> createState() => _CopyBotsScreenState();
}

class _CopyBotsScreenState extends State<CopyBotsScreen> {
  bool _isLoading = true;
  List<dynamic> _bots = [];
  
  // Filtering & Search
  String _searchQuery = '';
  String _selectedChain = 'All Chains';
  String _selectedStatus = 'All Status';
  
  // Bulk Selection
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

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

  void _showFloatingSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isError ? AppTheme.danger(context) : AppTheme.success(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _saveBotConfig(Map<String, dynamic> payload) async {
    final res = await context.read<ApiService>().postEndpoint('copy_bots.php?action=save', payload);
    if (mounted) {
      _showFloatingSnackbar(res['message'] ?? 'Saved', isError: res['status'] != 'success');
      _fetchBots();
    }
  }

  Future<void> _bulkUpdateBots(List<Map<String, dynamic>> updatedBots) async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().postEndpoint('copy_bots.php?action=save_bulk', {'bots': updatedBots});
    if (mounted) {
      _showFloatingSnackbar(res['message'] ?? 'Bulk update complete', isError: res['status'] != 'success');
      _selectedIds.clear();
      _isSelectionMode = false;
      _fetchBots();
    }
  }

  Future<void> _masterToggle(bool enable) async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().postEndpoint('copy_bots.php?action=toggle_all', {'enabled': enable ? 1 : 0});
    if (mounted) {
      _showFloatingSnackbar(res['message'] ?? 'Master toggle updated', isError: res['status'] != 'success');
      _fetchBots();
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
      _isSelectionMode = _selectedIds.isNotEmpty;
    });
  }

  void _selectAllFiltered(List<dynamic> filteredBots) {
    setState(() {
      if (_selectedIds.length == filteredBots.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(filteredBots.map((b) => b['bot_id'] as int));
      }
    });
  }

  void _openBulkTemplateManager() {
    final theme = Theme.of(context);
    final tradeCtrl = TextEditingController();
    final tpCtrl = TextEditingController();
    final slCtrl = TextEditingController();
    final concCtrl = TextEditingController();
    final minMcapCtrl = TextEditingController();
    final maxMcapCtrl = TextEditingController();
    String executionMode = 'real';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Bulk Configuration', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Applying settings to ${_selectedIds.length} bots. Leave fields blank to keep their existing values.', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 24),
                    
                    Text('EXECUTION MODE', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'real', label: Text('REAL FUNDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), icon: Icon(PhosphorIcons.currencyCircleDollarFill, size: 16)),
                        ButtonSegment(value: 'paper', label: Text('PAPER PORTFOLIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), icon: Icon(PhosphorIcons.paperPlaneTiltFill, size: 16)),
                      ],
                      selected: {executionMode},
                      onSelectionChanged: (val) => setStateDialog(() => executionMode = val.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return executionMode == 'real' ? AppTheme.danger(context).withOpacity(0.2) : AppTheme.info(context).withOpacity(0.2);
                          }
                          return theme.colorScheme.surfaceContainerHighest;
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(child: _buildSimpleInput('TRADE \$', tradeCtrl, PhosphorIcons.currencyDollar, theme)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSimpleInput('MAX OPEN', concCtrl, PhosphorIcons.infinity, theme)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSimpleInput('TP %', tpCtrl, PhosphorIcons.trendUp, theme)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSimpleInput('SL %', slCtrl, PhosphorIcons.trendDown, theme)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSimpleInput('MIN MCAP (\$)', minMcapCtrl, PhosphorIcons.chartLineDown, theme)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSimpleInput('MAX MCAP (\$)', maxMcapCtrl, PhosphorIcons.chartLineUp, theme)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          List<Map<String, dynamic>> updatedBots = [];
                          for (var id in _selectedIds) {
                            var bot = _bots.firstWhere((b) => b['bot_id'] == id);
                            updatedBots.add({
                              'bot_id': id,
                              'chain': bot['chain'],
                              'enabled': bot['enabled'],
                              'execution_mode': executionMode,
                              'trade_usd_amount': tradeCtrl.text.trim().isNotEmpty ? tradeCtrl.text.trim() : bot['trade_usd_amount'],
                              'tp_percent': tpCtrl.text.trim().isNotEmpty ? tpCtrl.text.trim() : bot['tp_percent'],
                              'sl_percent': slCtrl.text.trim().isNotEmpty ? slCtrl.text.trim() : bot['sl_percent'],
                              'max_concurrent': concCtrl.text.trim().isNotEmpty ? concCtrl.text.trim() : bot['max_concurrent'],
                              'min_mcap': minMcapCtrl.text.trim().isNotEmpty ? minMcapCtrl.text.trim() : bot['min_mcap'],
                              'max_mcap': maxMcapCtrl.text.trim().isNotEmpty ? maxMcapCtrl.text.trim() : bot['max_mcap'],
                            });
                          }
                          _bulkUpdateBots(updatedBots);
                        },
                        icon: const Icon(PhosphorIcons.checkCircleFill, size: 20),
                        label: Text('APPLY TO ${_selectedIds.length} BOTS', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildSimpleInput(String label, TextEditingController ctrl, IconData icon, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 18),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
    final currency = context.watch<CurrencyProvider>();

    int activeCount = 0;
    double totalAllocatedUsd = 0.0;
    bool hasMissingWallets = false;

    List<dynamic> filteredBots = _bots.where((b) {
      if (b['enabled'] == true) {
        activeCount++;
        totalAllocatedUsd += double.tryParse(b['trade_usd_amount']?.toString() ?? '0') ?? 0.0;
        if (b['has_wallet_on_chain'] == false) hasMissingWallets = true;
      }

      bool passSearch = _searchQuery.isEmpty || b['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      
      bool passChain = true;
      if (_selectedChain != 'All Chains') {
        passChain = b['chain'].toString().toLowerCase() == _selectedChain.toLowerCase();
      }

      bool passStatus = true;
      if (_selectedStatus == 'Active Only') passStatus = b['enabled'] == true;
      if (_selectedStatus == 'Inactive Only') passStatus = b['enabled'] == false;

      return passSearch && passChain && passStatus;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedIds.length} Selected', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18))
            : Text('COPY BOTS', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        leading: _isSelectionMode 
            ? IconButton(icon: Icon(PhosphorIcons.x, color: theme.colorScheme.onSurface), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); }))
            : IconButton(icon: Icon(PhosphorIcons.caretLeftBold, color: theme.colorScheme.onSurface), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(PhosphorIcons.checkSquareOffsetFill, color: theme.primaryColor),
              onPressed: () => _selectAllFiltered(filteredBots),
            )
          else
            PopupMenuButton<String>(
              icon: Icon(PhosphorIcons.dotsThreeOutlineVerticalFill, color: theme.colorScheme.onSurfaceVariant),
              color: theme.colorScheme.surface,
              onSelected: (val) {
                if (val == 'pause') _masterToggle(false);
                if (val == 'resume') _masterToggle(true);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'resume', child: Row(children: [Icon(PhosphorIcons.playFill, color: AppTheme.success(context), size: 18), const SizedBox(width: 8), Text('Resume All', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppTheme.success(context)))])),
                PopupMenuItem(value: 'pause', child: Row(children: [Icon(PhosphorIcons.pauseFill, color: AppTheme.danger(context), size: 18), const SizedBox(width: 8), Text('Pause All Bots', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: AppTheme.danger(context)))])),
              ],
            )
        ],
      ),
      body: AnimatedCryptoBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(PhosphorIcons.robotFill, color: theme.primaryColor, size: 16),
                                const SizedBox(width: 6),
                                Text('ACTIVE BOTS', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('$activeCount / ${_bots.length}', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('ALLOCATED SIZE', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                            const SizedBox(height: 8),
                            Text('\$${totalAllocatedUsd.toStringAsFixed(2)} / cycle', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 16)),
                            if (currency.isNaira) Text('≈ ${currency.format(totalAllocatedUsd)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    if (hasMissingWallets) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.danger(context).withOpacity(0.3))),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.warningCircleFill, color: AppTheme.danger(context), size: 14),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Warning: Some active bots have no wallet connected.', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context), fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(PhosphorIcons.magnifyingGlass, color: theme.colorScheme.onSurfaceVariant, size: 18),
                          filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedChain,
                          icon: Icon(PhosphorIcons.caretDownBold, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                          items: ['All Chains', 'Solana', 'BSC', 'Robinhood'].map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _selectedChain = val!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedStatus,
                          icon: Icon(PhosphorIcons.caretDownBold, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
                          items: ['All Status', 'Active Only', 'Inactive Only'].map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _selectedStatus = val!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : filteredBots.isEmpty 
                    ? Center(child: Text('No bots match your criteria.', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                        itemCount: filteredBots.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: BotConfigCard(
                              bot: filteredBots[index],
                              chainColors: _chainColors,
                              isSelectionMode: _isSelectionMode,
                              isSelected: _selectedIds.contains(filteredBots[index]['bot_id']),
                              onToggleSelect: () => _toggleSelection(filteredBots[index]['bot_id']),
                              onSave: _saveBotConfig,
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.danger(context).withOpacity(0.5)),
                          foregroundColor: AppTheme.danger(context),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          List<Map<String, dynamic>> updatedBots = [];
                          for (var id in _selectedIds) {
                            var b = _bots.firstWhere((bot) => bot['bot_id'] == id);
                            b['enabled'] = false;
                            updatedBots.add(b);
                          }
                          _bulkUpdateBots(updatedBots);
                        },
                        icon: const Icon(PhosphorIcons.pauseFill, size: 16),
                        label: const Text('PAUSE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.success(context).withOpacity(0.5)),
                          foregroundColor: AppTheme.success(context),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          List<Map<String, dynamic>> updatedBots = [];
                          for (var id in _selectedIds) {
                            var b = _bots.firstWhere((bot) => bot['bot_id'] == id);
                            b['enabled'] = true;
                            updatedBots.add(b);
                          }
                          _bulkUpdateBots(updatedBots);
                        },
                        icon: const Icon(PhosphorIcons.playFill, size: 16),
                        label: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: _openBulkTemplateManager,
                        icon: const Icon(PhosphorIcons.slidersHorizontalBold, size: 16),
                        label: const Text('CONFIG', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class BotConfigCard extends StatefulWidget {
  final dynamic bot;
  final Map<String, Color> chainColors;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final Function(Map<String, dynamic>) onSave;

  const BotConfigCard({super.key, required this.bot, required this.chainColors, required this.isSelectionMode, required this.isSelected, required this.onToggleSelect, required this.onSave});

  @override
  State<BotConfigCard> createState() => _BotConfigCardState();
}

class _BotConfigCardState extends State<BotConfigCard> {
  late bool isEnabled;
  late String executionMode;
  late TextEditingController tradeCtrl;
  late TextEditingController tpCtrl;
  late TextEditingController slCtrl;
  late TextEditingController concCtrl;
  late TextEditingController minMcapCtrl;
  late TextEditingController maxMcapCtrl;
  late TextEditingController xCtrl;
  
  double expectedProfit = 0.0;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  @override
  void didUpdateWidget(covariant BotConfigCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bot != oldWidget.bot) {
      _initValues();
    }
  }

  void _initValues() {
    isEnabled = widget.bot['enabled'] == true;
    executionMode = widget.bot['execution_mode'] == 'paper' ? 'paper' : 'real';
    tradeCtrl = TextEditingController(text: widget.bot['trade_usd_amount']?.toString() ?? '');
    tpCtrl = TextEditingController(text: widget.bot['tp_percent']?.toString() ?? '');
    slCtrl = TextEditingController(text: widget.bot['sl_percent']?.toString() ?? '');
    concCtrl = TextEditingController(text: widget.bot['max_concurrent']?.toString() ?? '');
    minMcapCtrl = TextEditingController(text: widget.bot['min_mcap']?.toString() ?? '');
    maxMcapCtrl = TextEditingController(text: widget.bot['max_mcap']?.toString() ?? '');
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
    minMcapCtrl.dispose();
    maxMcapCtrl.dispose();
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
    if (mounted) {
      setState(() {
        expectedProfit = size * (tp / 100);
      });
    }
  }

  void _handleSave() {
    FocusScope.of(context).unfocus();
    widget.onSave({
      'bot_id': widget.bot['bot_id'],
      'chain': widget.bot['chain'] ?? 'solana',
      'enabled': isEnabled,
      'execution_mode': executionMode,
      'trade_usd_amount': tradeCtrl.text.trim(),
      'tp_percent': tpCtrl.text.trim(),
      'sl_percent': slCtrl.text.trim(),
      'max_concurrent': concCtrl.text.trim(),
      'min_mcap': minMcapCtrl.text.trim(),
      'max_mcap': maxMcapCtrl.text.trim(),
    });
  }

  Widget _buildInput(String label, String hint, TextEditingController ctrl, IconData icon, Color iconColor, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1)),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: GoogleFonts.spaceGrotesk(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: iconColor, size: 16),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
              hintText: hint,
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
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
    final currency = context.watch<CurrencyProvider>();
    final String chainRaw = (widget.bot['chain'] ?? 'solana').toString().toLowerCase();
    final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
    final Color chainColor = widget.chainColors[chainRaw] ?? AppTheme.kainuwaPurple;
    final bool isPaper = executionMode == 'paper';

    Widget cardBody = GlassCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: IgnorePointer(
          ignoring: widget.isSelectionMode,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            collapsedIconColor: theme.colorScheme.onSurfaceVariant,
            iconColor: theme.primaryColor,
            title: Row(
              children: [
                if (widget.isSelectionMode) ...[
                  Icon(
                    widget.isSelected ? PhosphorIcons.checkCircleFill : PhosphorIcons.circle,
                    color: widget.isSelected ? theme.primaryColor : theme.colorScheme.outline,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled ? theme.primaryColor.withOpacity(0.12) : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PhosphorIcons.robotFill, size: 20, color: isEnabled ? theme.primaryColor : theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(widget.bot['name'], style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: chainColor.withOpacity(0.3))),
                            child: Text(chainLabel, style: TextStyle(fontSize: 9, color: chainColor, fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaper ? AppTheme.info(context).withOpacity(0.12) : AppTheme.danger(context).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: isPaper ? AppTheme.info(context).withOpacity(0.3) : AppTheme.danger(context).withOpacity(0.3)),
                            ),
                            child: Text(isPaper ? 'PAPER' : 'REAL', style: TextStyle(fontSize: 9, color: isPaper ? AppTheme.info(context) : AppTheme.danger(context), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isEnabled ? AppTheme.success(context) : theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                          Text(isEnabled ? 'ACTIVE' : 'INACTIVE', style: GoogleFonts.spaceGrotesk(color: isEnabled ? AppTheme.success(context) : theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 1, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 20),
                    if (widget.bot['has_wallet_on_chain'] == false && !isPaper)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.danger(context).withOpacity(0.3))),
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.warningCircleFill, color: AppTheme.danger(context), size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text('No $chainLabel wallet connected. Update Settings.', style: GoogleFonts.spaceGrotesk(color: AppTheme.danger(context), fontSize: 11, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                    
                    Text('EXECUTION MODE', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'real', label: Text('REAL FUNDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), icon: Icon(PhosphorIcons.currencyCircleDollarFill, size: 16)),
                        ButtonSegment(value: 'paper', label: Text('PAPER PORTFOLIO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), icon: Icon(PhosphorIcons.paperPlaneTiltFill, size: 16)),
                      ],
                      selected: {executionMode},
                      onSelectionChanged: (val) => setState(() { executionMode = val.first; _handleSave(); }),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return isPaper ? AppTheme.info(context).withOpacity(0.2) : AppTheme.danger(context).withOpacity(0.2);
                          }
                          return theme.colorScheme.surfaceContainerHighest;
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: _buildInput('TRADE \$', '5.00', tradeCtrl, PhosphorIcons.currencyDollar, theme.colorScheme.onSurface, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput('MAX OPEN', '∞', concCtrl, PhosphorIcons.infinity, theme.colorScheme.onSurfaceVariant, theme)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput('TP %', '100.00', tpCtrl, PhosphorIcons.trendUp, AppTheme.success(context), theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput('SL %', '90.00', slCtrl, PhosphorIcons.trendDown, AppTheme.danger(context), theme)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput('TARGET XS', '2.00', xCtrl, PhosphorIcons.x, theme.primaryColor, theme)),
                        const SizedBox(width: 12),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInput('MIN MCAP (\$)', '', minMcapCtrl, PhosphorIcons.chartLineDown, theme.colorScheme.onSurface, theme)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInput('MAX MCAP (\$)', '', maxMcapCtrl, PhosphorIcons.chartLineUp, theme.colorScheme.onSurface, theme)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.success(context).withOpacity(0.08),
                        border: Border.all(color: AppTheme.success(context).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(PhosphorIcons.calculatorFill, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text('EXPECTED PROFIT', style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1)),
                            ],
                          ),
                          Text('+\$${expectedProfit.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

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
                            const SizedBox(width: 4),
                            Text('Strategy Active', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _handleSave,
                          icon: const Icon(PhosphorIcons.floppyDiskFill, size: 16),
                          label: Text('Save', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );

    if (widget.isSelectionMode) {
      return GestureDetector(
        onTap: widget.onToggleSelect,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.isSelected ? theme.primaryColor : Colors.transparent, width: 2),
          ),
          child: cardBody,
        ),
      );
    }

    return GestureDetector(
      onLongPress: widget.onToggleSelect,
      child: cardBody,
    );
  }
}
