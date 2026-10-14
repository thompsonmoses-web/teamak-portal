import 'dart:convert';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../routes/index.dart' as route;

class _MockRequestContext extends Mock implements RequestContext {}

void main() {
  group('GET /', () {
    test('responds with service metadata', () async {
      final response = route.onRequest(_MockRequestContext());
      expect(response.statusCode, HttpStatus.ok);

      final body = jsonDecode(await response.body()) as Map<String, dynamic>;
      expect(body['service'], 'Teamak Rider Ownership API');
      expect(body['status'], 'ok');
      expect(body['version'], '1.0.0');
      expect(DateTime.tryParse('${body['time']}'), isNotNull);
    });
  });
}
