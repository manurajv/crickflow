import 'package:crickflow/core/utils/atomic_create.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('runAtomicCreate (t43: no half-created teams / tournaments)', () {
    test('commits once with every uploaded URL and keeps the files', () async {
      final deleted = <String>[];
      final result = await runAtomicCreate<String>(
        uploads: {
          'logo': () async => UploadedAsset(
                url: 'u/logo',
                delete: () async => deleted.add('u/logo'),
              ),
          'cover': () async => UploadedAsset(
                url: 'u/cover',
                delete: () async => deleted.add('u/cover'),
              ),
        },
        commit: (urls) async => '${urls['logo']}|${urls['cover']}',
      );
      expect(result, 'u/logo|u/cover');
      expect(deleted, isEmpty);
    });

    test('commit failure (e.g. PERMISSION_DENIED) deletes every upload', () async {
      final deleted = <String>[];
      await expectLater(
        runAtomicCreate<void>(
          uploads: {
            'logo': () async => UploadedAsset(
                  url: 'u/logo',
                  delete: () async => deleted.add('u/logo'),
                ),
            'thumb': () async => UploadedAsset(
                  url: 'u/thumb',
                  delete: () async => deleted.add('u/thumb'),
                ),
          },
          commit: (_) async => throw Exception(
            '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
          ),
        ),
        throwsException,
      );
      expect(deleted, ['u/thumb', 'u/logo']);
    });

    test('upload failure never commits and removes earlier uploads', () async {
      final deleted = <String>[];
      var committed = false;
      await expectLater(
        runAtomicCreate<void>(
          uploads: {
            'logo': () async => UploadedAsset(
                  url: 'u/logo',
                  delete: () async => deleted.add('u/logo'),
                ),
            'cover': () async => throw Exception('network down'),
          },
          commit: (_) async => committed = true,
        ),
        throwsException,
      );
      expect(committed, isFalse);
      expect(deleted, ['u/logo']);
    });

    test('a failing cleanup does not hide the original error', () async {
      Object? cleanupError;
      await expectLater(
        runAtomicCreate<void>(
          uploads: {
            'logo': () async => UploadedAsset(
                  url: 'u/logo',
                  delete: () async => throw StateError('storage offline'),
                ),
          },
          commit: (_) async => throw AtomicCreateException('boom'),
          onCleanupError: (e) => cleanupError = e,
        ),
        throwsA(isA<AtomicCreateException>()),
      );
      expect(cleanupError, isA<StateError>());
    });
  });

  group('friendlyCreateError', () {
    test('permission denied is explained, nothing saved', () {
      expect(
        friendlyCreateError(Exception(
          '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
        )),
        "You don't have permission to do this. Nothing was saved.",
      );
    });
    test('network problems ask to retry', () {
      expect(
        friendlyCreateError(Exception('[cloud_firestore/unavailable] x')),
        'Connection problem. Nothing was saved, so try again.',
      );
    });
    test('own messages pass through', () {
      expect(
        friendlyCreateError(AtomicCreateException('Could not generate Team ID.')),
        'Could not generate Team ID.',
      );
    });
  });
}
