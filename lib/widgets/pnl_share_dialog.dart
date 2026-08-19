import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../providers/currency_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'chain_icon.dart';

class PnlShareDialog extends StatefulWidget {
  final Map<String, dynamic> tradeData;
  final bool isAdmin;
  /// Optional override. If omitted, the dialog fetches the current user's
  /// username itself (same call dashboard_screen.dart already uses).
  final String? username;

  const PnlShareDialog({
    super.key,
    required this.tradeData,
    required this.isAdmin,
    this.username,
  });

  @override
  State<PnlShareDialog> createState() => _PnlShareDialogState();
}

class _PnlShareDialogState extends State<PnlShareDialog> {
  final GlobalKey _globalKey = GlobalKey();

  bool _isSaving = false;
  bool _isSharing = false;
  bool _showAmounts = true;
  String? _fetchedUsername;

  String get _displayUsername => widget.username ?? _fetchedUsername ?? 'Trader';

  // ── Tier metadata — matches assets/images/win1..10.png & loss1..10.png ──
  static const List<Map<String, String>> _winTiers = [
    {'name': 'HAPPY HAMMY', 'tag': 'A small win is still a win!'},
    {'name': 'PLAYFUL KITTY', 'tag': 'Nice moves! Keep it up!'},
    {'name': 'CHEERFUL CORGI', 'tag': "Double happy! You're doing great!"},
    {'name': 'COOL SHIBA', 'tag': "Now we're talking! Keep crushing it!"},
    {'name': 'MIGHTY PENGUIN', 'tag': "Powerful gains! You're unstoppable!"},
    {'name': 'TURBO TURTLE', 'tag': "Slow and steady? You're way ahead!"},
    {'name': 'ROCKET PUP', 'tag': 'To the moon! Unbelievable wins!'},
    {'name': 'DRAGON WINNER', 'tag': "Legendary gains! You're on fire!"},
    {'name': 'KING TIGER', 'tag': "You're a trading KING! Respect!"},
    {'name': 'KAINUWA LEGEND', 'tag': "You didn't just win... You made history!"},
  ];

  static const List<Map<String, String>> _lossTiers = [
    {'name': 'SAD PUPPY', 'tag': "It's okay, even champions have off days."},
    {'name': 'WORRIED KITTY', 'tag': 'A little setback. Learn and adjust.'},
    {'name': 'DOWN BUNNY', 'tag': 'That hurt a bit. Breathe and reset.'},
    {'name': 'TIRED PANDA', 'tag': 'Tough one. Stay calm, stay smart.'},
    {'name': 'BEAR IN PAIN', 'tag': "Deep loss. Don't give up now."},
    {'name': 'EXHAUSTED OWL', 'tag': "Almost drained. Protect what's left."},
    {'name': 'HURTING HEDGEHOG', 'tag': 'So close to the bottom. Hold on tight.'},
    {'name': 'FROZEN PENGUIN', 'tag': "It's freezing. But winter doesn't last."},
    {'name': 'DEVASTATED SQUIRREL', 'tag': 'Almost gone. Plan your comeback.'},
    {'name': 'GAME OVER', 'tag': 'Total loss. Reset. Refocus. Rise again.'},
  ];

  static const List<String> _winFlex = [
    'Just printed a solid gain on Kainuwa! 🚀',
    'Another win on the timeline! 🤑 Powered by @kainuwaafrica',
    'Snipe, profit, repeat. 🎯 @kainuwaafrica',
    'Secured the bag. 💰 Built different. @kainuwaafrica',
  ];

  static const List<String> _lossFlex = [
    'Took an L today. Comeback loading. 📈 @kainuwaafrica',
    'Every trader eats a loss sometimes. Reset and go again. @kainuwaafrica',
    'Down but not out. 🔁 @kainuwaafrica',
    'Losses are tuition. Lesson logged. @kainuwaafrica',
  ];

  int _tierIndex(double absPct, bool isProfit) {
    if (isProfit) {
      if (absPct < 10) return 1;
      if (absPct < 50) return 2;
      if (absPct < 100) return 3;
      if (absPct < 300) return 4;
      if (absPct < 500) return 5;
      if (absPct < 1000) return 6;
      if (absPct < 2500) return 7;
      if (absPct < 5000) return 8;
      if (absPct < 10000) return 9;
      return 10;
    } else {
      if (absPct <= 10) return 1;
      if (absPct <= 20) return 2;
      if (absPct <= 30) return 3;
      if (absPct <= 40) return 4;
      if (absPct <= 50) return 5;
      if (absPct <= 60) return 6;
      if (absPct <= 70) return 7;
      if (absPct <= 80) return 8;
      if (absPct <= 90) return 9;
      return 10;
    }
  }

