Map<String, dynamic> channelToJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'image': row['image'],
    'category': row['category'],
    'description': row['description'],
    'isPremium': (row['is_premium'] as int) == 1,
    'isLive': (row['is_live'] as int) == 1,
    'streamUrl': row['stream_url'],
    if (row['player_engine'] != null) 'playerEngine': row['player_engine'],
    if (row['drm_type'] != null) 'drmType': row['drm_type'],
    if (row['drm_license_url'] != null) 'drmLicenseUrl': row['drm_license_url'],
    if (row['drm_clear_key'] != null) 'drmClearKey': row['drm_clear_key'],
    'sortOrder': row['sort_order'],
    'enabled': (row['enabled'] as int) == 1,
  };
}

Map<String, dynamic> channelToAppJson(Map<String, Object?> row) {
  final json = channelToJson(row);
  json.remove('enabled');
  json.remove('sortOrder');
  return json;
}

Map<String, dynamic> carouselToJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'image': row['image'],
    'title': row['title'],
    'link': row['link'],
    'sortOrder': row['sort_order'],
    'enabled': (row['enabled'] as int) == 1,
  };
}

Map<String, dynamic> carouselToAppJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'image': row['image'],
    'title': row['title'],
    if ((row['link'] as String).isNotEmpty) 'link': row['link'],
  };
}

Map<String, dynamic> pricingToJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'durationDays': row['duration_days'],
    'price': row['price'],
    'originalPrice': row['original_price'],
    'enabled': (row['enabled'] as int) == 1,
    'sortOrder': row['sort_order'],
  };
}

Map<String, dynamic> pricingToAppJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'durationDays': row['duration_days'],
    'price': row['price'],
    'originalPrice': row['original_price'],
  };
}

Map<String, dynamic> userToJson(Map<String, Object?> row) {
  return {
    'id': row['id'],
    'name': row['name'],
    'phone': row['phone'],
    'packageType': row['package_type'],
    'expiryDate': row['expiry_date'],
    'createdAt': row['created_at'],
  };
}

bool parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return defaultValue;
}

int parseInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? defaultValue;
}

double parseDouble(dynamic value, {double defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? defaultValue;
}
