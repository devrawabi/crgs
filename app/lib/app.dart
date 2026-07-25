import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/theme_provider.dart';

class RexApp extends ConsumerWidget {
  const RexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final lightTheme = ref.watch(shadLightThemeProvider);
    final darkTheme = ref.watch(shadDarkThemeProvider);

    return ShadApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      materialThemeBuilder: (context, shadMaterialTheme) {
        final appTheme = shadMaterialTheme.brightness == Brightness.dark
            ? AppTheme.dark()
            : AppTheme.light();
        return shadMaterialTheme.copyWith(
          appBarTheme: appTheme.appBarTheme,
          cardTheme: appTheme.cardTheme,
          inputDecorationTheme: appTheme.inputDecorationTheme,
          dividerTheme: appTheme.dividerTheme,
          elevatedButtonTheme: appTheme.elevatedButtonTheme,
          floatingActionButtonTheme: appTheme.floatingActionButtonTheme,
          dialogTheme: appTheme.dialogTheme,
          snackBarTheme: appTheme.snackBarTheme,
        );
      },
      routerConfig: router,
      builder: (context, child) {
        return ScaffoldMessenger(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
