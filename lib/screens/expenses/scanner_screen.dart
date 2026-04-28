import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _simulateScan() {
    setState(() => _isScanning = true);
    _animationController.repeat(reverse: true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isScanning = false);
        _animationController.stop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RecordExpenseScreen(scannedAmount: 125.50)),
        );
      }
    });
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
          // Simulated Camera Background
          Container(
            color: const Color(0xFF1A1A1A), // Darker grey for camera simulation
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
                      'Scan Receipt',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_off_rounded, color: Colors.white, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Simulated Camera Viewfinder
          Center(
            child: Container(
              width: size.width * 0.85,
              height: size.height * 0.55,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.neonGreenDark.withValues(alpha: _isScanning ? 0.8 : 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                boxShadow: _isScanning ? [
                  BoxShadow(
                    color: AppTheme.neonGreenDark.withValues(alpha: 0.2),
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
                                    color: AppTheme.neonGreenDark.withValues(alpha: 0.8),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (!_isScanning)
                      Center(
                        child: Icon(
                          Icons.document_scanner_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
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
                  _isScanning ? 'Analyzing Receipt...' : 'Align receipt within the frame',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _isScanning ? null : _simulateScan,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: _isScanning ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
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
                  onPressed: () {
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

