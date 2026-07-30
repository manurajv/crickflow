import 'package:equatable/equatable.dart';

import 'monitoring_enums.dart';

class MonitoringKpi extends Equatable {
  const MonitoringKpi({
    required this.id,
    required this.label,
    required this.value,
    this.subtitle = '',
    this.health,
  });

  final String id;
  final String label;
  final String value;
  final String subtitle;
  final PlatformServiceHealth? health;

  @override
  List<Object?> get props => [id, value, health];
}

class ServiceStatusItem extends Equatable {
  const ServiceStatusItem({
    required this.id,
    required this.label,
    required this.health,
    this.note = '',
    this.lastChecked,
  });

  final FirebaseServiceId id;
  final String label;
  final PlatformServiceHealth health;
  final String note;
  final DateTime? lastChecked;

  @override
  List<Object?> get props => [id, health];
}

class FirestoreMetrics extends Equatable {
  const FirestoreMetrics({
    this.reads = 0,
    this.writes = 0,
    this.deletes = 0,
    this.queries = 0,
    this.activeConnections = 0,
    this.avgResponseMs = 0,
    this.topCollections = const [],
  });

  final int reads;
  final int writes;
  final int deletes;
  final int queries;
  final int activeConnections;
  final int avgResponseMs;
  final List<NamedCount> topCollections;

  @override
  List<Object?> get props => [reads, writes, deletes, queries];
}

class NamedCount extends Equatable {
  const NamedCount({required this.name, required this.count});

  final String name;
  final int count;

  @override
  List<Object?> get props => [name, count];
}

class AuthMetrics extends Equatable {
  const AuthMetrics({
    this.loggedInEstimate = 0,
    this.loginsToday = 0,
    this.failedLogins = 0,
    this.passwordResets = 0,
    this.googleSignIns = 0,
    this.emailSignIns = 0,
    this.blockedLogins = 0,
    this.suspiciousLogins = 0,
  });

  final int loggedInEstimate;
  final int loginsToday;
  final int failedLogins;
  final int passwordResets;
  final int googleSignIns;
  final int emailSignIns;
  final int blockedLogins;
  final int suspiciousLogins;

  @override
  List<Object?> get props => [loginsToday, failedLogins];
}

class CloudFunctionStatus extends Equatable {
  const CloudFunctionStatus({
    required this.name,
    this.status = PlatformServiceHealth.unknown,
    this.executions = 0,
    this.avgDurationMs = 0,
    this.failures = 0,
    this.memoryMb = 0,
    this.lastExecution,
    this.timeouts = 0,
  });

  final String name;
  final PlatformServiceHealth status;
  final int executions;
  final int avgDurationMs;
  final int failures;
  final int memoryMb;
  final DateTime? lastExecution;
  final int timeouts;

  @override
  List<Object?> get props => [name, status, executions];
}

class StorageMetrics extends Equatable {
  const StorageMetrics({
    this.totalLabel = '—',
    this.images = 0,
    this.videos = 0,
    this.documents = 0,
    this.broadcastAssets = 0,
    this.profilePictures = 0,
    this.tournamentPosters = 0,
    this.groundImages = 0,
    this.availableLabel = '—',
    this.growthPoints = const [],
  });

  final String totalLabel;
  final int images;
  final int videos;
  final int documents;
  final int broadcastAssets;
  final int profilePictures;
  final int tournamentPosters;
  final int groundImages;
  final String availableLabel;
  final List<double> growthPoints;

  @override
  List<Object?> get props => [totalLabel, images, videos];
}

class HostingDomainStatus extends Equatable {
  const HostingDomainStatus({
    required this.domain,
    this.status = PlatformServiceHealth.healthy,
    this.ssl = PlatformServiceHealth.healthy,
    this.note = '',
  });

  final String domain;
  final PlatformServiceHealth status;
  final PlatformServiceHealth ssl;
  final String note;

  @override
  List<Object?> get props => [domain, status];
}

class HostingMetrics extends Equatable {
  const HostingMetrics({
    this.status = PlatformServiceHealth.healthy,
    this.currentDeployment = '—',
    this.environment = MonitoringEnvironment.production,
    this.lastDeployment,
    this.domains = const [],
  });

  final PlatformServiceHealth status;
  final String currentDeployment;
  final MonitoringEnvironment environment;
  final DateTime? lastDeployment;
  final List<HostingDomainStatus> domains;

  @override
  List<Object?> get props => [status, currentDeployment, domains];
}

class FcmMetrics extends Equatable {
  const FcmMetrics({
    this.sentToday = 0,
    this.deliveryRate = 0,
    this.failures = 0,
    this.pending = 0,
    this.avgDeliveryMs = 0,
  });

  final int sentToday;
  final double deliveryRate;
  final int failures;
  final int pending;
  final int avgDeliveryMs;

  @override
  List<Object?> get props => [sentToday, deliveryRate, failures];
}

class StreamingHealthMetrics extends Equatable {
  const StreamingHealthMetrics({
    this.liveStreams = 0,
    this.youtube = 0,
    this.facebook = 0,
    this.externalRtmp = 0,
    this.broadcastSessions = 0,
    this.reconnectEvents = 0,
    this.avgDurationMin = 0,
    this.connectionFailures = 0,
    this.health = PlatformServiceHealth.healthy,
  });

