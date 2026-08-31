import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../repositories/character_repository.dart';
import '../../state/library_provider.dart';
import '../../state/settings_provider.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/section_header.dart';

/// Premium settings — every control is real and persists immediately.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settings',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text('Character Studio 3D · all data stays on this device',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),

            // ---------------- APPEARANCE ----------------
            const SectionHeader(title: 'Appearance'),
            _SettingsCard(children: [
              _SegmentedRow(
                icon: Icons.dark_mode_outlined,
                label: 'Theme',
                options: const ['Dark', 'Light', 'System'],
                selected: switch (settings.themeMode) {
                  ThemeMode.dark => 'Dark',
                  ThemeMode.light => 'Light',
                  ThemeMode.system => 'System',
                },
                onSelect: (v) => settings.setThemeMode(switch (v) {
                  'Light' => ThemeMode.light,
                  'System' => ThemeMode.system,
                  _ => ThemeMode.dark,
                }),
              ),
            ]),

            // ---------------- 3D ----------------
            const SectionHeader(title: '3D'),
            _SettingsCard(children: [
              _SegmentedRow(
                icon: Icons.speed_rounded,
                label: 'Default playback speed',
                options: const ['0.25x', '0.5x', '1x', '1.5x', '2x'],
                selected: _speedLabel(settings.defaultSpeed),
                onSelect: (v) => settings
                    .setDefaultSpeed(double.tryParse(v.replaceAll('x', '')) ?? 1.0),
              ),
              const _Divider(),
              _SwitchRow(
                icon: Icons.repeat_rounded,
                label: 'Auto loop',
                subtitle: 'Loop animations by default',
                value: settings.autoLoop,
                onChanged: settings.setAutoLoop,
              ),
              const _Divider(),
              _SwitchRow(
                icon: Icons.screen_rotation_rounded,
                label: 'Auto rotate camera',
                subtitle: 'Slowly orbit characters in previews',
                value: settings.autoRotateCamera,
                onChanged: settings.setAutoRotateCamera,
              ),
            ]),

            // ---------------- LIBRARY ----------------
            const SectionHeader(title: 'Library'),
            _SettingsCard(children: [
              _SwitchRow(
                icon: Icons.image_outlined,
                label: 'Auto generate thumbnails',
                subtitle: 'Capture a poster frame when a character first plays',
                value: settings.autoThumbnails,
                onChanged: settings.setAutoThumbnails,
              ),
              const _Divider(),
              _SwitchRow(
                icon: Icons.info_outline_rounded,
                label: 'Show file information',
                subtitle: 'Display file size, meshes and exporter on details',
                value: settings.showFileInfo,
                onChanged: settings.setShowFileInfo,
              ),
            ]),

            // ---------------- EXPORT ----------------
            const SectionHeader(title: 'Export'),
            _SettingsCard(children: [
              _SegmentedRow(
                icon: Icons.high_quality_outlined,
                label: 'Default resolution',
                options: const ['720p', '1080p'],
                selected: settings.exportResolution,
                onSelect: settings.setExportResolution,
              ),
              const _Divider(),
              _SegmentedRow(
                icon: Icons.movie_filter_outlined,
                label: 'Default FPS',
                options: const ['24', '30', '60'],
                selected: '${settings.exportFps}',
                onSelect: (v) => settings.setExportFps(int.parse(v)),
              ),
              const _Divider(),
              _SegmentedRow(
                icon: Icons.timer_outlined,
                label: 'Default duration',
                options: const ['5s', '10s', '15s', '30s'],
                selected: '${settings.exportDuration}s',
                onSelect: (v) =>
                    settings.setExportDuration(int.parse(v.replaceAll('s', ''))),
              ),
            ]),

            // ---------------- STORAGE ----------------
            const SectionHeader(title: 'Storage'),
            _StorageSection(),

            // ---------------- ABOUT ----------------
            const SectionHeader(title: 'About'),
            _SettingsCard(children: [
              _InfoRow(
                  icon: Icons.verified_outlined,
                  label: 'App version',
                  value: '${AppConstants.appVersion} (offline build)'),
              const _Divider(),
              _InfoRow(
                  icon: Icons.wifi_off_rounded,
                  label: 'Works fully offline',
                  value: 'Airplane mode ready'),
              const _Divider(),
              _InfoRow(
                  icon: Icons.no_accounts_outlined,
                  label: 'No account required',
                  value: 'All data stays on device'),
              const _Divider(),
              _InfoRow(
                  icon: Icons.storage_rounded,
                  label: 'Characters stored in',
                  value: 'app documents → characters/'),
              const _Divider(),
              _ActionRow(
                icon: Icons.copyright_rounded,
                label: 'Licenses & credits',
                onTap: _showCredits,
              ),
            ]),
            const SizedBox(height: 10),
            Text(
              'Rendering: model-viewer (three.js) bundled offline · '
              'Animation detection: on-device GLB parser',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _speedLabel(double v) => v == v.truncateToDouble()
      ? '${v.toStringAsFixed(0)}x'
      : '${v}x';

  Future<void> _showCredits() async {
    await showPremiumDialog<void>(
      context,
      PremiumDialog(
        title: 'Licenses & Credits',
        message: 'Character Studio 3D bundles the following open-source works.',
        icon: Icons.copyright_rounded,
        actions: [
          PremiumTextButton(
              label: 'Close', onPressed: () => Navigator.of(context).pop()),
        ],
        child: const _CreditsList(),
      ),
    );
  }
}