  String _tierAsset(bool isProfit, int tier) =>
      'assets/images/${isProfit ? 'win' : 'loss'}$tier.png';

  @override
  void initState() {
    super.initState();

    final chain = (widget.tradeData['chain'] ?? 'solana').toString();
    final iconUrl = ChainIcon.iconUrlFor(chain);

    if (widget.username == null) _fetchUsername();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (iconUrl != null) precacheImage(NetworkImage(iconUrl), context);

      final pnl = double.tryParse(widget.tradeData['pnl_usd']?.toString() ?? '0') ?? 0.0;
      final size = double.tryParse(widget.tradeData['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
      final pct = size > 0 ? (pnl / size) * 100 : 0.0;
      final isProfit = pnl >= 0;
      final tier = _tierIndex(pct.abs(), isProfit);
      precacheImage(AssetImage(_tierAsset(isProfit, tier)), context);
    });
  }

  Future<void> _fetchUsername() async {
    try {
      final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch');
      if (mounted && res['status'] == 'success') {
        final uname = res['stats']?['username']?.toString();
        if (uname != null && uname.isNotEmpty && uname != 'null') {
          setState(() => _fetchedUsername = uname);
        }
      }
    } catch (_) {
      // Silent fail — card just shows the 'Trader' fallback.
    }
  }

