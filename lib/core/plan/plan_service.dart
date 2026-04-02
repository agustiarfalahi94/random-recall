import '../streak/streak_service.dart';

/// Central source of truth for free vs premium limits.
/// In Phase 4, replace [isPremium] with a real RevenueCat check.
class PlanService {
  PlanService._();

  // ── Limits ─────────────────────────────────────────────────────────────────

  /// Max categories a free user can have questions in.
  static const int freeCategoryLimit = 2;

  /// Max *custom* (non-default) categories a free user can create.
  /// Default categories (General, Work) are excluded from this count.
  static const int freeMaxCustomCategories = 1;

  static const int freeQuestionBase = 20;

  // TODO Phase 4: replace with RevenueCat entitlement check
  static Future<bool> isPremium() async => false;

  /// Max questions for current user (base + streak bonus for free, ∞ for premium).
  static Future<int> getQuestionLimit() async {
    if (await isPremium()) return 999999;
    return StreakService.getFreeQuestionLimit();
  }

  /// Max distinct categories a free user may add questions to.
  static Future<int> getCategoryLimit() async {
    if (await isPremium()) return 999999;
    return freeCategoryLimit;
  }

  /// Returns true if the user has not yet hit the question limit.
  static Future<bool> canAddQuestion(int currentCount) async {
    final limit = await getQuestionLimit();
    return currentCount < limit;
  }

  /// Returns true if the user can create another *custom* category.
  /// Pass [currentCustomCount] = number of non-default categories already created.
  /// Premium: always allowed.
  /// Free: allowed while custom count < [freeMaxCustomCategories].
  static Future<bool> canAddCategory(int currentCustomCount) async {
    if (await isPremium()) return true;
    return currentCustomCount < freeMaxCustomCategories;
  }

  /// Returns true if [categoryId] is allowed for the current user.
  /// Premium: always allowed.
  /// Free: allowed if already used, OR fewer than [freeCategoryLimit] used so far.
  static Future<bool> canUseCategory({
    required int categoryId,
    required Set<int> usedCategoryIds,
  }) async {
    if (await isPremium()) return true;
    if (usedCategoryIds.contains(categoryId)) return true;
    return usedCategoryIds.length < freeCategoryLimit;
  }
}
