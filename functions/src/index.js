/**
 * CrickFlow Cloud Functions — entry point.
 *
 * Deploy: firebase deploy --only functions
 * Docs:   docs/FUNCTIONS.md
 */
const { initializeApp } = require('firebase-admin/app');

initializeApp();

const { onMatchCompleted } = require('./match/onMatchCompleted');
const { onMatchLive } = require('./match/onMatchLive');
const { onBallEventCreated } = require('./match/onBallEventCreated');
const { onMatchRevisionCreated } = require('./match/onMatchRevisionCreated');
const { onMatchBreak } = require('./match/onMatchBreak');
const { verifyScoringIntegrity } = require('./match/verifyScoringIntegrity');
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

exports.onMatchCompleted = onMatchCompleted;
exports.onMatchLive = onMatchLive;
exports.onBallEventCreated = onBallEventCreated;
exports.onMatchRevisionCreated = onMatchRevisionCreated;
exports.onMatchBreak = onMatchBreak;
exports.verifyScoringIntegrity = verifyScoringIntegrity;
exports.syncPublicScorecard = syncPublicScorecard;
exports.syncPublicOverlay = syncPublicOverlay;
exports.adminVerifyMatchIntegrity = adminVerifyMatchIntegrity;
exports.adminPreviewMatchStatsFromEvents = adminPreviewMatchStatsFromEvents;
exports.adminReprocessMatchStats = adminReprocessMatchStats;
exports.onNotificationCreated = onNotificationCreated;
exports.onTeamJoinRequestCreated = onTeamJoinRequestCreated;
exports.onTeamRosterReportCreated = onTeamRosterReportCreated;
