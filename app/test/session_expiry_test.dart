import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teamak_app/api/api_client.dart';
import 'package:teamak_app/state/session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A client that accepts one sign-in and then refuses everything else —
  /// standing in for a token the API stopped honouring twelve hours later.
  MockClient expiringClient() => MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            '{"token":"dead-token","staff":{"username":"admin",'
            '"fullName":"Portal Admin","role":"admin"}}',
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"error":"Token expired."}',
          401,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

  test('a rejected token ends the session it belonged to', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final api = ApiClient(client: expiringClient());
    final session = Session(api);
    expect(await session.signIn(username: 'admin', password: 'admin123'), true);
    expect(session.isSignedIn, isTrue);
    expect(api.token, 'dead-token');

    var notified = false;
    session.addListener(() => notified = true);

    await expectLater(
      api.get('/applications'),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
      ),
    );
    // The token is dropped synchronously, before the request's own error
    // propagates, so nothing retries with it.
    expect(api.token, isNull, reason: 'a dead token would be resent forever');
    expect(session.isSignedIn, isFalse);

    await pumpEventQueue();
    expect(
      notified,
      isTrue,
      reason: 'the router listens to Session to redirect to sign-in',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('teamak_staff_token'),
      isNull,
      reason: 'otherwise the dead token is restored on the next reload',
    );
  });

  test('a rejected sign-in does not drop a session already in place', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'teamak_staff_token': 'good-token',
    });

    // Every reply refuses, including the sign-in itself.
    final api = ApiClient(
      client: MockClient(
        (request) async => http.Response(
          '{"error":"Invalid username or password."}',
          401,
          headers: <String, String>{'content-type': 'application/json'},
        ),
      ),
    );
    final session = Session(api);
    api.token = 'good-token';

    var notified = false;
    session.addListener(() => notified = true);

    await expectLater(
      api.login(username: 'admin', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
    await pumpEventQueue();

    expect(
      api.token,
      'good-token',
      reason: 'a wrong password is not proof the old token is dead',
    );
    expect(notified, isFalse);
  });
}
