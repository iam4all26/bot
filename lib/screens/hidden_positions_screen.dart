import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

  static final Map<String, Color> _chainColors = {
    'solana': AppTheme.kainuwaPurple,
    'bsc': const Color(0xFFF0B90B),
    'robinhood': const Color(0xFF00C805),
  };

  @override
  void initState() {
    super.initState();
    _fetchHiddenPositions();
  }

  Future<void> _fetchHiddenPositions() async {
    setState(() => _isLoading = true);
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

  Future<void> _restorePosition(dynamic p) async {
    final pId = int.tryParse(p['id'].toString()) ?? 0;
    if (pId <= 0) return;

    setState(() => _animatingIds.add(pId));
    await Future.delayed(const Duration(milliseconds: 350));

    final res = await context.read<ApiService>().postEndpoint('positions.php?action=toggle_hide', {'id': pId, 'is_hidden': 0});
    if (mounted) {
      if (res['status'] != 'success') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'Failed to restore', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), backgroundColor: AppTheme.danger(context)));
        setState(() => _animatingIds.remove(pId));
      }
      _fetchHiddenPositions();
    }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatAddress(String addr) => addr.length <= 12 ? addr : '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';

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
                              title: Text('${_formatAddress(p['token_address'] ?? '')} ($chainLabel)', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
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
                        _fetchHiddenPositions();
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
                  
                  final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
                  final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
                  final isReal = p['is_real'] == 1 || p['is_real'] == '1';
                  final String chainRaw = (p['chain'] ?? 'solana').toString().toLowerCase();
                  final String chainLabel = {'bsc': 'BSC', 'robinhood': 'RBH'}[chainRaw] ?? 'SOL';
                  final Color chainColor = _chainColors[chainRaw] ?? AppTheme.kainuwaPurple;

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: isAnimating
                        ? const SizedBox(width: double.infinity, height: 0)
                        : AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: isAnimating ? 0.0 : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: GlassCard(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          children: [
                                            Text(_formatAddress(p['token_address'] ?? ''), style: TextStyle(color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 15)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(color: chainColor.withOpacity(0.12), borderRadius: BorderRadius.circular(5), border: Border.all(color: chainColor.withOpacity(0.3))),
                                              child: Text(chainLabel, style: TextStyle(fontSize: 9, color: chainColor, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        InkWell(
                                          onTap: () => _restorePosition(p),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.primaryColor.withOpacity(0.3))),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(PhosphorIcons.eyeFill, color: theme.primaryColor, size: 14), 
                                                const SizedBox(width: 4), 
                                                Text('Restore', style: GoogleFonts.spaceGrotesk(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Status: ${p['status']?.toString().toUpperCase()} • Size: \$${size.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('Archived Entry MCAP: ${_formatMcap(p['entry_mcap'])}', style: GoogleFonts.spaceGrotesk(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
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
