import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../util/password.dart';
import 'database.dart';

const _uuid = Uuid();
final _random = Random.secure();

void seedIfEmpty(AppDatabase db) {
  final count =
      db.raw.select('SELECT COUNT(*) AS c FROM admins').first['c'] as int;
  if (count > 0) return;

  final adminId = _uuid.v4();
  db.raw.execute(
    'INSERT INTO admins (id, email, password_hash, role) VALUES (?, ?, ?, ?)',
    [
      adminId,
      'admin@jamboad.co.tz',
      hashPassword('Admin@Jambo2026!'),
      'superadmin',
    ],
  );

  final apiKey = 'jamboplus-dev-key';
  final apiSecret = 'jamboplus-dev-secret-change-in-production';

  db.raw.execute(
    '''
    INSERT INTO app_config (
      id, player_engine, drm_type, stream_origin, stream_referer,
      user_agent, token_refresh_url, stream_user_id,
      app_api_key, app_api_secret, maintenance_mode
    ) VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    ''',
    [
      'exoplayer',
      'none',
      '',
      '',
      'JamboPlus/1.0',
      '',
      '',
      apiKey,
      apiSecret,
    ],
  );

  for (final row in _carouselRows) {
    db.raw.execute(
      '''
      INSERT INTO carousel (id, image, title, link, sort_order, enabled)
      VALUES (?, ?, ?, ?, ?, 1)
      ''',
      row,
    );
  }

  for (final row in _pricingRows) {
    db.raw.execute(
      '''
      INSERT INTO pricing (id, name, duration_days, price, original_price, enabled, sort_order)
      VALUES (?, ?, ?, ?, ?, 1, ?)
      ''',
      row,
    );
  }

  var order = 0;
  for (final ch in _channelRows) {
    db.raw.execute(
      '''
      INSERT INTO channels (
        id, name, image, category, description, is_premium, is_live,
        stream_url, player_engine, drm_type, drm_license_url, drm_clear_key,
        sort_order, enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, 1)
      ''',
      [
        ch.$1,
        ch.$2,
        ch.$3,
        ch.$4,
        ch.$5,
        ch.$6 ? 1 : 0,
        ch.$7 ? 1 : 0,
        ch.$8,
        order++,
      ],
    );
  }

  final today = DateTime.now().toUtc();
  final dateKey =
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  db.raw.execute(
    '''
    INSERT INTO revenue_daily (date, amount, transaction_count)
    VALUES (?, 0, 0)
    ON CONFLICT(date) DO NOTHING
    ''',
    [dateKey],
  );
}

String _randomToken(int bytes) {
  final data = List<int>.generate(bytes, (_) => _random.nextInt(256));
  return base64Url.encode(data).replaceAll('=', '');
}

final _carouselRows = [
  ['1', 'https://picsum.photos/seed/soka1/800/400', 'Mpira wa Moja kwa Moja', '', 0],
  ['2', 'https://picsum.photos/seed/soka2/800/400', 'Tamthilia Bora Zaidi', '', 1],
  ['3', 'https://picsum.photos/seed/soka3/800/400', 'Habari za Leo', '', 2],
  ['4', 'https://picsum.photos/seed/soka4/800/400', 'Katuni kwa Watoto', '', 3],
];

final _pricingRows = [
  [_uuid.v4(), 'Wiki 1', 7, 2000.0, 5000.0, 0],
  [_uuid.v4(), 'Mwezi 1', 30, 5000.0, 12000.0, 1],
  [_uuid.v4(), 'Miezi 3', 90, 12000.0, 36000.0, 2],
  [_uuid.v4(), 'Mwaka 1', 365, 40000.0, 144000.0, 3],
];

