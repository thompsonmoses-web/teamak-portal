import 'package:dart_frog/dart_frog.dart';
import 'package:server/database.dart';

const corsHeaders = <String, Object>{
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
  'access-control-allow-headers': 'authorization, content-type',
  'access-control-max-age': '86400',
};

/// Provides the shared database and adds CORS headers so the Flutter Web
/// front-end can call the API from another origin during development.
Handler middleware(Handler handler) {
  final provided = handler.use(
    provider<TeamakDatabase>((_) => TeamakDatabase.instance),
  );
  return (context) async {
    if (context.request.method == HttpMethod.options) {
      return Response(statusCode: 204, headers: corsHeaders);
    }
    final response = await provided(context);
    return response.copyWith(
      headers: <String, Object?>{...response.headers, ...corsHeaders},
    );
  };
}
