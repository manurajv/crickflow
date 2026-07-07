const { getFirestore } = require('firebase-admin/firestore');

const db = getFirestore();

const TOKEN_DOC = (uid) => `streaming_credentials/${uid}`;

/** Trim whitespace/newlines — piped `firebase secrets:set` often adds a trailing LF. */
function normalizeOAuthSecret(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function readYouTubeOAuthCredentials() {
  const clientId = normalizeOAuthSecret(process.env.YOUTUBE_CLIENT_ID);
  const clientSecret = normalizeOAuthSecret(process.env.YOUTUBE_CLIENT_SECRET);
  if (!clientId || !clientSecret) {
    throw new Error(
      'Set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET on Cloud Functions',
    );
  }
  if (!clientId.endsWith('.apps.googleusercontent.com')) {
    throw new Error(
      'YOUTUBE_CLIENT_ID must be the Firebase Web OAuth client (…apps.googleusercontent.com)',
    );
  }
  return { clientId, clientSecret };
}

/**
 * Persists OAuth refresh token for YouTube Live API (server-side only).
 */
async function storeYouTubeTokens(uid, tokens) {
  const snap = await db.doc(TOKEN_DOC(uid)).get();
  const existing = snap.data()?.youtube || {};
  const refreshToken =
    tokens.refreshToken != null
      ? normalizeOAuthSecret(tokens.refreshToken)
      : existing.refreshToken;
  if (!refreshToken) {
    throw new Error('refreshToken required');
  }
  await db.doc(TOKEN_DOC(uid)).set(
    {
      youtube: {
        refreshToken,
        accessToken:
          tokens.accessToken !== undefined
            ? tokens.accessToken
            : existing.accessToken || null,
        expiresAt:
          tokens.expiresAt !== undefined
            ? tokens.expiresAt
            : existing.expiresAt || null,
        channelId:
          tokens.channelId !== undefined
            ? tokens.channelId
            : existing.channelId || null,
        channelTitle:
          tokens.channelTitle !== undefined
            ? tokens.channelTitle
            : existing.channelTitle || null,
        updatedAt: new Date().toISOString(),
      },
    },
    { merge: true },
  );
}

async function getYouTubeTokens(uid) {
  const snap = await db.doc(TOKEN_DOC(uid)).get();
  return snap.data()?.youtube || null;
}

/**
 * Exchange Google server auth code for refresh token (OAuth web client).
 */
async function exchangeServerAuthCode(serverAuthCode) {
  const { clientId, clientSecret } = readYouTubeOAuthCredentials();

  const body = new URLSearchParams({
    code: serverAuthCode.trim(),
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: 'authorization_code',
    // Android/iOS server auth codes require an empty redirect_uri.
    redirect_uri: '',
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  const data = await res.json();
  if (!res.ok) {
    const description = data.error_description || data.error || 'Token exchange failed';
    if (
      data.error === 'invalid_client' &&
      /oauth client was not found/i.test(description)
    ) {
      throw new Error(
        'OAuth client not found — set YOUTUBE_CLIENT_ID to the Firebase Web client ' +
          '(same value as kYouTubeWebClientId), redeploy functions, and avoid trailing ' +
          'newlines when saving secrets. See docs/STREAMING_SETUP.md.',
      );
    }
    throw new Error(description);
  }

  return {
    refreshToken: data.refresh_token
      ? normalizeOAuthSecret(data.refresh_token)
      : null,
    accessToken: data.access_token || null,
    expiresAt: data.expires_in
      ? new Date(Date.now() + data.expires_in * 1000).toISOString()
      : null,
  };
}

module.exports = {
  storeYouTubeTokens,
  getYouTubeTokens,
  exchangeServerAuthCode,
  readYouTubeOAuthCredentials,
  normalizeOAuthSecret,
  TOKEN_DOC,
};
