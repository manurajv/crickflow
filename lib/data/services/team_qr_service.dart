import 'dart:typed_data';

import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/cf_team_id_format.dart';
import '../../core/utils/deep_link_utils.dart';
import 'storage_service.dart';

/// Generates team invite QR PNGs and uploads them to Firebase Storage.
class TeamQrService {
  TeamQrService({StorageService? storage})
      : _storage = storage ?? StorageService();

  final StorageService _storage;

  /// HTTPS invite link; includes team code query for lookup when scanned on web.
  String buildInvitePayload({
    required String teamId,
    String? teamCode,
  }) {
    final base = DeepLinkUtils.httpsTeamUri(teamId);
    if (teamCode == null || teamCode.isEmpty) return base.toString();
    return base
        .replace(
          queryParameters: {
            'code': CfTeamIdFormat.normalize(teamCode),
          },
        )
        .toString();
  }

  Future<Uint8List> renderQrPng(String data, {double size = 512}) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );
    final image = await painter.toImageData(size);
    if (image == null) {
      throw StateError('Could not render team QR code');
    }
    return image.buffer.asUint8List();
  }

  Future<String> generateAndUploadTeamQr({
    required String teamId,
    String? teamCode,
  }) async {
    final payload = buildInvitePayload(teamId: teamId, teamCode: teamCode);
    final bytes = await renderQrPng(payload);
    return _storage.uploadTeamQr(teamId, bytes);
  }
}
