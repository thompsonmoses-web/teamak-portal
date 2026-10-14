import 'package:dart_frog/dart_frog.dart';
import 'package:server/programmes.dart';

Response onRequest(RequestContext context) => Response.json(
      body: <String, Object?>{
        'programmes': Programme.all.map((p) => p.toJson()).toList(),
        'depositNote':
            'The programme contribution is a one-time deposit under the '
            'selected option. There is no further vehicle payment under the '
            'stated ownership offer, subject to programme approval, '
            'verification and the applicable terms of the final agreement.',
      },
    );
