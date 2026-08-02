/// Resolves admin API base URL.
/// Override with `--dart-define=JAMBOAD_API_URL=http://127.0.0.1:8080` for local.
abstract final class AdminApiConfig {
  static const _productionUrl = 'https://jamboplus-production.up.railway.app';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('JAMBOAD_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _productionUrl;
  }
}
