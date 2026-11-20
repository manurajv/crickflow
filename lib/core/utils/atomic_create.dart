import 'package:flutter/foundation.dart';

/// A file uploaded as part of a create flow, with a way to remove it again.
class UploadedAsset {
  const UploadedAsset({required this.url, required this.delete});

  final String url;
  final Future<void> Function() delete;
}

/// Thrown when a create flow fails. Nothing from the attempt is kept.
class AtomicCreateException implements Exception {
  AtomicCreateException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// All-or-nothing create:
/// 1. uploads every file (named, in order),
/// 2. runs [commit] once with the uploaded URLs (one Firestore batch /
///    transaction / callable, so the records land together or not at all),
/// 3. on ANY failure deletes every file it uploaded and rethrows.
///
/// Callers must not write any record before [commit].
Future<T> runAtomicCreate<T>({
  Map<String, Future<UploadedAsset> Function()> uploads = const {},
  required Future<T> Function(Map<String, String> urls) commit,
  void Function(Object error)? onCleanupError,
}) async {
  final uploaded = <UploadedAsset>[];
  final urls = <String, String>{};
  try {
    for (final entry in uploads.entries) {
      final asset = await entry.value();
      uploaded.add(asset);
      urls[entry.key] = asset.url;
    }
    return await commit(urls);
  } catch (_) {
    for (final asset in uploaded.reversed) {
      try {
        await asset.delete();
      } catch (cleanupError) {
        debugPrint('atomic create cleanup failed: $cleanupError');
        onCleanupError?.call(cleanupError);
      }
    }
    rethrow;
  }
}

/// Short, user-facing reason for a failed create ("Could not create team: …").
String friendlyCreateError(Object error) {
  if (error is AtomicCreateException) return error.message;
  final text = error.toString().toLowerCase();
  if (text.contains('permission-denied') ||
      text.contains('permission_denied') ||
      text.contains('insufficient permissions')) {
    return "You don't have permission to do this. Nothing was saved.";
  }
  if (text.contains('unavailable') ||
      text.contains('network') ||
      text.contains('deadline-exceeded') ||
      text.contains('timeout')) {
    return 'Connection problem. Nothing was saved, so try again.';
  }
  if (text.contains('unauthenticated')) {
    return 'Please sign in again. Nothing was saved.';
  }
  final raw = error.toString();
  final cleaned = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  return cleaned.length > 160 ? 'Something went wrong. Nothing was saved.' : cleaned;
}
