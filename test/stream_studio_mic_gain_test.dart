import 'package:crickflow/features/streaming/data/models/stream_studio_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new stream studio config defaults mic gain to 0', () {
    expect(const StreamStudioConfig().micGain, 0);
  });
}
