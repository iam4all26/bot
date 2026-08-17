import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/app_theme.dart';

// A small set of distinct colors cycled through for bank initial-badges,
// purely so the list doesn't look like a wall of identical grey circles.
const List<Color> _bankBadgeColors = [
  Color(0xFF7351FF), // brand purple
  Color(0xFF14B8A6),
  Color(0xFFF59E0B),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
  Color(0xFF10B981),
];

Color _colorForBank(String name) {
  final int idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _bankBadgeColors.length;
  return _bankBadgeColors[idx];
}

/// Shows a modern, searchable bank picker. Returns the selected bank map
/// (with 'code' and 'name' keys) or null if dismissed without a selection.
Future<Map<String, dynamic>?> showBankSelectorSheet(
  BuildContext context, {
  required List<dynamic> banks,
  String? currentCode,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BankSelectorSheet(banks: banks, currentCode: currentCode),
  );
}

class _BankSelectorSheet extends StatefulWidget {
  final List<dynamic> banks;
  final String? currentCode;

  const _BankSelectorSheet({required this.banks, required this.currentCode});

  @override
  State<_BankSelectorSheet> createState() => _BankSelectorSheetState();
}

class _BankSelectorSheetState extends State<_BankSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredBanks {
    if (_query.isEmpty) return widget.banks;
    final q = _query.toLowerCase();
    return widget.banks.where((b) {
      final name = (b['name']?.toString() ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredBanks;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Text(
                      'Select Destination Bank',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(PhosphorIcons.x, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search banks...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass, color: theme.colorScheme.onSurfaceVariant, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: Icon(PhosphorIcons.xCircleFill, color: theme.colorScheme.onSurfaceVariant, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'No banks match "$_query"',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final bank = filtered[index];
                          final String name = bank['name']?.toString() ?? 'Bank';
                          final String code = bank['code']?.toString() ?? '';
                          final bool isSelected = code == widget.currentCode;
                          final Color badgeColor = _colorForBank(name);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.of(context).pop(bank),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.14),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: badgeColor.withOpacity(0.25)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 15),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(PhosphorIcons.checkCircleFill, color: theme.primaryColor, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}