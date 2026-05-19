import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _highContrastKey = 'app_high_contrast';

  bool _isHighContrast = false;

  bool get isHighContrast => _isHighContrast;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isHighContrast = prefs.getBool(_highContrastKey) ?? false;
      notifyListeners();
    } catch (e) {
      // Handle SharedPreferences error gracefully
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setHighContrast(bool isHighContrast) async {
    if (_isHighContrast == isHighContrast) return;
    _isHighContrast = isHighContrast;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_highContrastKey, isHighContrast);
    } catch (e) {
      debugPrint('Error saving high contrast: $e');
    }
  }
}