  final int liveStreams;
  final int youtube;
  final int facebook;
  final int externalRtmp;
  final int broadcastSessions;
  final int reconnectEvents;
  final int avgDurationMin;
  final int connectionFailures;
  final PlatformServiceHealth health;

  @override
  List<Object?> get props => [liveStreams, health];
}

class DatabaseMetrics extends Equatable {
  const DatabaseMetrics({
    this.collections = 0,
    this.documentsEstimate = 0,
    this.estimatedSizeLabel = '—',
    this.readUsage = 0,
    this.writeUsage = 0,
    this.deleteUsage = 0,
    this.growthPoints = const [],
  });

  final int collections;
  final int documentsEstimate;
  final String estimatedSizeLabel;
  final int readUsage;
  final int writeUsage;
  final int deleteUsage;
  final List<double> growthPoints;

  @override
  List<Object?> get props => [collections, documentsEstimate];
}

class PerformanceMetrics extends Equatable {
  const PerformanceMetrics({
    this.avgApiResponseMs = 0,
    this.firestoreResponseMs = 0,
    this.cloudFunctionDurationMs = 0,
    this.realtimeLatencyMs = 0,
    this.avgQueryMs = 0,
  });

  final int avgApiResponseMs;
  final int firestoreResponseMs;
  final int cloudFunctionDurationMs;
  final int realtimeLatencyMs;
  final int avgQueryMs;

  @override
  List<Object?> get props => [avgApiResponseMs, firestoreResponseMs];
}

class MonitoringErrorItem extends Equatable {
  const MonitoringErrorItem({
    required this.id,
    required this.title,
    required this.module,
    required this.severity,
    required this.timestamp,
    this.status = 'Open',
    this.detail = '',
  });

  final String id;
  final String title;
  final String module;
  final MonitoringSeverity severity;
  final DateTime timestamp;
  final String status;
  final String detail;

  @override
  List<Object?> get props => [id, timestamp, severity];
}

class ScheduledJobItem extends Equatable {
  const ScheduledJobItem({
    required this.kind,
    this.status = BackgroundTaskStatus.pending,
    this.lastRun,
    this.note = 'Architecture ready — not implemented',
  });

  final ScheduledJobKind kind;
  final BackgroundTaskStatus status;
  final DateTime? lastRun;
  final String note;

  @override
  List<Object?> get props => [kind, status];
}

class BackgroundTaskItem extends Equatable {
  const BackgroundTaskItem({
    required this.id,
    required this.name,
    required this.status,
    this.updatedAt,
  });

  final String id;
  final String name;
  final BackgroundTaskStatus status;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [id, status];
}

class HealthTimelineEvent extends Equatable {
  const HealthTimelineEvent({
    required this.id,
    required this.title,
    required this.timestamp,
    this.severity = MonitoringSeverity.info,
    this.service,
    this.detail = '',
  });

  final String id;
  final String title;
  final DateTime timestamp;
  final MonitoringSeverity severity;
  final FirebaseServiceId? service;
  final String detail;

  @override
  List<Object?> get props => [id, timestamp];
}

class LiveStatusBarSnapshot extends Equatable {
  const LiveStatusBarSnapshot({
    this.platformHealth = PlatformServiceHealth.healthy,
    this.liveMatches = 0,
    this.liveStreams = 0,
    this.onlineUsers = 0,
    this.errors = 0,
  });

  final PlatformServiceHealth platformHealth;
  final int liveMatches;
  final int liveStreams;
  final int onlineUsers;
  final int errors;

  @override
  List<Object?> get props =>
      [platformHealth, liveMatches, liveStreams, onlineUsers, errors];
}

/// Full monitoring hub payload. Designed so Firebase Performance, Crashlytics,
/// BigQuery, Grafana, Datadog, and Sentry can replace repository internals later.
class MonitoringSnapshot extends Equatable {
  const MonitoringSnapshot({
    this.generatedAt,
    this.isOrgScoped = false,
    this.platformHealth = PlatformServiceHealth.healthy,
    this.overview = const [],
    this.services = const [],
    this.liveBar = const LiveStatusBarSnapshot(),
    this.firestore = const FirestoreMetrics(),
    this.auth = const AuthMetrics(),
    this.functions = const [],
    this.storage = const StorageMetrics(),
    this.hosting = const HostingMetrics(),
    this.fcm = const FcmMetrics(),
    this.streaming = const StreamingHealthMetrics(),
    this.database = const DatabaseMetrics(),
    this.performance = const PerformanceMetrics(),
    this.errors = const [],
    this.scheduledJobs = const [],
    this.backgroundTasks = const [],
    this.timeline = const [],
  });

  final DateTime? generatedAt;
  final bool isOrgScoped;
  final PlatformServiceHealth platformHealth;
  final List<MonitoringKpi> overview;
  final List<ServiceStatusItem> services;
  final LiveStatusBarSnapshot liveBar;
  final FirestoreMetrics firestore;
  final AuthMetrics auth;
  final List<CloudFunctionStatus> functions;
  final StorageMetrics storage;
  final HostingMetrics hosting;
  final FcmMetrics fcm;
  final StreamingHealthMetrics streaming;
  final DatabaseMetrics database;
  final PerformanceMetrics performance;
  final List<MonitoringErrorItem> errors;
  final List<ScheduledJobItem> scheduledJobs;
  final List<BackgroundTaskItem> backgroundTasks;
  final List<HealthTimelineEvent> timeline;

  @override
  List<Object?> get props => [generatedAt, platformHealth, overview.length];
}
