const { getFirestore } = require('firebase-admin/firestore');

const db = getFirestore();

const TOKEN_DOC = (uid) => `streaming_credentials/${uid}`;

/**
 * Persists OAuth refresh token for YouTube Live API (server-side only).
 */
async function storeYouTubeTokens(uid, tokens) {
  await db.doc(TOKEN_DOC(uid)).set(
    {
      youtube: {
        refreshToken: tokens.refreshToken,
        accessToken: tokens.accessToken || null,
        expiresAt: tokens.expiresAt || null,
        channelId: tokens.channelId || null,
        channelTitle: tokens.channelTitle || null,
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
  const clientId = process.env.YOUTUBE_CLIENT_ID;
  const clientSecret = process.env.YOUTUBE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error(
      'Set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET on Cloud Functions',
    );
  }

  const body = new URLSearchParams({
    code: serverAuthCode,
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: 'authorization_code',
  });

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
  });

  const data = await res.json();
  if (!res.ok) {
    throw new Error(
      data.error_description || data.error || 'Token exchange failed',
    );
  }

  return {
    refreshToken: data.refresh_token,
    accessToken: data.access_token,
    expiresAt: data.expires_in
      ? new Date(Date.now() + data.expires_in * 1000).toISOString()
      : null,
  };
}

module.exports = {
  storeYouTubeTokens,
  getYouTubeTokens,
  exchangeServerAuthCode,
  TOKEN_DOC,
};
