import 'package:flutter_test/flutter_test.dart';
import 'package:crickflow/core/constants/app_constants.dart';

void main() {
  test('app name is CrickFlow', () {
    expect(AppConstants.appName, 'CrickFlow');
  });
}
