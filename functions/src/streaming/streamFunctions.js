const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore } = require('firebase-admin/firestore');
const { fanOutMatchNotification } = require('../utils/fanOut');
const {
  storeYouTubeTokens,
  exchangeServerAuthCode,
} = require('./youtubeOAuth');
const {
  syncYouTubeChannel,
  listYouTubeChannels,
  createYouTubeLiveBroadcast,
  endYouTubeLiveBroadcast,
  transitionYouTubeBroadcastToLive,
  getYouTubeLiveChat,
  getYouTubeBroadcastStatus,
} = require('./youtubeLive');

const youtubeClientId = defineSecret('YOUTUBE_CLIENT_ID');
const youtubeClientSecret = defineSecret('YOUTUBE_CLIENT_SECRET');

const youtubeSecrets = [youtubeClientId, youtubeClientSecret];

function bindYouTubeSecrets() {
  process.env.YOUTUBE_CLIENT_ID = youtubeClientId.value();
  process.env.YOUTUBE_CLIENT_SECRET = youtubeClientSecret.value();
}

const db = getFirestore();

function formatChapterTime(ms) {
  const totalSeconds = Math.max(0, Math.floor((ms || 0) / 1000));
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) {
    return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds
      .toString()
      .padStart(2, '0')}`;
  }
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

/**
 * Notifies followers when a match stream goes live or ends.
 */
exports.onStreamStatusChanged = onDocumentUpdated(
  'matches/{matchId}',
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before?.stream || !after?.stream) return;

    const prevStatus = before.stream.status;
    const nextStatus = after.stream.status;
    if (prevStatus === nextStatus) return;

    const matchId = event.params.matchId;
    if (nextStatus === 'live') {
      await fanOutMatchNotification(
        db,
        matchId,
        after,
        {
          title: 'Live stream started',
          body: `${after.title || 'Match'} is streaming now on CrickFlow`,
          type: 'stream_started',
        },
        'stream_started',
      );
    } else if (nextStatus === 'ended' && prevStatus === 'live') {
      await fanOutMatchNotification(
        db,
        matchId,
        after,
        {
          title: 'Stream ended',
          body: `Live stream for ${after.title || 'match'} has ended`,
          type: 'stream_ended',
        },
        'stream_ended',
      );
    }
  },
);

exports.linkYouTubeAccount = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { serverAuthCode } = request.data || {};
  if (!serverAuthCode) {
    throw new HttpsError('invalid-argument', 'serverAuthCode required');
  }
  try {
    bindYouTubeSecrets();
    const tokens = await exchangeServerAuthCode(serverAuthCode);
    if (!tokens.refreshToken) {
      throw new HttpsError(
        'failed-precondition',
        'No refresh token — revoke CrickFlow in Google Account and retry',
      );
    }
    await storeYouTubeTokens(request.auth.uid, tokens);
    const channel = await syncYouTubeChannel(request.auth.uid);
    return { ok: true, channel };
  } catch (err) {
    throw new HttpsError('failed-precondition', err.message || 'Link failed');
  }
});

exports.storeStreamingOAuthToken = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { provider, refreshToken, accessToken, expiresAt, channelId } =
    request.data || {};
  if (provider !== 'youtube' || !refreshToken) {
    throw new HttpsError(
      'invalid-argument',
      'provider=youtube and refreshToken required',
    );
  }
  await storeYouTubeTokens(request.auth.uid, {
    refreshToken,
    accessToken,
    expiresAt,
    channelId,
  });
  return { ok: true };
});

exports.createYouTubeLiveStream = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { title, description, visibility, channelId, language, tags, goLiveImmediately } =
    request.data || {};

  try {
    bindYouTubeSecrets();
    return await createYouTubeLiveBroadcast(request.auth.uid, {
      title: title || 'CrickFlow Live',
      description: description || '',
      visibility: visibility || 'public',
      channelId,
      language: language || 'en',
      tags: tags || [],
      goLiveImmediately: goLiveImmediately === true,
    });
  } catch (err) {
    const message = err.message || 'YouTube live creation failed';
    throw new HttpsError('failed-precondition', message);
  }
});

exports.endYouTubeLiveStream = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { broadcastId } = request.data || {};
  if (!broadcastId) {
    throw new HttpsError('invalid-argument', 'broadcastId required');
  }
  try {
    bindYouTubeSecrets();
    return await endYouTubeLiveBroadcast(request.auth.uid, broadcastId);
  } catch (err) {
    throw new HttpsError('failed-precondition', err.message || 'YouTube end failed');
  }
});

exports.listYouTubeChannels = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  try {
    bindYouTubeSecrets();
    const channels = await listYouTubeChannels(request.auth.uid);
    return { channels };
  } catch (_) {
    return { channels: [] };
  }
});

exports.getYouTubeLiveChat = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { videoId, broadcastId } = request.data || {};
  const id = videoId || broadcastId;
  if (!id) {
    throw new HttpsError('invalid-argument', 'videoId or broadcastId required');
  }
  try {
    bindYouTubeSecrets();
    return await getYouTubeLiveChat(request.auth.uid, id);
  } catch (err) {
    throw new HttpsError('failed-precondition', err.message || 'Chat unavailable');
  }
});

exports.getYouTubeBroadcastStatus = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { broadcastId } = request.data || {};
  if (!broadcastId) {
    throw new HttpsError('invalid-argument', 'broadcastId required');
  }
  try {
    bindYouTubeSecrets();
    return await getYouTubeBroadcastStatus(request.auth.uid, broadcastId);
  } catch (err) {
    throw new HttpsError('failed-precondition', err.message || 'Status unavailable');
  }
});

exports.startYouTubeLiveBroadcast = onCall({ secrets: youtubeSecrets }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { broadcastId } = request.data || {};
  if (!broadcastId) {
    throw new HttpsError('invalid-argument', 'broadcastId required');
  }
  try {
    bindYouTubeSecrets();
    return await transitionYouTubeBroadcastToLive(request.auth.uid, broadcastId);
  } catch (err) {
    throw new HttpsError('failed-precondition', err.message || 'YouTube go-live failed');
  }
});

exports.exportYouTubeChapters = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  const { matchId } = request.data || {};
  if (!matchId) {
    throw new HttpsError('invalid-argument', 'matchId required');
  }

  const snap = await db
    .collection('matches')
    .doc(matchId)
    .collection('replayMarkers')
    .orderBy('streamOffsetMs')
    .get();

  const lines = snap.docs.map((doc) => {
    const m = doc.data();
    const time = formatChapterTime(m.streamOffsetMs);
    const kind = m.kind ? `[${m.kind}] ` : '';
    return `${time} ${kind}${m.label || 'Highlight'}`;
  });

  const chaptersText = lines.join('\n');
  const descriptionBlock = lines.length
    ? `\n\n--- Match highlights (paste into YouTube description) ---\n${chaptersText}`
    : '';

  return {
    chaptersText,
    descriptionBlock,
    count: lines.length,
    format: 'youtube_description',
  };
});

exports.createFacebookLiveStream = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  throw new HttpsError(
    'failed-precondition',
    'Facebook Live API not configured — paste RTMP stream key manually',
  );
});

exports.createTwitchLiveStream = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in required');
  }
  throw new HttpsError(
    'failed-precondition',
    'Twitch API not configured — paste stream key manually from Twitch Dashboard',
  );
});
