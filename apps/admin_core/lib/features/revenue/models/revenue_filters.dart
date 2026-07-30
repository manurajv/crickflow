import 'revenue_enums.dart';

class RevenueFilters {
  const RevenueFilters({
    this.query = '',
    this.stream,
    this.status,
  });

  static const empty = RevenueFilters();

  final String query;
  final RevenueStreamKind? stream;
  final RevenueTxnStatus? status;

  bool get hasActiveFilters =>
      query.trim().isNotEmpty || stream != null || status != null;

  RevenueFilters copyWith({
    String? query,
    RevenueStreamKind? stream,
    bool clearStream = false,
    RevenueTxnStatus? status,
    bool clearStatus = false,
  }) {
    return RevenueFilters(
      query: query ?? this.query,
      stream: clearStream ? null : (stream ?? this.stream),
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}
