/// How far before the scored moment replay markers seek in the stream.
///
/// Scorers often confirm 10–20s after the ball; pre-roll ensures viewers
/// see the delivery (run-up, release, contact), not the aftermath.
const int kReplayPreRollMs = 10000;

int replayMarkerOffsetMs({
  required DateTime? sessionStartedAt,
  DateTime? eventTime,
}) {
  if (sessionStartedAt == null) return 0;
  final anchor = eventTime ?? DateTime.now();
  final rawMs = anchor.difference(sessionStartedAt).inMilliseconds;
  if (rawMs <= 0) return 0;
  return (rawMs - kReplayPreRollMs).clamp(0, rawMs).toInt();
}
