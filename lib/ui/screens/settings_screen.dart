import 'package:flutter/material.dart';

import '../../core/engine/game_rules.dart';
import '../../core/models/game_settings.dart';
import '../../core/storage/player_store.dart';
import '../theme/palette.dart';
import '../widgets/readouts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.store,
    required this.settings,
    required this.onChanged,
  });

  final PlayerStore store;
  final GameSettings settings;
  final ValueChanged<GameSettings> onChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late GameSettings _settings = widget.settings;

  void _update(GameSettings value) {
    setState(() => _settings = value);
    widget.onChanged(value);
    widget.store.saveSettings(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('Controls'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('A tap opens a cell'),
                  subtitle: const Text(
                    'Turn this off to start each run in flag mode. The toggle '
                    'on the board switches either way.',
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: Switch(
                    value: _settings.defaultInputMode == InputMode.reveal,
                    onChanged: (value) => _update(
                      _settings.copyWith(
                        defaultInputMode:
                            value ? InputMode.reveal : InputMode.flag,
                      ),
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _settings.longPressToFlag,
                  onChanged: (value) =>
                      _update(_settings.copyWith(longPressToFlag: value)),
                  title: const Text('Long press does the other action'),
                  subtitle: const Text(
                    'Flag without leaving open mode, and open without leaving '
                    'flag mode.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _settings.confirmSalvage,
                  onChanged: (value) =>
                      _update(_settings.copyWith(confirmSalvage: value)),
                  title: const Text('Confirm before salvaging a batch'),
                  subtitle: const Text(
                    'A wrong pick ends the run, so this is on by default.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Feel'),
          _Card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _settings.haptics,
                  onChanged: (value) =>
                      _update(_settings.copyWith(haptics: value)),
                  title: const Text('Haptics'),
                  subtitle: const Text(
                    'Opening, flagging, salvaging and losing each feel '
                    'different.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _settings.animations,
                  onChanged: (value) =>
                      _update(_settings.copyWith(animations: value)),
                  title: const Text('Animations'),
                  subtitle: const Text(
                    'The reveal ripple, salvage beams and screen shake. Moves '
                    'never wait for them either way.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionLabel('Data'),
          _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Clear records'),
              subtitle: const Text(
                'Deletes your best scores and times. Saved runs are kept.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.delete_outline_rounded),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Palette.surface,
                    title: const Text('Clear all records?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed ?? false) {
                  await widget.store.clearStats();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Records cleared')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Rules version ${GameRules.rulesVersion}',
            style: const TextStyle(color: Palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.outline),
      ),
      child: child,
    );
  }
}
