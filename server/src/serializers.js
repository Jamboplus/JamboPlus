function parseBool(value, defaultValue = false) {
  if (value == null) return defaultValue;
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    return value.toLowerCase() === 'true' || value === '1';
  }
  return defaultValue;
}

function parseIntSafe(value, defaultValue = 0) {
  if (value == null) return defaultValue;
  if (typeof value === 'number') return Math.trunc(value);
  const n = Number.parseInt(String(value), 10);
  return Number.isNaN(n) ? defaultValue : n;
}

function parseDouble(value, defaultValue = 0) {
  if (value == null) return defaultValue;
  if (typeof value === 'number') return value;
  const n = Number.parseFloat(String(value));
  return Number.isNaN(n) ? defaultValue : n;
}

function channelToJson(row) {
  const json = {
    id: row.id,
    name: row.name,
    image: row.image,
    category: row.category,
    description: row.description,
    isPremium: row.is_premium === 1,
    isLive: row.is_live === 1,
    streamUrl: row.stream_url,
    sortOrder: row.sort_order,
    enabled: row.enabled === 1,
  };
  if (row.player_engine != null) json.playerEngine = row.player_engine;
  if (row.drm_type != null) json.drmType = row.drm_type;
  if (row.drm_license_url != null) json.drmLicenseUrl = row.drm_license_url;
  if (row.drm_clear_key != null) json.drmClearKey = row.drm_clear_key;
  return json;
}

function channelToAppJson(row) {
  const json = channelToJson(row);
  delete json.enabled;
  delete json.sortOrder;
  return json;
}

function carouselToJson(row) {
  return {
    id: row.id,
    image: row.image,
    title: row.title,
    link: row.link,
    sortOrder: row.sort_order,
    enabled: row.enabled === 1,
  };
}

function carouselToAppJson(row) {
  const json = {
    id: row.id,
    image: row.image,
    title: row.title,
  };
  if (row.link) json.link = row.link;
  return json;
}

function pricingToJson(row) {
  return {
    id: row.id,
    name: row.name,
    durationDays: row.duration_days,
    price: row.price,
    originalPrice: row.original_price,
    enabled: row.enabled === 1,
    sortOrder: row.sort_order,
  };
}

function pricingToAppJson(row) {
  return {
    id: row.id,
    name: row.name,
    durationDays: row.duration_days,
    price: row.price,
    originalPrice: row.original_price,
  };
}

function userToJson(row) {
  return {
    id: row.id,
    name: row.name,
    phone: row.phone,
    packageType: row.package_type,
    expiryDate: row.expiry_date,
    createdAt: row.created_at,
  };
}

function appConfigForBootstrap(row) {
  return {
    playerEngine: row.player_engine,
    drmType: row.drm_type,
    streamOrigin: row.stream_origin,
    streamReferer: row.stream_referer,
    userAgent: row.user_agent,
    tokenRefreshUrl: row.token_refresh_url,
    streamUserId: row.stream_user_id,
    appApiKey: row.app_api_key,
    maintenanceMode: row.maintenance_mode === 1,
  };
}

function appConfigForAdmin(row) {
  return {
    ...appConfigForBootstrap(row),
    appApiSecret: row.app_api_secret,
  };
}

module.exports = {
  parseBool,
  parseInt: parseIntSafe,
  parseDouble,
  channelToJson,
  channelToAppJson,
  carouselToJson,
  carouselToAppJson,
  pricingToJson,
  pricingToAppJson,
  userToJson,
  appConfigForBootstrap,
  appConfigForAdmin,
};
