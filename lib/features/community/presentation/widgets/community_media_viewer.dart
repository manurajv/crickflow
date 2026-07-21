import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/community_post_model.dart';

Future<void> openCommunityMediaViewer(
  BuildContext context, {
  required List<CommunityMediaItem> media,
  int initialIndex = 0,
}) {
  final images =
      media.where((m) => m.type != 'video' && m.url.isNotEmpty).toList();
  if (images.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, _, _) => CommunityMediaViewer(
        media: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class CommunityMediaViewer extends StatefulWidget {
  const CommunityMediaViewer({
    super.key,
    required this.media,
    this.initialIndex = 0,
  });

  final List<CommunityMediaItem> media;
  final int initialIndex;

  @override
  State<CommunityMediaViewer> createState() => _CommunityMediaViewerState();
}

class _CommunityMediaViewerState extends State<CommunityMediaViewer> {
  late final PageController _pageController;
  late int _index;
  final _transformController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final matrix = _transformController.value;
    final isZoomed = matrix.getMaxScaleOnAxis() > 1.05;
    if (isZoomed) {
      _transformController.value = Matrix4.identity();
      return;
    }
    final position = _doubleTapDetails?.localPosition;
    if (position == null) {
      _transformController.value = Matrix4.identity()..scaleByDouble(2.5, 2.5, 1, 1);
      return;
    }
    final x = -position.dx * 1.5;
    final y = -position.dy * 1.5;
    _transformController.value = Matrix4.identity()
      ..translateByDouble(x, y, 0, 1)
      ..scaleByDouble(2.5, 2.5, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.94),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.media.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _transformController.value = Matrix4.identity();
            },
            itemBuilder: (context, i) {
              final item = widget.media[i];
              return GestureDetector(
                onDoubleTapDown: (d) => _doubleTapDetails = d,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: i == _index
                      ? _transformController
                      : null,
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: item.url,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const CircularProgressIndicator(),
                      errorWidget: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        color: cf.textMuted,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.media.length > 1)
                    Text(
                      '${_index + 1} / ${widget.media.length}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
