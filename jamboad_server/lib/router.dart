import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/env.dart';
import '../db/database.dart';
import '../handlers/admin_handlers.dart';
import '../handlers/app_handlers.dart';
import '../middleware/admin_auth.dart';
import '../middleware/app_signature.dart';

Handler buildRouter(Env env, AppDatabase db) {
  final router = Router();

  router.get('/health', healthHandler);

  router.post('/v1/admin/login', (Request request) {
    return adminLoginHandler(request, env, db);
  });

  router.get(
    '/v1/admin/dashboard',
    withAdmin(env, (request, admin) => dashboardHandler(request, admin, db)),
  );

  router.get(
    '/v1/admin/users',
    withAdmin(env, (request, admin) => listUsersHandler(request, admin, db)),
  );
  router.post(
    '/v1/admin/users',
    withAdmin(env, (request, admin) => createUserHandler(request, admin, db)),
  );
  router.get('/v1/admin/users/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => getUserHandler(req, admin, db, id),
    )(request);
  });
  router.put('/v1/admin/users/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => updateUserHandler(req, admin, db, id),
    )(request);
  });
  router.delete('/v1/admin/users/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => deleteUserHandler(req, admin, db, id),
    )(request);
  });

  router.get(
    '/v1/admin/channels',
    withAdmin(
      env,
      (request, admin) => listChannelsAdminHandler(request, admin, db),
    ),
  );
  router.post(
    '/v1/admin/channels',
    withAdmin(env, (request, admin) => createChannelHandler(request, admin, db)),
  );
  router.get('/v1/admin/channels/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => getChannelHandler(req, admin, db, id),
    )(request);
  });
  router.put('/v1/admin/channels/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => updateChannelHandler(req, admin, db, id),
    )(request);
  });
  router.delete('/v1/admin/channels/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => deleteChannelHandler(req, admin, db, id),
    )(request);
  });

  router.get(
    '/v1/admin/carousel',
    withAdmin(
      env,
      (request, admin) => listCarouselAdminHandler(request, admin, db),
    ),
  );
  router.post(
    '/v1/admin/carousel',
    withAdmin(env, (request, admin) => createCarouselHandler(request, admin, db)),
  );
  router.get('/v1/admin/carousel/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => getCarouselItemHandler(req, admin, db, id),
    )(request);
  });
  router.put('/v1/admin/carousel/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => updateCarouselHandler(req, admin, db, id),
    )(request);
  });
  router.delete('/v1/admin/carousel/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => deleteCarouselHandler(req, admin, db, id),
    )(request);
  });

  router.get(
    '/v1/admin/pricing',
    withAdmin(
      env,
      (request, admin) => listPricingAdminHandler(request, admin, db),
    ),
  );
  router.post(
    '/v1/admin/pricing',
    withAdmin(env, (request, admin) => createPricingHandler(request, admin, db)),
  );
  router.get('/v1/admin/pricing/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => getPricingHandler(req, admin, db, id),
    )(request);
  });
  router.put('/v1/admin/pricing/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => updatePricingHandler(req, admin, db, id),
    )(request);
  });
  router.delete('/v1/admin/pricing/<id>', (Request request, String id) {
    return withAdmin(
      env,
      (req, admin) => deletePricingHandler(req, admin, db, id),
    )(request);
  });

  router.get(
    '/v1/admin/app-config',
    withAdmin(
      env,
      (request, admin) => getAppConfigAdminHandler(request, admin, db),
    ),
  );
  router.put(
    '/v1/admin/app-config',
    withAdmin(
      env,
      (request, admin) => putAppConfigAdminHandler(request, admin, db),
    ),
  );

  router.get(
    '/v1/app/bootstrap',
    withAppAuth(db, (request) => appBootstrapHandler(request, db)),
  );
  router.get(
    '/v1/app/channels',
    withAppAuth(db, (request) => appChannelsHandler(request, db)),
  );
  router.get(
    '/v1/app/carousel',
    withAppAuth(db, (request) => appCarouselHandler(request, db)),
  );
  router.get(
    '/v1/app/pricing',
    withAppAuth(db, (request) => appPricingHandler(request, db)),
  );

  return router.call;
}

Middleware corsMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      final response = await inner(request);
      return response.change(headers: _corsHeaders);
    };
  };
}

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
      'Origin, Content-Type, Authorization, X-Jambo-Timestamp, X-Jambo-Signature',
};

Handler buildHandler(Env env, AppDatabase db) {
  final pipeline = Pipeline()
      .addMiddleware(corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(buildRouter(env, db));
  return pipeline;
}
