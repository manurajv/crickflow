const { google } = require('googleapis');
const {
  getYouTubeTokens,
  storeYouTubeTokens,
  readYouTubeOAuthCredentials,
  normalizeOAuthSecret,
} = require('./youtubeOAuth');

function requireYouTubeEnv() {
  return readYouTubeOAuthCredentials();
}

function oauthErrorMessage(err) {
  return (
    err?.response?.data?.error_description ||
    err?.response?.data?.error ||
    err?.message ||
    String(err)
  );
}

async function persistAuthCredentials(uid, auth, tokens) {
  const creds = auth.credentials;
  const refreshToken = creds.refresh_token
    ? normalizeOAuthSecret(creds.refresh_token)
    : normalizeOAuthSecret(tokens.refreshToken);
  await storeYouTubeTokens(uid, {
    refreshToken,
    accessToken: creds.access_token || null,
    expiresAt: creds.expiry_date
      ? new Date(creds.expiry_date).toISOString()
      : null,
    channelId: tokens.channelId,
    channelTitle: tokens.channelTitle,
  });
}

async function getYouTubeClient(uid) {
  const tokens = await getYouTubeTokens(uid);
  if (!tokens?.refreshToken) {
    throw new Error('YouTube not linked — tap Connect YouTube account first');
  }
  const { clientId, clientSecret } = requireYouTubeEnv();
  const auth = new google.auth.OAuth2(clientId, clientSecret);
  const refreshToken = normalizeOAuthSecret(tokens.refreshToken);
  auth.setCredentials({
    refresh_token: refreshToken,
    ...(tokens.accessToken
      ? {
          access_token: tokens.accessToken,
          expiry_date: tokens.expiresAt
            ? Date.parse(tokens.expiresAt)
            : undefined,
        }
      : {}),
  });

  try {
    await auth.getAccessToken();
  } catch (err) {
    const message = oauthErrorMessage(err);
    if (/invalid_grant/i.test(message)) {
      throw new Error(
        'YouTube sign-in expired — open stream setup and connect your Google account again.',
      );
    }
    throw new Error(message);
  }

  await persistAuthCredentials(uid, auth, tokens);
  return google.youtube({ version: 'v3', auth });
}

/**
 * Fetches the authenticated user's channel and stores id/title on token doc.
 */
async function syncYouTubeChannel(uid) {
  const youtube = await getYouTubeClient(uid);
  const res = await youtube.channels.list({
    part: ['snippet'],
    mine: true,
  });
  const channel = res.data.items?.[0];
  if (!channel) {
    throw new Error('No YouTube channel found for this Google account');
  }
  const existing = await getYouTubeTokens(uid);
  await storeYouTubeTokens(uid, {
    refreshToken: existing.refreshToken,
    accessToken: existing.accessToken,
    expiresAt: existing.expiresAt,
    channelId: channel.id,
    channelTitle: channel.snippet?.title || 'YouTube channel',
  });
  return {
    id: channel.id,
    title: channel.snippet?.title || 'YouTube channel',
  };
}

async function listYouTubeChannels(uid) {
  const tokens = await getYouTubeTokens(uid);
  if (!tokens?.refreshToken) return [];
  if (tokens.channelId) {
    return [
      {
        id: tokens.channelId,
        title: tokens.channelTitle || 'YouTube channel',
      },
    ];
  }
  try {
    const channel = await syncYouTubeChannel(uid);
    return [channel];
  } catch (_) {
    return [];
  }
}

function mapPrivacy(visibility) {
  if (visibility === 'private') return 'private';
  if (visibility === 'unlisted') return 'unlisted';
  return 'public';
}

const YOUTUBE_CATEGORY_IDS = {
  Sports: '17',
  Gaming: '20',
  Entertainment: '24',
  News: '25',
};

function mapCategoryId(category) {
  if (!category) return '17';
  return YOUTUBE_CATEGORY_IDS[category] || '17';
}

async function uploadYouTubeThumbnail(youtube, videoId, thumbnailBase64, mimeType) {
  if (!thumbnailBase64) return;
  const buffer = Buffer.from(thumbnailBase64, 'base64');
  if (buffer.length > 2 * 1024 * 1024) {
    throw new Error('Thumbnail must be under 2 MB');
  }
  await youtube.thumbnails.set({
    videoId,
    media: {
      mimeType: mimeType || 'image/jpeg',
      body: buffer,
    },
  });
}

async function applyYouTubeVideoMetadata(youtube, videoId, options) {
  const categoryId = mapCategoryId(options.category);
  await youtube.videos.update({
    part: ['snippet', 'status'],
    requestBody: {
      id: videoId,
      snippet: {
        title: options.title || 'CrickFlow Live',
        description: options.description || '',
        categoryId,
        defaultLanguage: options.language || 'en',
        tags: Array.isArray(options.tags) ? options.tags.slice(0, 10) : [],
      },
      status: {
        privacyStatus: mapPrivacy(options.visibility),
        selfDeclaredMadeForKids: false,
        embeddable: true,
        publicStatsViewable: true,
      },
    },
  });
}

