import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _showErrorDialog(String title, String content) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(title, style: TextStyle(color: AppTheme.danger(context), fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error copied to clipboard')));
            },
            child: Text('COPY', style: TextStyle(color: theme.colorScheme.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CLOSE', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.login(_usernameController.text.trim(), _passwordController.text);

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result == null) {
          _showErrorDialog('Null Response', 'The API returned a null result. Check network connection or API URL.');
          return;
        }

        if (result['status'] == 'error') {
          _showErrorDialog('Login Rejected', result['message'] ?? 'Raw Result: $result');
        } else if (result['status'] == 'success') {
          if (!apiService.isAuthenticated) {
            _showErrorDialog('Storage Error', 'Login successful on server, but device failed to securely store session token.');
          } else {
            NotificationService.initialize(apiService);
            final data = result['data'];
            if (data != null && data['must_change_password'] == 1) {
               Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ForcePasswordChangeScreen(
                    currentPassword: _passwordController.text,
                  ),
                ),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            }
          }
        } else {
          _showErrorDialog('Unknown Format', 'Server returned an unknown format:\n\n$result');
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('App Crash / Exception', 'Error:\n$e\n\nStack:\n$stackTrace');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedCryptoBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 32, spreadRadius: 4)],
                        gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFC026D3)]),
                      ),
                      child: const Icon(PhosphorIcons.rocketLaunchFill, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text('Welcome to Kainuwa', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Text('Sign in to access your terminal', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
                    const SizedBox(height: 48),
                    GlassCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              prefixIcon: Icon(PhosphorIcons.user, color: theme.colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              prefixIcon: Icon(PhosphorIcons.lockKey, color: theme.colorScheme.onSurfaceVariant),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? PhosphorIcons.eyeClosed : PhosphorIcons.eye, color: theme.colorScheme.onSurfaceVariant),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surfaceContainerHighest,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.primaryColor)),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Secure Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForcePasswordChangeScreen extends StatefulWidget {
  final String currentPassword;
  const ForcePasswordChangeScreen({super.key, required this.currentPassword});

  @override
  State<ForcePasswordChangeScreen> createState() => _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState extends State<ForcePasswordChangeScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) return;
    if (newPass.length < 8) return;
    if (newPass != confirmPass) return;

    setState(() => _isLoading = true);
    final api = context.read<ApiService>();

    try {
      final res = await api.postEndpoint('auth.php?action=change_password', {
        'old_password': widget.currentPassword,
        'new_password': newPass,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['status'] == 'success') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Update Required', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.signOut, color: theme.colorScheme.onSurface),
            onPressed: () async {
              await context.read<ApiService>().logout();
              if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
          )
        ],
      ),
      body: AnimatedCryptoBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.warning(context).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(PhosphorIcons.shieldWarningFill, size: 48, color: AppTheme.warning(context)),
                ),
                const SizedBox(height: 24),
                Text('Secure Your Account', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Text('Your administrator has required you to set a new, secure password before accessing the trading terminal.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
                const SizedBox(height: 32),
                
                GlassCard(
                  child: Column(
                    children: [
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNew,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(PhosphorIcons.lockKey, color: theme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNew ? PhosphorIcons.eyeClosed : PhosphorIcons.eye, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          prefixIcon: Icon(PhosphorIcons.checkCircle, color: theme.primaryColor),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? PhosphorIcons.eyeClosed : PhosphorIcons.eye, color: theme.colorScheme.onSurfaceVariant),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updatePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        ),
                      ),
                    ],
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
