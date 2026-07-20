import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

enum LegalDocumentKind { privacyPolicy, termsOfService }

/// In-app Privacy Policy / Terms — themed Flutter content with an explicit back button.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind});

  final LegalDocumentKind kind;

  String get _title => switch (kind) {
        LegalDocumentKind.privacyPolicy => 'Privacy Policy',
        LegalDocumentKind.termsOfService => 'Terms of Service',
      };

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final sections = switch (kind) {
      LegalDocumentKind.privacyPolicy => _privacySections(),
      LegalDocumentKind.termsOfService => _termsSections(),
    };

    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(
        title: Text(_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceXl,
        ),
        children: [
          Text(
            _title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: cf.accent,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Last updated: July 2026',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cf.textMuted,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          for (final section in sections) ...[
            if (section.heading != null) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                section.heading!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cf.accent,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
            ],
            if (section.body != null)
              Text(
                section.body!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cf.textPrimary,
                      height: 1.55,
                    ),
              ),
            if (section.bullets != null)
              ...section.bullets!.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•  ',
                        style: TextStyle(color: cf.textPrimary, height: 1.55),
                      ),
                      Expanded(
                        child: Text.rich(
                          b,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cf.textPrimary,
                                height: 1.55,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            'Mavixas — CrickFlow support',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          InkWell(
            onTap: () => launchUrl(Uri.parse('mailto:mavixas.ceo@gmail.com')),
            child: Text(
              'mavixas.ceo@gmail.com',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.link,
                    decoration: TextDecoration.underline,
                    decorationColor: cf.link,
                  ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          TextButton.icon(
            onPressed: () => _goBack(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Settings'),
          ),
        ],
      ),
    );
  }

  List<_LegalSection> _privacySections() => [
        const _LegalSection(
          body:
              'CrickFlow is operated by Mavixas (“we”, “us”). This policy explains how we collect, use, store, and share information when you use the CrickFlow mobile app, websites, and related services (together, the “Service”).',
        ),
        _LegalSection(
          heading: 'Information we collect',
          bullets: [
            _boldLead(
              'Account: ',
              'Email, display name, phone number (if you use phone sign-in), and profile photo from Google Sign-In.',
            ),
            _boldLead(
              'Profile & cricket data: ',
              'Cricket ID, location (country/city), teams, players, squads, match scores, ball-by-ball events, tournaments, follows, and notification preferences you set.',
            ),
            _boldLead(
              'Device & notifications: ',
              'Firebase Cloud Messaging (FCM) token so we can send match and follow alerts you opt into.',
            ),
            _boldLead(
              'Streaming: ',
              'Camera and microphone are accessed only when you start a live stream. Stream destination settings (e.g. YouTube / custom RTMP) that you enter are stored to provide broadcasting features.',
            ),
            _boldLead(
              'Offline data: ',
              'Scoring actions may be stored temporarily on your device before syncing to our servers when you are online.',
            ),
          ],
        ),
        const _LegalSection(
          heading: 'How we use data',
          body:
              'We use this information to provide scoring, scorecards, tournaments, community features, notifications, live overlays, and optional streaming. We do not sell your personal data.',
        ),
        const _LegalSection(
          heading: 'Storage & security',
          body:
              'Data is stored in Google Firebase (project crickflow-b06bc) with authentication and security rules. You are responsible for keeping your login credentials secure.',
        ),
        _LegalSection(
          heading: 'Third parties',
          bullets: [
            TextSpan(text: 'Google (Authentication, Firebase, and Google Sign-In)'),
            TextSpan(text: 'YouTube / RTMP providers when you choose to broadcast'),
          ],
        ),
        const _LegalSection(
          body:
              'Their processing is governed by their own policies. We only share what is needed to operate the features you use.',
        ),
        _LegalSection(
          heading: 'Your choices',
          bullets: [
            _boldLead(
              'Notification Settings: ',
              'Control team and follow notification preferences in Settings → Notification Settings.',
            ),
            _boldLead(
              'Delete Account: ',
              'Removes your profile, linked player record, notifications, and Firebase sign-in. Matches and teams you created may remain visible to other users until an organizer removes them.',
            ),
            TextSpan(
              text:
                  'You may contact us to request access, correction, or deletion of additional personal data where applicable.',
            ),
          ],
        ),
        const _LegalSection(
          heading: 'Children',
          body:
              'CrickFlow is not directed at children under 13. If you believe a child has provided personal data, contact us and we will take appropriate steps to remove it.',
        ),
        const _LegalSection(
          heading: 'Changes',
          body:
              'We may update this policy from time to time. The “Last updated” date at the top reflects the latest revision. Continued use of the Service after changes are posted constitutes acceptance of the updated policy.',
        ),
      ];

  List<_LegalSection> _termsSections() => [
        const _LegalSection(
          body:
              'These Terms of Service (“Terms”) govern your use of the CrickFlow mobile application and related websites for cricket scoring and live streaming, operated by Mavixas.',
        ),
        const _LegalSection(
          heading: 'Acceptance',
          body:
              'By creating an account or using CrickFlow, you agree to these Terms and our Privacy Policy.',
        ),
        const _LegalSection(
          heading: 'Your account',
          body:
              'You are responsible for activity on your account and for keeping your login credentials secure. You must provide accurate profile information.',
        ),
        _LegalSection(
          heading: 'Acceptable use',
          bullets: [
            TextSpan(
              text:
                  'Use CrickFlow for lawful cricket scoring, tournaments, and optional live streaming.',
            ),
            TextSpan(text: 'Do not upload unlawful, abusive, or infringing content.'),
            TextSpan(
              text:
                  'Do not attempt to disrupt the service or access data you are not permitted to see.',
            ),
          ],
        ),
        const _LegalSection(
          heading: 'User content',
          body:
              'You retain ownership of match data, team names, and content you enter. You grant us permission to store and display that content to provide the service (e.g. scorecards, live overlays, shared links).',
        ),
        const _LegalSection(
          heading: 'Streaming & third parties',
          body:
              'If you connect YouTube or other RTMP providers, you must comply with their terms and policies. CrickFlow is not responsible for third-party platform outages or enforcement actions.',
        ),
        const _LegalSection(
          heading: 'Disclaimer',
          body:
              'CrickFlow is provided “as is” without warranties. We do not guarantee uninterrupted scoring, streaming, or data accuracy. Organizers are responsible for official match records.',
        ),
        const _LegalSection(
          heading: 'Limitation of liability',
          body:
              'To the extent permitted by law, CrickFlow and its operators are not liable for indirect or consequential damages arising from use of the app.',
        ),
        const _LegalSection(
          heading: 'Termination',
          body:
              'You may delete your account in the app under Settings → Delete Account. We may suspend access for violations of these Terms.',
        ),
        const _LegalSection(
          heading: 'Changes',
          body:
              'We may update these Terms. Continued use after changes are posted constitutes acceptance.',
        ),
      ];

  static TextSpan _boldLead(String lead, String rest) => TextSpan(
        children: [
          TextSpan(text: lead, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: rest),
        ],
      );
}

class _LegalSection {
  const _LegalSection({
    this.heading,
    this.body,
    this.bullets,
  });

  final String? heading;
  final String? body;
  final List<InlineSpan>? bullets;
}
