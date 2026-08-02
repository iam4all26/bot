import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
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
  
  // Independent flags so only the active button spins
  bool _isSaving = false;
  bool _isSharing = false;

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
        
        final List<String> flexMessages = [
          'Just printed a solid gain on Kainuwa! 🚀 #Solana',
          'Another win on the timeline! 🤑 Powered by @kainuwaafrica',
          'Snipe, profit, repeat. 🎯 @kainuwaafrica',
          'Secured the bag. 💰 Built different. @kainuwaafrica'
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
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Saved to Gallery successfully! 📸'), backgroundColor: AppTheme.success(context)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppTheme.danger(context)));
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

    String mainTitle = p['display_name'] ?? 'Manual';
    if (widget.isAdmin && mainTitle != 'Manual') mainTitle = mainTitle.toUpperCase();
    final String timeInTrade = calculateTimeInTrade(p['opened_at'], p['closed_at']);
    final String tokenPair = '${_formatAddress(p['token_address'] ?? '')} / SOL';
    
    final String entryMcap = _formatMcap(p['entry_mcap']);
    final String exitMcap = _formatMcap(p['close_mcap'] ?? p['current_mcap']);

    // EXPANDED CANVAS HEIGHT: 360px guarantees the entire footer and QR code fit without bottom clipping
    const double canvasWidth = 600;
    const double canvasHeight = 360;

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
                width: canvasWidth,
                height: canvasHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0B18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isProfit ? const Color(0xFF10B981).withOpacity(0.4) : const Color(0xFFEF4444).withOpacity(0.4), width: 2),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ReceiptBackgroundPainter(
                          accentColor: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),

                    // Character Graphic anchored cleanly to bottom left
                    Positioned(
                      left: -15,
                      bottom: 0,
                      child: Image.asset(
                        isProfit ? 'assets/icon/chad.png' : 'assets/icon/wojak.png',
                        height: 340,
                        fit: BoxFit.fitHeight,
                        alignment: Alignment.bottomLeft,
                      ),
                    ),

                    // Metrics Panel with ample vertical space
                    Positioned(
                      left: 230, 
                      right: 28,
                      top: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: AppTheme.kainuwaPurple.withOpacity(0.2), shape: BoxShape.circle),
                                child: const SolanaIcon(size: 18, color: AppTheme.kainuwaPurple),
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('KAINUWA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.0)),
                                  Text('ON SOLANA', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ],
                              )
                            ],
                          ),
                          
                          const Spacer(),

                          Text(tokenPair, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${isProfit ? '+' : ''}${pct.toStringAsFixed(2)}%', 
                              style: TextStyle(
                                color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), 
                                fontSize: 60, 
                                fontWeight: FontWeight.w900, 
                                height: 1.1
                              )
                            ),
                          ),
                          
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(PhosphorIcons.clock, color: Colors.white54, size: 14),
                              const SizedBox(width: 6),
                              Text(timeInTrade, style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.bold)),
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
                                  const Text('Entry MCAP', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(entryMcap, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text('Invested', style: TextStyle(color: Colors.white54, fontSize: 13)),
                                  Text('\$${size.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                  if (currency.isNaira) Text(currency.format(size), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ]
                              ),
                              const SizedBox(width: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Exit MCAP', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(exitMcap, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  Text(isProfit ? 'Current Gain' : 'Current Loss', style: TextStyle(color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text('${isProfit ? '+' : ''}\$${pnl.abs().toStringAsFixed(2)}', style: TextStyle(color: isProfit ? const Color(0xFF10B981) : const Color(0xFFEF4444), fontSize: 17, fontWeight: FontWeight.bold)),
                                  if (currency.isNaira) Text('${isProfit ? '+' : ''}${currency.format(pnl).replaceFirst('₦-', '-₦')}', style: TextStyle(color: isProfit ? const Color(0xFF10B981).withOpacity(0.7) : const Color(0xFFEF4444).withOpacity(0.7), fontSize: 11)),
                                ]
                              ),
                            ]
                          ),

                          const Spacer(),

                          // Footer with full QR code visibility
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
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                                child: Image.asset(
                                  'assets/icon/qr_code.png',
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stk) => const Icon(PhosphorIcons.qrCode, color: Colors.black, size: 48),
                                ),
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
          
          const SizedBox(height: 24),
          
          // Action Buttons with Isolated Loading Indicators
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
                  label: Text(_isSaving ? 'SAVING...' : 'SAVE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
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
                  label: Text(_isSharing ? 'SHARING...' : 'SHARE', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
      ..lineTo(size.width * 0.25, size.height)
      ..close();

    canvas.drawPath(path, paintAccent);

    final paintLine = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final linePath = Path()
      ..moveTo(size.width * 0.40, 0)
      ..lineTo(size.width * 0.25, size.height);

    canvas.drawPath(linePath, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
