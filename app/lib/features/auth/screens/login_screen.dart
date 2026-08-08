import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeCodeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _employeeCodeFocus.dispose();
    _passwordFocus.dispose();
    _employeeIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_employeeIdController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter employee code and password')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final success = await ref.read(authProvider.notifier).login(
          employeeId: _employeeIdController.text.trim(),
          password: _passwordController.text,
          rememberMe: true,
        );

    if (success && mounted) {
      final onboardingCompleted =
          ref.read(authProvider).user?.onboardingCompleted ?? false;
      context.go(
        onboardingCompleted ? RouteNames.routes : RouteNames.onboarding,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = height * 0.38;

    return Scaffold(
      backgroundColor: AppColors.brand,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _LoginHero(height: heroHeight),
          SlideTransition(
            position: _sheetSlide,
            child: Padding(
              padding: EdgeInsets.only(top: heroHeight - 28),
              child: _LoginSheet(
                employeeIdController: _employeeIdController,
                passwordController: _passwordController,
                employeeCodeFocus: _employeeCodeFocus,
                passwordFocus: _passwordFocus,
                obscurePassword: _obscurePassword,
                onTogglePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onLogin: _login,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero({required this.height});

  final double height;

  static const _heroImage =
      'assets/images/Operations-Executive-Line-Art-6-removebg-preview.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SizedBox(
              height: height * 0.88,
            child: Image.asset(
              _heroImage,
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.medium,
              cacheWidth: 900,
            ),
            ),
          ),
          Positioned(
            left: 28,
            bottom: 48,
            right: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Welcome back!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConstants.appShortName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
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

class _LoginSheet extends ConsumerWidget {
  const _LoginSheet({
    required this.employeeIdController,
    required this.passwordController,
    required this.employeeCodeFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final TextEditingController employeeIdController;
  final TextEditingController passwordController;
  final FocusNode employeeCodeFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider.select((s) => s.isLoading));
    final error = ref.watch(authProvider.select((s) => s.error));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 12, 28, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D9D9),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Text(
              'Enter to your account',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.fieldLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            _LoginField(
              label: 'Employee Code',
              controller: employeeIdController,
              focusNode: employeeCodeFocus,
              hint: 'Enter employee code',
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 20),
            _LoginField(
              label: 'Password',
              controller: passwordController,
              focusNode: passwordFocus,
              hint: 'Enter your password...',
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isLoading) onLogin();
              },
              onSuffixTap: onTogglePassword,
              suffixIcon: obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.fieldLabel,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot the password?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(color: AppColors.missingRed, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: isLoading ? null : onLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  disabledBackgroundColor:
                      AppColors.brand.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${AppConstants.appShortName} v${AppConstants.appVersion}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.controller,
    this.focusNode,
    this.hint,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffixIcon,
    this.onSuffixTap,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.fieldLabel,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.fieldLabel,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.fieldHint,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: suffixIcon != null
                ? IconButton(
                    onPressed: onSuffixTap,
                    icon: Icon(suffixIcon, size: 20, color: AppColors.fieldHint),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
          ),
        ),
      ],
    );
  }
}
