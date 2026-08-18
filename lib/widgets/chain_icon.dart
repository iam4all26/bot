import 'package:flutter/material.dart';

/// Renders the real crypto logo for a given chain — Solana, BNB (for BSC),
/// and ETH (for Robinhood Chain, since ETH is the asset that chain
/// represents — matches the asset badges shown elsewhere in the app,
/// where "Robinhood Chain" is a label next to the ETH icon). All three use
/// the same CDN the Buy/Send/Receive screens already rely on, so every
/// chain icon in the app now comes from one consistent source instead of
/// mixing a custom vector for Solana with network images for the rest.
///
/// Falls back to a plain colored initial letter only if the network image
/// genuinely fails to load (offline, CDN hiccup) — never as the default.
class ChainIcon extends StatelessWidget {
  final String chain;
  final double size;
  final Color color;

  const ChainIcon({super.key, required this.chain, required this.size, required this.color});

  /// Returns the CDN icon URL for a chain. Exposed so screens that
  /// capture a screenshot (e.g. the PnL share receipt) can precache it
  /// first — a RepaintBoundary capture happens synchronously and won't
  /// wait for an in-flight network image to finish loading.
  static String? iconUrlFor(String chain) {
    final symbol = _symbolFor(chain);
    if (symbol == null) return null;
    return 'https://cdn.jsdelivr.net/npm/cryptocurrency-icons@0.18.1/128/color/$symbol.png';
  }

  static String? _symbolFor(String chain) {
    switch (chain.toLowerCase()) {
      case 'solana':
        return 'sol';
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
    final symbol = _symbolFor(chain);

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