/// Service for validating display names for user profiles.
///
/// Validates that names contain only allowed characters (letters, numbers,
/// spaces, hyphens, underscores) and are within the max length of 50 chars.
class DisplayNameService {
  // Whitelist: letters (a-z, A-Z), numbers (0-9), spaces, hyphens (-), underscores (_)
  static final RegExp _validCharPattern = RegExp(r'^[a-zA-Z0-9\s_-]*$');
  static const int maxLength = 50;

  /// Validates that the name contains only allowed characters and is within length limit
  static bool isValidCharacters(String name) {
    if (name.isEmpty || name.trim().isEmpty) {
      return false;
    }
    if (name.length > maxLength) {
      return false;
    }
    return _validCharPattern.hasMatch(name);
  }

  /// Returns the trimmed display name (leading/trailing spaces removed)
  static String normalize(String name) {
    return name.trim();
  }
}