// (id, name, image, category, description, isPremium, isLive, streamUrl)
final _channelRows = [
  ('b1', 'Soka TV Bure', 'https://picsum.photos/seed/bure1/400/300', 'Bure',
      'Chaneli ya mpira bure', false, true, ''),
  ('b2', 'Tamthilia Bure', 'https://picsum.photos/seed/bure2/400/300', 'Bure',
      'Tamthilia bure kila siku', false, true, ''),
  ('b3', 'Habari Bure', 'https://picsum.photos/seed/bure3/400/300', 'Bure',
      'Habari za Tanzania', false, false, ''),
  ('b4', 'Katuni Bure', 'https://picsum.photos/seed/bure4/400/300', 'Bure',
      'Katuni kwa watoto', false, true, ''),
  ('b5', 'Wanyama Bure', 'https://picsum.photos/seed/bure5/400/300', 'Bure',
      'Maisha ya wanyama', false, false, ''),
  ('m1', 'Simba SC Live', 'https://picsum.photos/seed/mpira1/500/350', 'Mpira',
      'Mechi za Simba moja kwa moja', true, true, ''),
  ('m2', 'Yanga Live', 'https://picsum.photos/seed/mpira2/500/350', 'Mpira',
      'Mechi za Yanga moja kwa moja', true, true, ''),
  ('m3', 'Ligi Kuu TZ', 'https://picsum.photos/seed/mpira3/500/350', 'Mpira',
      'Ligi Kuu Tanzania', true, true, ''),
  ('m4', 'Premier League', 'https://picsum.photos/seed/mpira4/500/350', 'Mpira',
      'Premier League ya Uingereza', true, true, ''),
  ('m5', 'Champions League', 'https://picsum.photos/seed/mpira5/500/350', 'Mpira',
      'UEFA Champions League', true, false, ''),
  ('t1', 'Selina', 'https://picsum.photos/seed/tam1/400/550', 'Tamthilia',
      'Tamthilia ya Selina', true, true, ''),
  ('t2', 'Siri ya Mtungi', 'https://picsum.photos/seed/tam2/400/550', 'Tamthilia',
      'Tamthilia ya Siri ya Mtungi', true, false, ''),
  ('t3', "Mama's Daughter", 'https://picsum.photos/seed/tam3/400/550', 'Tamthilia',
      'Tamthilia ya kuvutia', true, true, ''),
  ('t4', 'Aziza', 'https://picsum.photos/seed/tam4/400/550', 'Tamthilia',
      'Tamthilia ya Aziza', true, false, ''),
  ('h1', 'TBC Taarifa', 'https://picsum.photos/seed/hab1/200/200', 'Habari',
      'Habari za Tanzania na duniani', false, true, ''),
  ('h2', 'Clouds Media', 'https://picsum.photos/seed/hab2/200/200', 'Habari',
      'Habari, burudani na michezo', false, true, ''),
  ('h3', 'Azam TV Habari', 'https://picsum.photos/seed/hab3/200/200', 'Habari',
      'Taarifa za kila dakika', true, false, ''),
  ('h4', 'ITV Habari', 'https://picsum.photos/seed/hab4/200/200', 'Habari',
      'Habari za ndani na nje ya nchi', false, false, ''),
  ('k1', 'Cartoon Plus', 'https://picsum.photos/seed/kat1/400/300', 'Katuni',
      'Katuni za kufurahisha', false, true, ''),
  ('k2', 'Kids Zone', 'https://picsum.photos/seed/kat2/400/300', 'Katuni',
      'Burudani kwa watoto', true, false, ''),
  ('k3', 'Anime Swahili', 'https://picsum.photos/seed/kat3/400/300', 'Katuni',
      'Anime kwa Kiswahili', true, true, ''),
  ('k4', 'Funny Toons', 'https://picsum.photos/seed/kat4/400/300', 'Katuni',
      'Katuni za kuchekesha', false, false, ''),
  ('w1', 'Safari Live', 'https://picsum.photos/seed/wan1/400/300', 'Wanyama',
      'Maisha ya wanyama porini', true, true, ''),
  ('w2', 'Ocean World', 'https://picsum.photos/seed/wan2/400/300', 'Wanyama',
      'Maisha ya baharini', true, false, ''),
  ('w3', 'Bird Paradise', 'https://picsum.photos/seed/wan3/400/300', 'Wanyama',
      'Ndege wa duniani', false, true, ''),
  ('w4', 'Wild Africa', 'https://picsum.photos/seed/wan4/400/300', 'Wanyama',
      'Wanyama wa Afrika', true, false, ''),
];
