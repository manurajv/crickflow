import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home page already used in Settings and the app drawer.
const kMavixasHomeUrl = 'https://mavixas.com';

/// "Powered by Mavixas 🇱🇰" with an external link to the company site.
class PoweredByMavixas extends StatelessWidget {
  const PoweredByMavixas({
    super.key,
    this.textStyle,
    this.mutedColor,
    this.linkColor,
    this.alignment = MainAxisAlignment.center,
  });

  final TextStyle? textStyle;
  final Color? mutedColor;
  final Color? linkColor;
  final MainAxisAlignment alignment;

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
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
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
    );
  }
}
