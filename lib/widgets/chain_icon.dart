import 'package:flutter/material.dart';
import 'solana_icon.dart';

/// Renders the real crypto logo for a given chain — Solana's existing
/// vector icon, or the actual BNB/ETH icon (via the same CDN the
/// Buy/Send/Receive screens already use) for BSC and Robinhood Chain.
/// Robinhood Chain's native asset is ETH, so ETH's icon is what
/// represents it here too — matches the asset badges shown elsewhere in
/// the app, where "Robinhood Chain" is a label next to the ETH icon.
///
/// Falls back to a plain colored initial letter only if the network image
/// genuinely fails to load (offline, CDN hiccup) — never as the default.
class ChainIcon extends StatelessWidget {
  final String chain;
  final double size;
  final Color color;

  const ChainIcon({super.key, required this.chain, required this.size, required this.color});

  /// Returns the CDN icon URL for a chain, or null if it doesn't use a
  /// network icon (Solana renders a local vector instead). Exposed so
  /// screens that capture a screenshot (e.g. the PnL share receipt) can
  /// precache it first — a RepaintBoundary capture happens synchronously
  /// and won't wait for an in-flight network image to finish loading.
  static String? iconUrlFor(String chain) {
    switch (chain.toLowerCase()) {
      case 'bsc':
        return 'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/bnb.png';
      case 'robinhood':
        return 'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/eth.png';
      default:
        return null;
    }
  }

  String? get _iconSymbol {
    switch (chain.toLowerCase()) {
      case 'bsc':
        return 'bnb';
      case 'robinhood':
        return 'eth';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (chain.toLowerCase() == 'solana') {
      return SolanaIcon(size: size, color: color);
    }

    final symbol = _iconSymbol;
    if (symbol == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            chain.isNotEmpty ? chain.substring(0, 1).toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size * 0.65),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/$symbol.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              symbol.substring(0, 1).toUpperCase(),
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: size * 0.65),
            ),
          );
        },
      ),
    );
  }
}
