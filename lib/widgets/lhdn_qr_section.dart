import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../core/app_theme.dart';
import 'app_dialogs.dart';

/// A reusable QR section for LHDN e-Invoice validation.
/// Includes buttons to open portal, share link, and save QR to photos.
class LhdnQrSection extends StatefulWidget {
  final String lhdnValidationUrl;
  final String invoiceNumber;

  const LhdnQrSection({
    super.key,
    required this.lhdnValidationUrl,
    required this.invoiceNumber,
  });

  @override
  State<LhdnQrSection> createState() => _LhdnQrSectionState();
}

class _LhdnQrSectionState extends State<LhdnQrSection> {
  bool _isSavingQr = false;

  Future<void> _launchUrl() async {
    // CRITICAL FIX: forced try-catch block to bypass Android 11+ intent restrictions
    try {
      await launchUrl(
        Uri.parse(widget.lhdnValidationUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open portal: $e')),
        );
      }
    }
  }

  void _shareValidationUrl() {
    SharePlus.instance.share(
      ShareParams(
        text: 'Here is your official e-Invoice receipt: ${widget.lhdnValidationUrl}',
        subject: 'e-Invoice ${widget.invoiceNumber}',
      ),
    );
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSavingQr = true);
    try {
      // 1. Check/Request Permission
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw 'Gallery access denied. Please enable it in settings.';
        }
      }

      // 2. Render QR to Image
      final qrPainter = QrPainter(
        data: widget.lhdnValidationUrl,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: true,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      const size = 512.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw white background
      final paint = Paint()..color = Colors.white;
      canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);
      
      // Draw QR code with padding
      const padding = 40.0;
      const qrSize = size - (padding * 2);
      canvas.save();
      canvas.translate(padding, padding);
      qrPainter.paint(canvas, const Size(qrSize, qrSize));
      canvas.restore();

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw 'Could not generate image data';
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 3. Save to Temp File and then to Gallery
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/QR_${widget.invoiceNumber}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path);

      if (!mounted) return;
      AppDialogs.showSystemAlert(
        context,
        title: 'Saved',
        body: 'QR Code saved to your photos.',
        icon: Icons.check_circle_rounded,
        iconColor: AppTheme.neonGreenDark,
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showSystemAlert(
        context,
        title: 'Save Failed',
        body: e.toString(),
        icon: Icons.error_outline_rounded,
        iconColor: Colors.redAccent,
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingQr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: QrImageView(
              data: widget.lhdnValidationUrl,
              version: QrVersions.auto,
              size: 160.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Scan to verify e-Invoice',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _launchUrl,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                  label: const Text('Open Portal'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareValidationUrl,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Link'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isSavingQr ? null : _saveQrToGallery,
              icon: _isSavingQr
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.download_for_offline_rounded, size: 18),
              label: Text(_isSavingQr ? 'Saving...' : 'Save QR to Photos'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
