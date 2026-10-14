import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Response onRequest(RequestContext context) => Response.json(
      body: <String, Object?>{
        'service': 'Teamak Rider Ownership API',
        'version': '1.0.0',
        'status': 'ok',
        'time': DateTime.now().toUtc().toIso8601String(),
        'pid': pid,
      },
    );
