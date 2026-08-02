const DEFAULT_BASE = 'https://api.sonicpesa.com';
const SONICPESA_TIMEOUT_MS = 28_000;
const API_ENVELOPE_STATUSES = new Set(['success', 'error', 'failed', 'failure', 'ok']);

function sonicHeaders() {
  const h = {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    'X-API-KEY': process.env.SONICPESA_API_KEY || '',
  };
  const secret =
    process.env.SONICPESA_SECRET_KEY ||
    process.env.SONICPESA_API_SECRET ||
    process.env.SONICPESA_SECRETE_KEY ||
    '';
  if (secret.trim()) {
    h['X-SECRET-KEY'] = secret.trim();
    h['X-API-SECRET'] = secret.trim();
  }
  return h;
}

function sonicpesaConfigured() {
  return Boolean((process.env.SONICPESA_API_KEY || '').trim());
}

/** Local `07…` / `06…` or `255…` → `2557XXXXXXXX`. */
function normalizeTzPhone(raw) {
  let digits = String(raw || '').replace(/\D/g, '');
  if (!digits) return null;

  if (digits.startsWith('255') && digits.length >= 12) {
    digits = digits.slice(3, 12);
  } else if (digits.startsWith('0') && digits.length >= 10) {
    digits = digits.slice(0, 10).slice(1);
  } else if (digits.length === 9 && /^[67]/.test(digits)) {
    // keep 9-digit national
  } else {
    return null;
  }

  if (!/^[67]\d{8}$/.test(digits)) return null;
  return `255${digits}`;
}

/** National `0XXXXXXXXX` for DB / display. */
function toLocalTzPhone(raw) {
  const intl = normalizeTzPhone(raw);
  if (!intl || !intl.startsWith('255') || intl.length !== 12) return null;
  return `0${intl.slice(3)}`;
}

function phoneCandidatesForSonic(local0) {
  const local = toLocalTzPhone(local0) || String(local0 || '').trim();
  const intl = normalizeTzPhone(local0);
  const isHalotel = /^(061|062|063)/.test(local);
  const isAirtel = /^(068|069|078)/.test(local);
  if (isHalotel || isAirtel) {
    return [...new Set([local, intl].filter(Boolean))];
  }
  return [...new Set([intl, local].filter(Boolean))];
}

function normalizePaymentStatus(raw) {
  return String(raw ?? '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

function isSonicpesaSuccess(status) {
  const s = normalizePaymentStatus(status);
  return (
    s === 'SUCCESS' ||
    s === 'SUCCESSFUL' ||
    s === 'COMPLETED' ||
    s === 'PAID' ||
    s === 'COMPLETE' ||
    s === 'SUCCEEDED' ||
    s === 'APPROVED' ||
    s === 'CONFIRMED' ||
    s === 'SETTLED' ||
    s === 'COLLECTED' ||
    s === 'PAYMENT_COMPLETED' ||
    s === 'TRANSACTION_SUCCESS' ||
    s === 'PAYMENT_SUCCESS'
  );
}

function isSonicpesaFailure(status) {
  const s = normalizePaymentStatus(status);
  return (
    s === 'CANCELLED' ||
    s === 'CANCELED' ||
    s === 'CANCEL' ||
    s === 'USERCANCELLED' ||
    s === 'REJECTED' ||
    s === 'DECLINED' ||
    s === 'FAILED' ||
    s === 'FAILURE' ||
    s === 'EXPIRED' ||
    s === 'TIMEOUT' ||
    s === 'ERROR' ||
    s === 'VOID'
  );
}

function unwrapSonicpesaBody(raw) {
  const data = raw.data;
  const fromData = data && typeof data === 'object' && !Array.isArray(data) ? data : null;
  const osd = fromData?.order_status_data ?? raw.order_status_data;
  const fromOsd = osd && typeof osd === 'object' && !Array.isArray(osd) ? osd : null;
  return { ...raw, ...(fromData || {}), ...(fromOsd || {}) };
}

function sonicpesaApiError(raw, httpStatus) {
  const topStatus = String(raw.status ?? '')
    .trim()
    .toLowerCase();
  if (topStatus === 'error' || topStatus === 'failed' || topStatus === 'failure') {
    return String(raw.message ?? raw.error ?? 'SonicPesa rejected the request').trim();
  }
  if (!httpStatus || httpStatus < 400) return undefined;
  return String(raw.error ?? raw.message ?? `SonicPesa HTTP ${httpStatus}`).trim();
}

function readOrderId(body) {
  return String(body.order_id ?? body.orderId ?? body.id ?? '').trim();
}

function readPaymentStatus(body) {
  const statusField = body.status;
  const statusStr = typeof statusField === 'string' ? statusField.trim().toLowerCase() : '';
  const statusIsPayment = statusStr.length > 0 && !API_ENVELOPE_STATUSES.has(statusStr);
  return normalizePaymentStatus(
    body.payment_status ?? body.order_status ?? (statusIsPayment ? statusField : undefined) ?? 'PENDING',
  );
}

async function sonicpesaPost(path, payload) {
  const base = (process.env.SONICPESA_BASE_URL || DEFAULT_BASE).replace(/\/+$/, '');
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), SONICPESA_TIMEOUT_MS);
  try {
    const res = await fetch(`${base}${path}`, {
      method: 'POST',
      headers: sonicHeaders(),
      body: JSON.stringify(payload),
      signal: ctrl.signal,
    });
    const raw = (await res.json().catch(() => ({}))) || {};
    return { ok: true, res, raw };
  } catch (e) {
    const name = e instanceof Error ? e.name : '';
    if (name === 'TimeoutError' || name === 'AbortError') {
      return { ok: false, error: 'SonicPesa request timed out' };
    }
    return { ok: false, error: 'SonicPesa is unreachable' };
  } finally {
    clearTimeout(timer);
  }
}

