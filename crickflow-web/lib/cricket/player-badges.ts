import { calculateOvers } from "@/lib/cricket/format";
import { isEligibleManOfTheMatch, playerTeamIds, decidedWinnerTeamId } from "@/lib/cricket/player-trophies";
import type { BallEvent, Match } from "@/types/models";

export type CaptainBadgeStats = {
  wins: number;
  matchesAsCaptain: number;
  winPct: number;
  successfulChases: number;
  lowestDefendedScore: number;
};

export type BadgeType =
  | "batting"
  | "bowling"
  | "fielding"
  | "captaincy"
  | "career"
  | "milestone"
  | "special"
  | "team"
  | "matchHero";

export type BadgeTier = "bronze" | "silver" | "gold" | "diamond";
export type BadgeRepeatability = "repeatable" | "oneTime";

export type PlayerBadgeDefinition = {
  id: string;
  title: string;
  category: BadgeType;
  tier: BadgeTier;
  requirement: string;
  repeatability?: BadgeRepeatability;
  iconName?: string;
  progressionGroup?: string;
  groupOrder?: number;
};

export type BadgeAchievementEntry = {
  matchId: string;
  achievedAt: Date;
  performanceSnapshot: string;
  matchTitle: string;
};

export type PlayerBadgeRecord = {
  badgeId: string;
  repeatability: BadgeRepeatability;
  unlockCount: number;
  firstAchievedAt?: Date;
  lastAchievedAt?: Date;
  achievementHistory: BadgeAchievementEntry[];
  oneTimeUnlocked: boolean;
  unlockedAt?: Date;
  unlockedMatchId?: string;
  unlockPerformanceSnapshot?: string;
  unlockMatchTitle?: string;
  unlocked: boolean;
};

export type PlayerBadgeProgress = {
  definition: PlayerBadgeDefinition;
  unlocked: boolean;
  unlockCount: number;
  progress: number;
  target: number;
  earnedAt?: Date;
  firstAchievedAt?: Date;
  matchId?: string;
  achievementHistory: BadgeAchievementEntry[];
  progressToNextTier?: string | null;
  nextTierTitle?: string;
  unlockedAt?: Date;
  unlockPerformanceSnapshot?: string;
  unlockMatchTitle?: string;
};

export type CareerBadgeStats = {
  runs: number;
  wickets: number;
  sixes: number;
  catches: number;
  matchesPlayed: number;
  oversBowledBalls: number;
  runsConceded: number;
};

