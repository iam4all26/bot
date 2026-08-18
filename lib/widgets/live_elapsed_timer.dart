import 'dart:async';
import 'package:flutter/material.dart';

/// Shows a continuously-updating "time in trade" that ticks every second
/// on its own — independent of the parent screen's poll cycle — so it
/// visibly counts up (2s... 7s... 1m 12s...) instead of only updating
/// whenever the next 3-5s poll happens to land. Only this small widget
/// rebuilds each tick, not the whole card or list.
class LiveElapsedTimer extends StatefulWidget {
  final String? openedAt;
  final TextStyle? style;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;

  const LiveElapsedTimer({
    super.key,
    required this.openedAt,
    this.style,
    this.icon,
    this.iconSize = 11,
    this.iconColor,
  });

  @override
  State<LiveElapsedTimer> createState() => _LiveElapsedTimerState();
}

class _LiveElapsedTimerState extends State<LiveElapsedTimer> {
  Timer? _ticker;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = _parseOpenedAt(widget.openedAt);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant LiveElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openedAt != widget.openedAt) {
      setState(() => _startedAt = _parseOpenedAt(widget.openedAt));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime? _parseOpenedAt(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      String s = raw.replaceAll(' ', 'T');
      if (!s.endsWith('Z')) s += 'Z';
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  String _formatElapsed(Duration d) {
    if (d.isNegative) return '0s';
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (days > 0) return '${days}d ${hours}h';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_startedAt == null) {
      return Text('-', style: widget.style);
    }

    final elapsed = DateTime.now().toUtc().difference(_startedAt!);
    final text = _formatElapsed(elapsed);

    if (widget.icon == null) {
      return Text(text, style: widget.style);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(widget.icon, size: widget.iconSize, color: widget.iconColor ?? widget.style?.color),
        const SizedBox(width: 4),
        Text(text, style: widget.style),
      ],
    );
  }
}