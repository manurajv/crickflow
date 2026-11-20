import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/atomic_create.dart';
import '../../data/models/community_post_model.dart';
import '../../data/models/tournament/tournament_create_draft.dart';
import '../../data/models/tournament/tournament_setup_meta.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../data/services/storage_service.dart';
import '../../shared/providers/community_provider.dart';
import '../../shared/providers/providers.dart';

class TournamentCreateService {
  TournamentCreateService({
    required TournamentRepository tournamentRepository,
    required CommunityRepository communityRepository,
    required StorageService storageService,
  })  : _tournaments = tournamentRepository,
        _community = communityRepository,
        _storage = storageService;

  final TournamentRepository _tournaments;
  final CommunityRepository _community;
  final StorageService _storage;

  Future<String> submit({
    required TournamentCreateDraft draft,
    required String uid,
    required String ownerDisplayName,
    String? authorPhotoUrl,
    String? authorPlayerId,
    bool authorVerified = false,
    bool postOfficialsRequest = true,
    bool postTeamsRequest = true,
  }) async {
    String? thumbnailUrl;
    // All-or-nothing: images are uploaded first, then the tournament doc is
    // written once. If that write fails the uploads are deleted again.
    final id = await runAtomicCreate<String>(
      uploads: {
        if (draft.bannerLocalFile != null)
          'banner': () => _storage.uploadTournamentImageAsset(
                draft.tournamentId,
                draft.bannerLocalFile!,
                kind: 'banner',
              ),
        if (draft.logoLocalFile != null)
          'logo': () => _storage.uploadTournamentImageAsset(
                draft.tournamentId,
                draft.logoLocalFile!,
                kind: 'logo',
              ),
        if (draft.thumbnailLocalFile != null)
          'thumbnail': () => _storage.uploadTournamentImageAsset(
                draft.tournamentId,
                draft.thumbnailLocalFile!,
                kind: 'thumbnail',
              ),
      },
      commit: (urls) {
        final bannerUrl = urls['banner'] ?? draft.bannerUrl;
        final logoUrl = urls['logo'] ?? draft.logoUrl;
        thumbnailUrl = urls['thumbnail'] ?? draft.thumbnailUrl ?? bannerUrl;
        final tournament = draft.toTournamentModel(
          uid: uid,
          bannerUrl: bannerUrl,
          logoUrl: logoUrl,
          thumbnailUrl: thumbnailUrl,
          thumbnailAspect: draft.thumbnailAspect,
        );
        return _tournaments.createTournament(
          tournament: tournament,
          ownerDisplayName: ownerDisplayName,
        );
      },
    );

    final meta = draft.mergedSetup();
    final location = draft.location.copyWith(city: draft.city);
    final snapshot = _buildSnapshot(
      tournamentId: id,
      draft: draft,
      meta: meta,
      ownerDisplayName: ownerDisplayName,
      thumbnailUrl: thumbnailUrl,
      organizerUserId: uid,
    );

    // Optional follow-up posts: the tournament is already complete, so a
    // failed post must not report the whole create as failed.
    if (postOfficialsRequest && draft.needOfficials) {
      await _optionalPost(() => _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        authorPhotoUrl: authorPhotoUrl,
        authorPlayerId: authorPlayerId,
        authorVerified: authorVerified,
        title: 'Officials needed',
        body: _officialsPostBody(meta),
        category: CommunityPostCategory.tournamentNeed,
        postKind: CommunityPostKind.tournament,
        location: location,
        tournamentId: id,
        tournamentSnapshot: snapshot,
      ));
    }

    if (postTeamsRequest && draft.needMoreTeams) {
      await _optionalPost(() => _community.createPost(
        authorId: uid,
        authorName: ownerDisplayName,
        authorRole: 'organizer',
        authorPhotoUrl: authorPhotoUrl,
        authorPlayerId: authorPlayerId,
        authorVerified: authorVerified,
        title: 'Teams wanted',
        body: _teamsPostBody(draft, meta),
        category: CommunityPostCategory.tournamentNeed,
        postKind: CommunityPostKind.tournament,
        location: location,
        tournamentId: id,
        tournamentSnapshot: snapshot,
      ));
    }

