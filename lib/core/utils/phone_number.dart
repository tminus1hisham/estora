/// Phone numbers as the API stores them.
///
/// A tenant types a number however they hold it in their head — `0712345678`,
/// `+254 712 345 678`, `712 345 678` — and the platform keys accounts, roles,
/// claims and M-Pesa prompts on the number, so two spellings of the same
/// handset are two different users to the server. Rather than push that onto
/// every form, every number leaving this app is put into one shape first: the
/// country's dialling code followed by the national number, no `+`, no spaces.
///
/// Normalisation is deliberately *forgiving in, strict out*. Anything that is
/// not recognisably a phone number — an email address in the sign-in field, a
/// half-typed number — is handed back untouched, because a made-up correction
/// here would only turn the server's clear rejection into a confusing one.
library;

/// A country as a phone number sees it: a dialling code, and how many digits
/// follow it.
///
/// [nationalLengths] is what a number is checked against, so a typo is caught
/// on the handset rather than a round trip later. Where a country genuinely
/// issues more than one length, all of them are listed — the check exists to
/// catch a missing digit, not to out-rule the operators.
class Country {
  const Country({
    required this.iso,
    required this.name,
    required this.dialCode,
    required this.flag,
    required this.nationalLengths,
    required this.example,
  });

  /// ISO 3166-1 alpha-2, and the stable key a stored preference would use.
  final String iso;

  final String name;

  /// Digits only, without the `+`.
  final String dialCode;

  final String flag;

  /// Accepted lengths of the national number — what follows [dialCode].
  final Set<int> nationalLengths;

  /// A national number in the country's own shape, shown as the field's hint.
  final String example;

  /// `+254`, as the selector and every hint write it.
  String get display => '+$dialCode';

  bool acceptsNational(String digits) =>
      nationalLengths.contains(digits.length);

  /// What the picker's search runs against: `kenya +254 ke`.
  String get searchText => '$name $display $iso'.toLowerCase();

  @override
  String toString() => '$name ($display)';
}

/// The countries the selector offers, [Countries.kenya] first because it is
/// where the malls are.
///
/// This is a working list, not a gazetteer: the markets the platform serves,
/// their neighbours, and the places tenants' head offices tend to be. Adding
/// one is a single entry here and nothing else.
class Countries {
  const Countries._();

  static const Country kenya = Country(
    iso: 'KE',
    name: 'Kenya',
    dialCode: '254',
    flag: '🇰🇪',
    nationalLengths: {9},
    example: '712 345 678',
  );

  /// What a field starts on, and what a bare `0712345678` is read as.
  static const Country fallback = kenya;

