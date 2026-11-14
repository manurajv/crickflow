/// Professional, contextual copy for guest sign-in gates (app + web keys).
///
/// Pass a [SignInPrompt] into [requireAuth] / [requireLogin] / the shared
/// sheet. Web URLs carry the [key] only (whitelisted); never raw free text.
class SignInPrompt {
  const SignInPrompt._(
    this.key,
    this.message, {
    this.title = 'Sign in required',
  });

  /// Stable key shared with crickflow-web (`guest-access.ts`).
  final String key;

  /// Body shown on the sheet and login banner.
  final String message;

  /// Sheet title (default "Sign in required").
  final String title;

  /// Ad-hoc body for rare call sites; prefer a catalog constant.
  factory SignInPrompt.custom(String message) => SignInPrompt._(
    'general',
    message.isNotEmpty
        ? message
        : 'Sign in to your CrickFlow account to continue.',
  );

  // ---- Catalog ----

  /// Default when no specific action is known.
  static const general = SignInPrompt._(
    'general',
    'Sign in to your CrickFlow account to continue.',
  );

  static const createPost = SignInPrompt._(
    'create_post',
    'Sign in to create a post and join the conversation.',
  );

  static const createOpportunity = SignInPrompt._(
    'create_opportunity',
    'Sign in to post an opportunity on Discover.',
  );

  static const likeComment = SignInPrompt._(
    'like_comment',
    'Sign in to like and comment on posts.',
  );

  static const savePost = SignInPrompt._(
    'save_post',
    'Sign in to save posts for later.',
  );

  static const follow = SignInPrompt._(
    'follow',
    'Sign in to follow players and build your cricket network.',
  );

  static const chat = SignInPrompt._(
    'chat',
    'Sign in to send messages and start chats.',
  );

  static const report = SignInPrompt._(
    'report',
    'Sign in to report content and help keep CrickFlow safe.',
  );

  static const managePost = SignInPrompt._(
    'manage_post',
    'Sign in to manage this post.',
  );

  static const blockUser = SignInPrompt._(
    'block_user',
    'Sign in to block users.',
  );

  static const notifications = SignInPrompt._(
    'notifications',
    'Sign in to view your notifications.',
  );

  static const notificationSettings = SignInPrompt._(
    'notification_settings',
    'Sign in to manage notification preferences.',
  );

  static const manageProfile = SignInPrompt._(
    'manage_profile',
    'Sign in to manage your profile.',
    title: 'Sign in to continue',
  );

  static const myCricket = SignInPrompt._(
    'my_cricket',
    'Sign in to see your matches, teams, stats, and highlights.',
  );

  static const startMatch = SignInPrompt._(
    'start_match',
    'Sign in to start a match and keep score.',
  );

  static const scoreMatch = SignInPrompt._(
    'score_match',
    'Sign in to score this match.',
  );

  static const streamMatch = SignInPrompt._(
    'stream_match',
    'Sign in to stream or broadcast this match.',
  );

  static const createTeam = SignInPrompt._(
    'create_team',
    'Sign in to create a team.',
  );

  static const manageTeam = SignInPrompt._(
    'manage_team',
    'Sign in to manage this team.',
  );

  static const createTournament = SignInPrompt._(
    'create_tournament',
    'Sign in to create a tournament.',
  );

  static const joinTournament = SignInPrompt._(
    'join_tournament',
    'Sign in to join this tournament.',
  );

  static const invitePlayer = SignInPrompt._(
    'invite_player',
    'Sign in to invite a player to CrickFlow.',
  );

  static const createOrg = SignInPrompt._(
    'create_org',
    'Sign in to create an organization.',
  );

  static const createOrgTeam = SignInPrompt._(
    'create_org_team',
    'Sign in to add a team to this organization.',
  );

  static const joinOrg = SignInPrompt._(
    'join_org',
    'Sign in to join this organization.',
    title: 'Sign in to continue',
  );

  static const joinOrgTeam = SignInPrompt._(
    'join_org_team',
    'Sign in to request to join this team and submit your registration documents.',
  );

  static const registerOrgPlayer = SignInPrompt._(
    'register_org_player',
    'Sign in to submit player registration documents for this organization.',
  );

  static const addOrgPlayer = SignInPrompt._(
    'add_org_player',
    'Sign in to add a player and submit their registration documents.',
  );

