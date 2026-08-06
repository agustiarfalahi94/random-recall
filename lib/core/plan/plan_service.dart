import 'package:shared_preferences/shared_preferences.dart';

import '../config/remote_config_service.dart';
import '../utils/date_utils.dart' as date_utils;

class PlanService {
  // Free tier limits — sourced from Remote Config so they can be tuned without
  // shipping a new release. The Remote Config defaults match the old hardcoded values.
  static int get freeQuestionBase =>
      RemoteConfigService.instance.freeQuestionBase;
  static int get freeMaxCustomCategories =>
      RemoteConfigService.instance.freeMaxCustomCategories;

  /// Returns true if the user has an active premium subscription.
  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_premium') ?? false;
  }

  /// Returns the max number of questions allowed.
  static Future<int> getQuestionLimit() async {
    if (await isPremium()) {
      return RemoteConfigService.instance.premiumQuestionLimit;
    }

    final prefs = await SharedPreferences.getInstance();
    final bonus = prefs.getInt('timer_streak_bonus_questions') ?? 0;
    return freeQuestionBase + bonus;
  }

  /// Checks if a user can add another question.
  static Future<bool> canAddQuestion(int currentCount) async {
    final limit = await getQuestionLimit();
    return currentCount < limit;
  }

  /// Returns the max number of custom categories allowed.
  static Future<int> getCategoryLimit() async {
    if (await isPremium()) {
      return RemoteConfigService.instance.premiumMaxCustomCategories;
    }
    final prefs = await SharedPreferences.getInstance();
    final bonus = prefs.getInt('bonus_categories') ?? 0;
    return freeMaxCustomCategories + bonus;
  }

  /// Checks if a user can add another custom category.
  /// [currentCustomCount] should exclude default categories (General, Work).
  static Future<bool> canAddCategory(int currentCustomCount) async {
    final limit = await getCategoryLimit();
    return currentCustomCount < limit;
  }

  /// Manually set premium status (used after successful IAP or cloud sync).
  static Future<void> setPremiumStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', status);
  }

  /// Returns true if the user has already used their daily Undo today.
  static Future<bool> hasUsedUndoToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    return prefs.getString('last_undo_date') == today;
  }

  /// Marks the Undo feature as used for today.
  static Future<void> consumeUndo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_undo_date', _dateKey(DateTime.now()));
  }

  static String _dateKey(DateTime d) => date_utils.dateKey(d);
}
