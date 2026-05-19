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

exports.onMatchCompleted = onMatchCompleted;
exports.onMatchLive = onMatchLive;
exports.onBallEventCreated = onBallEventCreated;
