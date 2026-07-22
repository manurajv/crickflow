import 'package:equatable/equatable.dart';

class CommunityCommentModel extends Equatable {
  const CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.authorPhotoUrl,
    this.parentId,
    this.likeCount = 0,
    this.createdAt,
    this.editedAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final String? parentId;
  final int likeCount;
  final DateTime? createdAt;
  final DateTime? editedAt;

  bool get isEdited => editedAt != null;

  factory CommunityCommentModel.fromMap(
    String id,
    Map<String, dynamic> map, {
    required String postId,
  }) {
    return CommunityCommentModel(
      id: id,
      postId: postId,
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      authorPhotoUrl: map['authorPhotoUrl'] as String?,
      text: map['text'] as String? ?? '',
      parentId: map['parentId'] as String?,
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? ''),
      editedAt: DateTime.tryParse(map['editedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() => {
        'authorId': authorId,
        'authorName': authorName,
        if (authorPhotoUrl != null) 'authorPhotoUrl': authorPhotoUrl,
        'text': text.trim(),
        if (parentId != null) 'parentId': parentId,
        'likeCount': likeCount,
        'createdAt': createdAt?.toIso8601String(),
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, postId, authorId, text, parentId, editedAt];
}
