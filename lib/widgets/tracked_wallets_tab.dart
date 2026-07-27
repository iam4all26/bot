import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
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
      'label': _labelController.text.trim()
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
      _walletController.clear();
      _labelController.clear();
      _fetchWallets();
    }
  }

  Future<void> _syncWebhook() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syncing Helius Webhook...'), backgroundColor: Colors.amber));
    final res = await context.read<ApiService>().getEndpoint('admin_wallets.php?action=sync_webhook');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
  }

  Future<void> _toggleCopy(int id, bool currentEnabled) async {
    final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=toggle_copy', {'id': id, 'enabled': currentEnabled ? 0 : 1});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
      _fetchWallets();
    }
  }

  void _showBulkImportModal() {
    List<Map<String, TextEditingController>> rows = [
      {'label': TextEditingController(), 'address': TextEditingController()}
    ];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(children: [Icon(PhosphorIcons.listPlusFill, color: Theme.of(context).primaryColor), const SizedBox(width: 8), const Text('Bulk Import', style: TextStyle(color: Colors.white, fontSize: 16))]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Duplicates are safely ignored.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: rows[index]['label'],
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: const InputDecoration(hintText: 'Label (e.g. Whale 1)', hintStyle: TextStyle(color: Colors.white38), isDense: true, border: InputBorder.none),
                                    ),
                                  ),
                                  if (index > 0)
                                    IconButton(
                                      icon: const Icon(PhosphorIcons.trash, color: Colors.redAccent, size: 16),
                                      onPressed: () => setStateDialog(() => rows.removeAt(index)),
                                    )
                                ],
                              ),
                              Divider(height: 1, color: Colors.white.withOpacity(0.1)),
                              TextField(
                                controller: rows[index]['address'],
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                                decoration: const InputDecoration(hintText: 'Solana Address', hintStyle: TextStyle(color: Colors.white38), isDense: true, border: InputBorder.none),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setStateDialog(() => rows.add({'label': TextEditingController(), 'address': TextEditingController()})),
                  icon: Icon(PhosphorIcons.plusCircleFill, color: Theme.of(context).primaryColor, size: 16),
                  label: Text('Add Row', style: TextStyle(color: Theme.of(context).primaryColor)),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                List<Map<String, String>> payload = [];
                for (var row in rows) {
                  if (row['label']!.text.isNotEmpty && row['address']!.text.isNotEmpty) {
                    payload.add({'label': row['label']!.text.trim(), 'address': row['address']!.text.trim()});
                  }
                }
                
                final res = await this.context.read<ApiService>().postEndpoint('admin_wallets.php?action=add_bulk', {'wallets': payload});
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
                  _fetchWallets();
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Text('Import All', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditModal(dynamic w) async {
    final lblCtrl = TextEditingController(text: w['label']);
    final addrCtrl = TextEditingController(text: w['address']);
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(children: [Icon(PhosphorIcons.pencilSimpleFill, color: Theme.of(context).primaryColor), const SizedBox(width: 8), const Text('Edit Tracker', style: TextStyle(color: Colors.white, fontSize: 16))]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: lblCtrl, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: 'Label', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
              const SizedBox(height: 12),
              TextField(controller: addrCtrl, style: const TextStyle(color: Colors.white, fontSize: 12), decoration: InputDecoration(labelText: 'Address', filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final res = await this.context.read<ApiService>().postEndpoint('admin_wallets.php?action=edit', {'id': w['id'], 'label': lblCtrl.text.trim(), 'address': addrCtrl.text.trim()});
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
                  _fetchWallets();
                }
              },
              child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white)) : const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteModal(int id) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: const Row(children: [Icon(PhosphorIcons.warningCircleFill, color: Colors.redAccent), SizedBox(width: 8), const Text('Remove Tracker?', style: TextStyle(color: Colors.white, fontSize: 16))]),
        content: const Text('Are you sure you want to stop tracking this wallet? You must sync the webhook afterward.', style: TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=delete', {'id': id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
        _fetchWallets();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _fetchWallets,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Track New Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    OutlinedButton.icon(
                      onPressed: _showBulkImportModal,
                      style: OutlinedButton.styleFrom(side: BorderSide(color: theme.primaryColor.withOpacity(0.5)), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                      icon: Icon(PhosphorIcons.listPlus, size: 14, color: theme.primaryColor),
                      label: Text('Bulk', style: TextStyle(color: theme.primaryColor, fontSize: 11)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(labelText: 'Wallet Label', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _walletController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(labelText: 'Solana Address', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: _isLoading ? null : _addWallet, child: const Text('Deploy Tracker', style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ACTIVE TRACKERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
              OutlinedButton.icon(
                onPressed: _syncWebhook,
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber), foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                icon: const Icon(PhosphorIcons.arrowsClockwiseBold, size: 16),
                label: const Text('Sync Webhook', style: TextStyle(fontSize: 11)),
              )
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading && _wallets.isEmpty) 
            const Center(child: CircularProgressIndicator())
          else if (_wallets.isEmpty) 
            Text('No wallets tracked yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
          else 
            ..._wallets.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(w['label'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(12)),
                                child: Text('${w['trade_count'] ?? 0}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(w['address'] ?? '', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white10),
                    const SizedBox(height: 12),
                    
                    // Action Buttons Row (Wrapped)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          onTap: () => _toggleCopy(w['id'], w['copy_enabled'] == true || w['copy_enabled'] == 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? Colors.greenAccent.withOpacity(0.1) : Colors.white10,
                              border: Border.all(color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? Colors.greenAccent.withOpacity(0.3) : Colors.white24),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.copy, color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? Colors.greenAccent : Colors.white54, size: 14),
                                const SizedBox(width: 6),
                                Text((w['copy_enabled'] == true || w['copy_enabled'] == 1) ? 'Copying' : 'Paused', style: TextStyle(color: (w['copy_enabled'] == true || w['copy_enabled'] == 1) ? Colors.greenAccent : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletHistoryScreen(walletId: w['id']))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), border: Border.all(color: Colors.blueAccent.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.eyeBold, color: Colors.blueAccent, size: 14),
                                SizedBox(width: 6),
                                Text('View', style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showEditModal(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white10, border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.pencilSimple, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Edit', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _showDeleteModal(w['id']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), border: Border.all(color: Colors.redAccent.withOpacity(0.3)), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(PhosphorIcons.trash, color: Colors.redAccent, size: 14),
                                SizedBox(width: 6),
                                Text('Remove', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
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
