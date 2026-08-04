import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';
import '../screens/wallet_history_screen.dart';

class TrackedWalletsTab extends StatefulWidget {
  const TrackedWalletsTab({super.key});
  @override State<TrackedWalletsTab> createState() => _TrackedWalletsTabState();
}

class _TrackedWalletsTabState extends State<TrackedWalletsTab> {
  final _walletController = TextEditingController();
  final _labelController = TextEditingController();
  List<dynamic> _wallets = [];
  bool _isLoading = false;

  // Static chain list matching the chains seeded server-side.
  static const List<Map<String, String>> _chains = [
    {'id': 'solana', 'name': 'Solana'},
    {'id': 'bsc', 'name': 'BSC'},
    {'id': 'robinhood', 'name': 'Robinhood'},
  ];
  String _addChain = 'solana';

  static const Map<String, Color> _chainColors = {
    'solana': Color(0xFF9945FF),
    'bsc': Color(0xFFF0B90B),
    'robinhood': Color(0xFF00C805),
  };

  @override void initState() { super.initState(); _fetchWallets(); }

  Future<void> _fetchWallets() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('admin_wallets.php?action=fetch');
    if (mounted) setState(() { _wallets = res['data']?['wallets'] ?? []; _isLoading = false; });
  }

  Future<void> _addWallet() async {
    if (_walletController.text.trim().isEmpty || _labelController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=add', {
      'address': _walletController.text.trim(),
      'label': _labelController.text.trim(),
      'chain': _addChain
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
      _walletController.clear();
      _labelController.clear();
      _fetchWallets();
    }
  }

  Future<void> _syncWebhook() async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Syncing Helius Webhook...'), backgroundColor: AppTheme.warning(context)));
    final res = await context.read<ApiService>().getEndpoint('admin_wallets.php?action=sync_webhook');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
  }

  Future<void> _toggleCopy(int id, bool currentEnabled) async {
    final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=toggle_copy', {'id': id, 'enabled': currentEnabled ? 0 : 1});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
      _fetchWallets();
    }
  }

  void _showBulkImportModal() {
    List<Map<String, dynamic>> rows = [
      {'label': TextEditingController(), 'address': TextEditingController(), 'chain': 'solana'}
    ];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.listPlusFill, color: theme.primaryColor), const SizedBox(width: 12), Text('Bulk Import', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Duplicates are safely ignored.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: rows[index]['label'],
                                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                                        decoration: InputDecoration(hintText: 'Label (e.g. Whale 1)', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), isDense: true, border: InputBorder.none),
                                      ),
                                    ),
                                    if (index > 0)
                                      IconButton(
                                        icon: Icon(PhosphorIcons.trash, color: AppTheme.danger(context), size: 18),
                                        onPressed: () => setStateDialog(() => rows.removeAt(index)),
                                      )
                                  ],
                                ),
                                Divider(height: 16, color: theme.colorScheme.outlineVariant),
                                TextField(
                                  controller: rows[index]['address'],
                                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontFamily: 'monospace'),
                                  decoration: InputDecoration(hintText: 'Token Address', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), isDense: true, border: InputBorder.none),
                                ),
                                Divider(height: 16, color: theme.colorScheme.outlineVariant),
                                Row(
                                  children: _chains.map((c) {
                                    final selected = c['id'] == rows[index]['chain'];
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: () => setStateDialog(() => rows[index]['chain'] = c['id']!),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: selected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: selected ? theme.primaryColor : theme.colorScheme.outlineVariant),
                                          ),
                                          child: Text(c['name']!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant)),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setStateDialog(() => rows.add({'label': TextEditingController(), 'address': TextEditingController(), 'chain': 'solana'})),
                    icon: Icon(PhosphorIcons.plusCircleFill, color: theme.primaryColor, size: 18),
                    label: Text('Add Row', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  List<Map<String, String>> payload = [];
                  for (var row in rows) {
                    final TextEditingController labelCtrl = row['label'];
                    final TextEditingController addressCtrl = row['address'];
                    if (labelCtrl.text.isNotEmpty && addressCtrl.text.isNotEmpty) {
                      payload.add({'label': labelCtrl.text.trim(), 'address': addressCtrl.text.trim(), 'chain': row['chain'] ?? 'solana'});
                    }
                  }
                  
                  final res = await this.context.read<ApiService>().postEndpoint('admin_wallets.php?action=add_bulk', {'wallets': payload});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
                    _fetchWallets();
                  }
                },
                child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Import All', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showEditModal(dynamic w) async {
    final lblCtrl = TextEditingController(text: w['label']);
    final addrCtrl = TextEditingController(text: w['address']);
    String editChain = w['chain'] ?? 'solana';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(children: [Icon(PhosphorIcons.pencilSimpleFill, color: theme.primaryColor), const SizedBox(width: 12), Text('Edit Tracker', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: _chains.map((c) {
                    final selected = c['id'] == editChain;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setStateDialog(() => editChain = c['id']!),
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
                const SizedBox(height: 16),
                TextField(controller: lblCtrl, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Label', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                const SizedBox(height: 16),
                TextField(controller: addrCtrl, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13, fontFamily: 'monospace'), decoration: InputDecoration(labelText: 'Address', filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: isSaving ? null : () async {
                  setStateDialog(() => isSaving = true);
                  final res = await this.context.read<ApiService>().postEndpoint('admin_wallets.php?action=edit', {'id': w['id'], 'label': lblCtrl.text.trim(), 'address': addrCtrl.text.trim(), 'chain': editChain});
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
                    _fetchWallets();
                  }
                },
                child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _showDeleteModal(int id) async {
    final theme = Theme.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [Icon(PhosphorIcons.warningCircleFill, color: AppTheme.danger(context)), const SizedBox(width: 12), Text('Remove Tracker?', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold))]),
        content: Text('Are you sure you want to stop tracking this wallet? You must sync the webhook afterward.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger(context), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=delete', {'id': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context)));
        _fetchWallets();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _fetchWallets,
      color: theme.primaryColor,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Track New Wallet', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                    OutlinedButton.icon(
                      onPressed: _showBulkImportModal,
                      style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primaryColor.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      icon: Icon(PhosphorIcons.listPlus, size: 16, color: theme.primaryColor),
                      label: Text('Bulk Import', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _labelController,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(labelText: 'Wallet Label', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                Row(
                  children: _chains.map((c) {
                    final selected = c['id'] == _addChain;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _addChain = c['id']!),
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
                const SizedBox(height: 16),
                TextField(
                  controller: _walletController,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(labelText: '${_chains.firstWhere((c) => c['id'] == _addChain)['name']} Address', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), onPressed: _isLoading ? null : _addWallet, child: const Text('Deploy Tracker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACTIVE TRACKERS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.5)),
              OutlinedButton.icon(
                onPressed: _syncWebhook,
                style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.warning(context)), foregroundColor: AppTheme.warning(context), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: const Icon(PhosphorIcons.arrowsClockwiseBold, size: 16),
                label: const Text('Sync Webhook', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading && _wallets.isEmpty) 
            Center(child: CircularProgressIndicator(color: theme.primaryColor))
          else if (_wallets.isEmpty) 
            Text('No wallets tracked yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
          else 
            ..._wallets.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(w['label'] ?? 'Unknown', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (_chainColors[w['chain']] ?? theme.colorScheme.onSurfaceVariant).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: (_chainColors[w['chain']] ?? theme.colorScheme.onSurfaceVariant).withOpacity(0.3)),
                                ),
                                child: Text((w['chain'] ?? 'solana').toString().toUpperCase(), style: TextStyle(color: _chainColors[w['chain']] ?? theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 9)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: AppTheme.success(context).withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                                child: Text('${w['trade_count'] ?? 0} Trades', style: TextStyle(color: AppTheme.success(context), fontWeight: FontWeight.bold, fontSize: 11)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(w['address'] ?? '', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontFamily: 'monospace', fontSize: 12)),
                    const SizedBox(height: 20),
                    Container(height: 1, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 20),
                    
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        InkWell(
                          onTap: () => _toggleCopy(w['id'], w['copy_enabled'] == true || w['copy_enabled'] == 1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? AppTheme.success(context).withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
                              border: Border.all(color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? AppTheme.success(context).withOpacity(0.3) : theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.copy, color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? AppTheme.success(context) : theme.colorScheme.onSurfaceVariant, size: 16),
                                const SizedBox(width: 8),
                                Text((w['copy_enabled'] == true || w['copy_enabled'] == 1) ? 'Copying' : 'Paused', style: TextStyle(color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? AppTheme.success(context) : theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletHistoryScreen(walletId: w['id']))),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppTheme.info(context).withOpacity(0.1), border: Border.all(color: AppTheme.info(context).withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.eyeBold, color: AppTheme.info(context), size: 16),
                                const SizedBox(width: 8),
                                Text('View', style: TextStyle(color: AppTheme.info(context), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showEditModal(w),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.pencilSimple, color: theme.colorScheme.onSurface, size: 16),
                                const SizedBox(width: 8),
                                Text('Edit', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showDeleteModal(w['id']),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: AppTheme.danger(context).withOpacity(0.1), border: Border.all(color: AppTheme.danger(context).withOpacity(0.3)), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.trash, color: AppTheme.danger(context), size: 16),
                                const SizedBox(width: 8),
                                Text('Remove', style: TextStyle(color: AppTheme.danger(context), fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )).toList()
        ],
      ),
    );
  }
}
