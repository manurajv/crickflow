import '../../features/ads/models/managed_ads.dart';
import '../../features/broadcasts/models/managed_broadcast.dart';
import '../../features/grounds/models/managed_ground.dart';
import '../../features/matches/models/managed_match.dart';
import '../../features/moderation/models/managed_moderation.dart';
import '../../features/notifications/models/managed_notification.dart';
import '../../features/players/models/managed_player.dart';
import '../../features/teams/models/managed_team.dart';
import '../../features/tournaments/models/managed_tournament.dart';
import '../../features/users/models/managed_user.dart';
import 'admin_csv.dart';

/// Column maps for Super Admin list-page CSV exports.
abstract final class AdminListExports {
  AdminListExports._();

  static const userHeaders = [
    'id',
    'name',
    'username',
    'email',
    'playerId',
    'country',
    'city',
    'status',
    'verified',
    'team',
    'role',
    'matchesPlayed',
    'createdAt',
    'lastLoginAt',
  ];

  static List<String?> userRow(ManagedUser u) => [
    u.id,
    u.effectiveName,
    u.username,
    u.email,
    u.playerId,
    u.country,
    u.city,
    u.accountStatus.label,
    u.adminVerified ? 'yes' : 'no',
    u.currentTeamName,
    u.adminRole?.name ?? u.mobileRole,
    '${u.matchesPlayed}',
    AdminCsv.cellDate(u.createdAt),
    AdminCsv.cellDate(u.lastLoginAt),
  ];

  static const teamHeaders = [
    'id',
    'name',
    'code',
    'country',
    'city',
    'status',
    'members',
    'matchesPlayed',
    'won',
    'lost',
    'tied',
    'followers',
    'createdBy',
    'createdAt',
  ];

  static List<String?> teamRow(ManagedTeam t) => [
    t.id,
    t.name,
    t.teamCode,
    t.country,
    t.city,
    t.adminStatus.label,
    '${t.memberCount}',
    '${t.matchesPlayed}',
    '${t.matchesWon}',
    '${t.matchesLost}',
    '${t.matchesTied}',
    '${t.followersCount}',
    t.createdBy,
    AdminCsv.cellDate(t.createdAt),
  ];

  static const playerHeaders = [
    'id',
    'name',
    'publicPlayerId',
    'userId',
    'role',
    'country',
    'city',
    'status',
    'matchesPlayed',
    'runs',
    'wickets',
    'createdAt',
  ];

  static List<String?> playerRow(ManagedPlayer p) => [
    p.id,
    p.fullName.isNotEmpty ? p.fullName : p.name,
    p.publicPlayerId,
    p.userId,
    p.role,
    p.country,
    p.city,
    p.adminStatus.label,
    '${p.matchesPlayed}',
    '${p.runs}',
    '${p.wickets}',
    AdminCsv.cellDate(p.createdAt),
  ];

  static const matchHeaders = [
    'id',
    'title',
    'status',
    'type',
    'teamA',
    'teamB',
    'score',
    'result',
    'venue',
    'city',
    'tournament',
    'scheduledAt',
    'createdAt',
  ];

  static List<String?> matchRow(ManagedMatch m) => [
    m.id,
    m.title,
    m.status.label,
    m.matchType.label,
    m.teamAName,
    m.teamBName,
    m.scoreLine,
    m.resultSummary,
    m.venue,
    m.city,
    m.tournamentName,
    AdminCsv.cellDate(m.scheduledAt),
    AdminCsv.cellDate(m.createdAt),
  ];

  static const tournamentHeaders = [
    'id',
    'name',
    'status',
    'format',
    'teams',
    'grounds',
    'organizer',
    'city',
    'country',
    'startDate',
    'endDate',
    'createdAt',
  ];

  static List<String?> tournamentRow(ManagedTournament t) => [
    t.id,
    t.name,
    t.status.label,
    t.format.label,
    '${t.teamCount}',
    t.grounds.join('; '),
    t.organizerName,
    t.city,
    t.country,
    AdminCsv.cellDate(t.startDate),
    AdminCsv.cellDate(t.endDate),
    AdminCsv.cellDate(t.createdAt),
  ];

  static const groundHeaders = [
    'id',
    'name',
    'code',
    'city',
    'country',
    'status',
    'availability',
    'matchesHosted',
    'capacity',
    'owner',
  ];

  static List<String?> groundRow(ManagedGround g) => [
    g.id,
    g.name,
    g.groundCode,
    g.city,
    g.country,
    g.adminStatus.label,
    g.availability.label,
    '${g.matchesHosted}',
    g.capacity?.toString(),
    g.ownerName,
  ];

  static const broadcastHeaders = [
    'id',
    'match',
    'status',
    'streamStatus',
    'platform',
    'teamA',
    'teamB',
    'venue',
    'organizer',
    'viewers',
    'watchUrl',
    'startedAt',
  ];

  static List<String?> broadcastRow(ManagedBroadcast b) => [
    b.id,
    b.matchTitle,
    b.matchStatus.label,
    b.streamStatus.label,
    b.platform.label,
    b.teamAName,
    b.teamBName,
    b.venue,
    b.organizerName,
    '${b.viewerCount}',
    b.watchUrl,
    AdminCsv.cellDate(b.streamStartedAt ?? b.matchStartedAt),
  ];

  static const campaignHeaders = [
    'id',
    'title',
    'campaign',
    'status',
    'type',
    'audience',
    'priority',
    'recipientCount',
    'sent',
    'delivered',
    'opened',
    'clicked',
    'failed',
    'scheduledAt',
    'createdBy',
  ];

