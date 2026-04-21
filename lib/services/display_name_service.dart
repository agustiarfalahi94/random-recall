class DisplayNameService {
  // Whitelist: letters (a-z, A-Z), numbers (0-9), spaces, hyphens (-), underscores (_)
  static final RegExp _validCharPattern = RegExp(r'^[a-zA-Z0-9\s\-_]*$');
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

  /// Checks if name contains only whitespace
  static bool isWhitespaceOnly(String name) {
    return name.trim().isEmpty;
  }

  /// Returns the trimmed display name (leading/trailing spaces removed)
  static String normalize(String name) {
    return name.trim();
  }
}
