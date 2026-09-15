import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every endpoint path is declared in api.md', () {
    final spec = jsonDecode(File('api.md').readAsStringSync()) as Map;
    final paths = (spec['paths'] as Map).keys.map((path) {
      return path
          .toString()
          .replaceFirst('/v1/api', '')
          .replaceAll(RegExp(r'\{[^}]+\}'), '{id}');
    }).toSet();
    final source = File(
      'lib/services/remote/endpoints.dart',
    ).readAsStringSync();
    final declarations = RegExp(r"'(/[^']*)'").allMatches(source).toList();
    expect(declarations, isNotEmpty);
    for (final declaration in declarations) {
      final path = declaration[1]!.replaceAll(RegExp(r'\$\w+'), '{id}');
      expect(paths, contains(path), reason: 'Undocumented endpoint: $path');
    }
  });
}