export const BADGE_CATALOG: PlayerBadgeDefinition[] = [
  { id: 'bat_30', title: '30 in a Match', category: 'batting', tier: 'bronze', requirement: 'Score 30+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 1 },
  { id: 'bat_50', title: '50 in a Match', category: 'batting', tier: 'silver', requirement: 'Score 50+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 2 },
  { id: 'bat_75', title: '75 in a Match', category: 'batting', tier: 'silver', requirement: 'Score 75+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 3 },
  { id: 'bat_100', title: '100 in a Match', category: 'batting', tier: 'gold', requirement: 'Score 100+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 4 },
  { id: 'bat_150', title: '150 in a Match', category: 'batting', tier: 'gold', requirement: 'Score 150+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 5 },
  { id: 'bat_200', title: '200 in a Match', category: 'batting', tier: 'diamond', requirement: 'Score 200+ runs in a match', progressionGroup: 'runs_in_match', groupOrder: 6 },
  { id: 'fast_50', title: 'Fast Fifty', category: 'batting', tier: 'gold', requirement: 'Fifty in 30 balls or fewer' },
  { id: 'fast_100', title: 'Fast Century', category: 'batting', tier: 'diamond', requirement: 'Century in 50 balls or fewer' },
  { id: 'sr_200', title: '200+ SR Match', category: 'batting', tier: 'silver', requirement: 'Strike rate 200+ (6+ balls or 21+ runs)', progressionGroup: 'strike_rate_match', groupOrder: 1 },
  { id: 'sr_250', title: '250+ SR Match', category: 'batting', tier: 'gold', requirement: 'Strike rate 250+ (6+ balls or 21+ runs)', progressionGroup: 'strike_rate_match', groupOrder: 2 },
  { id: 'sr_300', title: '300+ SR Match', category: 'batting', tier: 'diamond', requirement: 'Strike rate 300+ (6+ balls or 21+ runs)', progressionGroup: 'strike_rate_match', groupOrder: 3 },
  { id: '4s_10', title: '10 Fours Match', category: 'batting', tier: 'bronze', requirement: 'Hit 10+ fours in a match' },
  { id: '4s_15', title: '15 Fours Match', category: 'batting', tier: 'silver', requirement: 'Hit 15+ fours in a match' },
  { id: '4s_20', title: '20 Fours Match', category: 'batting', tier: 'gold', requirement: 'Hit 20+ fours in a match' },
  { id: '6s_5', title: '5 Sixes Match', category: 'batting', tier: 'bronze', requirement: 'Hit 5+ sixes in a match' },
  { id: '6s_10', title: '10 Sixes Match', category: 'batting', tier: 'silver', requirement: 'Hit 10+ sixes in a match' },
  { id: '6s_15', title: '15 Sixes Match', category: 'batting', tier: 'gold', requirement: 'Hit 15+ sixes in a match' },
  { id: 'career_runs_100', title: '100 Runs Career', category: 'batting', tier: 'bronze', requirement: '100 career runs', repeatability: 'oneTime', progressionGroup: 'career_runs', groupOrder: 1 },
  { id: 'career_runs_500', title: '500 Runs Career', category: 'batting', tier: 'silver', requirement: '500 career runs', repeatability: 'oneTime', progressionGroup: 'career_runs', groupOrder: 2 },
  { id: 'career_runs_1000', title: '1000 Runs Career', category: 'batting', tier: 'gold', requirement: '1000 career runs', repeatability: 'oneTime', progressionGroup: 'career_runs', groupOrder: 3 },
  { id: 'career_runs_5000', title: '5000 Runs Career', category: 'batting', tier: 'diamond', requirement: '5000 career runs', repeatability: 'oneTime', progressionGroup: 'career_runs', groupOrder: 4 },
  { id: 'career_runs_10000', title: '10000 Runs Career', category: 'batting', tier: 'diamond', requirement: '10000 career runs', repeatability: 'oneTime', progressionGroup: 'career_runs', groupOrder: 5 },
  { id: 'career_6s_50', title: '50 Sixes', category: 'batting', tier: 'bronze', requirement: '50 career sixes', repeatability: 'oneTime', progressionGroup: 'career_sixes', groupOrder: 1 },
  { id: 'career_6s_100', title: '100 Sixes', category: 'batting', tier: 'silver', requirement: '100 career sixes', repeatability: 'oneTime', progressionGroup: 'career_sixes', groupOrder: 2 },
  { id: 'career_6s_250', title: '250 Sixes', category: 'batting', tier: 'gold', requirement: '250 career sixes', repeatability: 'oneTime', progressionGroup: 'career_sixes', groupOrder: 3 },
  { id: 'career_6s_500', title: '500 Sixes', category: 'batting', tier: 'diamond', requirement: '500 career sixes', repeatability: 'oneTime', progressionGroup: 'career_sixes', groupOrder: 4 },
  { id: 'bowl_3', title: '3 Wicket Haul', category: 'bowling', tier: 'bronze', requirement: 'Take 3+ wickets in a match' },
  { id: 'bowl_4', title: '4 Wicket Haul', category: 'bowling', tier: 'silver', requirement: 'Take 4+ wickets in a match' },
  { id: 'bowl_5', title: '5 Wicket Haul', category: 'bowling', tier: 'gold', requirement: 'Take 5+ wickets in a match' },
  { id: 'bowl_6', title: '6 Wicket Haul', category: 'bowling', tier: 'diamond', requirement: 'Take 6+ wickets in a match' },
  { id: 'maiden', title: 'Maiden Over', category: 'bowling', tier: 'silver', requirement: 'Bowl a maiden over' },
  { id: 'career_wkts_50', title: '50 Wickets Career', category: 'bowling', tier: 'silver', requirement: '50 career wickets', repeatability: 'oneTime', progressionGroup: 'career_wickets', groupOrder: 1 },
  { id: 'career_wkts_100', title: '100 Wickets Career', category: 'bowling', tier: 'gold', requirement: '100 career wickets', repeatability: 'oneTime', progressionGroup: 'career_wickets', groupOrder: 2 },
  { id: 'career_wkts_250', title: '250 Wickets Career', category: 'bowling', tier: 'diamond', requirement: '250 career wickets', repeatability: 'oneTime', progressionGroup: 'career_wickets', groupOrder: 3 },
  { id: 'career_wkts_500', title: '500 Wickets Career', category: 'bowling', tier: 'diamond', requirement: '500 career wickets', repeatability: 'oneTime', progressionGroup: 'career_wickets', groupOrder: 4 },
  { id: 'econ_4', title: 'Economy Under 4', category: 'bowling', tier: 'gold', requirement: 'Career economy below 4 (20+ overs)', repeatability: 'oneTime' },
  { id: 'econ_3', title: 'Economy Under 3', category: 'bowling', tier: 'diamond', requirement: 'Career economy below 3 (20+ overs)', repeatability: 'oneTime' },
  { id: 'catch_3', title: '3 Catches Match', category: 'fielding', tier: 'bronze', requirement: '3+ catches in a match' },
  { id: 'catch_5', title: '5 Catches Match', category: 'fielding', tier: 'gold', requirement: '5+ catches in a match' },
  { id: 'ro_direct', title: 'Direct Hit Run Out', category: 'fielding', tier: 'silver', requirement: 'Direct hit run out in a match' },
  { id: 'ro_2', title: '2 Run Outs Match', category: 'fielding', tier: 'gold', requirement: '2+ run outs in a match' },
  { id: 'safe_hands', title: 'Safe Hands', category: 'fielding', tier: 'silver', requirement: '5+ dismissals in a match' },
  { id: 'career_catch_50', title: '50 Catches', category: 'fielding', tier: 'bronze', requirement: '50 career catches', repeatability: 'oneTime', progressionGroup: 'career_catches', groupOrder: 1 },
  { id: 'career_catch_100', title: '100 Catches', category: 'fielding', tier: 'gold', requirement: '100 career catches', repeatability: 'oneTime', progressionGroup: 'career_catches', groupOrder: 2 },
  { id: 'career_catch_250', title: '250 Catches', category: 'fielding', tier: 'diamond', requirement: '250 career catches', repeatability: 'oneTime', progressionGroup: 'career_catches', groupOrder: 3 },
  { id: 'cap_wins_10', title: '10 Wins', category: 'captaincy', tier: 'bronze', requirement: '10 wins as captain', repeatability: 'oneTime', progressionGroup: 'captain_wins', groupOrder: 1 },
  { id: 'cap_wins_25', title: '25 Wins', category: 'captaincy', tier: 'silver', requirement: '25 wins as captain', repeatability: 'oneTime', progressionGroup: 'captain_wins', groupOrder: 2 },
  { id: 'cap_wins_50', title: '50 Wins', category: 'captaincy', tier: 'gold', requirement: '50 wins as captain', repeatability: 'oneTime', progressionGroup: 'captain_wins', groupOrder: 3 },
  { id: 'cap_wins_100', title: '100 Wins', category: 'captaincy', tier: 'diamond', requirement: '100 wins as captain', repeatability: 'oneTime', progressionGroup: 'captain_wins', groupOrder: 4 },
  { id: 'winning_machine', title: 'Winning Machine', category: 'captaincy', tier: 'gold', requirement: '70%+ win rate as captain (10+ matches)', repeatability: 'oneTime' },
  { id: 'chase_master', title: 'Successful Chase Master', category: 'captaincy', tier: 'silver', requirement: '5+ successful chases as captain', repeatability: 'oneTime' },
  { id: 'defender', title: 'Defender', category: 'captaincy', tier: 'silver', requirement: 'Defend a target of 100+ as captain', repeatability: 'oneTime' },
  { id: 'debut', title: 'Debut Match', category: 'career', tier: 'bronze', requirement: 'Play your first match', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 1 },
  { id: 'matches_25', title: '25 Matches', category: 'career', tier: 'bronze', requirement: 'Play 25 matches', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 2 },
  { id: 'matches_50', title: '50 Matches', category: 'career', tier: 'silver', requirement: 'Play 50 matches', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 3 },
  { id: 'matches_100', title: '100 Matches', category: 'career', tier: 'gold', requirement: 'Play 100 matches', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 4 },
  { id: 'matches_250', title: '250 Matches', category: 'career', tier: 'gold', requirement: 'Play 250 matches', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 5 },
  { id: 'matches_500', title: '500 Matches', category: 'career', tier: 'diamond', requirement: 'Play 500 matches', repeatability: 'oneTime', progressionGroup: 'matches_played', groupOrder: 6 },
  { id: 'veteran', title: 'Veteran', category: 'career', tier: 'gold', requirement: 'Play 200+ matches', repeatability: 'oneTime' },
  { id: 'legend', title: 'Legend', category: 'career', tier: 'diamond', requirement: 'Play 1000+ matches', repeatability: 'oneTime' },
  { id: 'all_round_match', title: 'Century + 5 Wickets Same Match', category: 'special', tier: 'diamond', requirement: '100+ runs and 5+ wickets in same match' },
  { id: 'potm_streak', title: 'Player Of Match Streak', category: 'special', tier: 'gold', requirement: '2 consecutive Player Of Match awards' },
  { id: 'all_round_hero', title: 'All Round Hero', category: 'special', tier: 'gold', requirement: '50+ runs and 3+ wickets in same match' },
  { id: 'iron_man', title: 'Iron Man', category: 'special', tier: 'silver', requirement: 'Play 10 matches in 30 days', repeatability: 'oneTime' },
  { id: 'finisher', title: 'Finisher', category: 'special', tier: 'gold', requirement: '30+ runs at SR 150+ batting second' },
  { id: 'super_over_hero', title: 'Super Over Hero', category: 'special', tier: 'diamond', requirement: 'Top scorer in a super over match' },
  { id: 'first_century', title: 'First Century', category: 'special', tier: 'gold', requirement: 'Score your first 100 in a match', repeatability: 'oneTime' },
  { id: 'first_five_wicket', title: 'First Five Wicket Haul', category: 'special', tier: 'gold', requirement: 'Take your first 5 wickets in a match', repeatability: 'oneTime' },
  { id: 'first_hat_trick', title: 'First Hat-trick', category: 'special', tier: 'gold', requirement: 'Take your first hat-trick', repeatability: 'oneTime' },
  { id: 'first_motm', title: 'First Man of the Match', category: 'special', tier: 'gold', requirement: 'First Player of the Match award', repeatability: 'oneTime' },
  { id: 'first_mvp_rank', title: 'First MVP #1 Rank', category: 'special', tier: 'diamond', requirement: 'Reach #1 on the MVP leaderboard', repeatability: 'oneTime' },
  { id: 'tournament_winner', title: 'Tournament Winner', category: 'special', tier: 'gold', requirement: 'Win a tournament match', repeatability: 'oneTime' },
  { id: 'captain_champion', title: 'Captain Champion', category: 'special', tier: 'gold', requirement: 'Win a tournament match as captain', repeatability: 'oneTime' },
];

export function qualifiesForSrBadge(runs: number, balls: number): boolean {
  return balls >= 6 || runs > 20;
}

function strikeRate(runs: number, balls: number): number {
  if (balls <= 0) return 0;
  return (runs / balls) * 100;
}

class MutableRecord {
  repeatability: BadgeRepeatability;
  history: BadgeAchievementEntry[] = [];
  oneTimeUnlocked = false;

  constructor(repeatability: BadgeRepeatability) {
    this.repeatability = repeatability;
  }

  addRepeatable(entry: BadgeAchievementEntry) {
    this.history.push(entry);
  }

  unlockOneTime(entry: BadgeAchievementEntry) {
    if (this.oneTimeUnlocked) return;
    this.oneTimeUnlocked = true;
    this.history = [entry];
  }

  toRecord(badgeId: string, repeatability: BadgeRepeatability): PlayerBadgeRecord {
    if (repeatability === "oneTime") {
      const entry = this.history[0];
      return {
        badgeId,
        repeatability: "oneTime",
        unlockCount: 0,
        achievementHistory: [],
        oneTimeUnlocked: this.oneTimeUnlocked,
        unlockedAt: entry?.achievedAt,
        unlockedMatchId: entry?.matchId,
        unlockPerformanceSnapshot: entry?.performanceSnapshot,
        unlockMatchTitle: entry?.matchTitle,
        unlocked: this.oneTimeUnlocked,
      };
    }
    if (!this.history.length) {
      return {
        badgeId,
        repeatability: "repeatable",
        unlockCount: 0,
        achievementHistory: [],
        oneTimeUnlocked: false,
        unlocked: false,
      };
    }
    const sorted = this.history.slice().sort((a, b) => a.achievedAt.getTime() - b.achievedAt.getTime());
    return {
      badgeId,
      repeatability: "repeatable",
      unlockCount: sorted.length,
      firstAchievedAt: sorted[0].achievedAt,
      lastAchievedAt: sorted[sorted.length - 1].achievedAt,
      achievementHistory: sorted,
      oneTimeUnlocked: false,
      unlocked: sorted.length > 0,
    };
  }
}

function addAchievement(
  records: Map<string, MutableRecord>,
  badgeId: string,
  match: Match,
  achievedAt: Date,
  snapshot: string,
) {
  if (!records.has(badgeId)) records.set(badgeId, new MutableRecord("repeatable"));
  records.get(badgeId)!.addRepeatable({
    matchId: match.id,
    achievedAt,
    performanceSnapshot: snapshot,
    matchTitle: match.title,
  });
}

function unlockOneTime(
  records: Map<string, MutableRecord>,
  badgeId: string,
  achievedAt: Date,
  snapshot: string,
  match?: Match,
) {
  if (!records.has(badgeId)) records.set(badgeId, new MutableRecord("oneTime"));
  records.get(badgeId)!.unlockOneTime({
    matchId: match?.id ?? "",
    achievedAt,
    performanceSnapshot: snapshot,
    matchTitle: match?.title ?? "",
  });
}

function awardHighestInGroup(
  records: Map<string, MutableRecord>,
  tiers: Array<[string, number]>,
  value: number,
  match: Match,
  achievedAt: Date,
  snapshot: string,
) {
  if (value <= 0) return;
  let badgeId: string | undefined;
  for (const [id, threshold] of tiers) {
    if (value >= threshold) badgeId = id;
  }
  if (!badgeId) return;
  addAchievement(records, badgeId, match, achievedAt, snapshot);
}

function awardHighestSr(
  records: Map<string, MutableRecord>,
  sr: number,
  runs: number,
  balls: number,
  match: Match,
  achievedAt: Date,
) {
  if (!qualifiesForSrBadge(runs, balls)) return;
  const tiers: Array<[string, number]> = [
    ["sr_200", 200],
    ["sr_250", 250],
    ["sr_300", 300],
  ];
  let badgeId: string | undefined;
  for (const [id, srMin] of tiers) {
    if (sr >= srMin) badgeId = id;
  }
  if (!badgeId) return;
  addAchievement(records, badgeId, match, achievedAt, `${sr.toFixed(0)} SR (${runs}/${balls})`);
}

export function applyCareerHighestOnly(
  records: Map<string, MutableRecord>,
  value: number,
  tiers: Array<[string, number]>,
) {
  if (value <= 0) return;
  let badgeId: string | undefined;
  for (const [id, threshold] of tiers) {
    if (value >= threshold) badgeId = id;
  }
  if (!badgeId) return;
  for (const [id] of tiers) {
    if (id !== badgeId) records.delete(id);
  }
  if (records.get(badgeId)?.oneTimeUnlocked) return;
  const rec = new MutableRecord("oneTime");
  rec.unlockOneTime({
    matchId: "",
    achievedAt: new Date(),
    performanceSnapshot: `Career total: ${value}`,
    matchTitle: "",
  });
  records.set(badgeId, rec);
}

function evaluateFieldingExtras(
  records: Map<string, MutableRecord>,
  playerId: string,
  match: Match,
  achievedAt: Date,
) {
  let runOuts = 0;
  let dismissals = 0;
  for (const inn of match.innings ?? []) {
    for (const f of inn.fielders ?? []) {
      if (f.playerId !== playerId) continue;
      runOuts += f.runOuts;
      dismissals += f.catches + f.runOuts + f.stumpings;
    }
  }
  if (runOuts >= 2) addAchievement(records, "ro_2", match, achievedAt, `${runOuts} run outs`);
  if (dismissals >= 5) addAchievement(records, "safe_hands", match, achievedAt, `${dismissals} dismissals`);
}

function evaluateSpecialMatchBadges(
  records: Map<string, MutableRecord>,
  playerId: string,
  match: Match,
  achievedAt: Date,
) {
  let runs = 0;
  let wickets = 0;
  for (const inn of match.innings ?? []) {
    for (const b of inn.batsmen ?? []) if (b.playerId === playerId) runs += b.runs;
    for (const b of inn.bowlers ?? []) if (b.playerId === playerId) wickets += b.wickets;
  }
  if (runs >= 100 && wickets >= 5) {
    addAchievement(records, "all_round_match", match, achievedAt, `${runs} runs & ${wickets} wickets`);
  } else if (runs >= 50 && wickets >= 3) {
    addAchievement(records, "all_round_hero", match, achievedAt, `${runs} runs & ${wickets} wickets`);
  }
  if ((match.innings ?? []).length >= 2) {
    const second = match.innings[1];
    for (const b of second.batsmen ?? []) {
      if (b.playerId !== playerId) continue;
      const sr = strikeRate(b.runs, b.balls);
      if (b.runs >= 30 && sr >= 150) {
        addAchievement(
          records,
          "finisher",
          match,
          achievedAt,
          `${b.runs} (${b.balls}) SR ${sr.toFixed(0)}`,
        );
      }
    }
  }
}

function processMatch(
  records: Map<string, MutableRecord>,
  playerId: string,
  match: Match,
) {
  const achievedAt = match.completedAt ?? match.scheduledAt ?? new Date();
  let matchRuns = 0;
  let matchBalls = 0;
  let matchFours = 0;
  let matchSixes = 0;
  let matchWickets = 0;
  let matchCatches = 0;
  let bestSr = 0;
  let bestSrRuns = 0;
  let bestSrBalls = 0;
  for (const inn of match.innings ?? []) {
    for (const b of inn.batsmen ?? []) {
      if (b.playerId !== playerId) continue;
      matchRuns += b.runs;
      matchBalls += b.balls;
      matchFours += b.fours;
      matchSixes += b.sixes;
      if (b.balls > 0 && qualifiesForSrBadge(b.runs, b.balls)) {
        const sr = strikeRate(b.runs, b.balls);
        if (sr >= bestSr) {
          bestSr = sr;
          bestSrRuns = b.runs;
          bestSrBalls = b.balls;
        }
      }
    }
    for (const b of inn.bowlers ?? []) if (b.playerId === playerId) matchWickets += b.wickets;
    for (const f of inn.fielders ?? []) if (f.playerId === playerId) matchCatches += f.catches;
  }
  awardHighestInGroup(
    records,
    [["bat_30", 30], ["bat_50", 50], ["bat_75", 75], ["bat_100", 100], ["bat_150", 150], ["bat_200", 200]],
    matchRuns,
    match,
    achievedAt,
    `${matchRuns}${matchBalls > 0 ? ` (${matchBalls})` : ""}`,
  );
  awardHighestInGroup(records, [["6s_5", 5], ["6s_10", 10], ["6s_15", 15]], matchSixes, match, achievedAt, `${matchSixes} sixes`);
  awardHighestInGroup(records, [["4s_10", 10], ["4s_15", 15], ["4s_20", 20]], matchFours, match, achievedAt, `${matchFours} fours`);
  awardHighestSr(records, bestSr, bestSrRuns, bestSrBalls, match, achievedAt);
  awardHighestInGroup(records, [["bowl_3", 3], ["bowl_4", 4], ["bowl_5", 5], ["bowl_6", 6]], matchWickets, match, achievedAt, `${matchWickets} wickets`);
  awardHighestInGroup(records, [["catch_3", 3], ["catch_5", 5]], matchCatches, match, achievedAt, `${matchCatches} catches`);
  evaluateFieldingExtras(records, playerId, match, achievedAt);
  evaluateSpecialMatchBadges(records, playerId, match, achievedAt);
}

function evaluateFirstTimeSpecials(
  records: Map<string, MutableRecord>,
  playerId: string,
  matches: Match[],
  ballEventsByMatch: Record<string, BallEvent[]>,
) {
  for (const match of matches) {
    const achievedAt = match.completedAt ?? match.scheduledAt ?? new Date();
    let matchRuns = 0;
    let matchWickets = 0;
    for (const inn of match.innings ?? []) {
      for (const b of inn.batsmen ?? []) if (b.playerId === playerId) matchRuns += b.runs;
      for (const b of inn.bowlers ?? []) if (b.playerId === playerId) matchWickets += b.wickets;
    }
    if (matchRuns >= 100) unlockOneTime(records, "first_century", achievedAt, `${matchRuns} runs`, match);
    if (matchWickets >= 5) unlockOneTime(records, "first_five_wicket", achievedAt, `${matchWickets} wickets`, match);
    if (isEligibleManOfTheMatch(match, playerId)) {
      unlockOneTime(records, "first_motm", achievedAt, "Player of the match", match);
    }
    const events = ballEventsByMatch[match.id] ?? [];
    let streak = 0;
    for (const e of events) {
      if (e.bowlerId !== playerId) continue;
      if (e.bowlerGetsWicket && e.isLegalDelivery) {
        streak += 1;
        if (streak >= 3) {
          unlockOneTime(records, "first_hat_trick", achievedAt, "Hat-trick", match);
          break;
        }
      } else if (e.isLegalDelivery) {
        streak = 0;
      }
    }
    const winnerId = decidedWinnerTeamId(match);
    const onWinningSide = Boolean(winnerId && playerTeamIds(match, playerId).has(winnerId));
    if (match.tournamentId && onWinningSide) {
      unlockOneTime(records, "tournament_winner", achievedAt, "Tournament match win", match);
      const setup = match.setup as Record<string, unknown> | undefined;
      if (setup) {
        const isCap =
          winnerId === match.teamAId
            ? setup.teamACaptainId === playerId
            : setup.teamBCaptainId === playerId;
        if (isCap) {
          unlockOneTime(records, "captain_champion", achievedAt, "Captain — tournament win", match);
        }
      }
    }
  }
}

function applyStandaloneCareerBadges(
  records: Map<string, MutableRecord>,
  playerId: string,
  stats: CareerBadgeStats,
  matches: Match[],
  captainStats: CaptainBadgeStats,
  ballEventsByMatch: Record<string, BallEvent[]>,
) {
  const overs = calculateOvers(stats.oversBowledBalls, 6);
  if (overs >= 20) {
    const econ = overs <= 0 ? 0 : stats.runsConceded / overs;
    if (econ > 0 && econ < 3) {
      applyCareerHighestOnly(records, 1, [["econ_3", 1]]);
      records.delete("econ_4");
    } else if (econ > 0 && econ < 4) {
      applyCareerHighestOnly(records, 1, [["econ_4", 1]]);
    }
  }
  if (captainStats.matchesAsCaptain >= 10 && captainStats.winPct >= 70) {
    applyCareerHighestOnly(records, 1, [["winning_machine", 1]]);
  }
  if (captainStats.successfulChases >= 5) {
    unlockOneTime(records, "chase_master", new Date(), `${captainStats.successfulChases} successful chases`);
  }
  if (captainStats.lowestDefendedScore >= 100) {
    unlockOneTime(records, "defender", new Date(), `Defended ${captainStats.lowestDefendedScore}`);
  }
  let potmStreak = 0;
  for (const match of matches) {
    if (isEligibleManOfTheMatch(match, playerId)) {
      potmStreak += 1;
      if (potmStreak >= 2) {
        addAchievement(records, "potm_streak", match, match.completedAt ?? new Date(), "2 consecutive POTM");
        break;
      }
    } else {
      potmStreak = 0;
    }
  }
  const dates = matches
    .map((m) => m.completedAt ?? m.scheduledAt)
    .filter((d): d is Date => Boolean(d))
    .slice()
    .sort((a, b) => a.getTime() - b.getTime());
  if (dates.length >= 10) {
    for (let i = 0; i <= dates.length - 10; i++) {
      const days = (dates[i + 9].getTime() - dates[i].getTime()) / 86400000;
      if (days <= 30) {
        unlockOneTime(records, "iron_man", dates[i + 9], "10 matches in 30 days");
        break;
      }
    }
  }
  for (const match of matches) {
    if (!match.rules.superOverEnabled) continue;
    if (!isEligibleManOfTheMatch(match, playerId)) continue;
    addAchievement(records, "super_over_hero", match, match.completedAt ?? new Date(), "Super over hero");
  }
  for (const [matchId, events] of Object.entries(ballEventsByMatch)) {
    for (const e of events) {
      if (e.wicketType !== "runOut") continue;
      if (e.primaryFielderId === playerId || e.fielderId === playerId) {
        const match = matches.find((m) => m.id === matchId);
        if (match) {
          addAchievement(records, "ro_direct", match, match.completedAt ?? new Date(), "Direct hit run out");
        }
        break;
      }
    }
  }
}

function completedOnly(matches: Match[]): Match[] {
  return matches
    .filter((m) => m.status === "completed")
    .slice()
    .sort((a, b) => {
      const at = (a.completedAt ?? a.scheduledAt)?.getTime() ?? 0;
      const bt = (b.completedAt ?? b.scheduledAt)?.getTime() ?? 0;
      return at - bt;
    });
}

export function computeBadgeRecords(opts: {
  playerId: string;
  completedMatches: Match[];
  stats: CareerBadgeStats;
  captainStats: CaptainBadgeStats;
  ballEventsByMatch?: Record<string, BallEvent[]>;
  catalog?: PlayerBadgeDefinition[];
}): Record<string, PlayerBadgeRecord> {
  const catalog = opts.catalog ?? BADGE_CATALOG;
  const sorted = completedOnly(opts.completedMatches);
  const records = new Map<string, MutableRecord>();
  for (const match of sorted) processMatch(records, opts.playerId, match);

  applyCareerHighestOnly(records, opts.stats.runs, [
    ["career_runs_100", 100],
    ["career_runs_500", 500],
    ["career_runs_1000", 1000],
    ["career_runs_5000", 5000],
    ["career_runs_10000", 10000],
  ]);
  applyCareerHighestOnly(records, opts.stats.wickets, [
    ["career_wkts_50", 50],
    ["career_wkts_100", 100],
    ["career_wkts_250", 250],
    ["career_wkts_500", 500],
  ]);
  applyCareerHighestOnly(records, opts.stats.sixes, [
    ["career_6s_50", 50],
    ["career_6s_100", 100],
    ["career_6s_250", 250],
    ["career_6s_500", 500],
  ]);
  applyCareerHighestOnly(records, opts.stats.catches, [
    ["career_catch_50", 50],
    ["career_catch_100", 100],
    ["career_catch_250", 250],
  ]);
  applyCareerHighestOnly(records, opts.stats.matchesPlayed, [
    ["debut", 1],
    ["matches_25", 25],
    ["matches_50", 50],
    ["matches_100", 100],
    ["matches_250", 250],
    ["matches_500", 500],
  ]);
  if (opts.stats.matchesPlayed >= 200) {
    unlockOneTime(records, "veteran", new Date(), `${opts.stats.matchesPlayed} matches`);
  }
  if (opts.stats.matchesPlayed >= 1000) {
    unlockOneTime(records, "legend", new Date(), `${opts.stats.matchesPlayed} matches`);
  }
  applyCareerHighestOnly(records, opts.captainStats.wins, [
    ["cap_wins_10", 10],
    ["cap_wins_25", 25],
    ["cap_wins_50", 50],
    ["cap_wins_100", 100],
  ]);
  applyStandaloneCareerBadges(
    records,
    opts.playerId,
    opts.stats,
    sorted,
    opts.captainStats,
    opts.ballEventsByMatch ?? {},
  );
  evaluateFirstTimeSpecials(records, opts.playerId, sorted, opts.ballEventsByMatch ?? {});
  const repeatabilityById = new Map(catalog.map((d) => [d.id, d.repeatability ?? "repeatable"]));
  const out: Record<string, PlayerBadgeRecord> = {};
  for (const [id, rec] of records.entries()) {
    out[id] = rec.toRecord(id, repeatabilityById.get(id) ?? "repeatable");
  }
  return out;
}

function nextTierInGroup(def: PlayerBadgeDefinition, catalog: PlayerBadgeDefinition[]) {
  if (!def.progressionGroup) return undefined;
  const group = catalog
    .filter((d) => d.progressionGroup === def.progressionGroup)
    .slice()
    .sort((a, b) => (a.groupOrder ?? 0) - (b.groupOrder ?? 0));
  const idx = group.findIndex((d) => d.id === def.id);
  if (idx < 0 || idx >= group.length - 1) return undefined;
  return group[idx + 1];
}

function bestMatchTotal(
  matches: Match[],
  playerId: string,
  pick: (match: Match) => number,
): { progress: number; target: number } {
  let best = 0;
  for (const match of matches) best = Math.max(best, pick(match));
  return { progress: best, target: 0 };
}

function matchRuns(matches: Match[], playerId: string, threshold: number) {
  const r = bestMatchTotal(matches, playerId, (match) =>
    (match.innings ?? []).reduce(
      (total, inn) => total + (inn.batsmen ?? []).filter((b) => b.playerId === playerId).reduce((s, b) => s + b.runs, 0),
      0,
    ),
  );
  return { progress: r.progress, target: threshold };
}
function matchSixes(matches: Match[], playerId: string, threshold: number) {
  const r = bestMatchTotal(matches, playerId, (match) =>
    (match.innings ?? []).reduce(
      (total, inn) => total + (inn.batsmen ?? []).filter((b) => b.playerId === playerId).reduce((s, b) => s + b.sixes, 0),
      0,
    ),
  );
  return { progress: r.progress, target: threshold };
}
function matchFours(matches: Match[], playerId: string, threshold: number) {
  const r = bestMatchTotal(matches, playerId, (match) =>
    (match.innings ?? []).reduce(
      (total, inn) => total + (inn.batsmen ?? []).filter((b) => b.playerId === playerId).reduce((s, b) => s + b.fours, 0),
      0,
    ),
  );
  return { progress: r.progress, target: threshold };
}
function matchWickets(matches: Match[], playerId: string, threshold: number) {
  const r = bestMatchTotal(matches, playerId, (match) =>
    (match.innings ?? []).reduce(
      (total, inn) => total + (inn.bowlers ?? []).filter((b) => b.playerId === playerId).reduce((s, b) => s + b.wickets, 0),
      0,
    ),
  );
  return { progress: r.progress, target: threshold };
}
function matchCatches(matches: Match[], playerId: string, threshold: number) {
  const r = bestMatchTotal(matches, playerId, (match) =>
    (match.innings ?? []).reduce(
      (total, inn) => total + (inn.fielders ?? []).filter((f) => f.playerId === playerId).reduce((s, f) => s + f.catches, 0),
      0,
    ),
  );
  return { progress: r.progress, target: threshold };
}
function srProgress(matches: Match[], playerId: string, srTarget: number) {
  let bestSr = 0;
  for (const match of matches) {
    for (const inn of match.innings ?? []) {
      for (const b of inn.batsmen ?? []) {
        if (b.playerId !== playerId) continue;
        if (!qualifiesForSrBadge(b.runs, b.balls)) continue;
        const sr = strikeRate(b.runs, b.balls);
        if (sr > bestSr) bestSr = sr;
      }
    }
  }
  return { progress: bestSr, target: srTarget };
}

const RUNS_T: Record<string, number> = { bat_30: 30, bat_50: 50, bat_75: 75, bat_100: 100, bat_150: 150, bat_200: 200 };
const SIX_T: Record<string, number> = { "6s_5": 5, "6s_10": 10, "6s_15": 15 };
const FOUR_T: Record<string, number> = { "4s_10": 10, "4s_15": 15, "4s_20": 20 };
const WKT_T: Record<string, number> = { bowl_3: 3, bowl_4: 4, bowl_5: 5, bowl_6: 6 };
const MATCH_T: Record<string, number> = {
  debut: 1,
  matches_25: 25,
  matches_50: 50,
  matches_100: 100,
  matches_250: 250,
  matches_500: 500,
  veteran: 200,
  legend: 1000,
};

function progressTowardBadge(
  def: PlayerBadgeDefinition,
  stats: CareerBadgeStats,
  matches: Match[],
  playerId: string,
  captainStats: CaptainBadgeStats,
  unlocked: boolean,
): { progress: number; target: number } {
  const id = def.id;
  if (id in RUNS_T) return matchRuns(matches, playerId, RUNS_T[id]);
  if (id in SIX_T) return matchSixes(matches, playerId, SIX_T[id]);
  if (id in FOUR_T) return matchFours(matches, playerId, FOUR_T[id]);
  if (id in WKT_T) return matchWickets(matches, playerId, WKT_T[id]);
  if (id === "catch_3" || id === "catch_5") return matchCatches(matches, playerId, id === "catch_5" ? 5 : 3);
  if (id === "sr_200") return srProgress(matches, playerId, 200);
  if (id === "sr_250") return srProgress(matches, playerId, 250);
  if (id === "sr_300") return srProgress(matches, playerId, 300);
  const career: Record<string, [number, number]> = {
    career_runs_100: [stats.runs, 100],
    career_runs_500: [stats.runs, 500],
    career_runs_1000: [stats.runs, 1000],
    career_runs_5000: [stats.runs, 5000],
    career_runs_10000: [stats.runs, 10000],
    career_wkts_50: [stats.wickets, 50],
    career_wkts_100: [stats.wickets, 100],
    career_wkts_250: [stats.wickets, 250],
    career_wkts_500: [stats.wickets, 500],
    career_6s_50: [stats.sixes, 50],
    career_6s_100: [stats.sixes, 100],
    career_6s_250: [stats.sixes, 250],
    career_6s_500: [stats.sixes, 500],
    career_catch_50: [stats.catches, 50],
    career_catch_100: [stats.catches, 100],
    career_catch_250: [stats.catches, 250],
    cap_wins_10: [captainStats.wins, 10],
    cap_wins_25: [captainStats.wins, 25],
    cap_wins_50: [captainStats.wins, 50],
    cap_wins_100: [captainStats.wins, 100],
  };
  if (id in career) return { progress: career[id][0], target: career[id][1] };
  if (id in MATCH_T) return { progress: stats.matchesPlayed, target: MATCH_T[id] };
  return { progress: unlocked ? 1 : 0, target: 1 };
}

export function toProgressList(opts: {
  catalog?: PlayerBadgeDefinition[];
  records: Record<string, PlayerBadgeRecord>;
  playerId: string;
  stats: CareerBadgeStats;
  completedMatches: Match[];
  captainStats: CaptainBadgeStats;
}): PlayerBadgeProgress[] {
  const catalog = opts.catalog ?? BADGE_CATALOG;
  return catalog.map((def) => {
    const record = opts.records[def.id];
    const unlocked = record?.unlocked ?? false;
    const progress = progressTowardBadge(def, opts.stats, opts.completedMatches, opts.playerId, opts.captainStats, unlocked);
    const isRepeatable = (def.repeatability ?? "repeatable") === "repeatable";
    const next = isRepeatable ? nextTierInGroup(def, catalog) : undefined;
    if (!isRepeatable) {
      return {
        definition: def,
        unlocked,
        unlockCount: 0,
        progress: progress.progress,
        target: progress.target,
        unlockedAt: record?.unlockedAt,
        matchId: record?.unlockedMatchId,
        unlockPerformanceSnapshot: record?.unlockPerformanceSnapshot,
        unlockMatchTitle: record?.unlockMatchTitle,
        nextTierTitle: next?.title,
        progressToNextTier: next && !unlocked ? `Progress to ${next.title}` : null,
        achievementHistory: [],
      };
    }
    return {
      definition: def,
      unlocked,
      unlockCount: record?.unlockCount ?? 0,
      progress: progress.progress,
      target: progress.target,
      earnedAt: record?.lastAchievedAt,
      firstAchievedAt: record?.firstAchievedAt,
      matchId: record?.achievementHistory.at(-1)?.matchId,
      achievementHistory: record?.achievementHistory ?? [],
      nextTierTitle: next?.title,
      progressToNextTier: next && !unlocked ? `Progress to ${next.title}` : next && unlocked ? `Next: ${next.title}` : null,
    };
  });
}

export function evaluateBadgeCatalog(opts: {
  playerId: string;
  completedMatches: Match[];
  stats: CareerBadgeStats;
  captainStats: CaptainBadgeStats;
  ballEventsByMatch?: Record<string, BallEvent[]>;
}): PlayerBadgeProgress[] {
  const records = computeBadgeRecords(opts);
  return toProgressList({
    records,
    playerId: opts.playerId,
    stats: opts.stats,
    completedMatches: opts.completedMatches,
    captainStats: opts.captainStats,
  });
}
