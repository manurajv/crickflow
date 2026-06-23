import 'package:equatable/equatable.dart';
import '../../../core/constants/enums.dart';

class TournamentSponsorModel extends Equatable {
  const TournamentSponsorModel({
    required this.id,
    required this.tournamentId,
    required this.name,
    this.type = SponsorType.associate,
    this.logoUrl,
    this.website = '',
    this.sortOrder = 0,
    this.createdAt,
  });

  final String id;
  final String tournamentId;
  final String name;
  final SponsorType type;
  final String? logoUrl;
  final String website;
  final int sortOrder;
  final DateTime? createdAt;

  factory TournamentSponsorModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentSponsorModel(
      id: id,
      tournamentId: map['tournamentId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: SponsorType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SponsorType.associate,
      ),
      logoUrl: map['logoUrl'] as String?,
      website: map['website'] as String? ?? '',
      sortOrder: map['sortOrder'] as int? ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'tournamentId': tournamentId,
        'name': name,
        'type': type.name,
        if (logoUrl != null) 'logoUrl': logoUrl,
        'website': website,
        'sortOrder': sortOrder,
        'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

  @override
  List<Object?> get props => [id, name, type];
}
