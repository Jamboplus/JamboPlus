/// Resolves API base URL: `--dart-define=JAMBO_API_URL` overrides everything.
/// Defaults to Railway production so admin-managed content is always fetched live.
abstract final class ApiConfig {
  static const _productionUrl = 'https://jamboplus-production.up.railway.app';

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('JAMBO_API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _productionUrl;
  }
}
