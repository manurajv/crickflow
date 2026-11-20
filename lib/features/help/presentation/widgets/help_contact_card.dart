import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/support_contact.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/friendly_error.dart';

class HelpContactCard extends StatelessWidget {
  const HelpContactCard({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError('Could not open that link.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      width: double.infinity,
      padding: AppDimens.cardPadding,
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact details',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Reach the CrickFlow team by email, phone, or WhatsApp.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          for (final email in SupportContact.emails) ...[
            _ContactTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
              onTap: () => _open(context, SupportContact.mailto(email)),
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],
          _ContactTile(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: SupportContact.phoneDisplay,
            onTap: () => _open(context, SupportContact.tel),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _ContactTile(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            value: SupportContact.phoneDisplay,
            onTap: () => _open(context, SupportContact.whatsappUrl),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Material(
      color: cf.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm + 2,
          ),
          child: Row(
            children: [
              Icon(icon, color: CfColors.primaryBlueLight, size: 22),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cf.textSecondary,
                          ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cf.link,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: cf.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
