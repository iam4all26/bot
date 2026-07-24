import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';

// Your existing external tab widget
import '../widgets/bot_engine_tab.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isLoadingUsers = true;
  List<dynamic> _users = [];

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
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)]),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'Users'),
                Tab(text: 'Bot Engine'),
                Tab(text: 'Tracked Wallets'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              children: [
                _buildUsersTab(theme),
                const BotEngineTab(), 
                _buildTrackedWalletsTab(theme), // Set back to inline method to fix missing file error
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    if (_isLoadingUsers) return const Center(child: CircularProgressIndicator());
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
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
        ..._users.map((u) {
          final bool isActive = (u['is_active'] == 1 || u['is_active'] == '1' || u['is_active'] == true);
          final bool allowManual = (u['allow_manual_trade'] == 1 || u['allow_manual_trade'] == '1' || u['allow_manual_trade'] == true);
          final bool allowTelegram = (u['allow_telegram_alerts'] == 1 || u['allow_telegram_alerts'] == '1' || u['allow_telegram_alerts'] == true);
          
          final String daily = u['max_trades_daily']?.toString() ?? '∞';
          final String monthly = u['max_trades_monthly']?.toString() ?? '∞';
          final String yearly = u['max_trades_yearly']?.toString() ?? '∞';

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
                        onPressed: () => _showQuotaModal(u['id'], u['max_trades_daily'], u['max_trades_monthly'], u['max_trades_yearly']),
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
    );
  }

  Widget _buildTrackedWalletsTab(ThemeData theme) {
    // You can paste your tracked wallets code inside this method to restore it.
    return const Center(
      child: Text(
        'Please paste your Tracked Wallets code here',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }
}