/**
 * Forces "Allow embedding" on the live video + broadcast so in-app scorecard playback works.
 * Called on create and again when the broadcast transitions to live (YouTube can reset flags).
 */
async function ensureYouTubeLiveEmbeddable(youtube, broadcastId) {
  if (!broadcastId) return;

  try {
    const videoRes = await youtube.videos.list({
      part: ['status'],
      id: [broadcastId],
      maxResults: 1,
    });
    const currentStatus = videoRes.data.items?.[0]?.status;
    if (currentStatus) {
      await youtube.videos.update({
        part: ['status'],
        requestBody: {
          id: broadcastId,
          status: {
            ...currentStatus,
            embeddable: true,
          },
        },
      });
    }
  } catch (err) {
    console.warn(
      'YouTube embeddable (video) update skipped:',
      err?.message || err,
    );
  }

  try {
    await youtube.liveBroadcasts.update({
      part: ['contentDetails'],
      requestBody: {
        id: broadcastId,
        contentDetails: {
          enableEmbed: true,
        },
      },
    });
  } catch (err) {
    console.warn(
      'YouTube enableEmbed (broadcast) update skipped:',
      err?.message || err,
    );
  }
}

/**
 * Creates YouTube live broadcast + ingest stream and binds them.
 */
async function createYouTubeLiveBroadcast(uid, options) {
  const youtube = await getYouTubeClient(uid);
  const scheduledStart =
    options.scheduledAt || new Date().toISOString();
  const privacyStatus = mapPrivacy(options.visibility);
  const autoStart = options.goLiveImmediately === true;

  const broadcastRes = await youtube.liveBroadcasts.insert({
    part: ['snippet', 'status', 'contentDetails'],
    requestBody: {
      snippet: {
        title: options.title || 'CrickFlow Live',
        description: options.description || '',
        scheduledStartTime: scheduledStart,
        categoryId: mapCategoryId(options.category),
        defaultLanguage: options.language || 'en',
        tags: Array.isArray(options.tags) ? options.tags.slice(0, 10) : [],
      },
      status: {
        privacyStatus,
        selfDeclaredMadeForKids: false,
      },
      contentDetails: {
        enableAutoStart: autoStart,
        enableAutoStop: true,
        enableDvr: true,
        enableEmbed: true,
        recordFromStart: true,
        startWithSlate: false,
      },
    },
  });

  const broadcast = broadcastRes.data;
  if (!broadcast?.id) {
    throw new Error('YouTube did not return a broadcast id');
  }

  await applyYouTubeVideoMetadata(youtube, broadcast.id, options);

  if (options.thumbnailBase64) {
    try {
      await uploadYouTubeThumbnail(
        youtube,
        broadcast.id,
        options.thumbnailBase64,
        options.thumbnailMimeType,
      );
    } catch (err) {
      console.warn(
        'YouTube thumbnail upload skipped:',
        err?.message || err,
      );
    }
  }

  const streamRes = await youtube.liveStreams.insert({
    part: ['snippet', 'cdn', 'contentDetails'],
    requestBody: {
      snippet: {
        title: `${options.title || 'CrickFlow Live'} — RTMP`,
      },
      cdn: {
        // Variable lets YouTube auto-detect the ingested resolution/frame rate
        // (e.g. 720p or 1080p) instead of forcing a fixed 720p ingest.
        frameRate: 'variable',
        ingestionType: 'rtmp',
        resolution: 'variable',
      },
      contentDetails: {
        isReusable: false,
      },
    },
  });

  const stream = streamRes.data;
  if (!stream?.id) {
    throw new Error('YouTube did not return a stream id');
  }

  await youtube.liveBroadcasts.bind({
    id: broadcast.id,
    part: ['id', 'contentDetails'],
    streamId: stream.id,
  });

  await ensureYouTubeLiveEmbeddable(youtube, broadcast.id);

  const ingestion = stream.cdn?.ingestionInfo || {};
  return {
    rtmpUrl: ingestion.ingestionAddress || 'rtmp://a.rtmp.youtube.com/live2',
    streamKey: ingestion.streamName || '',
    watchUrl: `https://www.youtube.com/live/${broadcast.id}`,
    broadcastId: broadcast.id,
    streamId: stream.id,
  };
}

/**
 * Ends a YouTube live broadcast (marks it complete in YouTube Studio).
 */
async function endYouTubeLiveBroadcast(uid, broadcastId) {
  if (!broadcastId) {
    throw new Error('broadcastId required');
  }
  const youtube = await getYouTubeClient(uid);
  await youtube.liveBroadcasts.transition({
    id: broadcastId,
    broadcastStatus: 'complete',
    part: ['id', 'status'],
  });
  return { ok: true, broadcastId };
}

/**
 * Read-only live chat messages for an active broadcast video id.
 */
