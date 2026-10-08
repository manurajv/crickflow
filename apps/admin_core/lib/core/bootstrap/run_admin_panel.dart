import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/firebase_bootstrap.dart';

/// Starts an admin web panel without ever leaving a blank page.
///
/// If Firebase cannot start (network, blocked scripts, bad config) the user
/// gets a readable error screen with a retry button instead of a white page.
/// Build errors deep in the tree render as a small error card in release
/// builds instead of an empty grey box.
Future<void> runAdminPanel({
  required FirebaseOptions options,
  required Widget Function() buildApp,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  await _start(options, buildApp);
}

Future<void> _start(
  FirebaseOptions options,
  Widget Function() buildApp,
) async {
  try {
    await bootstrapFirebase(options).timeout(const Duration(seconds: 25));
  } catch (error, stack) {
    debugPrint('Admin panel startup failed: $error\n$stack');
    runApp(
      AdminStartupErrorApp(
        error: error,
        onRetry: () => _start(options, buildApp),
      ),
    );
    return;
  }
  runApp(buildApp());
}

void _installErrorHandlers() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previous != null) {
      previous(details);
    } else {
      FlutterError.presentError(details);
    }
    // Always log, including release builds, so the console shows the cause.
    debugPrint('Admin panel error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Admin panel uncaught error: $error\n$stack');
    return true;
  };
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => AdminInlineError(
          message: details.exceptionAsString(),
        );
  }
}

/// Small error card used in place of a widget that failed to build.
class AdminInlineError extends StatelessWidget {
  const AdminInlineError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: Text(
          'Something went wrong showing this section.\n$message',
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 12),
        ),
      ),
    );
  }
}

/// Full-page error shown when the panel cannot start.
class AdminStartupErrorApp extends StatefulWidget {
  const AdminStartupErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final Future<void> Function() onRetry;

  @override
  State<AdminStartupErrorApp> createState() => _AdminStartupErrorAppState();
}

class _AdminStartupErrorAppState extends State<AdminStartupErrorApp> {
  bool _retrying = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "The admin panel couldn't start",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection, then try again. If it keeps '
                      'happening, reload with Ctrl+Shift+R (Cmd+Shift+R on Mac).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '${widget.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retrying
                          ? null
                          : () async {
                              setState(() => _retrying = true);
                              await widget.onRetry();
                              if (mounted) setState(() => _retrying = false);
                            },
                      icon: const Icon(Icons.refresh),
                      label: Text(_retrying ? 'Retrying…' : 'Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