  static const proposeMatch = SignInPrompt._(
    'propose_match',
    'Sign in to propose a match in this organization.',
  );

  static const proposeTournament = SignInPrompt._(
    'propose_tournament',
    'Sign in to propose a tournament in this organization.',
  );

  static const orgManage = SignInPrompt._(
    'org_manage',
    'Sign in to manage this organization.',
  );

  static const editProfile = SignInPrompt._(
    'edit_profile',
    'Sign in to edit your profile.',
  );

  /// All prompts keyed for web URL whitelist + lookup.
  static const Map<String, SignInPrompt> byKey = {
    'general': general,
    'create_post': createPost,
    'create_opportunity': createOpportunity,
    'like_comment': likeComment,
    'save_post': savePost,
    'follow': follow,
    'chat': chat,
    'report': report,
    'manage_post': managePost,
    'block_user': blockUser,
    'notifications': notifications,
    'notification_settings': notificationSettings,
    'manage_profile': manageProfile,
    'my_cricket': myCricket,
    'start_match': startMatch,
    'score_match': scoreMatch,
    'stream_match': streamMatch,
    'create_team': createTeam,
    'manage_team': manageTeam,
    'create_tournament': createTournament,
    'join_tournament': joinTournament,
    'invite_player': invitePlayer,
    'create_org': createOrg,
    'create_org_team': createOrgTeam,
    'join_org': joinOrg,
    'join_org_team': joinOrgTeam,
    'register_org_player': registerOrgPlayer,
    'add_org_player': addOrgPlayer,
    'propose_match': proposeMatch,
    'propose_tournament': proposeTournament,
    'org_manage': orgManage,
    'edit_profile': editProfile,
  };

  static SignInPrompt fromKey(String? key) {
    if (key == null || key.isEmpty) return general;
    return byKey[key] ?? general;
  }

  /// Infer a prompt from a protected route (router redirect).
  static SignInPrompt forPath(String rawPath) {
    final path = rawPath.split('?').first;
    if (path == '/notifications' || path.startsWith('/notifications')) {
      return notifications;
    }
    if (path.startsWith('/settings/notifications')) {
      return notificationSettings;
    }
    if (path == '/profile/edit' || path == '/player-onboarding') {
      return editProfile;
    }
    if (path == '/register-player') return invitePlayer;
    if (path.startsWith('/community/chats')) return chat;
    if (path == '/match/start' ||
        path == '/match/quick' ||
        path == '/match/create' ||
        path.startsWith('/match/create/')) {
      return startMatch;
    }
    if (path.endsWith('/score') ||
        path.endsWith('/start-innings') ||
        path.endsWith('/takeover')) {
      return scoreMatch;
    }
    if (path.endsWith('/stream') || path.endsWith('/overlay')) {
      return streamMatch;
    }
    if (path == '/teams/create' || path.contains('/add-players')) {
      return createTeam;
    }
    if (path.contains('/series/') && path.contains('/add-player')) {
      return addOrgPlayer;
    }
    if (path.contains('/add-player')) return manageTeam;
    if (path == '/tournaments/create') return createTournament;
    if (path.contains('/tournaments/') && path.contains('/join')) {
      return joinTournament;
    }
    if (path == '/series/create' || path.startsWith('/series/create')) {
      return createOrg;
    }
    if (path.endsWith('/clubs/create')) return createOrgTeam;
    if (path.endsWith('/propose-match')) return proposeMatch;
    if (path.endsWith('/propose-tournament')) return proposeTournament;
    if (path.endsWith('/register')) return registerOrgPlayer;
    if (path.endsWith('/my-requests')) return joinOrg;
    if (path.endsWith('/settings') ||
        path.endsWith('/admins') ||
        path.endsWith('/audit') ||
        path.endsWith('/approvals') ||
        path.endsWith('/announcements')) {
      return orgManage;
    }
    return general;
  }
}

/// Default body when no contextual prompt is supplied.
const String kDefaultSignInMessage =
    'Sign in to your CrickFlow account to continue.';

/// @nodoc Kept as alias of [kDefaultSignInMessage] for older call sites.
@Deprecated('Use SignInPrompt.general or kDefaultSignInMessage')
const String kSignInToUseThisMessage = kDefaultSignInMessage;

/// @nodoc Prefer a contextual [SignInPrompt].
@Deprecated('Use SignInPrompt.general.message')
const String kPleaseSignInToContinue = kDefaultSignInMessage;
