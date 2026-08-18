import 'package:flutter/foundation.dart';

/// Tracks which position IDs are currently mid-close/mid-hide, shared
/// across every screen that shows open positions (Dashboard, Positions,
/// Hidden Positions). Before this, each screen kept its own local
/// Set<int> — but since IndexedStack keeps all bottom-nav tabs mounted at
/// once, closing a position from one tab left the other tab completely
/// unaware, showing a stale "still open" count until its own poll cycle
/// happened to catch up. A close that takes any real amount of time
/// (seconds, sometimes longer for a batch close) made that window very
/// visible — e.g. Dashboard showing 2 open while Positions showed 12 for
/// the same account at the same moment.
class ClosingPositionsProvider extends ChangeNotifier {
  final Set<int> _closingIds = {};

  bool isClosing(int id) => _closingIds.contains(id);

  void markClosing(Iterable<int> ids) {
    _closingIds.addAll(ids);
    notifyListeners();
  }

  void clear(int id) {
    if (_closingIds.remove(id)) notifyListeners();
  }

  void clearAll(Iterable<int> ids) {
    final before = _closingIds.length;
    _closingIds.removeAll(ids);
    if (_closingIds.length != before) notifyListeners();
  }

  /// Filters a freshly-fetched open_positions list down to whatever isn't
  /// still marked as closing locally — the standard "don't let a closed
  /// position flash back into view before the server confirms it" guard.
  List<dynamic> filterOpen(List<dynamic> rawOpen) {
    return rawOpen.where((p) {
      final id = int.tryParse(p['id'].toString()) ?? 0;
      return !_closingIds.contains(id);
    }).toList();
  }
}