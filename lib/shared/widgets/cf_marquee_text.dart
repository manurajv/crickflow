import 'package:flutter/material.dart';

/// Horizontally scrolls [text] when it overflows the available width.
class CfMarqueeText extends StatefulWidget {
  const CfMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 28,
    this.gap = 40,
    this.pauseBeforeStart = const Duration(milliseconds: 1500),
  });

  final String text;
  final TextStyle? style;
  final double velocity;
  final double gap;
  final Duration pauseBeforeStart;

  @override
  State<CfMarqueeText> createState() => _CfMarqueeTextState();
}

class _CfMarqueeTextState extends State<CfMarqueeText>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  ScrollController? _scrollController;
  double _viewportWidth = 0;
  double _textWidth = 0;

  @override
  void didUpdateWidget(CfMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.velocity != widget.velocity ||
        oldWidget.gap != widget.gap) {
      _stopAnimation();
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    super.dispose();
  }

  void _stopAnimation() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    _controller = null;
    _scrollController?.dispose();
    _scrollController = null;
    _viewportWidth = 0;
    _textWidth = 0;
  }

  void _onTick() {
    final controller = _controller;
    final scrollController = _scrollController;
    if (controller == null || scrollController == null || !scrollController.hasClients) {
      return;
    }
    final distance = _textWidth + widget.gap;
    scrollController.jumpTo(controller.value * distance);
  }

  void _ensureAnimation({
    required bool shouldMarquee,
    required double viewportWidth,
    required double textWidth,
  }) {
    if (!shouldMarquee) {
      if (_controller != null) {
        _stopAnimation();
        setState(() {});
      }
      return;
    }

    if (_controller != null &&
        _viewportWidth == viewportWidth &&
        _textWidth == textWidth) {
      return;
    }

    _stopAnimation();
    _viewportWidth = viewportWidth;
    _textWidth = textWidth;

    final distance = textWidth + widget.gap;
    final durationMs =
        (distance / widget.velocity * 1000).round().clamp(3000, 20000);
    _scrollController = ScrollController();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    )..addListener(_onTick);

    setState(() {});

    Future<void>.delayed(widget.pauseBeforeStart, () {
      if (!mounted || _controller == null) return;
      _controller!.repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    final textDirection = Directionality.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        if (!viewportWidth.isFinite || viewportWidth <= 0) {
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          textDirection: textDirection,
          maxLines: 1,
        )..layout(maxWidth: double.infinity);

        final textWidth = painter.width;
        final textHeight = painter.height;
        final shouldMarquee = textWidth > viewportWidth + 1;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ensureAnimation(
            shouldMarquee: shouldMarquee,
            viewportWidth: viewportWidth,
            textWidth: textWidth,
          );
        });

        if (!shouldMarquee) {
          return Text(
            widget.text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        final scrollController = _scrollController;

        return SizedBox(
          width: viewportWidth,
          height: textHeight,
          child: scrollController == null
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.text,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  clipBehavior: Clip.hardEdge,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.text,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      SizedBox(width: widget.gap),
                      Text(
                        widget.text,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
