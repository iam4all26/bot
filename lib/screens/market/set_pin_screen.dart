import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_card.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _hasExistingPin = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    final api = context.read<ApiService>();
    final res = await api.checkPinStatus();
    if (mounted) {
      setState(() {
        _isCheckingStatus = false;
        if (res['status'] == 'success' && res['data'] != null) {
          _hasExistingPin = res['data']['has_pin'] ?? false;
        }
      });
    }
  }

  Future<void> _handleSavePin() async {
    if (!_formKey.currentState!.validate()) return;

    final password = _passwordController.text.trim();
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The 4-digit PINs do not match.',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: AppTheme.danger(context),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final api = context.read<ApiService>();
    final res = await api.setWithdrawalPin(password: password, pin: pin);

    if (mounted) {
      setState(() => _isLoading = false);
      final bool isSuccess = res['status'] == 'success';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? (isSuccess ? 'PIN updated successfully' : 'Failed to update PIN'),
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: isSuccess ? AppTheme.success(context) : AppTheme.danger(context),
        ),
      );

      if (isSuccess) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _hasExistingPin ? 'UPDATE PIN' : 'SET WITHDRAWAL PIN',
          style: GoogleFonts.spaceGrotesk(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        leading: IconButton(
          icon: Icon(PhosphorIcons.caretLeftBold, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedCryptoBackground(
        child: _isCheckingStatus
            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PhosphorIcons.lockKeyFill,
                                color: theme.primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasExistingPin ? 'Update Your PIN' : 'Create Transactional PIN',
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This 4-digit PIN will be required to authorize all crypto sends and bank cash outs.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.spaceGrotesk(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Account Password',
                                labelStyle: GoogleFonts.spaceGrotesk(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  PhosphorIcons.lock,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Account password required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _pinController,
                                    obscureText: true,
                                    maxLength: 4,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 8,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'New PIN',
                                      counterText: '',
                                      labelStyle: GoogleFonts.spaceGrotesk(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                      filled: true,
                                      fillColor: theme.colorScheme.surfaceContainerHighest,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().length != 4) {
                                        return '4 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _confirmPinController,
                                    obscureText: true,
                                    maxLength: 4,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.spaceGrotesk(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 8,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Confirm PIN',
                                      counterText: '',
                                      labelStyle: GoogleFonts.spaceGrotesk(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                      filled: true,
                                      fillColor: theme.colorScheme.surfaceContainerHighest,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().length != 4) {
                                        return '4 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _handleSavePin,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(PhosphorIcons.shieldCheckFill, size: 20),
                          label: Text(
                            _isLoading
                                ? 'SAVING...'
                                : (_hasExistingPin ? 'UPDATE PIN' : 'SAVE & ACTIVATE PIN'),
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
