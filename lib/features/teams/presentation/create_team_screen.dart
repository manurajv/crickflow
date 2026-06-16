import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/create_team_form.dart';

/// Standalone screen that just hosts the create-team form.
/// Reached via `/teams/create` — no tabs, no extra chrome.
class CreateTeamScreen extends StatelessWidget {
  const CreateTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create team'),
        centerTitle: false,
      ),
      body: CreateTeamForm(
        onCreated: (_) {
          // Pop back to wherever we came from (My Cricket, match picker, etc.)
          if (context.canPop()) context.pop();
        },
      ),
    );
  }
}
