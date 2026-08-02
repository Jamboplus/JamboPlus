import 'dart:io';

import 'package:shelf/shelf_io.dart';

import 'package:jamboad_server/config/env.dart';
import 'package:jamboad_server/db/database.dart';
import 'package:jamboad_server/router.dart';

Future<void> main(List<String> args) async {
  final env = Env.load();
  final db = AppDatabase.open(env);

  final handler = buildHandler(env, db);
  final server = await serve(handler, env.host, env.port);

  print('JamboAd server listening on http://${server.address.host}:${server.port}');
  print('Database: ${env.dbPath}');

  ProcessSignal.sigint.watch().listen((_) async {
    print('Shutting down...');
    await server.close(force: true);
    db.close();
    exit(0);
  });
}
