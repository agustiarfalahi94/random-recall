import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/notification_service.dart';

// Notification strings stored in SharedPreferences for use by the background
// isolate (no BuildContext available there). Values must stay in sync with
// the corresponding keys in app_en.arb / app_id.arb.
// When adding a new locale, add an entry here and in both ARB files.
const _notifStrings = {
  'en': {
    'notif_title': 'Time for a quick recall! 🧠',
    'notif_body': 'Tap to answer the question',
    'test_notif_title': 'Test Notification 🧪',
    'test_notif_body': 'Tap to answer the question',
  },
  'id': {
    'notif_title': 'Saatnya mengingat kembali! 🧠',
    'notif_body': 'Tap untuk menjawab pertanyaan',
    'test_notif_title': 'Notifikasi Pengujian 🧪',
    'test_notif_body': 'Tap untuk menjawab pertanyaan',
  },
};

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
      await _updateNotificationStrings(langCode);
    } else {
      await _updateNotificationStrings('en');
    }
  }

  Future<void> _updateNotificationStrings(String languageCode) async {
    final strings = _notifStrings[languageCode] ?? _notifStrings['en']!;
    final prefs = await SharedPreferences.getInstance();
    await Future.wait(
      strings.entries.map((e) => prefs.setString(e.key, e.value)),
    );
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
    await _updateNotificationStrings(locale.languageCode);
    // Reschedule so the new language is baked into the next 7 days of alarms.
    // Notification title/body are written into zonedSchedule() at schedule time,
    // so already-queued notifications keep the old language without this call.
    NotificationService.instance.scheduleNotifications().ignore();
  }

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
