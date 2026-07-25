import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/common/app_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/theme_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.dashboard);
            }
          },
        ),
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                      child: Text(
                        user.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(user.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      user.employeeCode,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryBlue,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AppIcons.route, size: 16, color: AppColors.successGreen),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            user.assignedRoute,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SettingsTile(
              icon: AppIcons.userOutline,
              title: 'Edit Profile',
              onTap: () {},
            ),
            _SettingsTile(
              icon: AppIcons.lockOutline,
              title: 'Change Password',
              onTap: () => context.push(RouteNames.changePassword),
            ),
            _SettingsTile(
              icon: AppIcons.moon,
              title: 'Dark Mode',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
            _SettingsTile(
              icon: AppIcons.settings,
              title: 'Settings',
              onTap: () => context.push(RouteNames.settings),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
                context.go(RouteNames.login);
              },
              icon: const Icon(AppIcons.logout, color: AppColors.missingRed),
              label: const Text('Logout', style: TextStyle(color: AppColors.missingRed)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppColors.missingRed),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${AppConstants.appShortName} v${AppConstants.appVersion}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryBlue),
        title: Text(title),
        trailing: trailing ?? const Icon(AppIcons.chevron),
        onTap: onTap,
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppTextField(
              controller: _currentController,
              label: 'Current Password',
              obscureText: true,
              prefixIcon: AppIcons.lockOutline,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _newController,
              label: 'New Password',
              obscureText: true,
              prefixIcon: AppIcons.lock,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmController,
              label: 'Confirm Password',
              obscureText: true,
              prefixIcon: AppIcons.lock,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated')),
                );
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }
}