  static const List<Country> all = [
    kenya,
    Country(
      iso: 'UG',
      name: 'Uganda',
      dialCode: '256',
      flag: '🇺🇬',
      nationalLengths: {9},
      example: '712 345 678',
    ),
    Country(
      iso: 'TZ',
      name: 'Tanzania',
      dialCode: '255',
      flag: '🇹🇿',
      nationalLengths: {9},
      example: '712 345 678',
    ),
    Country(
      iso: 'RW',
      name: 'Rwanda',
      dialCode: '250',
      flag: '🇷🇼',
      nationalLengths: {9},
      example: '788 123 456',
    ),
    Country(
      iso: 'BI',
      name: 'Burundi',
      dialCode: '257',
      flag: '🇧🇮',
      nationalLengths: {8},
      example: '79 123 456',
    ),
    Country(
      iso: 'SS',
      name: 'South Sudan',
      dialCode: '211',
      flag: '🇸🇸',
      nationalLengths: {9},
      example: '921 234 567',
    ),
    Country(
      iso: 'ET',
      name: 'Ethiopia',
      dialCode: '251',
      flag: '🇪🇹',
      nationalLengths: {9},
      example: '911 234 567',
    ),
    Country(
      iso: 'SO',
      name: 'Somalia',
      dialCode: '252',
      flag: '🇸🇴',
      nationalLengths: {7, 8, 9},
      example: '61 234 567',
    ),
    Country(
      iso: 'CD',
      name: 'DR Congo',
      dialCode: '243',
      flag: '🇨🇩',
      nationalLengths: {9},
      example: '991 234 567',
    ),
    Country(
      iso: 'ZM',
      name: 'Zambia',
      dialCode: '260',
      flag: '🇿🇲',
      nationalLengths: {9},
      example: '971 234 567',
    ),
    Country(
      iso: 'MW',
      name: 'Malawi',
      dialCode: '265',
      flag: '🇲🇼',
      nationalLengths: {9},
      example: '991 234 567',
    ),
    Country(
      iso: 'MZ',
      name: 'Mozambique',
      dialCode: '258',
      flag: '🇲🇿',
      nationalLengths: {9},
      example: '841 234 567',
    ),
    Country(
      iso: 'ZW',
      name: 'Zimbabwe',
      dialCode: '263',
      flag: '🇿🇼',
      nationalLengths: {9},
      example: '771 234 567',
    ),
    Country(
      iso: 'ZA',
      name: 'South Africa',
      dialCode: '27',
      flag: '🇿🇦',
      nationalLengths: {9},
      example: '711 234 567',
    ),
    Country(
      iso: 'NG',
      name: 'Nigeria',
      dialCode: '234',
      flag: '🇳🇬',
      nationalLengths: {10},
      example: '803 123 4567',
    ),
    Country(
      iso: 'GH',
      name: 'Ghana',
      dialCode: '233',
      flag: '🇬🇭',
      nationalLengths: {9},
      example: '241 234 567',
    ),
    Country(
      iso: 'EG',
      name: 'Egypt',
      dialCode: '20',
      flag: '🇪🇬',
      nationalLengths: {10},
      example: '100 123 4567',
    ),
    Country(
      iso: 'MA',
      name: 'Morocco',
      dialCode: '212',
      flag: '🇲🇦',
      nationalLengths: {9},
      example: '612 345 678',
    ),
    Country(
      iso: 'AE',
      name: 'United Arab Emirates',
      dialCode: '971',
      flag: '🇦🇪',
      nationalLengths: {9},
      example: '501 234 567',
    ),
    Country(
      iso: 'SA',
      name: 'Saudi Arabia',
      dialCode: '966',
      flag: '🇸🇦',
      nationalLengths: {9},
      example: '501 234 567',
    ),
    Country(
      iso: 'QA',
      name: 'Qatar',
      dialCode: '974',
      flag: '🇶🇦',
      nationalLengths: {8},
      example: '3312 3456',
    ),
    Country(
      iso: 'KW',
      name: 'Kuwait',
      dialCode: '965',
      flag: '🇰🇼',
      nationalLengths: {8},
      example: '5012 3456',
    ),
    Country(
      iso: 'OM',
      name: 'Oman',
      dialCode: '968',
      flag: '🇴🇲',
      nationalLengths: {8},
      example: '9123 4567',
    ),
    Country(
      iso: 'TR',
      name: 'Türkiye',
      dialCode: '90',
      flag: '🇹🇷',
      nationalLengths: {10},
      example: '532 123 4567',
    ),
    Country(
      iso: 'GB',
      name: 'United Kingdom',
      dialCode: '44',
      flag: '🇬🇧',
      nationalLengths: {10},
      example: '7400 123456',
    ),
    Country(
      iso: 'IE',
      name: 'Ireland',
      dialCode: '353',
      flag: '🇮🇪',
      nationalLengths: {9},
      example: '85 123 4567',
    ),
    Country(
      iso: 'US',
      name: 'United States',
      dialCode: '1',
      flag: '🇺🇸',
      nationalLengths: {10},
      example: '201 555 0123',
    ),
    Country(
      iso: 'IN',
      name: 'India',
      dialCode: '91',
      flag: '🇮🇳',
      nationalLengths: {10},
      example: '98123 45678',
    ),
    Country(
      iso: 'PK',
      name: 'Pakistan',
      dialCode: '92',
      flag: '🇵🇰',
      nationalLengths: {10},
      example: '301 234 5678',
    ),
    Country(
      iso: 'CN',
      name: 'China',
      dialCode: '86',
      flag: '🇨🇳',
      nationalLengths: {11},
      example: '131 2345 6789',
    ),
    Country(
      iso: 'DE',
      name: 'Germany',
      dialCode: '49',
      flag: '🇩🇪',
      nationalLengths: {10, 11},
      example: '151 1234 5678',
    ),
    Country(
      iso: 'FR',
      name: 'France',
      dialCode: '33',
      flag: '🇫🇷',
      nationalLengths: {9},
      example: '612 345 678',
    ),
    Country(
      iso: 'NL',
      name: 'Netherlands',
      dialCode: '31',
      flag: '🇳🇱',
      nationalLengths: {9},
      example: '612 345 678',
    ),
    Country(
      iso: 'IT',
      name: 'Italy',
      dialCode: '39',
      flag: '🇮🇹',
      nationalLengths: {9, 10},
      example: '312 345 6789',
    ),
    Country(
      iso: 'ES',
      name: 'Spain',
      dialCode: '34',
      flag: '🇪🇸',
      nationalLengths: {9},
      example: '612 345 678',
    ),
    Country(
      iso: 'AU',
      name: 'Australia',
      dialCode: '61',
      flag: '🇦🇺',
      nationalLengths: {9},
      example: '412 345 678',
    ),
  ];

  static Country? byIso(String? iso) {
    if (iso == null) return null;
    final wanted = iso.trim().toUpperCase();
    for (final country in all) {
      if (country.iso == wanted) return country;
    }
    return null;
  }

  /// The countries whose name, dialling code or ISO code contains [query].
  static List<Country> search(String query) {
    final needle = query.trim().toLowerCase().replaceAll('+', '');
    if (needle.isEmpty) return all;
    return [
      for (final country in all)
        if (country.searchText.contains(needle)) country,
    ];
  }

