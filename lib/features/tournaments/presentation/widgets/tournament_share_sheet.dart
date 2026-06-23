import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/widgets/cf_button.dart';

class TournamentShareSheet extends StatelessWidget {
  const TournamentShareSheet({super.key, required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final joinLink =
        DeepLinkUtils.hostedTournamentJoinUri(tournament.id).toString();
    final code = tournament.tournamentCode?.trim();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share ${tournament.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Invite link'),
            subtitle: Text(
              joinLink,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: joinLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')),
                );
              },
            ),
          ),
          if (code != null && code.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.tag),
              title: const Text('Tournament code'),
              subtitle:
                  Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied')),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          CfButton(
            label: 'Share invite link',
            isGold: true,
            onPressed: () {
              Share.share(
                'Join ${tournament.name} on CrickFlow\n$joinLink',
                subject: tournament.name,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
