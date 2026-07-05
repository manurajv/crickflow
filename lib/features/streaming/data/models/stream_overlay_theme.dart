import 'package:equatable/equatable.dart';

import '../../domain/streaming_enums.dart';

class StreamOverlayTheme extends Equatable {
  const StreamOverlayTheme({
    this.layout = StreamOverlayLayout.full,
    this.primaryColor = 0xFF0D47A1,
    this.secondaryColor = 0xFFFFC107,
    this.opacity = 0.92,
    this.roundedCorners = true,
    this.compactMode = false,
    this.showSponsorBanner = true,
    this.showTicker = false,
    this.animationSpeed = 1.0,
    this.logoSize = 48.0,
    this.watermarkOpacity = 0.6,
    this.showWatermark = true,
  });

  final StreamOverlayLayout layout;
  final int primaryColor;
  final int secondaryColor;
  final double opacity;
  final bool roundedCorners;
  final bool compactMode;
  final bool showSponsorBanner;
  final bool showTicker;
  final double animationSpeed;
  final double logoSize;
  final double watermarkOpacity;
  final bool showWatermark;

  @override
  List<Object?> get props => [layout, primaryColor, opacity];
}

class StreamEventOverlay extends Equatable {
  const StreamEventOverlay({
    required this.type,
    required this.title,
    this.subtitle = '',
    this.playerName = '',
    this.playerId = '',
    this.duration = const Duration(seconds: 4),
    this.createdAt,
  });

  final StreamEventOverlayType type;
  final String title;
  final String subtitle;
  final String playerName;
  final String playerId;
  final Duration duration;
  final DateTime? createdAt;

  bool get isSidePanelEvent =>
      type == StreamEventOverlayType.newBowler ||
      type == StreamEventOverlayType.newBatter;

  @override
  List<Object?> get props => [type, title, playerId, createdAt];
}
