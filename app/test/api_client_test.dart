import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teamak_app/api/api_client.dart';

void main() {
  /// Records the URL the client actually asked for and answers with the
  /// smallest body that satisfies it.
  MockClient capturing(List<Uri> seen) => MockClient((request) async {
        seen.add(request.url);
        return http.Response(
          '{"programmes":[]}',
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

  test('an explicit base is used as-is', () async {
    final seen = <Uri>[];
    final client = ApiClient(
      client: capturing(seen),
      baseUrl: 'https://api.example.com',
    );

    await client.fetchProgrammes();

    expect(seen.single.toString(), 'https://api.example.com/programmes');
  });

  test('an empty base resolves against the page, so one host serves both',
      () async {
    final seen = <Uri>[];
    final client = ApiClient(client: capturing(seen), baseUrl: '');

    await client.fetchProgrammes();

    // Resolved against the running document rather than thrown away: the
    // request stays on whatever host the app was served from.
    expect(seen.single.path, '/programmes');
    expect(seen.single.scheme, Uri.base.scheme);
    expect(seen.single.host, Uri.base.host);
  });

  test('an empty base keeps the query string on the same origin', () async {
    final seen = <Uri>[];
    final client = ApiClient(client: capturing(seen), baseUrl: '');

    await client.listApplications(status: 'under_review');

    expect(seen.single.path, '/applications');
    expect(seen.single.queryParameters['status'], 'under_review');
    expect(seen.single.host, Uri.base.host);
  });
}
