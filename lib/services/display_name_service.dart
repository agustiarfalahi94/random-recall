// ignore: unused_import
import 'package:http/http.dart' as http;
// ignore: unused_import
import 'dart:convert';

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

  /// Checks if name contains profanity using Google Safe Browsing API
  /// Returns true if profanity detected, false if clean
  /// In production, requires GOOGLE_SAFE_BROWSING_API_KEY environment variable
  static Future<bool> checkProfanity(String name) async {
    // For now, return false (safe) - will be implemented after Firebase setup
    // Real implementation would call Google Safe Browsing API's malware/toxicity check
    // However, since we need API key and this is a Flutter app, we'll do client-side
    // checking on backend or use a simpler local approach

    // TODO: Implement with Google Safe Browsing API after determining backend approach
    return false; // Temporarily allow all names - will be replaced
  }
}
