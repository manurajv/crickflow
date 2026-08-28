class ExistingPlayerMatch {
  const ExistingPlayerMatch({
    required this.uid,
    required this.playerDocId,
    this.playerId,
    required this.displayName,
    this.photoUrl,
    required this.onboardingCompleted,
  });

  final String uid;
  final String playerDocId;
  final String? playerId;
  final String displayName;
  final String? photoUrl;
  final bool onboardingCompleted;

  factory ExistingPlayerMatch.fromMap(Map<String, dynamic> map) {
    return ExistingPlayerMatch(
      uid: map['uid'] as String? ?? '',
      playerDocId: map['playerDocId'] as String? ?? map['uid'] as String? ?? '',
      playerId: map['playerId'] as String?,
      displayName: (map['displayName'] as String?)?.trim().isNotEmpty == true
          ? map['displayName'] as String
          : 'CrickFlow player',
      photoUrl: map['photoUrl'] as String?,
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
    );
  }
}

class RegisterPlayerArgs {
  const RegisterPlayerArgs({this.popWithPlayer = false});

  /// When true (team / match flows), pop with an existing [PlayerModel],
  /// or `'invited'` after a shareable invite is created.
  final bool popWithPlayer;
}

enum PlayerInviteType {
  phone,
  google,
  either;

  String get apiValue => name;

  static PlayerInviteType fromApi(String? raw) {
    switch (raw) {
      case 'phone':
        return PlayerInviteType.phone;
      case 'google':
        return PlayerInviteType.google;
      default:
        return PlayerInviteType.either;
    }
  }
}

class PlayerInviteCreated {
  const PlayerInviteCreated({
    required this.inviteId,
    required this.url,
    required this.expiresAt,
    this.reused = false,
    this.inviteType = PlayerInviteType.either,
  });

  final String inviteId;
  final String url;
  final String expiresAt;
  final bool reused;
  final PlayerInviteType inviteType;
}

class PlayerInvitePreview {
  const PlayerInvitePreview({
    required this.id,
    required this.phoneNumber,
    required this.invitedByName,
    required this.status,
    this.displayName,
    this.expiresAt,
    this.inviteType = PlayerInviteType.either,
  });

  final String id;
  final String phoneNumber;
  final String invitedByName;
  final String status;
  final String? displayName;
  final String? expiresAt;
  final PlayerInviteType inviteType;

  bool get hasPhone => phoneNumber.trim().isNotEmpty;

  bool get isPending => status == 'pending';

  bool get isExpired {
    if (status == 'expired') return true;
    final raw = expiresAt;
    if (raw == null || raw.isEmpty) return false;
    final parsed = DateTime.tryParse(raw);
    return parsed != null && parsed.isBefore(DateTime.now());
  }

  factory PlayerInvitePreview.fromMap(String id, Map<String, dynamic> map) {
    return PlayerInvitePreview(
      id: id,
      phoneNumber: map['phoneNumber'] as String? ?? '',
      invitedByName: (map['invitedByName'] as String?)?.trim().isNotEmpty == true
          ? map['invitedByName'] as String
          : 'A CrickFlow user',
      status: map['status'] as String? ?? 'pending',
      displayName: map['displayName'] as String?,
      expiresAt: map['expiresAt'] as String?,
      inviteType: PlayerInviteType.fromApi(map['inviteType'] as String?),
    );
  }
}
