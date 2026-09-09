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

  group('PhoneNumber with a country selected', () {
    const uganda = Country(
      iso: 'UG',
      name: 'Uganda',
      dialCode: '256',
      flag: '🇺🇬',
      nationalLengths: {9},
      example: '712 345 678',
    );

    test('the selector decides what a local number means', () {
      expect(
        PhoneNumber.normalize('0712345678', country: uganda),
        '256712345678',
      );
      expect(
        PhoneNumber.normalize('712345678', country: uganda),
        '256712345678',
      );
      // The same digits on the default country are Kenyan.
      expect(PhoneNumber.normalize('0712345678'), '254712345678');
    });

    test('a number carrying its own code keeps it, whatever is selected', () {
      expect(
        PhoneNumber.normalize('+44 7400 123456', country: Countries.kenya),
        '447400123456',
      );
      expect(
        PhoneNumber.normalize('254712345678', country: uganda),
        '254712345678',
      );
    });

    test('length is held to the selected country, not to nine digits', () {
      final nigeria = Countries.byIso('NG')!;
      expect(PhoneNumber.isValid('08031234567', country: nigeria), isTrue);
      // Nine digits is short for a Nigerian number — and exactly a Kenyan
      // one, which is the whole reason the count follows the selector.
      expect(PhoneNumber.isValid('0803123456', country: nigeria), isFalse);
      expect(PhoneNumber.isValid('0803123456'), isTrue);
    });

    test('a stored number is taken apart into the pair a field shows', () {
      expect(PhoneNumber.countryOf('+254712345678')?.iso, 'KE');
      expect(PhoneNumber.nationalOf('+254712345678'), '712345678');

      expect(PhoneNumber.countryOf('+447400123456')?.iso, 'GB');
      expect(PhoneNumber.nationalOf('+447400123456'), '7400123456');

      // Nothing on file leaves the field empty and the selector on its
      // default, rather than guessing.
      expect(PhoneNumber.countryOf(null), isNull);
      expect(PhoneNumber.countryOf(''), isNull);
      expect(PhoneNumber.nationalOf(null), '');
    });

    test('display splits the code off for reading back', () {
      expect(PhoneNumber.display('0712345678'), '+254 712345678');
      expect(PhoneNumber.display('+44 7400 123456'), '+44 7400123456');
      expect(PhoneNumber.display(null), '');
      // Unplaceable input is shown as typed rather than dressed up.
      expect(PhoneNumber.display('0712345'), '0712345');
    });

    test('a number the app cannot place is handed back, not swallowed', () {
      expect(PhoneNumber.countryOf('0712345'), isNull);
      expect(PhoneNumber.nationalOf('0712345'), '0712345');
    });
  });

  group('Countries', () {
    test('Kenya is the default a field starts on', () {
      expect(Countries.fallback, Countries.kenya);
      expect(Countries.all.first, Countries.kenya);
      expect(Countries.kenya.display, '+254');
    });

    test('dialling codes are unambiguous enough to detect', () {
      expect(Countries.detect('254712345678')?.iso, 'KE');
      // The longer code wins over a shorter one it starts with.
      expect(Countries.detect('211921234567')?.iso, 'SS');
      expect(Countries.detect('12015550123')?.iso, 'US');
    });

    test('search matches a name, a code or an ISO code', () {
      expect(Countries.search('ken').single.iso, 'KE');
      expect(Countries.search('+254').single.iso, 'KE');
      expect(Countries.search('ke').map((c) => c.iso), contains('KE'));
      expect(Countries.search('  ').length, Countries.all.length);
      expect(Countries.search('atlantis'), isEmpty);
    });

    test('every country is listed once, with a plausible number in it', () {
      final isoCodes = Countries.all.map((country) => country.iso).toSet();
      expect(isoCodes.length, Countries.all.length);

      for (final country in Countries.all) {
        expect(country.dialCode, matches(RegExp(r'^[1-9][0-9]{0,3}$')));
        expect(country.nationalLengths, isNotEmpty);
        expect(
          country.acceptsNational(
            country.example.replaceAll(RegExp('[^0-9]'), ''),
          ),
          isTrue,
          reason: '${country.name} example does not match its own lengths',
        );
      }
    });
  });
}
