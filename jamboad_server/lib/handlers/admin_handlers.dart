import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

import '../config/env.dart';
import '../db/database.dart';
import '../middleware/app_signature.dart';
import '../util/http.dart';
import '../util/jwt_util.dart';
import '../util/password.dart';
import '../util/serializers.dart';

const _uuid = Uuid();

Future<Response> adminLoginHandler(Request request, Env env, AppDatabase db) async {
  try {
    final body = await readJsonBody(request);
    final email = (body['email'] as String?)?.trim().toLowerCase();
    final password = body['password'] as String?;
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return errorResponse(400, 'email and password required');
    }

    final rows = db.raw.select(
      'SELECT id, email, password_hash, role FROM admins WHERE email = ?',
      [email],
    );
    if (rows.isEmpty) {
      return errorResponse(401, 'Invalid credentials');
    }
    final row = rows.first;
    if (!verifyPassword(password, row['password_hash'] as String)) {
      return errorResponse(401, 'Invalid credentials');
    }

    final token = issueAdminToken(
      env,
      AdminClaims(
        adminId: row['id'] as String,
        email: row['email'] as String,
        role: row['role'] as String,
      ),
    );

    return jsonResponse({
      'token': token,
      'expiresInHours': 24,
      'admin': {
        'id': row['id'],
        'email': row['email'],
        'role': row['role'],
      },
    });
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> dashboardHandler(Request request, AdminClaims admin, AppDatabase db) async {
  final userCount =
      db.raw.select('SELECT COUNT(*) AS c FROM users').first['c'] as int;
  final premiumCount = db.raw
      .select(
        '''
        SELECT COUNT(*) AS c FROM users
        WHERE package_type = 'premium'
          AND (expiry_date IS NULL OR expiry_date >= ?)
        ''',
        [DateTime.now().toUtc().toIso8601String()],
      )
      .first['c'] as int;
  final channelCount =
      db.raw.select('SELECT COUNT(*) AS c FROM channels').first['c'] as int;

  final today = DateTime.now().toUtc();
  final dateKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final revRows = db.raw.select(
    'SELECT amount, transaction_count FROM revenue_daily WHERE date = ?',
    [dateKey],
  );
  final todayRevenue =
      revRows.isEmpty ? 0.0 : (revRows.first['amount'] as num).toDouble();
  final todayTransactions = revRows.isEmpty
      ? 0
      : revRows.first['transaction_count'] as int;

  return jsonResponse({
    'userCount': userCount,
    'premiumCount': premiumCount,
    'channelCount': channelCount,
    'todayRevenue': todayRevenue,
    'todayTransactionCount': todayTransactions,
  });
}

// --- Users ---

Future<Response> listUsersHandler(Request request, AdminClaims admin, AppDatabase db) async {
  final rows = db.raw.select('SELECT * FROM users ORDER BY created_at DESC');
  return jsonResponse(rows.map(userToJson).toList());
}

Future<Response> getUserHandler(Request request, AdminClaims admin, AppDatabase db, String id) async {
  final rows = db.raw.select('SELECT * FROM users WHERE id = ?', [id]);
  if (rows.isEmpty) return errorResponse(404, 'User not found');
  return jsonResponse(userToJson(rows.first));
}

Future<Response> createUserHandler(Request request, AdminClaims admin, AppDatabase db) async {
  try {
    final body = await readJsonBody(request);
    final name = body['name'] as String? ?? 'Free User';
    final phone = body['phone'] as String? ?? '';
    final packageType = body['packageType'] as String? ?? 'free';
    final expiryDate = body['expiryDate'] as String?;
    final id = _uuid.v4();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    db.raw.execute(
      '''
      INSERT INTO users (id, name, phone, package_type, expiry_date, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [id, name, phone, packageType, expiryDate, createdAt],
    );
    db.audit(admin.adminId, 'user.create:$id');
    return jsonResponse(userToJson({
      'id': id,
      'name': name,
      'phone': phone,
      'package_type': packageType,
      'expiry_date': expiryDate,
      'created_at': createdAt,
    }), statusCode: 201);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> updateUserHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT id FROM users WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'User not found');

  try {
    final body = await readJsonBody(request);
    final name = body['name'] as String?;
    final phone = body['phone'] as String?;
    final packageType = body['packageType'] as String?;
    final expiryDate = body.containsKey('expiryDate')
        ? body['expiryDate'] as String?
        : null;
    final hasExpiry = body.containsKey('expiryDate');

    if (name != null) {
      db.raw.execute('UPDATE users SET name = ? WHERE id = ?', [name, id]);
    }
    if (phone != null) {
      db.raw.execute('UPDATE users SET phone = ? WHERE id = ?', [phone, id]);
    }
    if (packageType != null) {
      db.raw.execute(
        'UPDATE users SET package_type = ? WHERE id = ?',
        [packageType, id],
      );
    }
    if (hasExpiry) {
      db.raw.execute(
        'UPDATE users SET expiry_date = ? WHERE id = ?',
        [expiryDate, id],
      );
    }

    db.audit(admin.adminId, 'user.update:$id');
    return getUserHandler(request, admin, db, id);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> deleteUserHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT id FROM users WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'User not found');
  db.raw.execute('DELETE FROM users WHERE id = ?', [id]);
  db.audit(admin.adminId, 'user.delete:$id');
  return jsonResponse({'deleted': true});
}

// --- Channels ---

Future<Response> listChannelsAdminHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  final rows =
      db.raw.select('SELECT * FROM channels ORDER BY sort_order ASC, name ASC');
  return jsonResponse(rows.map(channelToJson).toList());
}

Future<Response> getChannelHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final rows = db.raw.select('SELECT * FROM channels WHERE id = ?', [id]);
  if (rows.isEmpty) return errorResponse(404, 'Channel not found');
  return jsonResponse(channelToJson(rows.first));
}

Future<Response> createChannelHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  try {
    final body = await readJsonBody(request);
    final id = (body['id'] as String?)?.trim().isNotEmpty == true
        ? body['id'] as String
        : _uuid.v4();
    final name = body['name'] as String?;
    if (name == null || name.isEmpty) {
      return errorResponse(400, 'name required');
    }

    db.raw.execute(
      '''
      INSERT INTO channels (
        id, name, image, category, description, is_premium, is_live,
        stream_url, player_engine, drm_type, drm_license_url, drm_clear_key,
        sort_order, enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        name,
        body['image'] as String? ?? '',
        body['category'] as String? ?? 'Bure',
        body['description'] as String? ?? '',
        parseBool(body['isPremium']) ? 1 : 0,
        parseBool(body['isLive']) ? 1 : 0,
        body['streamUrl'] as String? ?? '',
        body['playerEngine'] as String?,
        body['drmType'] as String?,
        body['drmLicenseUrl'] as String?,
        body['drmClearKey'] as String?,
        parseInt(body['sortOrder']),
        parseBool(body['enabled'], defaultValue: true) ? 1 : 0,
      ],
    );
    db.audit(admin.adminId, 'channel.create:$id');
    return jsonResponse(
      channelToJson(
        db.raw.select('SELECT * FROM channels WHERE id = ?', [id]).first,
      ),
      statusCode: 201,
    );
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> updateChannelHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT * FROM channels WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Channel not found');

  try {
    final body = await readJsonBody(request);
    final current = Map<String, Object?>.from(existing.first);

    db.raw.execute(
      '''
      UPDATE channels SET
        name = ?, image = ?, category = ?, description = ?,
        is_premium = ?, is_live = ?, stream_url = ?,
        player_engine = ?, drm_type = ?, drm_license_url = ?, drm_clear_key = ?,
        sort_order = ?, enabled = ?
      WHERE id = ?
      ''',
      [
        body['name'] as String? ?? current['name'],
        body['image'] as String? ?? current['image'],
        body['category'] as String? ?? current['category'],
        body['description'] as String? ?? current['description'],
        parseBool(body['isPremium'], defaultValue: (current['is_premium'] as int) == 1)
            ? 1
            : 0,
        parseBool(body['isLive'], defaultValue: (current['is_live'] as int) == 1)
            ? 1
            : 0,
        body['streamUrl'] as String? ?? current['stream_url'],
        body.containsKey('playerEngine')
            ? body['playerEngine'] as String?
            : current['player_engine'],
        body.containsKey('drmType')
            ? body['drmType'] as String?
            : current['drm_type'],
        body.containsKey('drmLicenseUrl')
            ? body['drmLicenseUrl'] as String?
            : current['drm_license_url'],
        body.containsKey('drmClearKey')
            ? body['drmClearKey'] as String?
            : current['drm_clear_key'],
        body.containsKey('sortOrder')
            ? parseInt(body['sortOrder'])
            : current['sort_order'],
        parseBool(
          body['enabled'],
          defaultValue: (current['enabled'] as int) == 1,
        )
            ? 1
            : 0,
        id,
      ],
    );
    db.audit(admin.adminId, 'channel.update:$id');
    return getChannelHandler(request, admin, db, id);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> deleteChannelHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT id FROM channels WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Channel not found');
  db.raw.execute('DELETE FROM channels WHERE id = ?', [id]);
  db.audit(admin.adminId, 'channel.delete:$id');
  return jsonResponse({'deleted': true});
}

// --- Carousel ---

Future<Response> listCarouselAdminHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  final rows =
      db.raw.select('SELECT * FROM carousel ORDER BY sort_order ASC');
  return jsonResponse(rows.map(carouselToJson).toList());
}

Future<Response> getCarouselItemHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final rows = db.raw.select('SELECT * FROM carousel WHERE id = ?', [id]);
  if (rows.isEmpty) return errorResponse(404, 'Carousel item not found');
  return jsonResponse(carouselToJson(rows.first));
}

Future<Response> createCarouselHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  try {
    final body = await readJsonBody(request);
    final id = (body['id'] as String?)?.trim().isNotEmpty == true
        ? body['id'] as String
        : _uuid.v4();
    final image = body['image'] as String?;
    final title = body['title'] as String?;
    if (image == null || title == null) {
      return errorResponse(400, 'image and title required');
    }

    db.raw.execute(
      '''
      INSERT INTO carousel (id, image, title, link, sort_order, enabled)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        image,
        title,
        body['link'] as String? ?? '',
        parseInt(body['sortOrder']),
        parseBool(body['enabled'], defaultValue: true) ? 1 : 0,
      ],
    );
    db.audit(admin.adminId, 'carousel.create:$id');
    return jsonResponse(
      carouselToJson(db.raw.select('SELECT * FROM carousel WHERE id = ?', [id]).first),
      statusCode: 201,
    );
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> updateCarouselHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT * FROM carousel WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Carousel item not found');

  try {
    final body = await readJsonBody(request);
    final current = Map<String, Object?>.from(existing.first);

    db.raw.execute(
      '''
      UPDATE carousel SET image = ?, title = ?, link = ?, sort_order = ?, enabled = ?
      WHERE id = ?
      ''',
      [
        body['image'] as String? ?? current['image'],
        body['title'] as String? ?? current['title'],
        body['link'] as String? ?? current['link'],
        body.containsKey('sortOrder')
            ? parseInt(body['sortOrder'])
            : current['sort_order'],
        parseBool(
          body['enabled'],
          defaultValue: (current['enabled'] as int) == 1,
        )
            ? 1
            : 0,
        id,
      ],
    );
    db.audit(admin.adminId, 'carousel.update:$id');
    return getCarouselItemHandler(request, admin, db, id);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> deleteCarouselHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT id FROM carousel WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Carousel item not found');
  db.raw.execute('DELETE FROM carousel WHERE id = ?', [id]);
  db.audit(admin.adminId, 'carousel.delete:$id');
  return jsonResponse({'deleted': true});
}

// --- Pricing ---

Future<Response> listPricingAdminHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  final rows =
      db.raw.select('SELECT * FROM pricing ORDER BY sort_order ASC');
  return jsonResponse(rows.map(pricingToJson).toList());
}

Future<Response> getPricingHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final rows = db.raw.select('SELECT * FROM pricing WHERE id = ?', [id]);
  if (rows.isEmpty) return errorResponse(404, 'Pricing plan not found');
  return jsonResponse(pricingToJson(rows.first));
}

Future<Response> createPricingHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  try {
    final body = await readJsonBody(request);
    final id = _uuid.v4();
    final name = body['name'] as String?;
    if (name == null || name.isEmpty) {
      return errorResponse(400, 'name required');
    }

    db.raw.execute(
      '''
      INSERT INTO pricing (id, name, duration_days, price, original_price, enabled, sort_order)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        id,
        name,
        parseInt(body['durationDays'], defaultValue: 30),
        parseDouble(body['price']),
        parseDouble(body['originalPrice']),
        parseBool(body['enabled'], defaultValue: true) ? 1 : 0,
        parseInt(body['sortOrder']),
      ],
    );
    db.audit(admin.adminId, 'pricing.create:$id');
    return jsonResponse(
      pricingToJson(db.raw.select('SELECT * FROM pricing WHERE id = ?', [id]).first),
      statusCode: 201,
    );
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> updatePricingHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT * FROM pricing WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Pricing plan not found');

  try {
    final body = await readJsonBody(request);
    final current = Map<String, Object?>.from(existing.first);

    db.raw.execute(
      '''
      UPDATE pricing SET
        name = ?, duration_days = ?, price = ?, original_price = ?,
        enabled = ?, sort_order = ?
      WHERE id = ?
      ''',
      [
        body['name'] as String? ?? current['name'],
        body.containsKey('durationDays')
            ? parseInt(body['durationDays'])
            : current['duration_days'],
        body.containsKey('price')
            ? parseDouble(body['price'])
            : (current['price'] as num).toDouble(),
        body.containsKey('originalPrice')
            ? parseDouble(body['originalPrice'])
            : (current['original_price'] as num).toDouble(),
        parseBool(
          body['enabled'],
          defaultValue: (current['enabled'] as int) == 1,
        )
            ? 1
            : 0,
        body.containsKey('sortOrder')
            ? parseInt(body['sortOrder'])
            : current['sort_order'],
        id,
      ],
    );
    db.audit(admin.adminId, 'pricing.update:$id');
    return getPricingHandler(request, admin, db, id);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}

Future<Response> deletePricingHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
  String id,
) async {
  final existing = db.raw.select('SELECT id FROM pricing WHERE id = ?', [id]);
  if (existing.isEmpty) return errorResponse(404, 'Pricing plan not found');
  db.raw.execute('DELETE FROM pricing WHERE id = ?', [id]);
  db.audit(admin.adminId, 'pricing.delete:$id');
  return jsonResponse({'deleted': true});
}

