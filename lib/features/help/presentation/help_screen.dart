import 'package:flutter/material.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../../shared/widgets/powered_by_mavixas.dart';
import '../../../core/theme/cf_colors.dart';
import 'widgets/help_contact_card.dart';
import 'widgets/support_chat_panel.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('CrickFlow Help')),
      body: ListView(
        padding: AppDimens.listPadding,
        children: [
          Text(
            'We are here to help',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Use the contact details below, or chat with CrickFlow staff if you are signed in.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          const HelpContactCard(),
          const SizedBox(height: AppDimens.spaceLg),
          const SupportChatPanel(),
          const SizedBox(height: AppDimens.spaceXl),
          PoweredByMavixas(
            mutedColor: cf.textMuted,
            linkColor: cf.link,
          ),
          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}