// ======================================================================
// Storage section (computed live from the character repository)
// ======================================================================
class _StorageSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repository = context.read<CharacterRepository>();
    final library = context.read<LibraryProvider>();
    final usage = repository.service.directoryUsageBytes();
    final fileCount = repository.service.fileCount;

    return _SettingsCard(children: [
      _ActionRow(
        icon: Icons.folder_outlined,
        label: 'Character storage',
        value:
            '$fileCount files · ${Formatters.fileSize(usage)}',
        onTap: () {
          showPremiumDialog<void>(
            context,
            PremiumDialog(
              title: 'Character Storage',
              message:
                  'Characters live in the app\'s private documents folder and are '
                  'scanned automatically at launch. Imported .glb files are copied '
                  'here; nothing ever leaves your device.',
              icon: Icons.folder_outlined,
              actions: [
                PremiumTextButton(
                    label: 'Close', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          );
        },
      ),
      const _Divider(),
      _ActionRow(
        icon: Icons.history_rounded,
        label: 'Clear recent history',
        value: '${library.recentCount} entries',
        onTap: () async {
          final confirmed = await showConfirmDialog(
            context,
            title: 'Clear Recent History?',
            message:
                'Your recently used characters and animations will be cleared. '
                'Favorites and characters are not affected.',
            confirmLabel: 'Clear',
            destructive: false,
          );
          if (confirmed) {
            await library.clearRecents();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recent history cleared')),
              );
            }
          }
        },
      ),
      const _Divider(),
      _ActionRow(
        icon: Icons.cleaning_services_outlined,
        label: 'Clear thumbnail cache',
        value: 'Regenerated automatically',
        onTap: () async {
          final removed =
              library.repository.thumbnails.clearGeneratedThumbnails();
          await library.refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(removed == 0
                      ? 'No cached thumbnails found'
                      : '$removed thumbnails cleared')),
            );
          }
        },
      ),
    ]);
  }
}

// ======================================================================
// Building blocks
// ======================================================================
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isDark ? AppColors.stroke : AppColors.lightStroke),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.stroke);
}

class _SegmentedRow extends StatelessWidget {
  const _SegmentedRow({
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in options)
                Semantics(
                  label: '$label: $option',
                  button: true,
                  selected: option == selected,
                  child: GestureDetector(
                    onTap: () => onSelect(option),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: option == selected
                            ? AppColors.accent
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.stroke),
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: option == selected
                              ? const Color(0xFF0A0C11)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 20, color: AppColors.accent),
      title: Text(label,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              if (value != null)
                Flexible(
                  child: Text(value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreditsList extends StatelessWidget {
  const _CreditsList();

  @override
  Widget build(BuildContext context) {
    const credits = [
      ('model-viewer', 'Apache License 2.0 — © Google LLC. '
          'Bundled locally in assets/viewer for offline rendering.'),
      ('three.js', 'MIT License — the renderer inside model-viewer.'),
      ('Fox sample model', 'CC0 1.0 — by PixelMannen (rigged by TomKranis), '
          'from the Khronos glTF sample models.'),
      ('CesiumMan sample model', 'CC-BY 4.0 — © Cesium GS, Inc., '
          'from the Khronos glTF sample models.'),
      ('Flutter & Dart', 'BSD 3-Clause License — © Google LLC and contributors.'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, text) in credits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(text,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}