  Future<Uint8List?> _getReceiptBytes() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _captureAndShare() async {
    setState(() => _isSharing = true);
    final bytes = await _getReceiptBytes();

    if (bytes != null) {
      try {
        final pnl = double.tryParse(widget.tradeData['pnl_usd']?.toString() ?? '0') ?? 0.0;
        final isProfit = pnl >= 0;

        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/kainuwa_receipt_${DateTime.now().millisecondsSinceEpoch}.png').create();
        await file.writeAsBytes(bytes);

        final chainTag = {'solana': '#Solana', 'bsc': '#BSC', 'robinhood': '#RobinhoodChain'}[(widget.tradeData['chain'] ?? 'solana').toString()] ?? '#Crypto';
        final pool = isProfit ? _winFlex : _lossFlex;
        final randomMessage = '${pool[Random().nextInt(pool.length)]} $chainTag';

        await Share.shareXFiles([XFile(file.path)], text: randomMessage);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e'), backgroundColor: AppTheme.danger(context)));
      }
    }
    if (mounted) {
      setState(() => _isSharing = false);
      Navigator.pop(context);
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isSaving = true);

    try {
      final bytes = await _getReceiptBytes();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/kainuwa_saved_receipt_${DateTime.now().millisecondsSinceEpoch}.png').create();
        await file.writeAsBytes(bytes);

        await Gal.putImage(file.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to Gallery successfully! 📸', style: GoogleFonts.spaceGrotesk()), backgroundColor: AppTheme.success(context)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e', style: GoogleFonts.spaceGrotesk()), backgroundColor: AppTheme.danger(context)));
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  String calculateTimeInTrade(String? openedAtStr, [String? closedAtStr]) {
    if (openedAtStr == null || openedAtStr.isEmpty) return '-';
    try {
      String startStr = openedAtStr.replaceAll(' ', 'T');
      if (!startStr.endsWith('Z')) startStr += 'Z';
      final start = DateTime.parse(startStr);
      DateTime end = closedAtStr != null && closedAtStr.isNotEmpty
          ? DateTime.parse(closedAtStr.replaceAll(' ', 'T') + (closedAtStr.endsWith('Z') ? '' : 'Z'))
          : DateTime.now().toUtc();

      final diff = end.difference(start);
      if (diff.inMinutes < 1) return '< 1m';

      List<String> parts = [];
      if (diff.inDays > 0) parts.add('${diff.inDays}d');
      if (diff.inHours % 24 > 0) parts.add('${diff.inHours % 24}h');
      if (diff.inMinutes % 60 > 0) parts.add('${diff.inMinutes % 60}m');
      return parts.join(' ');
    } catch (_) {
      return '-';
    }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(2)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatAddress(String addr) => addr.length > 8 ? '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}' : addr;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final p = widget.tradeData;

    final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
    final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
    final pct = size > 0 ? (pnl / size) * 100 : 0.0;
    final isProfit = pnl >= 0;
    final Color accent = isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final int tier = _tierIndex(pct.abs(), isProfit);
    final Map<String, String> tierInfo = (isProfit ? _winTiers : _lossTiers)[tier - 1];
    final String tierAsset = _tierAsset(isProfit, tier);

    final String tradeChain = (p['chain'] ?? 'solana').toString();
    const Map<String, String> chainNativeSymbols = {'solana': 'SOL', 'bsc': 'BNB', 'robinhood': 'ETH'};
    final String nativeSymbol = chainNativeSymbols[tradeChain] ?? 'SOL';
    final String chainDisplayName = {'solana': 'SOLANA', 'bsc': 'BSC', 'robinhood': 'ROBINHOOD'}[tradeChain] ?? tradeChain.toUpperCase();

    final String timeInTrade = calculateTimeInTrade(p['opened_at'], p['closed_at']);
    final String tokenPair = '${_formatAddress(p['token_address'] ?? '')} / $nativeSymbol';

    final String entryMcap = _formatMcap(p['entry_mcap']);
    final String exitMcap = _formatMcap(p['close_mcap'] ?? p['current_mcap']);

    const double canvasSize = 680;
    final isBusy = _isSaving || _isSharing;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: RepaintBoundary(
              key: _globalKey,
              child: Container(
                width: canvasSize,
                height: canvasSize,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B18),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: accent.withOpacity(0.4), width: 2),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _SquareGlowPainter(accentColor: accent)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stk) => Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(color: AppTheme.kainuwaPurple, borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(PhosphorIcons.lightningFill, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('KAINUWA', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.0)),
                                Text('TRADING BOT', style: GoogleFonts.spaceGrotesk(color: AppTheme.kainuwaGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.kainuwaPurple.withOpacity(0.5)),
                                color: AppTheme.kainuwaPurple.withOpacity(0.12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ChainIcon(chain: tradeChain, size: 13, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text('ON $chainDisplayName', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ── Username chip ──
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIcons.userFill, color: Colors.white54, size: 12),
                              const SizedBox(width: 5),
                              Text('@$_displayUsername', style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                        // ── Center hero: % / mascot / tier name / tagline ──
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${isProfit ? '+' : ''}${pct.toStringAsFixed(2)}%',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  color: accent,
                                  fontSize: 58,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  shadows: [Shadow(color: accent.withOpacity(0.55), blurRadius: 30)],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Image.asset(
                                tierAsset,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (ctx, err, stk) => Icon(
                                  isProfit ? PhosphorIcons.smileyFill : PhosphorIcons.smileySadFill,
                                  color: accent, size: 140,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(color: accent.withOpacity(0.18), borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withOpacity(0.4))),
                                child: Text(tierInfo['name']!, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1)),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  tierInfo['tag']!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Token / time row ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(tokenPair, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(PhosphorIcons.clock, color: Colors.white54, size: 13),
                                const SizedBox(width: 5),
                                Text(timeInTrade, style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ENTRY MCAP', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(entryMcap, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EXIT MCAP', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 3),
                                  Text(exitMcap, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (_showAmounts) ...[
                          const SizedBox(height: 12),
                          Container(height: 1, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('INVESTED', style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 3),
                                    Text('\$${size.toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                                    if (currency.isNaira) Text(currency.format(size), style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isProfit ? 'REALIZED PROFIT' : 'REALIZED LOSS', style: GoogleFonts.spaceGrotesk(color: accent.withOpacity(0.8), fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 3),
                                    Text('${isProfit ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}', style: GoogleFonts.spaceGrotesk(color: accent, fontSize: 15, fontWeight: FontWeight.bold)),
                                    if (currency.isNaira) Text('${isProfit ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦')}', style: GoogleFonts.spaceGrotesk(color: accent.withOpacity(0.7), fontSize: 10)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),
                        Container(height: 1, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Trade natively on', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10)),
                                Text('@kainuwaafrica', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                              child: Image.asset(
                                'assets/icon/qr_code.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stk) => const Icon(PhosphorIcons.qrCode, color: Colors.black, size: 40),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Toggle: include invested + realized amounts ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(_showAmounts ? PhosphorIcons.eyeFill : PhosphorIcons.eyeSlashFill, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Show invested amount & realized P&L',
                    style: GoogleFonts.spaceGrotesk(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _showAmounts,
                  activeColor: AppTheme.kainuwaPurple,
                  onChanged: (v) => setState(() => _showAmounts = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isBusy ? null : _saveToGallery,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(PhosphorIcons.downloadSimpleBold, size: 20),
                  label: Text(_isSaving ? 'SAVING...' : 'SAVE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kainuwaPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isBusy ? null : _captureAndShare,
                  icon: _isSharing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(PhosphorIcons.shareNetworkFill, size: 20),
                  label: Text(_isSharing ? 'SHARING...' : 'SHARE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }
}

class _SquareGlowPainter extends CustomPainter {
  final Color accentColor;
  _SquareGlowPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [accentColor.withOpacity(0.16), accentColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.42), radius: size.width * 0.55));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), glowPaint);

    final cornerPaint = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFF7351FF).withOpacity(0.10), const Color(0xFF7351FF).withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.05, size.height * 0.05), radius: size.width * 0.4));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
