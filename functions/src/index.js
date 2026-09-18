/**
 * CrickFlow Cloud Functions — entry point.
 *
 * Deploy: firebase deploy --only functions
 * Docs:   docs/FUNCTIONS.md
 */
const { initializeApp } = require('firebase-admin/app');
const { setGlobalOptions } = require('firebase-functions/v2');

initializeApp();

// 0.25 vCPU per service keeps ~35 Cloud Run functions under regional CPU quota.
// concurrency must be 1 when cpu < 1 (Firebase requirement).
setGlobalOptions({
  region: 'us-central1',
  memory: '256MiB',
  cpu: 0.25,
  concurrency: 1,
  maxInstances: 20,
});

const { onMatchCompleted } = require('./match/onMatchCompleted');
const { onMatchLive } = require('./match/onMatchLive');
const { onBallEventCreated } = require('./match/onBallEventCreated');
const { onMatchRevisionCreated } = require('./match/onMatchRevisionCreated');
const { onMatchBreak } = require('./match/onMatchBreak');
const { verifyScoringIntegrity } = require('./match/verifyScoringIntegrity');
const {
  cleanupExpiredTournamentLookingPosts,
} = require('./community/cleanupExpiredTournamentLookingPosts');
const {
  syncPublicScorecard,
  syncPublicOverlay,
} = require('./match/syncPublicScorecard');
const {
  adminVerifyMatchIntegrity,
  adminPreviewMatchStatsFromEvents,
  adminReprocessMatchStats,
} = require('./admin/scoringAdmin');
const { onNotificationCreated } = require('./notifications/onNotificationCreated');
const { onTeamJoinRequestCreated } = require('./notifications/onTeamJoinRequestCreated');
const { onTeamRosterReportCreated } = require('./notifications/onTeamRosterReportCreated');
const {
  onPlayerFollowWritten,
  onProfileViewWritten,
} = require('./social/onPlayerFollowWritten');
const {
  onTeamProfileViewWritten,
} = require('./social/onTeamProfileViewWritten');
const {
  onStreamStatusChanged,
  linkYouTubeAccount,
  storeStreamingOAuthToken,
  createYouTubeLiveStream,
  endYouTubeLiveStream,
  listYouTubeChannels,
  getYouTubeLiveChat,
  getYouTubeBroadcastStatus,
  startYouTubeLiveBroadcast,
  exportYouTubeChapters,
  createFacebookLiveStream,
  createTwitchLiveStream,
} = require('./streaming/streamFunctions');
const {
  lookupPlayerByPhone,
  stampProxyPlayerRegistration,
} = require('./players/lookupPlayerByPhone');
const {
  createPlayerInvite,
  acceptPlayerInvite,
} = require('./players/playerInvites');
const {
  createSeries,
  addSeriesAdmin,
  removeSeriesAdmin,
  updateSeriesSettings,
  createSeriesClub,
  reviewSeriesApproval,
  submitSeriesRegistration,
  submitPlayerJoinRequest,
  submitPlayerAddRequest,
  submitPlayerRemovalRequest,
  proposeSeriesMatch,
  proposeSeriesTournament,
  suspendSeriesEntity,
  getSeriesRegistrationIdentity,
  reviewClubJoinRequest,
  addSeriesClubAdmin,
  removeSeriesClubAdmin,
  syncSeriesApprovalMirrors,
} = require('./series/seriesFunctions');

exports.onMatchCompleted = onMatchCompleted;
exports.onMatchLive = onMatchLive;
exports.onBallEventCreated = onBallEventCreated;
exports.onMatchRevisionCreated = onMatchRevisionCreated;
exports.onMatchBreak = onMatchBreak;
exports.verifyScoringIntegrity = verifyScoringIntegrity;
exports.cleanupExpiredTournamentLookingPosts =
  cleanupExpiredTournamentLookingPosts;
exports.syncPublicScorecard = syncPublicScorecard;
exports.syncPublicOverlay = syncPublicOverlay;
exports.adminVerifyMatchIntegrity = adminVerifyMatchIntegrity;
exports.adminPreviewMatchStatsFromEvents = adminPreviewMatchStatsFromEvents;
exports.adminReprocessMatchStats = adminReprocessMatchStats;
exports.onNotificationCreated = onNotificationCreated;
exports.onTeamJoinRequestCreated = onTeamJoinRequestCreated;
exports.onTeamRosterReportCreated = onTeamRosterReportCreated;
exports.onPlayerFollowWritten = onPlayerFollowWritten;
exports.onProfileViewWritten = onProfileViewWritten;
exports.onTeamProfileViewWritten = onTeamProfileViewWritten;
exports.onStreamStatusChanged = onStreamStatusChanged;
exports.linkYouTubeAccount = linkYouTubeAccount;
exports.storeStreamingOAuthToken = storeStreamingOAuthToken;
exports.createYouTubeLiveStream = createYouTubeLiveStream;
exports.endYouTubeLiveStream = endYouTubeLiveStream;
exports.listYouTubeChannels = listYouTubeChannels;
exports.getYouTubeLiveChat = getYouTubeLiveChat;
exports.getYouTubeBroadcastStatus = getYouTubeBroadcastStatus;
exports.startYouTubeLiveBroadcast = startYouTubeLiveBroadcast;
exports.exportYouTubeChapters = exportYouTubeChapters;
exports.createFacebookLiveStream = createFacebookLiveStream;
exports.createTwitchLiveStream = createTwitchLiveStream;
exports.lookupPlayerByPhone = lookupPlayerByPhone;
exports.stampProxyPlayerRegistration = stampProxyPlayerRegistration;
exports.createPlayerInvite = createPlayerInvite;
exports.acceptPlayerInvite = acceptPlayerInvite;
exports.createSeries = createSeries;
exports.addSeriesAdmin = addSeriesAdmin;
exports.removeSeriesAdmin = removeSeriesAdmin;
exports.updateSeriesSettings = updateSeriesSettings;
exports.createSeriesClub = createSeriesClub;
exports.reviewSeriesApproval = reviewSeriesApproval;
exports.submitSeriesRegistration = submitSeriesRegistration;
exports.submitPlayerJoinRequest = submitPlayerJoinRequest;
exports.submitPlayerAddRequest = submitPlayerAddRequest;
exports.submitPlayerRemovalRequest = submitPlayerRemovalRequest;
exports.proposeSeriesMatch = proposeSeriesMatch;
exports.proposeSeriesTournament = proposeSeriesTournament;
exports.suspendSeriesEntity = suspendSeriesEntity;
exports.getSeriesRegistrationIdentity = getSeriesRegistrationIdentity;
exports.reviewClubJoinRequest = reviewClubJoinRequest;
exports.addSeriesClubAdmin = addSeriesClubAdmin;
exports.removeSeriesClubAdmin = removeSeriesClubAdmin;
exports.syncSeriesApprovalMirrors = syncSeriesApprovalMirrors;