    return id;
  }

  Future<void> _optionalPost(Future<Object?> Function() post) async {
    try {
      await post();
    } catch (e) {
      debugPrint('tournament community post skipped: $e');
    }
  }

  CommunityTournamentSnapshot _buildSnapshot({
    required String tournamentId,
    required TournamentCreateDraft draft,
    required TournamentSetupMeta meta,
    required String ownerDisplayName,
    String? thumbnailUrl,
    required String organizerUserId,
  }) {
    final methods = _contactMethods(meta.officialContactMethods);
    final phone = meta.organizerPhone.isNotEmpty
        ? meta.organizerPhone
        : draft.organizerPhone;
    final email = meta.organizerEmail.isNotEmpty
        ? meta.organizerEmail
        : draft.organizerEmail;
    final visibility = methods.isEmpty
        ? CommunityContactVisibility.hide
        : methods.first;

    final grounds = <String>[
      ...draft.grounds.map((g) => g.trim()).where((g) => g.isNotEmpty),
    ];
    final primary = meta.primaryGround.trim();
    if (primary.isNotEmpty &&
        !grounds.any((g) => g.toLowerCase() == primary.toLowerCase())) {
      grounds.insert(0, primary);
    }
    final groundsLabel = grounds.join(' · ');
    final cityLabel = draft.location.copyWith(city: draft.city).displayLabel;

    return CommunityTournamentSnapshot(
      tournamentId: tournamentId,
      name: draft.name.trim(),
      organizer: meta.organizerName.isNotEmpty
          ? meta.organizerName
          : (draft.organizerName.isNotEmpty
              ? draft.organizerName
              : ownerDisplayName),
      thumbnailUrl: thumbnailUrl,
      thumbnailAspect: draft.thumbnailAspect,
      locationLabel: cityLabel,
      groundsLabel: groundsLabel,
      grounds: grounds,
      startDate: draft.startDate,
      endDate: draft.endDate,
      entryFee: draft.entryFeeText.isNotEmpty ? draft.entryFeeText : null,
      budgetPerDayLabel: meta.sameBudgetForAll && meta.budgetPerDay != null
          ? _budgetLabelWithCurrency(meta.budgetPerDay!, meta.budgetCurrencyCode)
          : '',
      budgetPerMatchLabel: meta.sameBudgetForAll && meta.budgetPerMatch != null
          ? _budgetLabelWithCurrency(
              meta.budgetPerMatch!,
              meta.budgetCurrencyCode,
            )
          : '',
      budgetByRoleLabels: meta.sameBudgetForAll
          ? const []
          : officialBudgetSummaryLines(meta),
      budgetCurrencyCode: meta.budgetCurrencyCode,
      ballType: draft.ballTypeOther ? 'Other' : draft.ballType.name,
      matchFormat: tournamentMatchFormatLabel(meta.matchFormat),
      formatLabel: _tournamentTypeLabel(draft.format),
      teamCount: meta.totalTeams ?? meta.teamsRequired,
      registrationStatus: draft.needMoreTeams ? 'Open' : '',
      contactVisibility: visibility,
      contactMethods: methods,
      contactPhone: methods.contains(CommunityContactVisibility.phone)
          ? phone
          : '',
      contactWhatsApp: methods.contains(CommunityContactVisibility.whatsapp)
          ? phone
          : '',
      contactEmail: methods.contains(CommunityContactVisibility.email)
          ? email
          : '',
      organizerUserId: organizerUserId,
    );
  }

  List<CommunityContactVisibility> _contactMethods(
    Set<OfficialContactMethod> methods,
  ) {
    final ordered = <CommunityContactVisibility>[];
    void add(OfficialContactMethod src, CommunityContactVisibility dest) {
      if (methods.contains(src) && !ordered.contains(dest)) {
        ordered.add(dest);
      }
    }

    add(OfficialContactMethod.inAppMessage, CommunityContactVisibility.crickflowDm);
    add(OfficialContactMethod.whatsApp, CommunityContactVisibility.whatsapp);
    add(OfficialContactMethod.phoneCall, CommunityContactVisibility.phone);
    add(OfficialContactMethod.email, CommunityContactVisibility.email);
    return ordered;
  }

  String _tournamentTypeLabel(TournamentFormat format) => switch (format) {
        TournamentFormat.league => 'League',
        TournamentFormat.knockout => 'Knockout',
        TournamentFormat.leagueKnockout => 'League Knockout',
        TournamentFormat.custom => 'Custom',
      };

  /// One short line — details live on the tournament card.
  String _officialsPostBody(TournamentSetupMeta meta) {
    final roles = meta.requiredOfficialRoles.map((r) => r.name).join(', ');
    if (roles.isNotEmpty) return 'Looking for: $roles';
    return '';
  }

  String _budgetLabelWithCurrency(OfficialBudgetBand band, String currency) {
    final label = officialBudgetLabel(band);
    final code = currency.trim();
    if (code.isEmpty) return label;
    return '$label $code';
  }

  String _teamsPostBody(
    TournamentCreateDraft draft,
    TournamentSetupMeta meta,
  ) {
    final needed = meta.teamsRequired;
    if (needed != null && needed > 0) {
      return 'Need $needed more team${needed == 1 ? '' : 's'}';
    }
    if (meta.additionalDetails.trim().isNotEmpty) {
      final t = meta.additionalDetails.trim();
      return t.length > 120 ? '${t.substring(0, 117)}…' : t;
    }
    return '';
  }
}

final tournamentCreateServiceProvider = Provider((ref) {
  return TournamentCreateService(
    tournamentRepository: ref.watch(tournamentRepositoryProvider),
    communityRepository: ref.watch(communityRepositoryProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});
