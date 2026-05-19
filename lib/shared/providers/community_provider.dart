import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';
import '../../data/models/community_post_model.dart';
import '../../data/repositories/community_repository.dart';
import 'providers.dart';

final communityRepositoryProvider =
    Provider((ref) => CommunityRepository());

class CommunityFeedFilter {
  const CommunityFeedFilter({
    this.category,
    this.nearMeOnly = false,
  });

  final CommunityPostCategory? category;
  final bool nearMeOnly;

  CommunityFeedFilter copyWith({
    CommunityPostCategory? category,
    bool? clearCategory,
    bool? nearMeOnly,
  }) {
    return CommunityFeedFilter(
      category: clearCategory == true ? null : (category ?? this.category),
      nearMeOnly: nearMeOnly ?? this.nearMeOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CommunityFeedFilter &&
      other.category == category &&
      other.nearMeOnly == nearMeOnly;

  @override
  int get hashCode => Object.hash(category, nearMeOnly);
}

final communityFeedFilterProvider =
    StateProvider<CommunityFeedFilter>((ref) => const CommunityFeedFilter());

final communityPostsProvider =
    StreamProvider<List<CommunityPostModel>>((ref) {
  final filter = ref.watch(communityFeedFilterProvider);
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  final city = filter.nearMeOnly ? profile?.location.city : null;

  return ref.watch(communityRepositoryProvider).watchFeed(
        category: filter.category,
        city: city,
      );
});