// --- App config ---

Future<Response> getAppConfigAdminHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  final row = loadAppConfigRow(db);
  return jsonResponse(appConfigForAdmin(row));
}

Future<Response> putAppConfigAdminHandler(
  Request request,
  AdminClaims admin,
  AppDatabase db,
) async {
  try {
    final body = await readJsonBody(request);
    final current = loadAppConfigRow(db);

    db.raw.execute(
      '''
      UPDATE app_config SET
        player_engine = ?, drm_type = ?, stream_origin = ?, stream_referer = ?,
        user_agent = ?, token_refresh_url = ?, stream_user_id = ?,
        app_api_key = ?, app_api_secret = ?, maintenance_mode = ?
      WHERE id = 1
      ''',
      [
        body['playerEngine'] as String? ?? current['player_engine'],
        body['drmType'] as String? ?? current['drm_type'],
        body['streamOrigin'] as String? ?? current['stream_origin'],
        body['streamReferer'] as String? ?? current['stream_referer'],
        body['userAgent'] as String? ?? current['user_agent'],
        body['tokenRefreshUrl'] as String? ?? current['token_refresh_url'],
        body['streamUserId'] as String? ?? current['stream_user_id'],
        body['appApiKey'] as String? ?? current['app_api_key'],
        body['appApiSecret'] as String? ?? current['app_api_secret'],
        parseBool(
          body['maintenanceMode'],
          defaultValue: (current['maintenance_mode'] as int) == 1,
        )
            ? 1
            : 0,
      ],
    );
    db.audit(admin.adminId, 'app_config.update');
    return getAppConfigAdminHandler(request, admin, db);
  } on FormatException {
    return errorResponse(400, 'Invalid JSON body');
  }
}
