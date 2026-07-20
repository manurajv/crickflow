import 'package:equatable/equatable.dart';

import '../../core/utils/date_utils.dart';

/// Active in-match break (drinks, rain, lunch, etc.).
class ActiveMatchBreakModel extends Equatable {
  const ActiveMatchBreakModel({
    required this.breakType,
    required this.startTime,
    required this.startedBy,
    this.reason = '',
    this.status = 'active',
  });

  final String breakType;
  final DateTime startTime;
  final String startedBy;
  final String reason;
  final String status;

  bool get isActive => status == 'active';

  factory ActiveMatchBreakModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return ActiveMatchBreakModel(
        breakType: '',
        startTime: DateTime.now(),
        startedBy: '',
      );
    }
    return ActiveMatchBreakModel(
      breakType: map['breakType'] as String? ?? '',
      startTime: DateTime.tryParse(map['startTime']?.toString() ?? '') ??
          DateTime.now(),
      startedBy: map['startedBy'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toMap() => {
        'breakType': breakType,
        'startTime': startTime.toIso8601String(),
        'startedBy': startedBy,
        if (reason.isNotEmpty) 'reason': reason,
        'status': status,
      };

  @override
  List<Object?> get props => [breakType, startTime, startedBy, reason, status];
}

/// Completed break stored in match history.
class MatchBreakHistoryEntry extends Equatable {
  const MatchBreakHistoryEntry({
    required this.breakType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.reason = '',
  });

  final String breakType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String reason;

  factory MatchBreakHistoryEntry.fromMap(Map<String, dynamic> map) {
    return MatchBreakHistoryEntry(
      breakType: map['breakType'] as String? ?? '',
      startTime: DateTime.tryParse(map['startTime']?.toString() ?? '') ??
          DateTime.now(),
      endTime: DateTime.tryParse(map['endTime']?.toString() ?? ''),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      reason: map['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'breakType': breakType,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime!.toIso8601String(),
        'durationSeconds': durationSeconds,
        if (reason.isNotEmpty) 'reason': reason,
      };

  String get displayLabel {
    final mins = (durationSeconds / 60).round();
    return '$breakType – $mins min${mins == 1 ? '' : 's'}';
  }

  /// e.g. `11:30 AM – 11:45 AM` (or start only if end missing).
  String get timeRangeLabel {
    final start = AppDateUtils.formatTime(startTime.toLocal());
    if (endTime == null) return 'Started $start';
    final end = AppDateUtils.formatTime(endTime!.toLocal());
    return '$start – $end';
  }

  @override
  List<Object?> get props =>
      [breakType, startTime, endTime, durationSeconds, reason];
}