async function getYouTubeLiveChat(uid, videoId) {
  if (!videoId) {
    throw new Error('videoId or broadcastId required');
  }
  const youtube = await getYouTubeClient(uid);
  const videoRes = await youtube.videos.list({
    part: ['liveStreamingDetails'],
    id: [videoId],
  });
  const liveChatId =
    videoRes.data.items?.[0]?.liveStreamingDetails?.activeLiveChatId;
  if (!liveChatId) {
    return { messages: [], liveChatId: null };
  }

  const chatRes = await youtube.liveChatMessages.list({
    liveChatId,
    part: ['snippet', 'authorDetails'],
    maxResults: 25,
  });

  const messages = (chatRes.data.items || []).map((item) => ({
    id: item.id,
    text: item.snippet?.displayMessage || '',
    author: item.authorDetails?.displayName || 'Viewer',
    publishedAt: item.snippet?.publishedAt,
  }));

  return { messages, liveChatId };
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function isYouTubeIngestActive(youtube, broadcast, streamIdHint) {
  const streamStatus = broadcast.status?.streamStatus || null;
  if (streamStatus === 'active' || streamStatus === 'good') {
    return true;
  }

  const boundStreamId =
    streamIdHint || broadcast.contentDetails?.boundStreamId || null;
  if (!boundStreamId) return false;

  const streamRes = await youtube.liveStreams.list({
    part: ['status'],
    id: [boundStreamId],
    maxResults: 1,
  });
  const ingestStatus = streamRes.data.items?.[0]?.status?.streamStatus;
  return ingestStatus === 'active' || ingestStatus === 'good';
}

/**
 * Transitions an API-created broadcast to live after RTMP ingest is active.
 */
async function transitionYouTubeBroadcastToLive(uid, broadcastId, streamId) {
  if (!broadcastId) {
    throw new Error('broadcastId required');
  }
  const youtube = await getYouTubeClient(uid);

  for (let attempt = 0; attempt < 40; attempt += 1) {
    const res = await youtube.liveBroadcasts.list({
      part: ['status', 'contentDetails'],
      id: [broadcastId],
      maxResults: 1,
    });
    const broadcast = res.data.items?.[0];
    if (!broadcast) {
      throw new Error('YouTube broadcast not found');
    }

    const lifeCycleStatus = broadcast.status?.lifeCycleStatus || 'unknown';
    const streamStatus = broadcast.status?.streamStatus || null;
    const streamActive = await isYouTubeIngestActive(
      youtube,
      broadcast,
      streamId,
    );

    if (lifeCycleStatus === 'live') {
      await ensureYouTubeLiveEmbeddable(youtube, broadcastId);
      return { ok: true, broadcastId, lifeCycleStatus, streamStatus };
    }
    if (lifeCycleStatus === 'complete' || lifeCycleStatus === 'revoked') {
      throw new Error('YouTube broadcast already ended');
    }

    if (lifeCycleStatus === 'ready' && streamActive) {
      try {
        await youtube.liveBroadcasts.transition({
          id: broadcastId,
          broadcastStatus: 'testing',
          part: ['status'],
        });
        await sleep(1500);
        continue;
      } catch (err) {
        const reason = err?.message || '';
        if (
          !reason.includes('invalidTransition') &&
          !reason.includes('redundantTransition')
        ) {
          throw err;
        }
      }
    }

    if (lifeCycleStatus === 'testing' || streamActive) {
      try {
        const transitioned = await youtube.liveBroadcasts.transition({
          id: broadcastId,
          broadcastStatus: 'live',
          part: ['status'],
        });
        await ensureYouTubeLiveEmbeddable(youtube, broadcastId);
        return {
          ok: true,
          broadcastId,
          lifeCycleStatus:
            transitioned.data?.status?.lifeCycleStatus || 'live',
          streamStatus: transitioned.data?.status?.streamStatus || streamStatus,
        };
      } catch (err) {
        const reason = err?.message || '';
        if (
          !reason.includes('invalidTransition') &&
          !reason.includes('redundantTransition')
        ) {
          throw err;
        }
      }
    }

    await sleep(2500);
  }

  throw new Error(
    'YouTube did not go live — check Studio or try again in a moment',
  );
}

/**
 * Returns YouTube live broadcast lifecycle status for app-side sync.
 */
async function getYouTubeBroadcastStatus(uid, broadcastId) {
  if (!broadcastId) {
    throw new Error('broadcastId required');
  }
  const youtube = await getYouTubeClient(uid);
  const res = await youtube.liveBroadcasts.list({
    part: ['status', 'snippet'],
    id: [broadcastId],
    maxResults: 1,
  });
  const broadcast = res.data.items?.[0];
  if (!broadcast) {
    return { broadcastId, lifeCycleStatus: 'not_found', streamStatus: null };
  }
  return {
    broadcastId,
    lifeCycleStatus: broadcast.status?.lifeCycleStatus || 'unknown',
    streamStatus: broadcast.status?.streamStatus || null,
    title: broadcast.snippet?.title || '',
  };
}

module.exports = {
  syncYouTubeChannel,
  listYouTubeChannels,
  createYouTubeLiveBroadcast,
  endYouTubeLiveBroadcast,
  transitionYouTubeBroadcastToLive,
  getYouTubeLiveChat,
  getYouTubeBroadcastStatus,
};
