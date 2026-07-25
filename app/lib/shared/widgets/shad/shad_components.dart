import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';

/// Default branded title shown when a page header omits an explicit title.
const kDefaultAppHeaderTitle = AppConstants.appShortName;

/// Standard page scaffold with shadcn-styled app bar.
class ShadPageScaffold extends StatelessWidget {
  const ShadPageScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showBackButton = false,
    this.showHeader = true,
    this.useMeshBackground = true,
  });

  final String? title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showBackButton;
  final bool showHeader;
  final bool useMeshBackground;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final content = Column(
      children: [
        if (showHeader)
          AppHeader(
            title: title ?? kDefaultAppHeaderTitle,
            subtitle: subtitle,
            actions: actions,
            showBackButton: showBackButton,
          ),
        Expanded(child: body),
      ],
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: useMeshBackground
          ? AppMeshBackground(child: content)
          : content,
    );
  }
}

/// Reusable page header with optional back button and actions.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return LoginStyleNavBar(
      showBackButton: showBackButton,
      onBack: () => Navigator.maybePop(context),
      title: title,
      subtitle: subtitle ?? AppConstants.appShortName,
      actions: actions,
    );
  }
}

/// Login-page styled top bar — brand teal background, white typography.
class LoginStyleNavBar extends StatelessWidget {
  const LoginStyleNavBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.bottomRadius = 24,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final double bottomRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(bottomRadius),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null)
                leading!
              else if (showBackButton)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                )
              else
                const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (actions != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!
                      .map(
                        (action) => Theme(
                          data: Theme.of(context).copyWith(
                            iconTheme: const IconThemeData(color: Colors.white),
                          ),
                          child: DefaultTextStyle(
                            style: const TextStyle(color: Colors.white),
                            child: action,
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Page title block for screens that use the shell-level default header.
class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 4),
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.h4.copyWith(
              color: theme.colorScheme.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Labeled field using shadcn Input.
class ShadLabeledField extends StatelessWidget {
  const ShadLabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.leading,
    this.trailing,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.foreground,
          ),
        ),
        const SizedBox(height: 8),
        ShadInput(
          controller: controller,
          placeholder: placeholder != null ? Text(placeholder!) : null,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          onPressed: readOnly ? onTap : null,
          leading: leading,
          trailing: trailing,
        ),
      ],
    );
  }
}

/// Primary action button — full width.
class ShadPrimaryButton extends StatelessWidget {
  const ShadPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.leading,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? leading;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      width: width ?? double.infinity,
      size: ShadButtonSize.lg,
      onPressed: loading ? null : onPressed,
      leading: SizedBox(
        width: 18,
        height: 18,
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
            : leading ?? const SizedBox.shrink(),
      ),
      child: Text(label),
    );
  }
}

/// Outlined secondary action.
class ShadOutlineButton extends StatelessWidget {
  const ShadOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? leading;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      width: width ?? double.infinity,
      size: ShadButtonSize.lg,
      onPressed: onPressed,
      leading: leading,
      child: Text(label),
    );
  }
}
