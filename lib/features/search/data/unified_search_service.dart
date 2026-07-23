import '../../../data/models/community_post_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/team_model.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../data/repositories/player_discovery_repository.dart';
import '../domain/search_models.dart';

class UnifiedSearchHit {
  const UnifiedSearchHit({
    required this.category,
    required this.score,
    this.player,
    this.team,
    this.match,
    this.tournament,
    this.post,
    this.groundName,
    this.groundCity,
    this.matchCount,
  });

  final SearchCategory category;
  final double score;
  final UserModel? player;
  final TeamModel? team;
  final MatchModel? match;
  final TournamentModel? tournament;
  final CommunityPostModel? post;
  final String? groundName;
  final String? groundCity;
  final int? matchCount;
}

class UnifiedSearchResult {
  const UnifiedSearchResult({
    required this.query,
    required this.category,
    this.hits = const [],
  });

  final String query;
  final SearchCategory category;
  final List<UnifiedSearchHit> hits;
}

class UnifiedSearchService {
  UnifiedSearchService({
    required PlayerDiscoveryRepository playerDiscovery,
    required CommunityRepository communityRepository,
  })  : _playerDiscovery = playerDiscovery,
        _community = communityRepository;

  final PlayerDiscoveryRepository _playerDiscovery;
  final CommunityRepository _community;

  Future<UnifiedSearchResult> search({
    required String query,
    required SearchCategory category,
    required List<MatchModel> matches,
    required List<TeamModel> teams,
    required List<TournamentModel> tournaments,
    String? currentUserId,
    UserModel? currentUser,
    int limit = 40,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      return UnifiedSearchResult(query: q, category: category);
    }

    final hits = <UnifiedSearchHit>[];

    Future<void> addPlayers() async {
      final players = await _playerDiscovery.searchPlayers(
        query: q,
        currentUserId: currentUserId,
        currentUser: currentUser,
        limit: limit,
      );
      for (final p in players) {
        final score = _maxScore([
          searchRelevanceScore(p.effectiveName, q),
          searchRelevanceScore(p.name, q),
          searchRelevanceScore(p.displayName, q),
          searchRelevanceScore(p.playerId ?? '', q),
        ]);
        // Always include discovery hits — they already matched by name.
        final followers = p.socialStats.followersCount;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.players,
            score: (score > 0 ? score : 500) +
                (followers.clamp(0, 500) * 0.05),
            player: p,
          ),
        );
      }
    }

    void addTeams() {
      for (final t in teams) {
        final score = _maxScore([
          searchRelevanceScore(t.name, q),
          searchRelevanceScore(t.teamCode ?? '', q),
          searchRelevanceScore(t.location.city, q),
        ]);
        if (score <= 0) continue;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.teams,
            score: score + t.memberCount.clamp(0, 200) * 0.02,
            team: t,
          ),
        );
      }
    }

    void addMatches() {
      for (final m in matches) {
        final score = _maxScore([
          searchRelevanceScore(m.title, q),
          searchRelevanceScore(m.teamAName, q),
          searchRelevanceScore(m.teamBName, q),
          searchRelevanceScore(m.venue, q),
          searchRelevanceScore(m.location.city, q),
        ]);
        if (score <= 0) continue;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.matches,
            score: score,
            match: m,
          ),
        );
      }
    }

    void addTournaments() {
      for (final t in tournaments) {
        final score = _maxScore([
          searchRelevanceScore(t.name, q),
          searchRelevanceScore(t.tournamentCode ?? '', q),
          searchRelevanceScore(t.location.city, q),
          searchRelevanceScore(t.location.displayLabel, q),
        ]);
        if (score <= 0) continue;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.tournaments,
            score: score,
            tournament: t,
          ),
        );
      }
    }

    void addGrounds() {
      final groundCounts = <String, int>{};
      final groundCities = <String, String>{};
      for (final m in matches) {
        final name = m.venue.trim();
        if (name.isEmpty) continue;
        groundCounts[name] = (groundCounts[name] ?? 0) + 1;
        if (m.location.city.isNotEmpty) {
          groundCities[name] = m.location.city;
        }
      }
      for (final entry in groundCounts.entries) {
        final score = searchRelevanceScore(entry.key, q);
        if (score <= 0) continue;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.grounds,
            score: score + entry.value.clamp(0, 50).toDouble(),
            groundName: entry.key,
            groundCity: groundCities[entry.key],
            matchCount: entry.value,
          ),
        );
      }
    }

    Future<void> addPosts() async {
      final posts = await _community.searchPosts(q, limit: limit);
      for (final p in posts) {
        final score = _maxScore([
          searchRelevanceScore(p.title, q),
          searchRelevanceScore(p.body, q),
          searchRelevanceScore(p.authorName, q),
          if (q.startsWith('#')) searchRelevanceScore(p.body, q) * 1.2,
        ]);
        if (score <= 0) continue;
        hits.add(
          UnifiedSearchHit(
            category: SearchCategory.posts,
            score: score + (p.likeCount.clamp(0, 200) * 0.1),
            post: p,
          ),
        );
      }
    }

    switch (category) {
      case SearchCategory.all:
        await addPlayers();
        addTeams();
        addMatches();
        addTournaments();
        addGrounds();
        await addPosts();
      case SearchCategory.players:
        await addPlayers();
      case SearchCategory.teams:
        addTeams();
      case SearchCategory.matches:
        addMatches();
      case SearchCategory.tournaments:
        addTournaments();
      case SearchCategory.grounds:
        addGrounds();
      case SearchCategory.posts:
        await addPosts();
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    return UnifiedSearchResult(
      query: q,
      category: category,
      hits: hits.take(limit).toList(),
    );
  }

  double _maxScore(List<double> scores) {
    var max = 0.0;
    for (final s in scores) {
      if (s > max) max = s;
    }
    return max;
  }
}
