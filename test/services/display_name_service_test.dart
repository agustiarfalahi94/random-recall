import 'package:flutter_test/flutter_test.dart';
import 'package:random_recall/services/display_name_service.dart';

void main() {
  group('DisplayNameService', () {
    test('accepts valid characters: letters, numbers, spaces, hyphens, underscores', () {
      expect(DisplayNameService.isValidCharacters('John Doe-123_test'), true);
      expect(DisplayNameService.isValidCharacters('Jean-Pierre'), true);
      expect(DisplayNameService.isValidCharacters('User_Name'), true);
    });

    test('rejects special characters', () {
      expect(DisplayNameService.isValidCharacters('John@Doe'), false);
      expect(DisplayNameService.isValidCharacters('User!Name'), false);
      expect(DisplayNameService.isValidCharacters('Test#123'), false);
      expect(DisplayNameService.isValidCharacters('Name\$'), false);
    });

    test('rejects empty or whitespace-only names', () {
      expect(DisplayNameService.isValidCharacters(''), false);
      expect(DisplayNameService.isValidCharacters('   '), false);
    });

    test('rejects names exceeding 50 characters', () {
      expect(DisplayNameService.isValidCharacters('a' * 51), false);
      expect(DisplayNameService.isValidCharacters('a' * 50), true);
    });
  });
}
