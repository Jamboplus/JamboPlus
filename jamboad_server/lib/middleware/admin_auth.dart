import 'package:shelf/shelf.dart';

import '../config/env.dart';
import '../util/http.dart';
import '../util/jwt_util.dart';

typedef AdminHandler = Future<Response> Function(
  Request request,
  AdminClaims admin,
);

Middleware adminAuth(Env env) {
  return (Handler inner) {
    return (Request request) async {
      final token = bearerToken(request);
      if (token == null) {
        return errorResponse(401, 'Missing Authorization Bearer token');
      }
      try {
        final claims = verifyAdminToken(env, token);
        return inner(request.change(context: {'admin': claims}));
      } catch (_) {
        return errorResponse(401, 'Invalid or expired token');
      }
    };
  };
}

AdminClaims adminFrom(Request request) {
  return request.context['admin'] as AdminClaims;
}

Handler withAdmin(Env env, AdminHandler handler) {
  return adminAuth(env)((Request request) => handler(request, adminFrom(request)));
}
