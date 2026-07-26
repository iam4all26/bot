import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';

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
        const SnackBar(content: Text('Title and Message Body are required!'), backgroundColor: Colors.orangeAccent),
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
        backgroundColor: res['status'] == 'success' ? Colors.green : Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: const Color(0xFF13131A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(PhosphorIcons.megaphoneFill, color: theme.primaryColor),
          const SizedBox(width: 10),
          const Text('Push Broadcast', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send a real-time push notification to all active mobile users.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Notification Title',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'e.g. 🚀 App Update v2.0 Released!',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Message Body',
                labelStyle: const TextStyle(color: Colors.white54),
                hintText: 'e.g. We have added new Solana DEX pools and faster execution speeds. Update now!',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetUserCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Target User ID (Optional)',
                labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                hintText: 'Leave empty to broadcast to ALL users',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
