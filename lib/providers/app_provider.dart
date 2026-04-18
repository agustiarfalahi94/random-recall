import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  bool _isLoading = false;
  Locale? _locale;

  bool get isLoading => _isLoading;
  Locale? get locale => _locale;

  AppProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('app_locale');
    if (langCode != null) {
      _locale = Locale(langCode);
      notifyListeners();
      // Ensure notification strings are set for the loaded locale
      await _updateNotificationStrings(langCode);
    } else {
      // Set default (English) notification strings
      await _updateNotificationStrings('en');
    }
  }

  Future<void> _updateNotificationStrings(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    final isIndonesian = languageCode == 'id';

    await Future.wait([
      prefs.setString('notif_title',
        isIndonesian ? 'Saatnya mengingat kembali! 🧠' : 'Time for a quick recall! 🧠'),
      prefs.setString('notif_body',
        isIndonesian ? 'Tap untuk menjawab pertanyaan' : 'Tap to answer the question'),
      prefs.setString('test_notif_title',
        isIndonesian ? 'Notifikasi Pengujian 🧪' : 'Test Notification 🧪'),
      prefs.setString('test_notif_body',
        isIndonesian ? 'Tap untuk menjawab pertanyaan' : 'Tap to answer the question'),
    ]);
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
    // Update notification strings for background service
    await _updateNotificationStrings(locale.languageCode);
  }

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
