import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BroadcastPushDialog extends StatefulWidget {
  const BroadcastPushDialog({super.key});

  @override
  State<BroadcastPushDialog> createState() => _BroadcastPushDialogState();
}

class _BroadcastPushDialogState extends State<BroadcastPushDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _targetUserCtrl = TextEditingController();
  bool _isSending = false;

  Future<void> _sendBroadcast() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Title and Message Body are required!'), backgroundColor: AppTheme.warning(context)),
      );
      return;
    }

    setState(() => _isSending = true);

    final payload = {
      'title': _titleCtrl.text.trim(),
      'body': _bodyCtrl.text.trim(),
    };

    if (_targetUserCtrl.text.trim().isNotEmpty) {
      payload['target_user_id'] = _targetUserCtrl.text.trim();
    }

    final res = await context.read<ApiService>().postEndpoint('admin.php?action=send_push_broadcast', payload);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['message'] ?? 'Notification processed.'),
        backgroundColor: res['status'] == 'success' ? AppTheme.success(context) : AppTheme.danger(context),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.warning(context).withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.megaphoneFill, color: AppTheme.warning(context), size: 20),
          ),
          const SizedBox(width: 12),
          Text('Push Broadcast', style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send a real-time push notification to all active mobile users.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleCtrl,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Notification Title',
                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                hintText: 'e.g. 🚀 App Update Released!',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Message Body',
                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                hintText: 'e.g. We have added new DEX pools...',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetUserCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Target User ID (Optional)',
                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                hintText: 'Leave empty to broadcast to ALL',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warning(context),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isSending ? null : _sendBroadcast,
          icon: _isSending
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(PhosphorIcons.paperPlaneRightBold, color: Colors.white, size: 18),
          label: const Text('Send Push', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
