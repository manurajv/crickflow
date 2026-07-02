const { google } = require('googleapis');
const { getYouTubeTokens, storeYouTubeTokens } = require('./youtubeOAuth');

function requireYouTubeEnv() {
  const clientId = process.env.YOUTUBE_CLIENT_ID;
  const clientSecret = process.env.YOUTUBE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    throw new Error(
      'Set YOUTUBE_CLIENT_ID and YOUTUBE_CLIENT_SECRET on Cloud Functions',
    );
  }
  return { clientId, clientSecret };
}

async function getYouTubeClient(uid) {
  const tokens = await getYouTubeTokens(uid);
  if (!tokens?.refreshToken) {
    throw new Error('YouTube not linked — tap Connect YouTube account first');
  }
  const { clientId, clientSecret } = requireYouTubeEnv();
  const auth = new google.auth.OAuth2(clientId, clientSecret);
  auth.setCredentials({ refresh_token: tokens.refreshToken });
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

/**
 * Creates YouTube live broadcast + ingest stream and binds them.
 */
async function createYouTubeLiveBroadcast(uid, options) {
  const youtube = await getYouTubeClient(uid);
  const scheduledStart = new Date().toISOString();
  const privacyStatus = mapPrivacy(options.visibility);
  const autoStart = options.goLiveImmediately === true;

  const broadcastRes = await youtube.liveBroadcasts.insert({
    part: ['snippet', 'status', 'contentDetails'],
    requestBody: {
      snippet: {
        title: options.title || 'CrickFlow Live',
        description: options.description || '',
        scheduledStartTime: scheduledStart,
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

  const streamRes = await youtube.liveStreams.insert({
    part: ['snippet', 'cdn', 'contentDetails'],
    requestBody: {
      snippet: {
        title: `${options.title || 'CrickFlow Live'} — RTMP`,
      },
      cdn: {
        frameRate: '30fps',
        ingestionType: 'rtmp',
        resolution: '720p',
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

  const ingestion = stream.cdn?.ingestionInfo || {};
  return {
    rtmpUrl: ingestion.ingestionAddress || 'rtmp://a.rtmp.youtube.com/live2',
    streamKey: ingestion.streamName || '',
    watchUrl: `https://www.youtube.com/watch?v=${broadcast.id}`,
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

module.exports = {
  syncYouTubeChannel,
  listYouTubeChannels,
  createYouTubeLiveBroadcast,
  endYouTubeLiveBroadcast,
  getYouTubeLiveChat,
};
