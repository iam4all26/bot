import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_theme.dart';

// Returned to the caller (market_buy_screen) when the sheet closes.
enum CheckoutExit { completed, cancelled }

class MarketCheckoutWebviewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String reference;

  const MarketCheckoutWebviewScreen({
    super.key,
    required this.checkoutUrl,
    required this.reference,
  });

  @override
  State<MarketCheckoutWebviewScreen> createState() => _MarketCheckoutWebviewScreenState();
}

class _MarketCheckoutWebviewScreenState extends State<MarketCheckoutWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            // Paystack/Flutterwave both redirect back to our
            // market_callback.php once checkout finishes. That page needs a
            // logged-in web session (which the app never has), so we never
            // let it load — we catch the redirect here and hand control
            // straight back to the app, which polls the real status over
            // the same Bearer-token API as everything else.
            if (request.url.contains('market_callback.php')) {
              _finish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _finish() {
    if (_isFinishing) return;
    _isFinishing = true;
    if (mounted) Navigator.of(context).pop(CheckoutExit.completed);
  }

  Future<bool> _confirmLeave() async {
    if (_isFinishing) return true;
    final theme = Theme.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this payment?'),
        content: const Text(
          "If you already paid, don't worry — it'll still confirm automatically. "
          "Leaving now just closes this checkout screen.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Leave', style: TextStyle(color: AppTheme.danger(context))),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && mounted) {
          Navigator.of(context).pop(CheckoutExit.cancelled);
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'SECURE CHECKOUT',
            style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
            onPressed: () async {
              if (await _confirmLeave() && mounted) {
                Navigator.of(context).pop(CheckoutExit.cancelled);
              }
            },
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: theme.scaffoldBackgroundColor,
                child: Center(child: CircularProgressIndicator(color: theme.primaryColor)),
              ),
          ],
        ),
      ),
    );
  }
}
