// Minimal static file server for the built Flutter web app.
//
//   dart run tool/static_server.dart [root] [port]
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

  if (!root.existsSync()) {
    stderr.writeln('Root does not exist: ${root.path}');
    exitCode = 1;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Serving ${root.path} on http://localhost:${server.port}');

  await for (final request in server) {
    try {
      await _handle(request, root);
    } catch (error) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('$error');
    } finally {
      await request.response.close();
    }
  }
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
