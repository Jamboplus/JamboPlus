import 'dart:io';

/// Runtime configuration from environment variables.
class Env {
  Env._({
    required this.port,
    required this.jwtSecret,
    required this.dbPath,
    required this.host,
  });

  final int port;
  final String jwtSecret;
  final String dbPath;
  final String host;

  static Env load() {
    final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    final jwtSecret = Platform.environment['JWT_SECRET'] ??
        'dev-jwt-secret-change-in-production';
    final dbPath = Platform.environment['DB_PATH'] ??
        '${Directory.current.path}/data/jamboad.db';
    final host = Platform.environment['HOST'] ?? '0.0.0.0';
    return Env._(
      port: port,
      jwtSecret: jwtSecret,
      dbPath: dbPath,
      host: host,
    );
  }
}
