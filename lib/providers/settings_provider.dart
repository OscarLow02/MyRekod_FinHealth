import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  static const String _highContrastKey = 'app_high_contrast';

  String _currentLanguage = 'en'; // 'en', 'ms', 'zh'
  bool _isHighContrast = false;

  String get currentLanguage => _currentLanguage;
  bool get isHighContrast => _isHighContrast;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguage = prefs.getString(_languageKey) ?? 'en';
      _isHighContrast = prefs.getBool(_highContrastKey) ?? false;
      notifyListeners();
    } catch (e) {
      // Handle SharedPreferences error gracefully
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    _currentLanguage = languageCode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
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
