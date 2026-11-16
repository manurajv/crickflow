import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/cf_player_id_format.dart';
import '../../../../core/utils/friendly_error.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/repositories/player_discovery_repository.dart';
import '../../../../shared/widgets/cf_chrome_app_bar.dart';

/// Full-screen player search used to add a squad member or invite a team admin.
/// Matches Find Cricketers / add-official search chrome: bar, avatar tiles,
/// CrickFlow ID, and empty / loading / error states.
class SeriesPlayerSearchScreen extends StatefulWidget {
  const SeriesPlayerSearchScreen({
    super.key,
    this.title = 'Search players',
  });

  final String title;

  static Future<UserModel?> open(
    BuildContext context, {
    String title = 'Search players',
  }) {
    return Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (_) => SeriesPlayerSearchScreen(title: title),
      ),
    );
  }

  @override
  State<SeriesPlayerSearchScreen> createState() =>
      _SeriesPlayerSearchScreenState();
}

class _SeriesPlayerSearchScreenState extends State<SeriesPlayerSearchScreen> {
  final _query = TextEditingController();
  PlayerDiscoveryRepository? _repo;

  PlayerDiscoveryRepository get _discovery =>
      _repo ??= PlayerDiscoveryRepository();
  Timer? _debounce;
  List<UserModel> _results = const [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    _lastQuery = q;
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _discovery.searchPlayers(
        query: q,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      );
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _lastQuery != q) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final q = _query.text.trim();
    return Scaffold(
      backgroundColor: cf.background,
      appBar: CfChromeAppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: AppDimens.listPadding.copyWith(bottom: AppDimens.spaceSm),
            child: TextField(
              key: const Key('org_player_search_field'),
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or CrickFlow Player ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: q.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _search('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(child: _buildBody(cf, q)),
        ],
      ),
    );
  }

  Widget _buildBody(CfColors cf, String q) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: AppDimens.listPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: cf.textSecondary),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              OutlinedButton(
                onPressed: () => _search(q),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      final message = q.length < 2
          ? 'Type a name or CrickFlow ID to find players'
          : 'No players match your search';
      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cf.textSecondary,
              ),
        ),
      );
    }
    return ListView.builder(
      padding: AppDimens.listPadding,
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final u = _results[i];
        return _SeriesPlayerSearchTile(
          user: u,
          onTap: () => Navigator.pop(context, u),
        );
      },
    );
  }
}

class _SeriesPlayerSearchTile extends StatelessWidget {
  const _SeriesPlayerSearchTile({required this.user, required this.onTap});

  final UserModel user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final name = user.displayName.isNotEmpty ? user.displayName : user.name;
    final idLabel = (user.playerId != null && user.playerId!.trim().isNotEmpty)
        ? CfPlayerIdFormat.displayLabel(user.playerId)
        : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: cf.sectionBackground,
        backgroundImage: user.photoUrl == null ? null : NetworkImage(user.photoUrl!),
        child: user.photoUrl == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cf.textPrimary,
                ),
              )
            : null,
      ),
      title: Text(
        name.isEmpty ? 'Player' : name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: cf.textPrimary,
        ),
      ),
      subtitle: idLabel == null
          ? null
          : Text(
              idLabel,
              style: TextStyle(color: cf.accent, fontSize: 12),
            ),
      onTap: onTap,
    );
  }
}
