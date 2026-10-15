// Terminal-free entry point for local development.
//
// `dart_frog dev` drives the generated server through `hotReload`, which needs
// an interactive stdin and dies when run from a non-interactive shell. This
// runner calls the same generated `createServer` directly, so it can be run in
// the background or as a plain process.
//
//   dart run tool/serve.dart
//   PORT=9000 dart run tool/serve.dart
import 'dart:io';

import '../.dart_frog/server.dart' as generated;

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  // anyIPv4 rather than anyIPv6 so that `localhost` resolves reliably.
  final server = await generated.createServer(InternetAddress.anyIPv4, port);
  stdout.writeln('Teamak API listening on http://localhost:${server.port}');
}
