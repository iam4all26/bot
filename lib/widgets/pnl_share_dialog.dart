import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../providers/currency_provider.dart';
import '../theme/app_theme.dart';
import 'solana_icon.dart';

class PnlShareDialog extends StatefulWidget {
  final Map<String, dynamic> tradeData;
  final bool isAdmin;

  const PnlShareDialog({super.key, required this.tradeData, required this.isAdmin});

  @override
  State<PnlShareDialog> createState() => _PnlShareDialogState();
}

class _PnlShareDialogState extends State<PnlShareDialog> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _captureAndShare() async {
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/kainuwa_receipt_${DateTime.now().millisecondsSinceEpoch}.png').create();
        await file.writeAsBytes(byteData.buffer.asUint8List());
        
        final List<String> flexMessages = [
          'Just printed a solid gain on Kainuwa! 🚀 #Solana',
          'Another win on the timeline! 🤑 Powered by @kainuwaafrica',
          'Snipe, profit, repeat. 🎯 @kainuwaafrica',
          'Secured the bag. 💰 Built different. @kainuwaafrica'
        ];
        final randomMessage = flexMessages[DateTime.now().millisecondsSinceEpoch % flexMessages.length];
        
        await Share.shareXFiles([XFile(file.path)], text: randomMessage);
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate receipt: $e'), backgroundColor: AppTheme.danger(context)));
    }
    if (mounted) {
      setState(() => _isSharing = false);
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

  String _formatAddress(String addr) => addr.length > 8 ? '${addr.substring(0, 4)}...${addr.substring(addr.length - 4)}' : addr;

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final p = widget.tradeData;
    
    final pnl = double.tryParse(p['pnl_usd']?.toString() ?? '0') ?? 0.0;
    final size = double.tryParse(p['virtual_usd_amount']?.toString() ?? '0') ?? 0.0;
    final pct = size > 0 ? (pnl / size) * 100 : 0.0;
    final isProfit = pnl >= 0;

    String mainTitle = p['display_name'] ?? 'Manual';
    if (widget.isAdmin && mainTitle != 'Manual') mainTitle = mainTitle.toUpperCase();
    final String timeInTrade = calculateTimeInTrade(p['opened_at'], p['closed_at']);
    final String tokenPair = '${_formatAddress(p['token_address'] ?? '')} / SOL';

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
                width: 600,
                height: 315,
                clipBehavior: Clip.hardEdge, // Prevents images from spilling out of the rounded corners
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isProfit ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4), width: 2),
                ),
                child: Stack(
                  children: [
                    // Diagonal Background Accent
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ReceiptBackgroundPainter(
                          accentColor: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),

                    // STRICTLY ANCHORED CHARACTER
                    // Dragged left (-40) and locked to the bottom (0). Scaled up massively.
                    Positioned(
                      left: -40,
                      bottom: 0, 
                      child: Transform.scale(
                        scale: isProfit ? 1.0 : 1.15, // Wojak is drawn smaller, so we boost him 15%
                        alignment: Alignment.bottomLeft,
                        child: Image.asset(
                          isProfit ? 'assets/icon/chad.png' : 'assets/icon/wojak.png',
                          height: 290, // Nearly full height of the card
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomLeft,
                        ),
                      ),
                    ),

                    // STRICTLY BOUNDED METRICS PANEL
                    // The 330px fixed width prevents the text from ever wrapping unexpectedly
                    Positioned(
                      right: 24,
                      top: 24,
                      bottom: 20,
                      width: 330, 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: AppTheme.kainuwaPurple.withOpacity(0.2), shape: BoxShape.circle),
                                child: const SolanaIcon(size: 16, color: AppTheme.kainuwaPurple),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('KAINUWA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.0)),
                                  Text('ON SOLANA', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              )
                            ],
                          ),
                          
                          const Spacer(),

                          Text(tokenPair, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          
                          // THE WRAP FIX: FittedBox forces the text to shrink rather than wrap to a new line
                          SizedBox(
                            height: 60,
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${isProfit ? '+' : ''}${pct.toStringAsFixed(2)}%', 
                                style: TextStyle(
                                  color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), 
                                  fontSize: 60, 
                                  fontWeight: FontWeight.w900, 
                                  height: 1.0
                                )
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 4),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIcons.clock, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text(timeInTrade, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold)),
                            ]
                          ),

                          const Spacer(),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Invested', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 2),
                                  Text('\$${size.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (currency.isNaira) Text(currency.format(size), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ]
                              ),
                              const SizedBox(width: 28),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(isProfit ? 'Current Gain' : 'Current Loss', style: TextStyle(color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text('${isProfit ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}', style: TextStyle(color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 16, fontWeight: FontWeight.bold)),
                                  if (currency.isNaira) Text('${isProfit ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦')}', style: TextStyle(color: isProfit ? const Color(0xFF10B981).withOpacity(0.7) : const Color(0xFFEF4444).withOpacity(0.7), fontSize: 11)),
                                ]
                              ),
                            ]
                          ),

                          const Spacer(),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Trade natively on', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text('@kainuwaafrica', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                child: const Icon(PhosphorIcons.qrCode, color: Colors.black, size: 26),
                              )
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.kainuwaPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isSharing ? null : _captureAndShare,
              icon: _isSharing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(PhosphorIcons.shareNetworkFill, size: 20),
              label: Text(_isSharing ? 'GENERATING...' : 'SHARE RECEIPT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
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
    final paintAccent = Paint()
      ..color = accentColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.40, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.30, size.height)
      ..close();

    canvas.drawPath(path, paintAccent);

    final paintLine = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final linePath = Path()
      ..moveTo(size.width * 0.40, 0)
      ..lineTo(size.width * 0.30, size.height);

    canvas.drawPath(linePath, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
