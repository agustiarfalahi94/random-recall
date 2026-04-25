// Tests the phone-auth session gate logic in isolation.
// We test the boolean condition, not AuthService directly (Firebase can't be
// instantiated in unit tests without full Firebase setup).
import 'package:flutter_test/flutter_test.dart';

bool isVerifiedUser({
  required bool emailVerified,
  required bool isGoogle,
  required bool isAnonymous,
  required String? phoneNumber,
}) {
  return isGoogle || isAnonymous || emailVerified || phoneNumber != null;
}

void main() {
  group('isVerifiedUser gate', () {
    test('phone user with no email is considered verified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: '+628123456789',
        ),
        isTrue,
      );
    });

    test('email user with unverified email is not verified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: null,
        ),
        isFalse,
      );
    });

    test('google user is verified regardless of emailVerified', () {
      expect(
        isVerifiedUser(
          emailVerified: false,
          isGoogle: true,
          isAnonymous: false,
          phoneNumber: null,
        ),
        isTrue,
      );
    });

    test('linked account with phone and email verified is verified', () {
      expect(
        isVerifiedUser(
          emailVerified: true,
          isGoogle: false,
          isAnonymous: false,
          phoneNumber: '+628123456789',
        ),
        isTrue,
      );
    });
  });
}
