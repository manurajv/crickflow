/**
 * Calendar-day expiry for community tournament looking posts
 * (Teams wanted / Officials needed). Mirrors Dart helper
 * `tournament_looking_post_visibility.dart`.
 */

function calendarDay(date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === 'function') return value.toDate();
  const d = new Date(String(value));
  return Number.isNaN(d.getTime()) ? null : d;
}

function isTournamentLookingPost(data) {
  if (!data || typeof data !== 'object') return false;
  if (data.category === 'tournamentNeed') return true;
  if (data.postKind !== 'tournament') return false;
  const title = String(data.title || '')
    .trim()
    .toLowerCase();
  return title === 'teams wanted' || title === 'officials needed';
}

/**
 * @param {object} data Firestore community_posts document data
 * @param {Date} [now]
 * @returns {boolean}
 */
function isTournamentLookingPostExpired(data, now = new Date()) {
  if (!isTournamentLookingPost(data)) return false;

  const snap = data.tournamentSnapshot;
  if (!snap || typeof snap !== 'object') return false;

  const today = calendarDay(now);

  const end = parseDate(snap.endDate);
  if (end) {
    const endDay = calendarDay(end);
    if (endDay < today) return true;
  }

  const start = parseDate(snap.startDate);
  if (start) {
    const startDay = calendarDay(start);
    if (startDay <= today) return true;
  }

  return false;
}

module.exports = {
  calendarDay,
  isTournamentLookingPost,
  isTournamentLookingPostExpired,
};