async function sonicpesaCreateOrder(input) {
  const phones = phoneCandidatesForSonic(input.buyer_phone);
  let last = { ok: false, error: 'SonicPesa did not return an order id' };

  for (const buyer_phone of phones.length ? phones : [input.buyer_phone]) {
    const posted = await sonicpesaPost('/api/v1/payment/create_order', {
      ...input,
      buyer_phone,
    });
    if (!posted.ok) {
      last = { ok: false, error: posted.error };
      continue;
    }

    const { res, raw } = posted;
    const apiError = sonicpesaApiError(raw, res.status);
    if (apiError && !res.ok) {
      last = { ok: false, error: apiError, raw };
      continue;
    }
    if (!res.ok) {
      last = { ok: false, error: apiError || `SonicPesa HTTP ${res.status}`, raw };
      continue;
    }

    const body = unwrapSonicpesaBody(raw);
    const orderId = readOrderId(body);
    const paymentStatus = readPaymentStatus(body);
    const wrappedError = sonicpesaApiError(raw, 0);

    if (orderId && !wrappedError) {
      return {
        ok: true,
        order_id: orderId,
        reference: String(body.reference ?? body.ref ?? '').trim() || undefined,
        payment_status: paymentStatus,
        status: paymentStatus,
        amount: Number(body.amount ?? input.amount),
        currency: String(body.currency ?? input.currency),
        buyer_phone,
        raw,
      };
    }
    last = {
      ok: false,
      error: wrappedError || 'SonicPesa did not return an order id',
      raw,
    };
  }

  return last;
}

async function sonicpesaOrderStatus(orderId) {
  const posted = await sonicpesaPost('/api/v1/payment/order_status', { order_id: orderId });
  if (!posted.ok) return { ok: false, error: posted.error };

  const { res, raw } = posted;
  const apiError = sonicpesaApiError(raw, res.status);
  if (!res.ok) {
    return { ok: false, error: apiError || `SonicPesa HTTP ${res.status}`, raw };
  }
  if (apiError) return { ok: false, error: apiError, raw };

  const body = unwrapSonicpesaBody(raw);
  const paymentStatus = readPaymentStatus(body);
  return {
    ok: true,
    order_id: readOrderId(body) || orderId,
    payment_status: paymentStatus,
    status: paymentStatus,
    reference: String(body.reference ?? '').trim() || undefined,
    amount: body.amount != null ? Number(body.amount) : undefined,
    currency: body.currency != null ? String(body.currency) : undefined,
    raw,
  };
}

module.exports = {
  sonicpesaConfigured,
  normalizeTzPhone,
  toLocalTzPhone,
  normalizePaymentStatus,
  isSonicpesaSuccess,
  isSonicpesaFailure,
  sonicpesaCreateOrder,
  sonicpesaOrderStatus,
};
