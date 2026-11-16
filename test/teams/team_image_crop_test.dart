import 'package:crickflow/features/teams/presentation/utils/team_image_crop_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';

void main() {
  test('reduced aspect ratio is positive and in lowest terms', () {
    expect(reducedAspectRatio(1920, 1080), (16, 9));
    expect(reducedAspectRatio(4000, 3000), (4, 3));
    expect(reducedAspectRatio(100, 100), (1, 1));
    expect(reducedAspectRatio(0, 100), isNull);
    expect(reducedAspectRatio(-3, 4), isNull);
  });

  test('document presets never include the built-in original (null ratio)', () {
    final unknown = documentAspectPresets();
    expect(unknown, isNot(contains(CropAspectRatioPreset.original)));
    expect(unknown.first, CropAspectRatioPreset.square);

    final known = documentAspectPresets(width: 4032, height: 2268);
    expect(known, isNot(contains(CropAspectRatioPreset.original)));
    expect(known.first, isA<DocumentOriginalPreset>());
    final original = known.first as DocumentOriginalPreset;
    expect(original.ratioX, greaterThan(0));
    expect(original.ratioY, greaterThan(0));
    expect(original.data, isNotNull);
  });

  test('registration size caps match storage.rules', () {
    expect(registrationMaxBytes(isDocument: true), 5 * 1024 * 1024 - 1);
    expect(registrationMaxBytes(isDocument: false), 2 * 1024 * 1024 - 1);
    expect(
      registrationTooLargeMessage(isDocument: true),
      contains('5 MB'),
    );
  });
}
