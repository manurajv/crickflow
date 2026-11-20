import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Re-subscribes to a Firestore stream after a `permission-denied` error.
///
/// Right after a client creates a document (e.g. a new team), local listeners
/// see it before the server has committed it. A listener on a child
/// collection started in that window is checked by the server against the
/// not-yet-written parent and denied. Retrying a few times with a short
/// backoff lets it succeed once the write lands. Real denials still surface
/// after the last attempt.
Stream<T> retryOnPermissionDenied<T>(
  Stream<T> Function() subscribe, {
  List<Duration> delays = const [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ],
}) {
  late StreamController<T> controller;
  StreamSubscription<T>? sub;
  Timer? timer;
  var attempt = 0;
  var cancelled = false;

  void listen() {
    sub = subscribe().listen(
      (value) {
        attempt = 0;
        controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        final denied =
            error is FirebaseException && error.code == 'permission-denied';
        if (denied && attempt < delays.length && !cancelled) {
          final delay = delays[attempt++];
          sub?.cancel();
          timer = Timer(delay, () {
            if (!cancelled) listen();
          });
          return;
        }
        controller.addError(error, stack);
      },
      onDone: () {
        if (timer == null || !(timer!.isActive)) controller.close();
      },
      cancelOnError: false,
    );
  }

  controller = StreamController<T>(
    onListen: listen,
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () async {
      cancelled = true;
      timer?.cancel();
      await sub?.cancel();
    },
  );
  return controller.stream;
}
