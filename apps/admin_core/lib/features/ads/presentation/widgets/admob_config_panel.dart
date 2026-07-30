import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/cf_card.dart';
import '../../../../shared/widgets/cf_loading_state.dart';
import '../../models/ads_enums.dart';
import '../../models/managed_ads.dart';
import '../../providers/ads_providers.dart';

class AdmobConfigPanel extends ConsumerStatefulWidget {
  const AdmobConfigPanel({
    super.key,
    required this.config,
    required this.isLoading,
  });

  final ManagedAdmobConfig? config;
  final bool isLoading;

  @override
  ConsumerState<AdmobConfigPanel> createState() => _AdmobConfigPanelState();
}

class _AdmobConfigPanelState extends ConsumerState<AdmobConfigPanel> {
  bool _testMode = true;
  late List<ManagedAdmobPlacementConfig> _placements;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _applyConfig(widget.config ?? ManagedAdmobConfig.defaults());
  }

  @override
  void didUpdateWidget(covariant AdmobConfigPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config && widget.config != null) {
      _applyConfig(widget.config!);
    }
  }

  void _applyConfig(ManagedAdmobConfig config) {
    _testMode = config.testMode;
    _placements = [
      for (final f in ManagedAdmobFormat.values)
        config.placements.firstWhere(
          (p) => p.format == f,
          orElse: () => ManagedAdmobPlacementConfig(format: f),
        ),
    ];
    _dirty = false;
  }

  ManagedAdmobPlacementConfig _placement(ManagedAdmobFormat format) {
    return _placements.firstWhere((p) => p.format == format);
  }

  void _updatePlacement(ManagedAdmobFormat format, ManagedAdmobPlacementConfig next) {
    setState(() {
      _placements = [
        for (final p in _placements)
          if (p.format == format) next else p,
      ];
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(adsHubControllerProvider.notifier).saveAdmobConfig(
            ManagedAdmobConfig(
              testMode: _testMode,
              placements: _placements,
            ),
          );
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AdMob config saved (admin mirror)')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;

    if (widget.isLoading && widget.config == null) {
      return const CfCard(
        child: SizedBox(
          height: 280,
          child: CfLoadingState(message: 'Loading AdMob config…'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.info),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Admin mirror only — mobile AdMobConfig is unchanged until a future sync.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CfCard(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Test mode'),
            subtitle: const Text('Use test ad units during development'),
            value: _testMode,
            onChanged: (v) => setState(() {
              _testMode = v;
              _dirty = true;
            }),
          ),
        ),
        const SizedBox(height: 16),
        for (final format in ManagedAdmobFormat.values) ...[
          _FormatCard(
            config: _placement(format),
            onChanged: (next) => _updatePlacement(format, next),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: CfButton(
            label: _saving ? 'Saving…' : 'Save AdMob config',
            icon: Icons.save_outlined,
            onPressed: _saving || !_dirty ? null : _save,
          ),
        ),
      ],
    );
  }
}

class _FormatCard extends StatefulWidget {
  const _FormatCard({required this.config, required this.onChanged});

  final ManagedAdmobPlacementConfig config;
  final ValueChanged<ManagedAdmobPlacementConfig> onChanged;

  @override
  State<_FormatCard> createState() => _FormatCardState();
}

class _FormatCardState extends State<_FormatCard> {
  late final TextEditingController _androidUnitId;
  late final TextEditingController _iosUnitId;
  late final TextEditingController _refresh;
  late final TextEditingController _frequency;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    _enabled = c.enabled;
    _androidUnitId = TextEditingController(text: c.androidUnitId);
    _iosUnitId = TextEditingController(text: c.iosUnitId);
    _refresh = TextEditingController(text: '${c.refreshRateSeconds}');
    _frequency = TextEditingController(text: '${c.frequencyCap}');
  }

  @override
  void didUpdateWidget(covariant _FormatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config) {
      final c = widget.config;
      _enabled = c.enabled;
      _androidUnitId.text = c.androidUnitId;
      _iosUnitId.text = c.iosUnitId;
      _refresh.text = '${c.refreshRateSeconds}';
      _frequency.text = '${c.frequencyCap}';
    }
  }

  @override
  void dispose() {
    _androidUnitId.dispose();
    _iosUnitId.dispose();
    _refresh.dispose();
    _frequency.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      ManagedAdmobPlacementConfig(
        format: widget.config.format,
        enabled: _enabled,
        androidUnitId: _androidUnitId.text.trim(),
        iosUnitId: _iosUnitId.text.trim(),
        refreshRateSeconds: int.tryParse(_refresh.text.trim()) ?? 60,
        frequencyCap: int.tryParse(_frequency.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    return CfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              widget.config.format.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              _emit();
            },
          ),
          if (_enabled) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _androidUnitId,
              decoration: const InputDecoration(
                labelText: 'Android unit ID',
                hintText: 'ca-app-pub-xxx/yyy',
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _iosUnitId,
              decoration: const InputDecoration(
                labelText: 'iOS unit ID',
                hintText: 'ca-app-pub-xxx/yyy',
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _refresh,
                    decoration: const InputDecoration(
                      labelText: 'Refresh (seconds)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _frequency,
                    decoration: const InputDecoration(
                      labelText: 'Frequency cap',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'Disabled — no unit IDs required',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
