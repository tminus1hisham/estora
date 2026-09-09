import 'package:flutter_test/flutter_test.dart';
import 'package:mall/core/utils/phone_number.dart';

/// The platform keys accounts, roles, claims and M-Pesa prompts on the phone
/// number, so two spellings of one handset are two different users to the
/// server. Every number leaving the app goes through [PhoneNumber.normalize]
/// first, and these are the spellings tenants actually type.
void main() {
  group('PhoneNumber.normalize', () {
    test('puts every spelling of one handset into the same form', () {
      const expected = '254712345678';
      for (final input in [
        '0712345678',
        '712345678',
        '254712345678',
        '+254712345678',
        '00254712345678',
        '+254 712 345 678',
        '0712-345-678',
        ' (0712) 345 678 ',
      ]) {
        expect(PhoneNumber.normalize(input), expected, reason: input);
      }
    });

    test('treats the 01 range the same as the 07 range', () {
      expect(PhoneNumber.normalize('0112345678'), '254112345678');
      expect(PhoneNumber.normalize('112345678'), '254112345678');
      expect(PhoneNumber.normalize('254112345678'), '254112345678');
      expect(PhoneNumber.normalize('+254 112 345 678'), '254112345678');
    });

    test('is idempotent, so a normalised number survives a second pass', () {
      final once = PhoneNumber.normalize('0712345678');
      expect(PhoneNumber.normalize(once), once);
    });

    test('hands back anything that is not a Kenyan number, untouched', () {
      // An email in the sign-in field, which accepts either.
      expect(PhoneNumber.normalize(' tenant@ndai.co.ke '), 'tenant@ndai.co.ke');
      // Half-typed, or the wrong length — the server says so better than a
      // guess made here would.
      expect(PhoneNumber.normalize('0712345'), '0712345');
      expect(PhoneNumber.normalize('07123456789012'), '07123456789012');
      expect(PhoneNumber.normalize(''), '');
    });

    test('normalizeOrNull preserves an absent number', () {
      expect(PhoneNumber.normalizeOrNull(null), isNull);
      expect(PhoneNumber.normalizeOrNull('0712345678'), '254712345678');
    });

    test('isValid accepts what the API accepts and nothing else', () {
      expect(PhoneNumber.isValid('0712345678'), isTrue);
      expect(PhoneNumber.isValid('+254 712 345 678'), isTrue);
      expect(PhoneNumber.isValid('0712345'), isFalse);
      expect(PhoneNumber.isValid('tenant@ndai.co.ke'), isFalse);
    });
  });
}
