import 'package:equatable/equatable.dart';
import '../../core/constants/enums.dart';
import 'location_model.dart';

class CommunityPostModel extends Equatable {
  const CommunityPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.body,
    this.category = CommunityPostCategory.general,
    this.authorRole = '',
    this.location = const LocationModel(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String authorRole;
  final CommunityPostCategory category;
  final String title;
  final String body;
  final LocationModel location;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CommunityPostModel.fromMap(String id, Map<String, dynamic> map) {
    return CommunityPostModel(
      id: id,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorRole: map['authorRole'] as String? ?? '',
      category: _categoryFromString(map['category'] as String?),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      location: LocationModel.fromMap(map['location'] as Map<String, dynamic>?),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(map['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        if (authorRole.isNotEmpty) 'authorRole': authorRole,
        'category': category.name,
        'title': title,
        'body': body,
        'location': location.toMap(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static CommunityPostCategory _categoryFromString(String? raw) {
    return CommunityPostCategory.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => CommunityPostCategory.general,
    );
  }

  @override
  List<Object?> get props => [id, authorId, title, category, createdAt];
}
