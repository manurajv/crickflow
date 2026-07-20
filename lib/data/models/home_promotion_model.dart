import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum HomePromotionKind {
  advertisement,
  announcement,
}

/// Admin-managed home carousel item (ads + announcements).
class HomePromotionModel extends Equatable {
  const HomePromotionModel({
    required this.id,
    this.kind = HomePromotionKind.advertisement,
    this.title = '',
    this.description = '',
    this.imageUrl = '',
    this.buttonText = '',
    this.redirectAction = '',
    this.redirectUrl = '',
    this.priority = 0,
    this.active = true,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final HomePromotionKind kind;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;

  /// e.g. `url`, `route`, `none`
  final String redirectAction;
  final String redirectUrl;
  final int priority;
  final bool active;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isExpired {
    if (expiresAt == null) return false;
    return expiresAt!.isBefore(DateTime.now());
  }

  bool get isVisible => active && !isExpired;

  bool get isAnnouncement => kind == HomePromotionKind.announcement;

  factory HomePromotionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return HomePromotionModel.fromMap(doc.id, map);
  }

  factory HomePromotionModel.fromMap(String id, Map<String, dynamic> map) {
    final kindRaw = map['kind'] as String? ?? 'advertisement';
    final kind = HomePromotionKind.values.firstWhere(
      (k) => k.name == kindRaw,
      orElse: () => HomePromotionKind.advertisement,
    );
    DateTime? expiresAt;
    final expires = map['expiresAt'];
    if (expires is Timestamp) {
      expiresAt = expires.toDate();
    } else if (expires != null) {
      expiresAt = DateTime.tryParse(expires.toString());
    }
    DateTime? createdAt;
    final created = map['createdAt'];
    if (created is Timestamp) {
      createdAt = created.toDate();
    } else if (created != null) {
      createdAt = DateTime.tryParse(created.toString());
    }
    return HomePromotionModel(
      id: id,
      kind: kind,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      buttonText: map['buttonText'] as String? ?? '',
      redirectAction: map['redirectAction'] as String? ?? '',
      redirectUrl: map['redirectUrl'] as String? ?? map['redirect'] as String? ?? '',
      priority: map['priority'] as int? ?? 0,
      active: map['active'] as bool? ?? true,
      expiresAt: expiresAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'kind': kind.name,
        'title': title,
        'description': description,
        'imageUrl': imageUrl,
        'buttonText': buttonText,
        'redirectAction': redirectAction,
        'redirectUrl': redirectUrl,
        'priority': priority,
        'active': active,
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      };

  @override
  List<Object?> get props => [id, title, kind, priority, active];
}
