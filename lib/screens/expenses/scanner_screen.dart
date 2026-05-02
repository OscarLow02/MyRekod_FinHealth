import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/app_theme.dart';
import '../../services/ocr_service.dart';
import '../../widgets/app_dialogs.dart';
import 'record_expense_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  final ImagePicker _imagePicker = ImagePicker();
  
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    final hasPermission = await _requestCameraPermission();
    if (!hasPermission) return;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final firstCamera = cameras.first;
      _cameraController = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Permission Handling ─────────────────────────────────────────────────

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && mounted) {
      // TODO: Implement i18n
      AppDialogs.showActionModal(
        context,
        title: 'Camera Permission Required',
        body: 'Please enable camera access in your device settings to scan receipts.',
        primaryButtonText: 'Open Settings',
        onPrimaryPressed: () => openAppSettings(),
        secondaryButtonText: 'Cancel',
        icon: Icons.camera_alt_rounded,
        iconColor: Colors.orange.shade700,
        primaryButtonColor: AppTheme.primary,
      );
    }
    return false;
  }

  // ── Image Capture ───────────────────────────────────────────────────────

  Future<void> _captureFromCamera() async {
    // Prevent double-tapping the shutter button
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isScanning) return;

    setState(() => _isScanning = true);
    _animationController.repeat(reverse: true);

    try {
      // Use the CameraController to take the picture natively
      final XFile photo = await _cameraController!.takePicture();

      // Secure the image locally
      final String permanentImagePath = await OcrService.standardSecureCapturedImage(photo.path);

      // Run Offline OCR
      final Map<String, dynamic> extractedData = await OcrService.extractReceiptData(permanentImagePath);

      if (!mounted) return;

      // Navigate to the form
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecordExpenseScreen(
            scannedAmount: extractedData['amount'],
            scannedVendor: extractedData['vendor'],
            scannedDate: extractedData['date'],
            imagePath: permanentImagePath,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Capture Error: $e");
      if (mounted) {
        _animationController.stop();
        AppDialogs.showActionModal(
          context,
          title: 'Capture Failed',
          body: 'Failed to capture the receipt. Please try again.',
          primaryButtonText: 'OK',
          onPrimaryPressed: () {}, // showActionModal auto-dismisses
          icon: Icons.error_outline_rounded,
          iconColor: Colors.redAccent,
          primaryButtonColor: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
        if (!_isScanning) _animationController.stop();
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);
    _animationController.repeat(reverse: true);

    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo == null) {
        setState(() => _isScanning = false);
        _animationController.stop();
        return;
      }

      final String permanentImagePath = await OcrService.standardSecureCapturedImage(photo.path);
      final Map<String, dynamic> extractedData = await OcrService.extractReceiptData(permanentImagePath);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecordExpenseScreen(
            scannedAmount: extractedData['amount'],
            scannedVendor: extractedData['vendor'],
            scannedDate: extractedData['date'],
            imagePath: permanentImagePath,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Gallery Error: $e");
      if (mounted) {
        _animationController.stop();
        
        // Handle the specific iCloud offline error (PlatformException)
        final isICloudError = e.toString().contains('public.jpeg') || e.toString().contains('Cannot load representation');
        
        AppDialogs.showActionModal(
          context,
          title: isICloudError ? 'Image Unavailable Offline' : 'Gallery Error',
          body: isICloudError 
              ? 'This photo is stored in iCloud and requires an internet connection to download. Please select a locally saved photo or turn on WiFi.'
              : 'Failed to pick image from gallery. Please try again.',
          primaryButtonText: 'OK',
          onPrimaryPressed: () {},
          icon: isICloudError ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
          iconColor: isICloudError ? Colors.orange.shade700 : Colors.redAccent,
          primaryButtonColor: isICloudError ? Colors.orange.shade700 : Colors.redAccent,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
        if (!_isScanning) _animationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Background
          if (_isCameraInitialized && _cameraController != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              color: const Color(0xFF1A1A1A),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.neonGreenDark),
              ),
            ),
          
          // Semi-transparent overlay to darken everything except the viewfinder
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: size.width * 0.85,
                    height: size.height * 0.55,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // AppBar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      // TODO: Implement i18n
                      'Scan Receipt',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Gallery picker button
                    IconButton(
                      icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
                      onPressed: _isScanning ? null : _pickFromGallery,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Viewfinder Borders and Animation
          Center(
            child: Container(
              width: size.width * 0.85,
              height: size.height * 0.55,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.neonGreenDark.withOpacity(_isScanning ? 0.8 : 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                boxShadow: _isScanning ? [
                  BoxShadow(
                    color: AppTheme.neonGreenDark.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ] : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                child: Stack(
                  children: [
                    if (_isScanning)
                      AnimatedBuilder(
                        animation: _scanLineAnimation,
                        builder: (context, child) {
                          return Positioned(
                            top: _scanLineAnimation.value * (size.height * 0.55),
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppTheme.neonGreenLight,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.neonGreenDark.withOpacity(0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  // TODO: Implement i18n
                  _isScanning ? 'Analyzing Receipt...' : 'Align receipt within the frame',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _isScanning ? null : _captureFromCamera,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isScanning ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isScanning ? AppTheme.neonGreenDark : Colors.white,
                        ),
                        child: _isScanning ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ) : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: _isScanning ? null : () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RecordExpenseScreen()),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                    ),
                  ),
                  child: Text(
                    // TODO: Implement i18n
                    'Enter Manually',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.neonGreenDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
