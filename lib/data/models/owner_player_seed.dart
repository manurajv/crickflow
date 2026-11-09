/// The creator's own player profile, added to a new team in the same batch
/// as the team itself.
class OwnerPlayerSeed {
  const OwnerPlayerSeed.existing({required this.playerId, this.fullName})
      : exists = true,
        newPlayerData = null;

  const OwnerPlayerSeed.create({
    required this.playerId,
    required Map<String, dynamic> this.newPlayerData,
  })  : exists = false,
        fullName = null;

  final String playerId;
  final bool exists;
  final String? fullName;

  /// Full player doc when [exists] is false.
  final Map<String, dynamic>? newPlayerData;
}
