const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const fs = require('fs');

function loadServiceAccount() {
  const jsonEnv = (process.env.FCM_SERVICE_ACCOUNT_JSON || '').trim();
  if (jsonEnv) {
    return JSON.parse(jsonEnv);
  }
  const path = (process.env.FCM_SERVICE_ACCOUNT_PATH || '').trim();
  if (path && fs.existsSync(path)) {
    return JSON.parse(fs.readFileSync(path, 'utf8'));
  }
  const projectId = (process.env.FCM_PROJECT_ID || '').trim();
  const clientEmail = (process.env.FCM_CLIENT_EMAIL || '').trim();
  const privateKey = (process.env.FCM_PRIVATE_KEY || '').trim().replace(/\\n/g, '\n');
  if (projectId && clientEmail && privateKey) {
    return { project_id: projectId, client_email: clientEmail, private_key: privateKey };
  }
  return null;
}

function ensureFirebase() {
  if (getApps().length > 0) return true;
  const sa = loadServiceAccount();
  if (!sa) return false;
  initializeApp({
    credential: cert({
      projectId: sa.project_id,
      clientEmail: sa.client_email,
      privateKey: sa.private_key,
    }),
  });
  return true;
}

function topicForTarget(target) {
  const t = String(target || 'all').trim().toLowerCase();
  if (t === 'premium') return 'premium_users';
  if (t === 'free') return 'free_users';
  return 'all_users';
}

const androidPushConfig = {
  priority: 'high',
  ttl: 28 * 24 * 60 * 60 * 1000,
  notification: {
    channelId: 'supasoka_high_importance',
    defaultSound: true,
    priority: 'high',
    visibility: 'public',
  },
};

/**
 * Fan-out a SupaAdmin-mirrored push to JamboPlus FCM topics.
 */
async function sendPushToTopic({ title, body, target = 'all' }) {
  if (!ensureFirebase()) {
    throw new Error('FCM credentials missing on JamboPlus API');
  }
  const topic = topicForTarget(target);
  const message = {
    topic,
    notification: { title: String(title).trim(), body: String(body).trim() },
    data: {
      target: String(target || 'all'),
      source: 'supaadmin',
    },
    android: androidPushConfig,
  };
  const messageId = await getMessaging().send(message);
  return { topic, messageId };
}

function fcmReady() {
  try {
    return ensureFirebase();
  } catch (_) {
    return false;
  }
}

module.exports = { sendPushToTopic, fcmReady, topicForTarget };
