import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';

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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        title: Text(title, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(
            content,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error copied to clipboard')));
            },
            child: const Text('COPY', style: TextStyle(color: Colors.blueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
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
            // Success! 
            NotificationService.initialize(apiService);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green),
            );
            // Add your navigation to Dashboard here if it's missing!
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
                        boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 40, spreadRadius: 5)],
                        gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)]),
                      ),
                      child: Icon(PhosphorIcons.chartLineUpBold, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text('KAINUWA BOT', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Enterprise Trading Terminal', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1)),
                    const SizedBox(height: 48),
                    GlassCard(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _usernameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Username',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              prefixIcon: Icon(PhosphorIcons.user, color: theme.colorScheme.onSurfaceVariant),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              prefixIcon: Icon(PhosphorIcons.lockKey, color: theme.colorScheme.onSurfaceVariant),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? PhosphorIcons.eyeClosed : PhosphorIcons.eye, color: theme.colorScheme.onSurfaceVariant),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              filled: true,
                              fillColor: Colors.black.withOpacity(0.2),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(colors: [theme.primaryColor, const Color(0xFFE024CE)]),
                                boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('LOGIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                              ),
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
