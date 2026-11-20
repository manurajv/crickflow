import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const kMavixasHomeUrl = 'https://mavixas.com';

class PoweredByMavixas extends StatelessWidget {
  const PoweredByMavixas({
    super.key,
    this.textStyle,
    this.mutedColor,
    this.linkColor,
    this.compact = false,
  });

  final TextStyle? textStyle;
  final Color? mutedColor;
  final Color? linkColor;
  final bool compact;

  static final uri = Uri.parse(kMavixasHomeUrl);

  Future<void> _open(BuildContext context) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $uri')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = textStyle ?? Theme.of(context).textTheme.bodySmall;
    final muted = mutedColor ?? base?.color;
    final link = linkColor ?? Theme.of(context).colorScheme.primary;
    if (compact) {
      return IconButton(
        tooltip: 'Powered by Mavixas',
        onPressed: () => _open(context),
        icon: const Text('🇱🇰', style: TextStyle(fontSize: 16)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Powered by ', style: base?.copyWith(color: muted)),
          InkWell(
            onTap: () => _open(context),
            child: Text(
              'Mavixas',
              style: base?.copyWith(
                color: link,
                decoration: TextDecoration.underline,
                decorationColor: link,
              ),
            ),
          ),
          Text(' 🇱🇰', style: base),
        ],
      ),
    );
  }
}
