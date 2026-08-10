import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';

class HiddenPositionsScreen extends StatefulWidget {
  const HiddenPositionsScreen({super.key});

  @override
  State<HiddenPositionsScreen> createState() => _HiddenPositionsScreenState();
}

class _HiddenPositionsScreenState extends State<HiddenPositionsScreen> {
  bool _isLoading = true;
  List<dynamic> _hiddenPositions = [];
  final Set<int> _animatingIds = {};
  final Set<int> _closingIds = {};
  Timer? _pollingTimer;

  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

  @override
  void initState() {
    super.initState();
    _fetchHiddenPositions();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchHiddenPositions(silent: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchHiddenPositions({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch_hidden');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _hiddenPositions = res['data'] ?? [];
        }
        _isLoading = false;
      });
    }
  }

  void _showFloatingSnackbar(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isError ? AppTheme.danger(context) : theme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _launchDexScreener(String address, {String chain = 'solana'}) async {
    final url = Uri.parse('https://dexscreener.com/$chain/$address');
    try { await launchUrl(url, mode: LaunchMode.inAppWebView); } catch (_) {}
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatFullAddress(String addr) {
    if (addr.length <= 12) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  Future<void> _toggleLock(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;
    
    final isCurrentlyLocked = (p['is_locked'] == 1 || p['is_locked'] == '1');
    final newLockStatus = !isCurrentlyLocked;
    
    setState(() { p['is_locked'] = newLockStatus ? 1 : 0; });
    
    final res = await context.read<ApiService>().postEndpoint('trade.php?action=toggle_lock', {'id': pId, 'is_locked': newLockStatus ? 1 : 0});
    
    if (mounted && res['status'] != 'success') {
      setState(() { p['is_locked'] = isCurrentlyLocked ? 1 : 0; });
      _showFloatingSnackbar(res['message'] ?? 'Failed to sync lock status', isError: true);
    }
  }

  Future<void> _restorePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;

    setState(() => _animatingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350));

    final res = await context.read<ApiService>().postEndpoint('positions.php?action=toggle_hide', {'id': pId, 'is_hidden': 0});
    if (mounted) {
      if (res['status'] != 'success') {
        _showFloatingSnackbar(res['message'] ?? 'Failed to restore', isError: true);
        setState(() => _animatingIds.remove(pId));
      }
      _fetchHiddenPositions(silent: true);
    }
  }

  Future<void> _quickClosePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (p['is_locked'] == 1 || p['is_locked'] == '1') {
      _showFloatingSnackbar('Trade is locked! 🔓 Unlock to close.', isError: true);
      return;
    }

    setState(() => _closingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350)); 

    final res = await context.read<ApiService>().postEndpoint('trade.php?action=close_position', {'id': pId});
    if (mounted) {
      if (res['status'] != 'success' && res['status'] != 'closed') {
         _showFloatingSnackbar(res['message'] ?? 'Failed to close', isError: true);
         setState(() => _closingIds.remove(pId)); 
      }
      _fetchHiddenPositions(silent: true);
    }
  }

  Future<void> _editLimits(Map<String, dynamic> p) async {
    final tpCtrl = TextEditingController(text: (p['tp_percent'] != null && double.tryParse(p['tp_percent'].toString()) != 0) ? p['tp_percent'].toString() : '');
    final slCtrl = TextEditingController(text: (p['sl_percent'] != null && double.tryParse(p['sl_percent'].toString()) != 0) ? p['sl_percent'].toString() : '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.slidersHorizontalBold, color: theme.primaryColor), const SizedBox(width: 12), Text('Edit Live Targets', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('Leave a field blank (or 0) to remove that limit.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12))),
                    TextButton.icon(
                      onPressed: () {
                        setStateDialog(() {
                          tpCtrl.clear();
                          slCtrl.clear();
                        });
                      },
                      icon: Icon(PhosphorIcons.trash, size: 14, color: AppTheme.danger(context)),
                      label: Text('Clear All', style: TextStyle(color: AppTheme.danger(context), fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                TextField(controller: tpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Take Profit (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                TextField(controller: slCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Stop Loss (%)', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  final tpVal = tpCtrl.text.trim().isEmpty ? '0' : tpCtrl.text.trim();
                  final slVal = slCtrl.text.trim().isEmpty ? '0' : slCtrl.text.trim();
                  final res = await this.context.read<ApiService>().postEndpoint('trade.php?action=update_tpsl', {'id': p['id'], 'tp_percent': tpVal, 'sl_percent': slVal});
                  if (this.mounted) {
                    Navigator.pop(ctx);
                    _showFloatingSnackbar(res['message'] ?? 'Updated', isError: res['status'] != 'success');
                    _fetchHiddenPositions(silent: true);
                  }
                },
                child: isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _goLive(Map<String, dynamic> p) async {
    final theme = Theme.of(context);
    final chainName = (p['chain'] ?? 'solana').toString().toUpperCase();
    final defaultAmount = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0')?.toStringAsFixed(2) ?? '20.00';
    
    final amountCtrl = TextEditingController(text: defaultAmount);
    bool removeLimits = false;
    bool isSubmitting = false;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [Icon(PhosphorIcons.lightningFill, color: AppTheme.danger(context)), const SizedBox(width: 8), Text('Go Live on $chainName?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Execute a REAL trade mirroring this token.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 16),
                Text('TRADE AMOUNT (\$)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: Icon(PhosphorIcons.currencyDollar, color: theme.colorScheme.onSurfaceVariant, size: 18),
                    filled: true, fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 10, 20, 50, 100].map((amt) => InkWell(
                    onTap: () => setStateDialog(() => amountCtrl.text = amt.toStringAsFixed(2)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outlineVariant)),
                      child: Text('\$$amt', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => setStateDialog(() => removeLimits = !removeLimits),
                  child: Row(
                    children: [
                      Icon(removeLimits ? PhosphorIcons.checkSquareFill : PhosphorIcons.square, color: removeLimits ? AppTheme.danger(context) : theme.colorScheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Remove all limits (No TP/SL)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                onPressed: isSubmitting ? null : () async {
                  setStateDialog(() => isSubmitting = true);
                  final payload = {
                    'id': p['id'],
                    'trade_usd': amountCtrl.text.trim(),
                  };
                  if (removeLimits) {
                    payload['tp_percent'] = '0';
                    payload['sl_percent'] = '0';
                  }
                  final res = await this.context.read<ApiService>().postEndpoint('trade.php?action=mirror_real', payload);
                  if (this.mounted) {
                    Navigator.pop(ctx, true);
                    final ok = res['status'] == 'success' || res['status'] == 'ok';
                    _showFloatingSnackbar(res['message'] ?? (ok ? 'Live trade executed.' : 'Failed to go live.'), isError: !ok);
                    _fetchHiddenPositions(silent: true);
                  }
                }, 
                child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Go Live', style: TextStyle(fontWeight: FontWeight.bold))
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showBulkHideModal() async {
    final theme = Theme.of(context);
    List<dynamic> activeOpen = [];
    bool isFetchingOpen = true;
    String selectedChain = 'All Chains';
    Set<int> selectedToHide = {};
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          if (isFetchingOpen && activeOpen.isEmpty) {
            context.read<ApiService>().getEndpoint('positions.php?action=fetch').then((res) {
              if (mounted) {
                setStateDialog(() {
                  activeOpen = res['open_positions'] ?? [];
                  isFetchingOpen = false;
                });
              }
            });
          }

          List<dynamic> filteredOpen = activeOpen.where((p) {
            if (selectedChain == 'All Chains') return true;
            return (p['chain'] ?? 'solana').toString().toLowerCase() == selectedChain.toLowerCase();
          }).toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hide Open Trades', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20), onPressed: () => Navigator.pop(ctx))
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedChain,
                      icon: Icon(PhosphorIcons.caretDownBold, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                      items: ['All Chains', 'Solana', 'BSC', 'Robinhood'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setStateDialog(() => selectedChain = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: isFetchingOpen 
                    ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                    : filteredOpen.isEmpty 
                      ? Center(child: Text('No active trades to hide.', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant)))
                      : ListView.builder(
                          itemCount: filteredOpen.length,
                          itemBuilder: (context, index) {
                            final p = filteredOpen[index];
                            final int id = int.tryParse(p['id'].toString()) ?? 0;
                            final isSelected = selectedToHide.contains(id);
                            final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[(p['chain'] ?? 'solana').toString().toLowerCase()] ?? 'SOL';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Checkbox(
                                value: isSelected,
                                activeColor: theme.primaryColor,
                                onChanged: (val) => setStateDialog(() {
                                  if (val == true) selectedToHide.add(id); else selectedToHide.remove(id);
                                }),
                              ),
                              title: Text('${_formatFullAddress(p['token_address'] ?? '')} ($chainLabel)', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                              subtitle: Text('Size: \$${p['virtual_usd_amount']} • PnL: \$${p['unrealized_pnl'] ?? 0}', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                            );
                          },
                        ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: (selectedToHide.isEmpty || isSubmitting) ? null : () async {
                      setStateDialog(() => isSubmitting = true);
                      for (int id in selectedToHide) {
                        await context.read<ApiService>().postEndpoint('positions.php?action=toggle_hide', {'id': id, 'is_hidden': 1});
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchHiddenPositions(silent: true);
                      }
                    },
                    icon: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(PhosphorIcons.eyeSlashFill, size: 20),
                    label: Text('HIDE ${selectedToHide.length} TRADES', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = context.watch<CurrencyProvider>();
    final isAdmin = context.read<ApiService>().role == 'admin';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('HIDDEN POSITIONS', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.plusBold, color: theme.colorScheme.onSurface),
            onPressed: _showBulkHideModal,
          ),
        ],
      ),
      body: AnimatedCryptoBackground(
        child: _isLoading && _hiddenPositions.isEmpty
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : _hiddenPositions.isEmpty
            ? Center(child: Text('No hidden positions found.', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                itemCount: _hiddenPositions.length,
                itemBuilder: (context, index) {
                  final p = _hiddenPositions[index];
                  final pId = int.tryParse(p['id'].toString()) ?? 0;
                  final isAnimating = _animatingIds.contains(pId);
                  final isClosing = _closingIds.contains(pId);
                  final isLocked = p['is_locked'] == 1 || p['is_locked'] == '1';

                  final double? cpnl = double.tryParse(p['unrealized_pnl']?.toString() ?? '');
                  final bool cpIsProfit = (cpnl ?? 0) >= 0;
                  
                  final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                  final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                  final tp = double.tryParse(p['tp_percent']?.toString() ?? '0') ?? 0.0;
                  final sl = double.tryParse(p['sl_percent']?.toString() ?? '0') ?? 0.0;
                  final pct = double.tryParse(p['change_percent']?.toString() ?? '0') ?? 0.0;

                  final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                  final String chainRaw = (p['chain'] ?? 'solana').toString().toLowerCase();
                  final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
                  final Color chainColor = _chainColors[chainRaw] ?? AppTheme.kainuwaPurple;
                  
                  String botName = p['display_name'] ?? 'Manual';
                  if (isAdmin && botName != 'Manual') botName = botName.toUpperCase();

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: (isAnimating || isClosing)
                        ? const SizedBox(width: double.infinity, height: 0)
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: (isAnimating || isClosing) ? 0.0 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _toggleLock(p),
                                          child: Icon(isLocked ? PhosphorIcons.lockKeyFill : PhosphorIcons.lockKeyOpen, color: isLocked ? AppTheme.warning(context) : theme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_formatFullAddress(p['token_address']), style: TextStyle(fontFamily: 'monospace', color: theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: chainColor.withOpacity(0.3))),
                                          child: Text(chainLabel, style: TextStyle(fontSize: 8, color: chainColor, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)), 
                                            child: Text(botName, style: TextStyle(fontSize: 9, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(isReal ? 'LIVE' : '📄', style: TextStyle(color: isReal ? AppTheme.danger(context) : theme.colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    if (p['status'] == 'open') ...[
                                      Text(
                                        cpnl != null ? '${cpIsProfit && cpnl > 0 ? '+' : ''}\$${cpnl.toStringAsFixed(2)} (${cpIsProfit && cpnl > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)' : '-',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cpIsProfit ? AppTheme.success(context) : AppTheme.danger(context)),
                                      ),
                                      if (currency.isNaira && cpnl != null)
                                        Text('≈ ${cpIsProfit && cpnl > 0 ? '+' : ''}${currency.format(cpnl).replaceFirst('₦-', '-₦').replaceFirst('\$-', '-\$')}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: cpIsProfit ? AppTheme.success(context).withOpacity(0.8) : AppTheme.danger(context).withOpacity(0.8))),
                                      const SizedBox(height: 8),
                                    ] else ...[
                                      Text(
                                        '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)} (${pnl >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pnl >= 0 ? AppTheme.success(context) : AppTheme.danger(context)),
                                      ),
                                      const SizedBox(height: 8),
                                    ],

                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Size: \$${size.toStringAsFixed(2)} • Entry: ${_formatMcap(p['entry_mcap'])} • Live: ${_formatMcap(p['current_mcap'] ?? p['close_mcap'])}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text('TP: ${tp > 0 ? "+$tp%" : "None"} • SL: ${sl > 0 ? "-$sl%" : "None"}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _restorePosition(p),
                                              child: Icon(PhosphorIcons.eyeFill, color: theme.primaryColor, size: 20),
                                            ),
                                            const SizedBox(width: 16),
                                            if (p['status'] == 'open') ...[
                                              GestureDetector(
                                                onTap: () => _editLimits(p),
                                                child: Icon(PhosphorIcons.slidersHorizontalBold, color: theme.colorScheme.onSurface, size: 20),
                                              ),
                                              const SizedBox(width: 16),
                                            ],
                                            GestureDetector(
                                              onTap: () => _launchDexScreener(p['token_address'] ?? '', chain: p['chain'] ?? 'solana'),
                                              child: Icon(PhosphorIcons.arrowSquareOutBold, color: theme.colorScheme.onSurface, size: 20),
                                            ),
                                            if (!isReal && p['status'] == 'open') ...[
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _goLive(p),
                                                child: Icon(PhosphorIcons.lightningFill, color: AppTheme.success(context), size: 22),
                                              ),
                                            ],
                                            if (p['status'] == 'open') ...[
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () => _quickClosePosition(p),
                                                child: Icon(PhosphorIcons.xCircleFill, color: AppTheme.danger(context), size: 24),
                                              ),
                                            ],
                                          ],
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  );
                },
              ),
      ),
    );
  }
}
