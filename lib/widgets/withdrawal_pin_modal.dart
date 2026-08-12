import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/app_theme.dart';

class WithdrawalPinModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final Function(String pin) onPinEntered;

  const WithdrawalPinModal({
    super.key,
    this.title = 'Authorize Transaction',
    this.subtitle = 'Enter your 4-digit PIN to release funds.',
    required this.onPinEntered,
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'Authorize Transaction',
    String subtitle = 'Enter your 4-digit PIN to release funds.',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: WithdrawalPinModal(
          title: title,
          subtitle: subtitle,
          onPinEntered: (pin) => Navigator.pop(ctx, pin),
        ),
      ),
    );
  }

  @override
  State<WithdrawalPinModal> createState() => _WithdrawalPinModalState();
}

class _WithdrawalPinModalState extends State<WithdrawalPinModal> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _submitPin() {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() {
        _isError = true;
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isError = false);
      });
      return;
    }

    widget.onPinEntered(pin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(PhosphorIcons.lockKeyFill, color: theme.primaryColor, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    widget.title,
                    style: GoogleFonts.spaceGrotesk(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(PhosphorIcons.xBold, color: theme.colorScheme.onSurfaceVariant, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isError ? AppTheme.danger(context) : theme.colorScheme.outlineVariant,
                width: _isError ? 2 : 1,
              ),
            ),
            child: TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: theme.colorScheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
              ),
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                hintText: '••••',
                hintStyle: TextStyle(
                  letterSpacing: 16,
                  color: Colors.grey,
                ),
              ),
              onChanged: (val) {
                if (val.length == 4) {
                  _submitPin();
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: _submitPin,
              icon: const Icon(PhosphorIcons.arrowRightBold, size: 18),
              label: Text(
                'CONFIRM & AUTHORIZE',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
