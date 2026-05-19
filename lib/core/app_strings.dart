class AppStrings {
  static const Map<String, Map<String, String>> translations = {
    'en': {
      'settings': 'Settings',
      'language': 'Language',
      'high_contrast': 'High Contrast Theme',
      'high_contrast_desc': 'Increase contrast and font size for better visibility.',
      'english': 'English',
      'malay': 'Bahasa Melayu',
      'chinese': '中文',
    },
    'ms': {
      'settings': 'Tetapan',
      'language': 'Bahasa',
      'high_contrast': 'Tema Kontras Tinggi',
      'high_contrast_desc': 'Tingkatkan kontras dan saiz fon untuk penglihatan yang lebih baik.',
      'english': 'English',
      'malay': 'Bahasa Melayu',
      'chinese': '中文',
    },
    'zh': {
      'settings': '设置',
      'language': '语言',
      'high_contrast': '高对比度主题',
      'high_contrast_desc': '增加对比度和字体大小以获得更好的可见性。',
      'english': 'English',
      'malay': 'Bahasa Melayu',
      'chinese': '中文',
    },
  };

  static String get(String key, String languageCode) {
    return translations[languageCode]?[key] ?? translations['en']?[key] ?? key;
  }
}