  static List<String?> campaignRow(ManagedNotificationCampaign c) => [
    c.id,
    c.title,
    c.campaignName,
    c.status.label,
    c.type.label,
    c.audience.label,
    c.priority.label,
    '${c.recipientCount}',
    '${c.sentCount}',
    '${c.deliveredCount}',
    '${c.openedCount}',
    '${c.clickedCount}',
    '${c.failedCount}',
    AdminCsv.cellDate(c.scheduledAt),
    c.createdByEmail.isNotEmpty ? c.createdByEmail : c.createdByUid,
  ];

  static const announcementHeaders = [
    'id',
    'title',
    'kind',
    'active',
    'priority',
    'expiresAt',
    'createdAt',
  ];

  static List<String?> announcementRow(ManagedAnnouncement a) => [
    a.id,
    a.title,
    a.kind,
    a.active ? 'yes' : 'no',
    '${a.priority}',
    AdminCsv.cellDate(a.expiresAt),
    AdminCsv.cellDate(a.createdAt),
  ];

  static const templateHeaders = ['id', 'name', 'title', 'type', 'createdAt'];

  static List<String?> templateRow(ManagedNotificationTemplate t) => [
    t.id,
    t.name,
    t.title,
    t.type.label,
    AdminCsv.cellDate(t.createdAt),
  ];

  static const segmentHeaders = [
    'id',
    'name',
    'audience',
    'estimatedCount',
    'createdAt',
  ];

  static List<String?> segmentRow(ManagedNotificationSegment s) => [
    s.id,
    s.name,
    s.audience.label,
    '${s.estimatedCount}',
    AdminCsv.cellDate(s.createdAt),
  ];

  static const autoNotificationHeaders = [
    'id',
    'userId',
    'title',
    'type',
    'read',
    'createdAt',
  ];

  static List<String?> autoNotificationRow(ManagedAutoNotification n) => [
    n.id,
    n.userId,
    n.title,
    n.type,
    n.read ? 'yes' : 'no',
    AdminCsv.cellDate(n.createdAt),
  ];

  static const adCampaignHeaders = [
    'id',
    'title',
    'campaign',
    'status',
    'type',
    'advertiser',
    'impressions',
    'clicks',
    'estimatedRevenue',
    'startDate',
    'endDate',
    'createdBy',
  ];

  static List<String?> adCampaignRow(ManagedAdCampaign c) => [
    c.id,
    c.title,
    c.campaignName,
    c.status.label,
    c.campaignType.label,
    c.advertiserName,
    '${c.impressions}',
    '${c.clicks}',
    c.estimatedRevenue.toString(),
    AdminCsv.cellDate(c.startDate),
    AdminCsv.cellDate(c.endDate),
    c.createdByEmail.isNotEmpty ? c.createdByEmail : c.createdByUid,
  ];

  static const advertiserHeaders = [
    'id',
    'company',
    'contact',
    'email',
    'phone',
    'activeAds',
    'campaigns',
    'createdAt',
  ];

  static List<String?> advertiserRow(ManagedAdvertiser a) => [
    a.id,
    a.companyName,
    a.contactPerson,
    a.email,
    a.phone,
    '${a.activeAds}',
    '${a.campaignCount}',
    AdminCsv.cellDate(a.createdAt),
  ];

  static const sponsoredHeaders = [
    'id',
    'entityType',
    'entity',
    'sponsor',
    'campaign',
    'status',
    'featured',
    'startDate',
    'endDate',
  ];

  static List<String?> sponsoredRow(ManagedSponsoredContent s) => [
    s.id,
    s.entityType.label,
    s.entityLabel,
    s.sponsorName,
    s.campaignName,
    s.status.label,
    s.featuredBadge ? 'yes' : 'no',
    AdminCsv.cellDate(s.startDate),
    AdminCsv.cellDate(s.endDate),
  ];

  static const moderationPostHeaders = [
    'id',
    'source',
    'author',
    'authorId',
    'title',
    'status',
    'likes',
    'comments',
    'reports',
    'createdAt',
  ];

  static List<String?> moderationPostRow(ManagedModerationPost p) => [
    p.id,
    p.source.name,
    p.authorName,
    p.authorId,
    p.title.isNotEmpty ? p.title : p.body,
    p.status.label,
    '${p.likeCount}',
    '${p.commentCount}',
    '${p.reportCount}',
    AdminCsv.cellDate(p.createdAt),
  ];

  static const chatHeaders = [
    'id',
    'status',
    'participantCount',
    'participantNames',
    'reported',
    'lastMessageAt',
    'createdAt',
  ];

  static List<String?> chatRow(ManagedChatThread c) => [
    c.id,
    c.status,
    '${c.participantIds.length}',
    c.participantNames.join('; '),
    c.reported ? 'yes' : 'no',
    AdminCsv.cellDate(c.lastMessageAt),
    AdminCsv.cellDate(c.createdAt),
  ];

  static const reportHeaders = [
    'id',
    'source',
    'targetType',
    'postId',
    'reason',
    'status',
    'reporterUserId',
    'authorId',
    'createdAt',
  ];

  static List<String?> reportRow(ManagedContentReport r) => [
    r.id,
    r.source.name,
    r.targetType.label,
    r.postId,
    r.reason,
    r.status.label,
    r.reporterUserId,
    r.authorId,
    AdminCsv.cellDate(r.createdAt),
  ];
}
