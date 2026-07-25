import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/bot_engine_tab.dart'; 

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: Colors.white.withOpacity(0.05))
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24), 
                gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)])
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'Users'), 
                Tab(text: 'Bot Engine'), 
                Tab(text: 'Tracked Wallets')
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: TabBarView(
              children: [
                UsersTab(), 
                BotEngineTab(), 
                TrackedWalletsTab() 
              ]
            )
          ),
        ],
      ),
    );
  }
}

// ==================== TAB 1: USERS & ECONOMY ====================
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});
  @override State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  bool _isLoadingUsers = true;
  List<dynamic> _users = [];
  
  final _rateCtrl = TextEditingController();
  bool _isSavingRate = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    final res = await context.read<ApiService>().getEndpoint('admin.php?action=fetch_users');
    if (mounted) {
      setState(() {
        if (res['status'] == 'success') {
          _users = res['data'] ?? [];
        }
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _saveCustomRate() async {
    final val = _rateCtrl.text.trim();
    if (val.isEmpty) return;
    
    setState(() => _isSavingRate = true);
    FocusScope.of(context).unfocus();
    
    final res = await context.read<ApiService>().postEndpoint(
      'admin.php?action=set_exchange_rate', 
      {'custom_ngn_rate': val}
    );
    
    if (mounted) {
      setState(() => _isSavingRate = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? ''),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
      _rateCtrl.clear();
    }
  }

  Future<void> _toggleSetting(String action, int userId, Map<String, dynamic> payload) async {
    final res = await context.read<ApiService>().postEndpoint('admin.php?action=$action', payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Updated'),
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _showCreateUserModal() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: Row(
            children: [
              Icon(PhosphorIcons.userPlusFill, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Create New User', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. trader_john',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Temporary Password',
                  hintText: 'Min 8 characters',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              onPressed: isSaving ? null : () async {
                if (userCtrl.text.trim().isEmpty || passCtrl.text.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username required & Password min 8 chars'), backgroundColor: Colors.red));
                  return;
                }
                setStateDialog(() => isSaving = true);
                final res = await this.context.read<ApiService>().postEndpoint(
                  'admin.php?action=create_user',
                  {'username': userCtrl.text.trim(), 'password': passCtrl.text},
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ));
                  _fetchUsers();
                }
              },
              child: isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text('Create User', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuotaModal(int userId, dynamic daily, dynamic monthly, dynamic yearly) async {
    final dailyCtrl = TextEditingController(text: daily?.toString() ?? '');
    final monthlyCtrl = TextEditingController(text: monthly?.toString() ?? '');
    final yearlyCtrl = TextEditingController(text: yearly?.toString() ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF13131A),
          title: const Row(
            children: [
              Icon(PhosphorIcons.ticketFill, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Trading Allocation Limits', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Leave blank for unlimited allocations.', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 12),
              TextField(
                controller: dailyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Daily Limit',
                  hintText: '∞',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: monthlyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Monthly Limit',
                  hintText: '∞',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: yearlyCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Yearly Limit',
                  hintText: '∞',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, foregroundColor: Colors.black),
              onPressed: isSaving ? null : () async {
                setStateDialog(() => isSaving = true);
                final res = await this.context.read<ApiService>().postEndpoint(
                  'admin.php?action=set_quota',
                  {
                    'user_id': userId,
                    'max_trades_daily': dailyCtrl.text.trim(),
                    'max_trades_monthly': monthlyCtrl.text.trim(),
                    'max_trades_yearly': yearlyCtrl.text.trim(),
                  },
                );
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text(res['message'] ?? ''),
                    backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
                  ));
                  _fetchUsers();
                }
              },
              child: isSaving 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Save Allocations', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    
    return RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // 1. EXCHANGE RATE CONTROL CARD
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(PhosphorIcons.currencyCircleDollarFill, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('Global Exchange Rate (₦/USD)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Set to 0 to automatically fetch the live market rate.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'e.g. 1600 or 0',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent, 
                        foregroundColor: Colors.black, 
                        padding: const EdgeInsets.symmetric(vertical: 14)
                      ),
                      onPressed: _isSavingRate ? null : _saveCustomRate,
                      child: _isSavingRate 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('Set Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. CREATE USER BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _showCreateUserModal,
              icon: const Icon(PhosphorIcons.userPlusFill, color: Colors.white, size: 18),
              label: const Text('Create New User Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 16),
          
          // 3. USERS LIST
          ..._users.map((u) {
            final bool isActive = (u['is_active'] == 1 || u['is_active'] == '1' || u['is_active'] == true);
            final bool allowManual = (u['allow_manual_trade'] == 1 || u['allow_manual_trade'] == '1' || u['allow_manual_trade'] == true);
            final bool allowTelegram = (u['allow_telegram_alerts'] == 1 || u['allow_telegram_alerts'] == '1' || u['allow_telegram_alerts'] == true);
            
            final String daily = u['quotas']?['daily']?.toString() ?? '∞';
            final String monthly = u['quotas']?['monthly']?.toString() ?? '∞';
            final String yearly = u['quotas']?['yearly']?.toString() ?? '∞';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['username'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text('Role: ${u['role']}', style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            side: BorderSide(color: Colors.white.withOpacity(0.1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showQuotaModal(u['id'], u['quotas']?['daily'], u['quotas']?['monthly'], u['quotas']?['yearly']),
                          icon: const Icon(PhosphorIcons.ticket, color: Colors.white54, size: 14),
                          label: const Text('Quotas', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Limits:  $daily/day   |   $monthly/mo   |   $yearly/yr', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white.withOpacity(0.05)),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.shieldCheck, color: isActive ? Colors.greenAccent : Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Text('Account Access', style: TextStyle(color: isActive ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: isActive,
                          activeColor: Colors.greenAccent,
                          inactiveThumbColor: Colors.redAccent,
                          onChanged: (val) {
                            setState(() => u['is_active'] = val);
                            _toggleSetting('toggle_active', u['id'], {'user_id': u['id'], 'is_active': val ? 1 : 0});
                          },
                        ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(PhosphorIcons.rocketLaunch, color: Colors.purpleAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Allow Manual Snipe', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                        Switch(
                          value: allowManual,
                          activeColor: theme.primaryColor,
                          onChanged: (val) {
                            setState(() => u['allow_manual_trade'] = val);
                            _toggleSetting('toggle_manual', u['id'], {'user_id': u['id'], 'allow_manual_trade': val ? 1 : 0});
                          },
                        ),
                      ],
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(PhosphorIcons.paperPlaneTilt, color: Colors.blueAccent, size: 16),
                            SizedBox(width: 8),
                            Text('Allow Telegram Alerts', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                        Switch(
                          value: allowTelegram,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) {
                            setState(() => u['allow_telegram_alerts'] = val);
                            _toggleSetting('toggle_telegram', u['id'], {'user_id': u['id'], 'allow_telegram_alerts': val ? 1 : 0});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          })
        ],
      ),
    );
  }
}

// ==================== TAB 3: TRACKED WALLETS ====================
class TrackedWalletsTab extends StatefulWidget {
  const TrackedWalletsTab({super.key});
  @override State<TrackedWalletsTab> createState() => _TrackedWalletsTabState();
}

class _TrackedWalletsTabState extends State<TrackedWalletsTab> {
  final _walletController = TextEditingController();
  List<dynamic> _wallets = [];
  bool _isLoading = false;

  @override void initState() { super.initState(); _fetchWallets(); }

  Future<void> _fetchWallets() async {
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().getEndpoint('admin_wallets.php?action=fetch');
    if (mounted) setState(() { _wallets = res['data']?['wallets'] ?? []; _isLoading = false; });
  }

  Future<void> _addWallet() async {
    if (_walletController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    final res = await context.read<ApiService>().postEndpoint('admin_wallets.php?action=add', {
      'address': _walletController.text.trim(),
      'label': 'Whale Tracker'
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? ''), backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red));
      _walletController.clear();
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
                    const Text('Track Target Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Icon(PhosphorIcons.userPlusFill, color: theme.primaryColor),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _walletController,
                  style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(labelText: 'Whale / Shark Wallet Address', labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant), filled: true, fillColor: Colors.black.withOpacity(0.2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
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
                        Expanded(child: Text(w['label'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        Row(
                          children: [
                            IconButton(icon: const Icon(PhosphorIcons.pencilSimple, color: Colors.white54, size: 18), onPressed: () => _showEditModal(w), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 4)),
                            IconButton(icon: const Icon(PhosphorIcons.trash, color: Colors.redAccent, size: 18), onPressed: () => _showDeleteModal(w['id']), constraints: const BoxConstraints(), padding: const EdgeInsets.symmetric(horizontal: 4)),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(w['address'] ?? '', style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11)),
                    const SizedBox(height: 12),
                    Container(height: 1, color: Colors.white10),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Copy Trading', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                        Switch(
                          value: w['copy_enabled'] == true || w['copy_enabled'] == 1,
                          activeColor: Colors.greenAccent,
                          onChanged: (_) => _toggleCopy(w['id'], w['copy_enabled'] == true || w['copy_enabled'] == 1),
                        )
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
