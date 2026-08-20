
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
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../providers/currency_provider.dart';
import '../theme/app_theme.dart';
import 'chain_icon.dart';

class PnlShareDialog extends StatefulWidget {
  final Map<String, dynamic> tradeData;
  final bool isAdmin;

  const PnlShareDialog({super.key, required this.tradeData, required this.isAdmin});

  @override
  State<PnlShareDialog> createState() => _PnlShareDialogState();
}

class _PnlShareDialogState extends State<PnlShareDialog> {
  final GlobalKey _globalKey = GlobalKey();
  
  bool _isSaving = false;
  bool _isSharing = false;
  bool _showAmounts = true;
  
  bool _isLoadingUsername = true;
  String _username = '';

  @override
  void initState() {
    super.initState();
    final chain = (widget.tradeData['chain'] ?? 'solana').toString();
    final iconUrl = ChainIcon.iconUrlFor(chain);
    if (iconUrl != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) precacheImage(NetworkImage(iconUrl), context);
      });
    }
    _fetchUsername();
  }

  Future<void> _fetchUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('cached_kainuwa_username');
      
      if (cachedName != null && cachedName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _username = cachedName;
            _isLoadingUsername = false;
          });
        }
      }

      final res = await context.read<ApiService>().getEndpoint('positions.php?action=fetch');
      if (res['status'] == 'success' && mounted) {
        final fetchedName = res['stats']?['username'] ?? '';
        if (fetchedName.isNotEmpty) {
          await prefs.setString('cached_kainuwa_username', fetchedName);
          setState(() {
            _username = fetchedName;
            _isLoadingUsername = false;
          });
        } else if (cachedName == null) {
          if (mounted) setState(() => _isLoadingUsername = false);
        }
      } else if (cachedName == null) {
        if (mounted) setState(() => _isLoadingUsername = false);
      }
    } catch (_) {
      if (mounted && _isLoadingUsername) setState(() => _isLoadingUsername = false);
    }
  }

  Map<String, dynamic> _getTierInfo(double pct) {
    if (pct >= 0) {
      if (pct < 10) return {'img': 'win1.png', 'title': 'HAPPY HAMMY', 'sub': 'A small win is still a win!', 'color': const Color(0xFF10B981)};
      if (pct < 50) return {'img': 'win2.png', 'title': 'PLAYFUL KITTY', 'sub': 'Nice moves!\nKeep it up!', 'color': const Color(0xFF10B981)};
      if (pct < 100) return {'img': 'win3.png', 'title': 'CHEERFUL CORGI', 'sub': 'Double happy!\nYou\'re doing great!', 'color': const Color(0xFF10B981)};
      if (pct < 300) return {'img': 'win4.png', 'title': 'COOL SHIBA', 'sub': 'Now we\'re talking!\nKeep crushing it!', 'color': const Color(0xFF10B981)};
      if (pct < 500) return {'img': 'win5.png', 'title': 'MIGHTY PENGUIN', 'sub': 'Powerful gains!\nYou\'re unstoppable!', 'color': const Color(0xFF10B981)};
      if (pct < 1000) return {'img': 'win6.png', 'title': 'TURBO TURTLE', 'sub': 'Slow and steady?\nYou\'re way ahead!', 'color': const Color(0xFF10B981)};
      if (pct < 2500) return {'img': 'win7.png', 'title': 'ROCKET PUP', 'sub': 'To the moon!\nUnbelievable wins!', 'color': const Color(0xFF10B981)};
      if (pct < 5000) return {'img': 'win8.png', 'title': 'DRAGON WINNER', 'sub': 'Legendary gains!\nYou\'re on fire!', 'color': const Color(0xFF10B981)};
      if (pct < 10000) return {'img': 'win9.png', 'title': 'KING TIGER', 'sub': 'You\'re a trading KING!\nRespect!', 'color': const Color(0xFF10B981)};
      return {'img': 'win10.png', 'title': 'KAINUWA LEGEND', 'sub': 'You didn\'t just win...\nYou made history!', 'color': const Color(0xFF10B981)};
    } else {
      if (pct >= -10) return {'img': 'loss1.png', 'title': 'SAD PUPPY', 'sub': 'It\'s okay, even puppies\nhave off days.', 'color': const Color(0xFFEF4444)};
      if (pct >= -20) return {'img': 'loss2.png', 'title': 'WORRIED KITTY', 'sub': 'A little setback.\nLearn and adjust.', 'color': const Color(0xFFEF4444)};
      if (pct >= -30) return {'img': 'loss3.png', 'title': 'DOWN BUNNY', 'sub': 'That hurt a bit.\nBreathe and reset.', 'color': const Color(0xFFEF4444)};
      if (pct >= -40) return {'img': 'loss4.png', 'title': 'TIRED PANDA', 'sub': 'Tough one. Stay calm,\nstay smart.', 'color': const Color(0xFFEF4444)};
      if (pct >= -50) return {'img': 'loss5.png', 'title': 'BEAR IN PAIN', 'sub': 'Deep loss.\nDon\'t give up now.', 'color': const Color(0xFFEF4444)};
      if (pct >= -60) return {'img': 'loss6.png', 'title': 'EXHAUSTED OWL', 'sub': 'Almost drained.\nProtect what\'s left.', 'color': const Color(0xFFEF4444)};
      if (pct >= -70) return {'img': 'loss7.png', 'title': 'HURTING HEDGEHOG', 'sub': 'So close to the bottom.\nHold on tight.', 'color': const Color(0xFFEF4444)};
      if (pct >= -80) return {'img': 'loss8.png', 'title': 'FROZEN PENGUIN', 'sub': 'It\'s freezing. But\nwinter doesn\'t last.', 'color': const Color(0xFFEF4444)};
      if (pct >= -90) return {'img': 'loss9.png', 'title': 'DEVASTATED SQUIRREL', 'sub': 'Almost gone.\nPlan your comeback.', 'color': const Color(0xFFEF4444)};
      return {'img': 'loss10.png', 'title': 'GAME OVER', 'sub': 'Total loss. Reset.\nRefocus. Rise again.', 'color': const Color(0xFFEF4444)};
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
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/kainuwa_receipt_${DateTime.now().millisecondsSinceEpoch}.png').create();
        await file.writeAsBytes(bytes);
        
        final chainTag = {'solana': '#Solana', 'bsc': '#BSC', 'robinhood': '#RobinhoodChain'}[(widget.tradeData['chain'] ?? 'solana').toString()] ?? '#Crypto';
        final List<String> flexMessages = [
          'Just printed a solid gain on Kainuwa! 🚀 $chainTag',
          'Another win on the timeline! 💰 Powered by @kainuwaafrica',
          'Snipe, profit, repeat. 🎯 @kainuwaafrica',
          'Secured the bag. 💼 Built different. @kainuwaafrica'
        ];
        final randomMessage = flexMessages[DateTime.now().millisecondsSinceEpoch % flexMessages.length];
        
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
    } catch (_) { return '-'; }
  }

  String _formatMcap(dynamic v) {
    if (v == null) return '-';
    double val = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
    if (val >= 1000000000) return '\$${(val / 1000000000).toStringAsFixed(2)}B';
    if (val >= 1000000) return '\$${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '\$${(val / 1000).toStringAsFixed(1)}K';
    return '\$${val.round()}';
  }

  String _formatAddress(String addr) => addr.length > 8 ? '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}' : addr;

  String _formatTokenDisplay(dynamic symbol, dynamic address) {
    final s = symbol?.toString().trim();
    if (s != null && s.isNotEmpty && !['UNKNOWN', 'MANUAL', 'N/A'].contains(s.toUpperCase())) {
      return s.startsWith('\$') ? s : '\$$s';
    }
    return _formatAddress(address?.toString() ?? '');
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.spaceGrotesk(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.tradeData;
    
    final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
    final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
    final pct = size > 0 ? (pnl / size) * 100 : 0.0;
    final isProfit = pnl >= 0;

    final String tradeChain = (p['chain'] ?? 'solana').toString();
    final String chainDisplayName = {'solana': 'SOLANA', 'bsc': 'BSC', 'robinhood': 'ROBINHOOD'}[tradeChain] ?? tradeChain.toUpperCase();

    final String timeInTrade = calculateTimeInTrade(p['opened_at'], p['closed_at']);
    final String tokenDisplay = _formatTokenDisplay(p['symbol'], p['token_address']);
    final String entryMcap = _formatMcap(p['entry_mcap']);
    final String exitMcap = _formatMcap(p['close_mcap'] ?? p['current_mcap']);
    
    final String displayUser = _isLoadingUsername 
        ? '...' 
        : (_username.isNotEmpty ? '@$_username' : '@kainuwaafrica');

    final tier = _getTierInfo(pct);
    const double canvasSize = 480;

    final isBusy = _isSaving || _isSharing || _isLoadingUsername;

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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: tier['color'].withOpacity(0.4), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      // 1. Premium Brand Background Layer
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ReceiptBackgroundPainter(accentColor: tier['color']),
                        ),
                      ),

                      // 2. Top Bar (Chain + KAINUWA / Username)
                      Positioned(
                        top: 24, left: 24, right: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: AppTheme.kainuwaPurple.withOpacity(0.2), shape: BoxShape.circle),
                                  child: ChainIcon(chain: tradeChain, size: 18, color: AppTheme.kainuwaPurple),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('KAINUWA', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.0)),
                                    Text('ON $chainDisplayName', style: GoogleFonts.spaceGrotesk(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                  ],
                                )
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(PhosphorIcons.userCircleFill, color: Colors.white70, size: 14),
                                  const SizedBox(width: 6),
                                  Text(displayUser, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),

                      // 3. Grounding Shadow for Mascot
                      Positioned(
                        left: 15, bottom: 145,
                        child: Container(
                          width: 200, height: 20,
                          decoration: BoxDecoration(
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 25, spreadRadius: 10)],
                            borderRadius: BorderRadius.circular(100)
                          ),
                        ),
                      ),

                      // 4. Mascot Image
                      Positioned(
                        left: -5, bottom: 135,
                        child: Image.asset(
                          'assets/images/${tier['img']}',
                          width: 230,
                          height: 230,
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, err, stk) => const SizedBox(), 
                        ),
                      ),

                      // 5. Right Percentage, X Multiplier & Badge Info
                      Positioned(
                        right: 24, top: 110,
                        width: 220,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(tokenDisplay, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${isProfit ? '+' : ''}${pct.toStringAsFixed(2)}%', 
                                style: GoogleFonts.spaceGrotesk(color: tier['color'], fontSize: 54, fontWeight: FontWeight.w900, height: 1.1)
                              ),
                            ),
                            if (isProfit && pct > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                child: Text(
                                  '${((pct / 100) + 1).toStringAsFixed(2)}X', 
                                  style: GoogleFonts.spaceGrotesk(color: tier['color'], fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2)
                                ),
                              ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: tier['color'].withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: tier['color'].withOpacity(0.3))),
                              child: Text(tier['title'], style: GoogleFonts.spaceGrotesk(color: tier['color'], fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            ),
                            const SizedBox(height: 10),
                            Text(tier['sub'], textAlign: TextAlign.right, style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),

                      // 6. Stats Row 
                      Positioned(
                        bottom: 70, left: 24, right: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatColumn('Entry MCAP', entryMcap, Colors.white),
                              _buildStatColumn('Exit MCAP', exitMcap, Colors.white),
                              if (_showAmounts) _buildStatColumn('Invested', '\$${size.toStringAsFixed(2)}', Colors.white),
                              if (_showAmounts) _buildStatColumn(isProfit ? 'Profit' : 'Loss', '${isProfit ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}', tier['color']),
                              _buildStatColumn('Duration', timeInTrade, Colors.white70),
                            ],
                          ),
                        ),
                      ),

                      // 7. Footer: QR Code & Brand Tagline 
                      Positioned(
                        bottom: 20, left: 24, right: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isProfit ? 'BUILT DIFFERENT. TRADE SMARTER. WIN BIGGER.' : 'LOSSES ARE TEMPORARY. GROWTH IS FOREVER.', 
                              style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                            ),
                            Row(
                              children: [
                                Text('@kainuwaafrica', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Container(
                                  width: 32, height: 32,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.white, 
                                    borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.asset(
                                      'assets/icon/qr_code.png', 
                                      fit: BoxFit.cover, 
                                      errorBuilder: (c,e,s) => const Icon(PhosphorIcons.qrCode, color: Colors.black, size: 24)
                                    ),
                                  ),
                                )
                              ]
                            )
                          ]
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Toggle Controls
          Theme(
            data: Theme.of(context).copyWith(unselectedWidgetColor: Colors.white54),
            child: CheckboxListTile(
              title: Text('Include Invested & PnL Amounts', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              value: _showAmounts,
              onChanged: (val) {
                if (val != null) setState(() => _showAmounts = val);
              },
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppTheme.kainuwaPurple,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          
          const SizedBox(height: 8),

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

class _ReceiptBackgroundPainter extends CustomPainter {
  final Color accentColor;
  _ReceiptBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero, 
        Offset(0, size.height), 
        [const Color(0xFF130E24), const Color(0xFF08060E)]
      );
    canvas.drawRect(rect, bgPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (double i = 0; i <= size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i <= size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    final auraPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.25, size.height * 0.55), 
        size.width * 0.45,
        [accentColor.withOpacity(0.35), accentColor.withOpacity(0.0)],
      );
    canvas.drawRect(rect, auraPaint);

    final slashPath = Path()
      ..moveTo(size.width * 0.65, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.35)
      ..close();
    canvas.drawPath(slashPath, Paint()..color = accentColor.withOpacity(0.06));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}