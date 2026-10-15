// Minimal static file server for the built Flutter web app.
//
//   dart run tool/static_server.dart [root] [port] [apiOrigin]
//
// When [apiOrigin] is given (for example http://127.0.0.1:8080) the API routes
// are proxied to it, so the app and the API share a single origin. That keeps
// a demo or a reverse-proxied deployment down to one URL.
import 'dart:io';

final _mimeTypes = <String, String>{
  'html': 'text/html; charset=utf-8',
  'js': 'text/javascript; charset=utf-8',
  'mjs': 'text/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'ico': 'image/x-icon',
  'svg': 'image/svg+xml',
  'wasm': 'application/wasm',
  'txt': 'text/plain; charset=utf-8',
  'map': 'application/json; charset=utf-8',
  'fam': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final root = Directory(
    args.isNotEmpty ? args[0] : 'build/web',
  ).absolute;
  final port = args.length > 1 ? int.parse(args[1]) : 8888;
  final apiOrigin = args.length > 2 ? Uri.parse(args[2]) : null;

  if (!root.existsSync()) {
    stderr.writeln('Root does not exist: ${root.path}');
    exitCode = 1;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Serving ${root.path} on http://localhost:${server.port}'
      '${apiOrigin == null ? '' : ' (proxying ${_apiPrefixes.join(', ')} to $apiOrigin)'}');

  final api = apiOrigin == null ? null : HttpClient();
  await for (final request in server) {
    try {
      if (apiOrigin != null && api != null && _isApiPath(request.uri.path)) {
        await _proxy(request, apiOrigin, api);
      } else {
        await _handle(request, root);
      }
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('$error');
    } finally {
      await request.response.close();
    }
  }
}

/// Route prefixes owned by the API rather than by the static build.
const _apiPrefixes = <String>['/programmes', '/applications', '/auth', '/health'];

bool _isApiPath(String path) => _apiPrefixes.any(path.startsWith);

/// Forwards a request to [origin], streaming the body in both directions so
/// large payloads are not buffered in memory.
Future<void> _proxy(HttpRequest request, Uri origin, HttpClient client) async {
  final target = origin.replace(
    path: request.uri.path,
    queryParameters:
        request.uri.queryParameters.isEmpty ? null : request.uri.queryParameters,
  );

  final outgoing = await client.openUrl(request.method, target);
  for (final name in const ['content-type', 'authorization', 'accept']) {
    final value = request.headers.value(name);
    if (value != null) outgoing.headers.set(name, value);
  }
  // Stream the caller's body through, then close to send the request.
  await outgoing.addStream(request);
  final response = await outgoing.close();
  final body = <int>[];
  await for (final chunk in response) {
    body.addAll(chunk);
  }

  request.response.statusCode = response.statusCode;
  response.headers.forEach((name, values) {
    if (name == 'content-length' || name == 'transfer-encoding') return;
    request.response.headers.set(name, values);
  });
  request.response.headers.contentLength = body.length;
  request.response.add(body);
}

Future<void> _handle(HttpRequest request, Directory root) async {
  if (request.method != 'GET' && request.method != 'HEAD') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    return;
  }

  // Prevent path traversal outside the build root.
  final decoded = Uri.decodeComponent(request.uri.path);
  final relative = decoded.startsWith('/') ? decoded.substring(1) : decoded;
  final file = File('${root.path}${Platform.pathSeparator}$relative');

  File resolved;
  if (file.existsSync() && FileSystemEntity.isFileSync(file.path)) {
    resolved = file;
  } else {
    // Flutter web apps use path URLs; unknown paths fall back to index.html
    // so deep links such as /staff/login still load the app shell.
    resolved = File('${root.path}${Platform.pathSeparator}index.html');
    if (!resolved.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('Not found');
      return;
    }
  }

  final bytes = await resolved.readAsBytes();
  final ext = resolved.path.split('.').last.toLowerCase();
  request.response.statusCode = HttpStatus.ok;
  request.response.headers.contentType =
      ContentType.parse(_mimeTypes[ext] ?? 'application/octet-stream');
  request.response.headers.set('access-control-allow-origin', '*');
  request.response.headers.contentLength = bytes.length;
  if (request.method == 'GET') {
    request.response.add(bytes);
  }
}
