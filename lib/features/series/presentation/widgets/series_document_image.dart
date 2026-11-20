import 'package:flutter/material.dart';

/// Loads a registration document image with a per-image loading/error state.
/// Tap opens a full-screen pinch-zoom viewer.
class SeriesDocumentImage extends StatelessWidget {
  const SeriesDocumentImage({
    super.key,
    required this.url,
    required this.label,
    this.height = 180,
  });

  final String? url;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (src.isEmpty)
          _DocFrame(
            height: height,
            child: const Center(child: Text('No document uploaded')),
          )
        else
          GestureDetector(
            onTap: () =>
                openSeriesDocumentViewer(context, url: src, label: label),
            child: _DocFrame(
              height: height,
              child: _NetworkDocImage(url: src, fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }
}

class _DocFrame extends StatelessWidget {
  const _DocFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }
}

class _NetworkDocImage extends StatelessWidget {
  const _NetworkDocImage({required this.url, this.fit = BoxFit.contain});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
      errorBuilder: (context, error, stack) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Could not load this document. Try again.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}

Future<void> openSeriesDocumentViewer(
  BuildContext context, {
  required String url,
  required String label,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SeriesDocumentViewerScreen(url: url, label: label),
    ),
  );
}

class SeriesDocumentViewerScreen extends StatelessWidget {
  const SeriesDocumentViewerScreen({
    super.key,
    required this.url,
    required this.label,
  });

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(label),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: _NetworkDocImage(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
