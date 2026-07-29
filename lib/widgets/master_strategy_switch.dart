import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MasterStrategySwitch extends StatefulWidget {
  const MasterStrategySwitch({super.key});

  @override
  State<MasterStrategySwitch> createState() => _MasterStrategySwitchState();
}

class _MasterStrategySwitchState extends State<MasterStrategySwitch> {
  bool _isLoading = true;
  bool _isAllPaused = false;

  @override
  void initState() {
    super.initState();
    _fetchStrategyStatus();
  }

  Future<void> _fetchStrategyStatus() async {
    final api = context.read<ApiService>();
    final res = await api.getEndpoint('strategies.php?action=fetch');
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success') {
          _isAllPaused = res['data']['all_paused'];
        }
      });
    }
  }

  Future<void> _toggleAll(bool value) async {
    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.postEndpoint('strategies.php?action=toggle_all', {
      'enable_state': value ? 1 : 0
    });

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['status'] == 'success') {
          _isAllPaused = res['all_paused'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = !_isAllPaused;
    final activeColor = AppTheme.success(context);
    final inactiveColor = AppTheme.warning(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.08) : inactiveColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? activeColor.withOpacity(0.2) : inactiveColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.15) : inactiveColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? PhosphorIcons.rocketLaunchFill : PhosphorIcons.pauseCircleFill,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Copy Trading',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive ? 'Strategies are actively monitoring.' : 'All strategies currently paused.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (_isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
            )
          else
            Switch(
              value: isActive,
              activeColor: activeColor,
              onChanged: _toggleAll,
            ),
        ],
      ),
    );
  }
}
