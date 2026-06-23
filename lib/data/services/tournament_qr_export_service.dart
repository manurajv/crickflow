import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/utils/deep_link_utils.dart';
import '../../data/models/tournament_model.dart';

/// Renders tournament invite QR cards (PNG) for sharing and download.
class TournamentQrExportService {
  const TournamentQrExportService();

  String buildInvitePayload(TournamentModel tournament) {
    return DeepLinkUtils.hostedTournamentJoinUri(tournament.id).toString();
  }

  Future<Uint8List> renderShareCard({
    required TournamentModel tournament,
    required Color accentColor,
  }) async {
    const cardWidth = 900.0;
    const horizontalPadding = 56.0;
    const qrSize = 520.0;
    const topPadding = 56.0;

    final payload = buildInvitePayload(tournament);
    final name = tournament.name.trim().isEmpty
        ? 'Tournament'
        : tournament.name.trim();
    final code = tournament.tournamentCode?.trim();
    const footer = 'Scan to join this tournament on CrickFlow';
    const subFooter =
        'Let cricketers find this tournament easily with this QR code.';

    final contentWidth = cardWidth - (horizontalPadding * 2);

    final titlePainter = _buildText(
      name,
      fontSize: 42,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF111827),
      maxWidth: contentWidth,
      align: TextAlign.center,
    );
    final codePainter = code != null && code.isNotEmpty
        ? _buildText(
            code,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: accentColor,
            maxWidth: contentWidth,
            align: TextAlign.center,
            letterSpacing: 1.2,
          )
        : null;
    final footerPainter = _buildText(
      footer,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF374151),
      maxWidth: contentWidth,
      align: TextAlign.center,
    );
    final subFooterPainter = _buildText(
      subFooter,
      fontSize: 20,
      fontWeight: FontWeight.w400,
      color: const Color(0xFF6B7280),
      maxWidth: contentWidth,
      align: TextAlign.center,
    );

    var y = topPadding;
    y += titlePainter.height + 36;
    final qrTop = y;
    y += qrSize + 36;
    if (codePainter != null) {
      y += codePainter.height + 20;
    }
    y += footerPainter.height + 10;
    y += subFooterPainter.height + topPadding;
    final cardHeight = y;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, cardWidth, cardHeight));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, cardWidth, cardHeight),
        const Radius.circular(28),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, cardWidth, cardHeight),
        const Radius.circular(28),
      ),
      Paint()
        ..color = const Color(0xFFE5E7EB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    var textY = topPadding;
    _paintText(
      canvas,
      titlePainter,
      Offset(horizontalPadding, textY),
      contentWidth,
    );
    textY += titlePainter.height + 36;

    final qrPainter = QrPainter(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: accentColor),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: accentColor,
      ),
    );
    canvas.save();
    canvas.translate((cardWidth - qrSize) / 2, qrTop);
    qrPainter.paint(canvas, const Size(qrSize, qrSize));
    canvas.restore();

    textY = qrTop + qrSize + 36;
    if (codePainter != null) {
      _paintText(canvas, codePainter, Offset(horizontalPadding, textY), contentWidth);
      textY += codePainter.height + 20;
    }

    _paintText(
      canvas,
      footerPainter,
      Offset(horizontalPadding, textY),
      contentWidth,
    );
    textY += footerPainter.height + 10;
    _paintText(
      canvas,
      subFooterPainter,
      Offset(horizontalPadding, textY),
      contentWidth,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(cardWidth.toInt(), cardHeight.toInt());
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Could not encode tournament QR card');
    }
    return byteData.buffer.asUint8List();
  }

  TextPainter _buildText(
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    required double maxWidth,
    required TextAlign align,
    double letterSpacing = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          height: 1.25,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: maxWidth);
    return painter;
  }

  void _paintText(
    Canvas canvas,
    TextPainter painter,
    Offset offset,
    double width,
  ) {
    final dx = offset.dx + (width - painter.width) / 2;
    painter.paint(canvas, Offset(dx, offset.dy));
  }
}
