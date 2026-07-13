import 'package:flutter_test/flutter_test.dart';
import 'package:crickflow/features/streaming/domain/stream_permission_service.dart';

void main() {
  const service = StreamPermissionService();

  test('signed-in users can go live', () {
    expect(service.canStartStream(userId: 'uid-1'), isTrue);
  });

  test('guests without an account cannot go live', () {
    expect(service.canStartStream(userId: null), isFalse);
    expect(service.canStartStream(userId: ''), isFalse);
  });
}
