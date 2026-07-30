import 'package:equatable/equatable.dart';

import 'revenue_enums.dart';

class RevenueSummary extends Equatable {
  const RevenueSummary({
    this.estimatedTotal = 0,
    this.adsEstimated = 0,
    this.sponsorshipEstimated = 0,
    this.subscriptionEstimated = 0,
    this.transactionCount = 0,
    this.activeCampaigns = 0,
    this.currency = 'USD',
    this.readinessNote =
        'Architecture ready — no payment gateway. Figures are estimates from admin ads metadata.',
  });

  final double estimatedTotal;
  final double adsEstimated;
  final double sponsorshipEstimated;
  final double subscriptionEstimated;
  final int transactionCount;
  final int activeCampaigns;
  final String currency;
  final String readinessNote;

  @override
  List<Object?> get props => [estimatedTotal, adsEstimated, transactionCount];
}

class ManagedRevenueEntry extends Equatable {
  const ManagedRevenueEntry({
    required this.id,
    required this.title,
    required this.stream,
    required this.amount,
    required this.status,
    this.currency = 'USD',
    this.sourceId,
    this.note = '',
    this.createdAt,
  });

  final String id;
  final String title;
  final RevenueStreamKind stream;
  final double amount;
  final RevenueTxnStatus status;
  final String currency;
  final String? sourceId;
  final String note;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, stream, amount, status];
}

class RevenueIntegrationCard extends Equatable {
  const RevenueIntegrationCard({
    required this.id,
    required this.name,
    required this.description,
    required this.statusLabel,
    this.ready = false,
  });

  final String id;
  final String name;
  final String description;
  final String statusLabel;
  final bool ready;

  @override
  List<Object?> get props => [id, ready];
}
