// Tests the pure AuthService.isVerified predicate (and the null half of
// isVerifiedUser) in isolation. Firebase can't be instantiated in unit tests
// without full Firebase setup, so we test the static predicate — it needs no
// User object and no AuthService.instance, so no Firebase is touched.
import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/core/auth/auth_service.dart';

void main() {
  group('AuthService.isVerified', () {
    test('both email verified and phone present is true', () {
      expect(
        AuthService.isVerified(hasEmailVerified: true, hasPhone: true),
        isTrue,
      );
    });

    test('email verified only is true', () {
      expect(
        AuthService.isVerified(hasEmailVerified: true, hasPhone: false),
        isTrue,
      );
    });

    test('phone present only is true', () {
      expect(
        AuthService.isVerified(hasEmailVerified: false, hasPhone: true),
        isTrue,
      );
    });

    test('neither email verified nor phone present is false', () {
      expect(
        AuthService.isVerified(hasEmailVerified: false, hasPhone: false),
        isFalse,
      );
    });
  });

  group('AuthService.isVerifiedUser', () {
    test('null user is false', () {
      expect(AuthService.isVerifiedUser(null), isFalse);
    });
  });
}
