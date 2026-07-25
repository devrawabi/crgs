import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../shared/providers/connectivity_provider.dart';
import '../../../shared/providers/theme_provider.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../shared/widgets/shad/shad_components.dart';

enum _SyncFrequency { fiveMin, fifteenMin, thirtyMin, manual }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  _SyncFrequency _syncFrequency = _SyncFrequency.fifteenMin;
  bool _autoSync = true;
  bool _highAccuracyGps = true;
  bool _visitReminders = true;
  bool _pushNotifications = true;
  bool _offlineMode = false;

  String get _syncLabel => switch (_syncFrequency) {
        _SyncFrequency.fiveMin => 'Every 5 minutes',
        _SyncFrequency.fifteenMin => 'Every 15 minutes',
        _SyncFrequency.thirtyMin => 'Every 30 minutes',
        _SyncFrequency.manual => 'Manual only',
      };

  void _showSyncPicker() {
    final theme = ShadTheme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Sync Frequency', style: theme.textTheme.h4),
              const SizedBox(height: 12),
              for (final option in _SyncFrequency.values)
                _SyncOptionTile(
                  label: switch (option) {
                    _SyncFrequency.fiveMin => 'Every 5 minutes',
                    _SyncFrequency.fifteenMin => 'Every 15 minutes',
                    _SyncFrequency.thirtyMin => 'Every 30 minutes',
                    _SyncFrequency.manual => 'Manual only',
                  },
                  selected: _syncFrequency == option,
                  onTap: () {
                    setState(() => _syncFrequency = option);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: RouteMasterColors.background(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppHeader(
            title: 'Settings',
            subtitle: 'Customize your ${AppConstants.appShortName} experience',
            showBackButton: true,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SettingsCard(
                  child: Row(
                    children: [
                      _SettingsIconBadge(
                        icon: isOnline ? Icons.cloud_done_outlined : AppIcons.cloudOff,
                        color: isOnline
                            ? AppColors.successGreen
                            : AppColors.offlineAmber,
                        background: isOnline
                            ? AppColors.successGreenContainer
                            : const Color(0xFFFFF7ED),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Connected' : 'Offline',
                              style: theme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              isOnline
                                  ? 'Data syncs automatically when online'
                                  : 'Changes saved locally until reconnected',
                              style: theme.textTheme.muted.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ShadBadge(
                        child: Text(isOnline ? 'Online' : 'Offline'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Appearance'),
                _SettingsCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theme',
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose how ${AppConstants.appShortName} looks on your device',
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _ThemeOption(
                              icon: AppIcons.sun,
                              label: 'Light',
                              selected: themeMode == ThemeMode.light,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOption(
                              icon: AppIcons.moon,
                              label: 'Dark',
                              selected: themeMode == ThemeMode.dark,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(ThemeMode.dark),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ThemeOption(
                              icon: AppIcons.systemTheme,
                              label: 'System',
                              selected: themeMode == ThemeMode.system,
                              onTap: () => ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(ThemeMode.system),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Sync & Data'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: AppIcons.upload,
                        iconColor: AppColors.brand,
                        iconBackground: AppColors.brandContainer,
                        title: 'Auto Sync',
                        subtitle: 'Sync visits and tasks in the background',
                        trailing: Switch.adaptive(
                          value: _autoSync,
                          activeTrackColor: AppColors.brand,
                          onChanged: (v) => setState(() => _autoSync = v),
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: AppIcons.clock,
                        iconColor: AppColors.followUpBlue,
                        iconBackground: AppColors.brandContainer,
                        title: 'Sync Frequency',
                        subtitle: _syncLabel,
                        trailing: const Icon(AppIcons.chevronRight, size: 18),
                        onTap: _showSyncPicker,
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: AppIcons.cloudOff,
                        iconColor: AppColors.outstandingOrange,
                        iconBackground: const Color(0xFFFFEDD5),
                        title: 'Offline Mode',
                        subtitle: 'Work without network; sync later',
                        trailing: Switch.adaptive(
                          value: _offlineMode,
                          activeTrackColor: AppColors.brand,
                          onChanged: (v) => setState(() => _offlineMode = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Location & Notifications'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: AppIcons.gps,
                        iconColor: AppColors.brandDark,
                        iconBackground: AppColors.brandContainer,
                        title: 'High Accuracy GPS',
                        subtitle: 'Precise check-in for customer visits',
                        trailing: Switch.adaptive(
                          value: _highAccuracyGps,
                          activeTrackColor: AppColors.brand,
                          onChanged: (v) => setState(() => _highAccuracyGps = v),
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: AppIcons.bell,
                        iconColor: AppColors.brand,
                        iconBackground: AppColors.brandContainer,
                        title: 'Push Notifications',
                        subtitle: 'Task alerts and route updates',
                        trailing: Switch.adaptive(
                          value: _pushNotifications,
                          activeTrackColor: AppColors.brand,
                          onChanged: (v) => setState(() => _pushNotifications = v),
                        ),
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: AppIcons.calendarClock,
                        iconColor: AppColors.successGreenDark,
                        iconBackground: AppColors.successGreenContainer,
                        title: 'Visit Reminders',
                        subtitle: 'Remind before scheduled follow-ups',
                        trailing: Switch.adaptive(
                          value: _visitReminders,
                          activeTrackColor: AppColors.brand,
                          onChanged: (v) => setState(() => _visitReminders = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'Account'),
                _SettingsCard(
                  child: _SettingsRow(
                    icon: AppIcons.lockOutline,
                    iconColor: AppColors.brand,
                    iconBackground: AppColors.brandContainer,
                    title: 'Change Password',
                    subtitle: 'Update your login credentials',
                    trailing: const Icon(AppIcons.chevronRight, size: 18),
                    onTap: () => context.push(RouteNames.changePassword),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'About'),
                _SettingsCard(
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: AppIcons.badge,
                        iconColor: AppColors.brand,
                        iconBackground: AppColors.brandContainer,
                        title: 'App Version',
                        subtitle: AppConstants.appVersion,
                        showChevron: false,
                      ),
                      const _SettingsDivider(),
                      _SettingsRow(
                        icon: AppIcons.store,
                        iconColor: AppColors.textSecondaryLight,
                        iconBackground: AppColors.surfaceContainerLight,
                        title: 'Company',
                        subtitle: AppConstants.companyName,
                        showChevron: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${AppConstants.appShortName} v${AppConstants.appVersion}',
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              _SettingsIconBadge(
                icon: icon,
                color: iconColor,
                background: iconBackground,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (showChevron && onTap != null)
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: theme.colorScheme.mutedForeground,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        height: 1,
        color: theme.colorScheme.border.withValues(alpha: 0.8),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandContainer
                : theme.colorScheme.muted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.brand : theme.colorScheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppColors.brand : theme.colorScheme.mutedForeground,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.muted.copyWith(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.brandDark : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncOptionTile extends StatelessWidget {
  const _SyncOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: theme.textTheme.small),
      trailing: selected
          ? const Icon(AppIcons.check, color: AppColors.brand, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
