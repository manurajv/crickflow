import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _allowedUrl = RegExp(r'^(https?:\/\/|\/)[^\s]*$', caseSensitive: false);

String stripAnnouncementHtml(String input) {
  return input
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<\s*/p\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
      .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
      .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
      .replaceAll('&#39;', "'");
}

String sanitizeAnnouncementText(String input, {int maxLength = 20000}) {
  var text = stripAnnouncementHtml(input)
      .replaceAll('\u0000', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  text = text.replaceAll(RegExp(r'javascript\s*:', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'vbscript\s*:', caseSensitive: false), '');
  text = text.replaceAll(RegExp(r'data\s*:', caseSensitive: false), '');
  text = text.trim();
  if (text.length > maxLength) text = text.substring(0, maxLength);
  return text;
}

bool isSafeAnnouncementHref(String href) {
  final value = href.trim();
  if (value.isEmpty || value.startsWith('//')) return false;
  if (!_allowedUrl.hasMatch(value)) return false;
  final lower = value.toLowerCase();
  return !lower.contains('javascript:') &&
      !lower.contains('data:') &&
      !lower.contains('vbscript:');
}

final _inline = RegExp(r'\[([^\]]+)\]\(([^)]+)\)|\*\*([^*]+)\*\*|\*([^*]+)\*|_([^_]+)_');

List<InlineSpan> announcementInlineSpans(
  String text, {
  required TextStyle style,
  required TextStyle bold,
  required TextStyle italic,
  required TextStyle link,
  required void Function(String href) onLink,
}) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in _inline.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start), style: style));
    }
    if (match[1] != null && match[2] != null) {
      final href = match[2]!.trim();
      final label = match[1]!;
      if (isSafeAnnouncementHref(href)) {
        spans.add(TextSpan(
          text: label,
          style: link,
          recognizer: TapGestureRecognizer()..onTap = () => onLink(href),
        ));
      } else {
        spans.add(TextSpan(text: label, style: style));
      }
    } else if (match[3] != null) {
      spans.add(TextSpan(text: match[3], style: bold));
    } else {
      spans.add(TextSpan(text: match[4] ?? match[5] ?? '', style: italic));
    }
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: style));
  }
  return spans.isEmpty ? [TextSpan(text: '', style: style)] : spans;
}

/// Renders the same conservative markdown subset as the website announcements.
class AnnouncementBody extends StatelessWidget {
  const AnnouncementBody({super.key, required this.body, this.style, this.maxLines});

  final String body;
  final TextStyle? style;
  final int? maxLines;

  Future<void> _open(BuildContext context, String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $href')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = sanitizeAnnouncementText(body);
    if (text.isEmpty) return const SizedBox.shrink();
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final bold = (base ?? const TextStyle()).copyWith(fontWeight: FontWeight.w700);
    final italic = (base ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic);
    final link = (base ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final paragraphs = <Widget>[];
    final lines = text.split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final bullet = RegExp(r'^\s*[-*]\s+').hasMatch(line);
      final numbered = RegExp(r'^\s*\d+\.\s+').hasMatch(line);
      if (bullet || numbered) {
        final items = <String>[];
        while (i < lines.length) {
          final l = lines[i];
          final b = RegExp(r'^\s*[-*]\s+').hasMatch(l);
          final n = RegExp(r'^\s*\d+\.\s+').hasMatch(l);
          if (!b && !n) break;
          items.add(l.replaceFirst(RegExp(r'^\s*([-*]|\d+\.)\s+'), ''));
          i++;
        }
        paragraphs.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var n = 0; n < items.length; n++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bullet ? '•  ' : '${n + 1}. ', style: base),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: announcementInlineSpans(
                          items[n],
                          style: base ?? const TextStyle(),
                          bold: bold,
                          italic: italic,
                          link: link,
                          onLink: (href) => _open(context, href),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ));
        continue;
      }
      paragraphs.add(Text.rich(
        TextSpan(
          children: announcementInlineSpans(
            line,
            style: base ?? const TextStyle(),
            bold: bold,
            italic: italic,
            link: link,
            onLink: (href) => _open(context, href),
          ),
        ),
        maxLines: maxLines,
        overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
      ));
      i++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var p = 0; p < paragraphs.length; p++) ...[
          if (p > 0) const SizedBox(height: 6),
          paragraphs[p],
        ],
      ],
    );
  }
}
