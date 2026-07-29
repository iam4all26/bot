import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/bot_engine_tab.dart';
import '../widgets/broadcast_dialog.dart';
import '../widgets/tracked_wallets_tab.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, 
              borderRadius: BorderRadius.circular(24), 
              border: Border.all(color: theme.colorScheme.outlineVariant)
            ),
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24), 
                gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFC026D3)])
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              tabs: const [
                Tab(text: 'Users'), 
                Tab(text: 'Bot Engine'), 
                Tab(text: 'Tracked Wallets')
              ],
            ),
          ),
          const SizedBox(height: 16),
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
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
      ));
      _rateCtrl.clear();
    }
  }

  Future<void> _toggleSetting(String action, int userId, Map<String, dynamic> payload) async {
    final res = await context.read<ApiService>().postEndpoint('admin.php?action=$action', payload);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Updated'),
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
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
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(PhosphorIcons.userPlusFill, color: theme.primaryColor),
                const SizedBox(width: 12),
                Text('Create User', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: userCtrl,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    hintText: 'e.g. trader_john',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Temporary Password',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    hintText: 'Min 8 characters',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                onPressed: isSaving ? null : () async {
                  if (userCtrl.text.trim().isEmpty || passCtrl.text.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Username required & Password min 8 chars'), backgroundColor: AppTheme.danger(context)));
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
                      backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
                    ));
                    _fetchUsers();
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Create User', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
        builder: (context, setStateDialog) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(PhosphorIcons.ticketFill, color: AppTheme.warning(context)),
                const SizedBox(width: 12),
                Text('Trading Limits', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Leave blank for unlimited allocations.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 24),
                TextField(
                  controller: dailyCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Daily Limit',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    hintText: '∞',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: monthlyCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Monthly Limit',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    hintText: '∞',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearlyCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Yearly Limit',
                    labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    hintText: '∞',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning(context), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
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
                      backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
                    ));
                    _fetchUsers();
                  }
                },
                child: isSaving 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Save Allocations', style: TextStyle(fontWeight: FontWeight.bold)),
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
    
    if (_isLoadingUsers) return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    
    return RefreshIndicator(
      onRefresh: _fetchUsers,
      color: theme.primaryColor,
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 1. EXCHANGE RATE CONTROL CARD
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.currencyCircleDollarFill, color: AppTheme.success(context)),
                    const SizedBox(width: 12),
                    Text('Global Exchange Rate (₦/USD)', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Set to 0 to automatically fetch the live market rate.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rateCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'e.g. 1600 or 0',
                          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success(context).withOpacity(0.12), 
                        foregroundColor: AppTheme.success(context), 
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24)
                      ),
                      onPressed: _isSavingRate ? null : _saveCustomRate,
                      child: _isSavingRate 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Set Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. CREATE USER BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0
              ),
              onPressed: _showCreateUserModal,
              icon: const Icon(PhosphorIcons.userPlusFill, size: 20),
              label: const Text('Create New User Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          
          // 3. BROADCAST PUSH NOTIFICATION BUTTON
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning(context).withOpacity(0.12),
                foregroundColor: AppTheme.warning(context),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const BroadcastPushDialog(),
                );
              },
              icon: const Icon(PhosphorIcons.megaphoneFill, size: 20),
              label: const Text('Send Push Broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 32),
          Text('SYSTEM USERS', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          
          // 4. USERS LIST
          ..._users.map((u) {
            final bool isActive = (u['is_active'] == 1 || u['is_active'] == '1' || u['is_active'] == true);
            final bool allowManual = (u['allow_manual_trade'] == 1 || u['allow_manual_trade'] == '1' || u['allow_manual_trade'] == true);
            final bool allowTelegram = (u['allow_telegram_alerts'] == 1 || u['allow_telegram_alerts'] == '1' || u['allow_telegram_alerts'] == true);
            
            final String daily = u['quotas']?['daily']?.toString() ?? '∞';
            final String monthly = u['quotas']?['monthly']?.toString() ?? '∞';
            final String yearly = u['quotas']?['yearly']?.toString() ?? '∞';

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u['username'] ?? '', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text('Role: ${u['role']}', style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _showQuotaModal(u['id'], u['quotas']?['daily'], u['quotas']?['monthly'], u['quotas']?['yearly']),
                          icon: Icon(PhosphorIcons.ticket, color: theme.colorScheme.onSurfaceVariant, size: 16),
                          label: Text('Quotas', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Limits:  $daily/day  •  $monthly/mo  •  $yearly/yr', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 20),
                    Container(height: 1, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.shieldCheckFill, color: isActive ? AppTheme.success(context) : AppTheme.danger(context), size: 18),
                            const SizedBox(width: 12),
                            Text('Account Access', style: TextStyle(color: isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Switch(
                          value: isActive,
                          activeColor: AppTheme.success(context),
                          inactiveThumbColor: AppTheme.danger(context),
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
                        Row(
                          children: [
                            const Icon(PhosphorIcons.rocketLaunchFill, color: Color(0xFFC026D3), size: 18),
                            const SizedBox(width: 12),
                            Text('Allow Manual Snipe', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
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
                        Row(
                          children: [
                            Icon(PhosphorIcons.paperPlaneTiltFill, color: AppTheme.info(context), size: 18),
                            const SizedBox(width: 12),
                            Text('Allow Telegram Alerts', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Switch(
                          value: allowTelegram,
                          activeColor: AppTheme.info(context),
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
          }),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