  /// The country whose dialling code [digits] starts with, or null.
  ///
  /// Longest code first, so `211` is South Sudan rather than a `21` that does
  /// not exist. The national part is length-checked before a match is taken,
  /// which is what stops a Kenyan `254…` being read as a `2` somewhere; a
  /// prefix that matches but does not measure up is returned only if nothing
  /// better is found, so a partly typed number still shows the right flag.
  static Country? detect(String digits) {
    Country? loose;
    for (final country in _byCodeLength) {
      if (!digits.startsWith(country.dialCode)) continue;
      final national = digits.substring(country.dialCode.length);
      if (country.acceptsNational(national)) return country;
      loose ??= country;
    }
    return loose;
  }

  static final List<Country> _byCodeLength = [...all]
    ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
}

/// The one rule every number leaving the app goes through.
class PhoneNumber {
  const PhoneNumber._();

  /// E.164 allows fifteen digits including the dialling code.
  static const int _maxDigits = 15;

  static final RegExp _notANumber = RegExp('[A-Za-z@]');
  static final RegExp _nonDigits = RegExp('[^0-9]');
  static final RegExp _digitsOnly = RegExp(r'^[0-9]+$');

  /// Returns [input] as `<dialling code><national number>`, or [input] trimmed
  /// if it is not recognisably a phone number.
  ///
  /// [country] is the one the selector is sitting on, and is what a locally
  /// written number — `0712345678`, or a bare `712345678` — is read as. A
  /// number that already carries a dialling code keeps it, whatever the
  /// selector says, because the number is the more specific statement.
  static String normalize(String input, {Country? country}) {
    final home = country ?? Countries.fallback;
    final trimmed = input.trim();

    // Letters or an `@` mean this is not a phone number at all — most often
    // the email a tenant typed into a field that accepts either.
    if (_notANumber.hasMatch(trimmed)) return trimmed;

    var digits = trimmed.replaceAll(_nonDigits, '');
    if (digits.isEmpty || digits.length > _maxDigits) return trimmed;

    // `00` is the other way of writing `+`.
    if (digits.startsWith('00')) digits = digits.substring(2);

    // A trunk zero belongs to the national number, not to the subscriber, and
    // only the selected country can say what follows it.
    if (digits.startsWith('0')) {
      final national = digits.substring(1);
      return home.acceptsNational(national)
          ? '${home.dialCode}$national'
          : trimmed;
    }

    // A bare national number is read as the selected country's before any
    // dialling code is looked for, so `712345678` on Kenya stays Kenyan even
    // though some country dials `71`.
    if (home.acceptsNational(digits)) return '${home.dialCode}$digits';

    final dialled = Countries.detect(digits);
    if (dialled != null &&
        dialled.acceptsNational(digits.substring(dialled.dialCode.length))) {
      return digits;
    }

    return trimmed;
  }

  /// [normalize] for an optional field, preserving null.
  static String? normalizeOrNull(String? input, {Country? country}) =>
      input == null ? null : normalize(input, country: country);

  /// Whether [input] normalises to a number the API will accept. Forms use
  /// this to catch a typo before spending a round trip on it.
  static bool isValid(String input, {Country? country}) {
    final normalized = normalize(input, country: country);
    if (!_digitsOnly.hasMatch(normalized)) return false;
    final dialled = Countries.detect(normalized);
    if (dialled == null) return false;
    return dialled.acceptsNational(
      normalized.substring(dialled.dialCode.length),
    );
  }

  /// The country [input] is written in, for seeding a selector from a number
  /// the server already holds. Null rather than a guess when the number is not
  /// one this app can place, so the caller can decide whether to fall back to
  /// [Countries.fallback].
  static Country? countryOf(String? input, {Country? country}) {
    if (input == null || input.trim().isEmpty) return null;
    final normalized = normalize(input, country: country);
    if (!_digitsOnly.hasMatch(normalized)) return null;
    return Countries.detect(normalized);
  }

  /// How a number is shown back to the person who gave it: `+254 712345678`.
  ///
  /// The code is split off and nothing else is regrouped, because where the
  /// spaces fall inside a national number is a local habit and getting it
  /// wrong for a country reads worse than not trying.
  static String display(String? input, {Country? country}) {
    if (input == null || input.trim().isEmpty) return '';
    final normalized = normalize(input, country: country);
    if (!_digitsOnly.hasMatch(normalized)) return input.trim();
    final dialled = Countries.detect(normalized);
    // A number that could not be placed never gained a dialling code, so it is
    // shown as it was typed rather than dressed with a `+` it has not earned.
    if (dialled == null) return input.trim();
    return '+${dialled.dialCode} '
        '${normalized.substring(dialled.dialCode.length)}';
  }

  /// The part of [input] that follows the dialling code — what the selector's
  /// text field holds and the tenant edits.
  ///
  /// Anything unplaceable is handed back as typed rather than thrown away.
  static String nationalOf(String? input, {Country? country}) {
    if (input == null || input.trim().isEmpty) return '';
    final normalized = normalize(input, country: country);
    if (!_digitsOnly.hasMatch(normalized)) return input.trim();
    final dialled = Countries.detect(normalized);
    if (dialled == null) return normalized;
    return normalized.substring(dialled.dialCode.length);
  }
}
