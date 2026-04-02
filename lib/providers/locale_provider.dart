import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('tr');
  Locale get locale => _locale;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Map<String, String> _localizedStrings = {};

  LocaleProvider() {
    debugPrint('➡️ LocaleProvider constructor called');
    _loadSavedLocale();
  }

  void _loadSavedLocale() {
    debugPrint('➡️ LocaleProvider._loadSavedLocale called');
    String? lang = Hive.box('settings').get('language');
    if (lang != null) {
      _locale = Locale(lang);
      debugPrint('➡️ LocaleProvider: Found saved language: $lang');
    } else {
      debugPrint('➡️ LocaleProvider: No saved language, defaulting to tr');
    }
    _loadLanguageData();
  }

  Future<void> _loadLanguageData() async {
    debugPrint('➡️ LocaleProvider._loadLanguageData called for ${_locale.languageCode}');
    try {
      String jsonString = await rootBundle.loadString('assets/langs/${_locale.languageCode}.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
      _isLoading = false; 
      debugPrint('➡️ LocaleProvider: Language data loaded successfully. Keys count: ${_localizedStrings.length}');
      
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint("⚠️ Dil dosyası yüklenemedi: $e");
      _isLoading = false; 
      Future.microtask(() => notifyListeners());
    }
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    Hive.box('settings').put('language', locale.languageCode);
    _loadLanguageData();
  }

  String translate(String key) {
    if (_localizedStrings.isEmpty) {
      return key; // Henüz yüklenmediyse key'in kendisini döndür
    }
    return _localizedStrings[key] ?? key;
  }

  // Statik kullanım için (Bildirimler vb. BuildContext olmayan yerler için)
  static Future<String> getTranslated(String key) async {
    String lang = Hive.box('settings').get('language') ?? 'tr';
    try {
      String jsonString = await rootBundle.loadString('assets/langs/$lang.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      return jsonMap[key]?.toString() ?? key;
    } catch (e) {
      return key;
    }
  }
}
