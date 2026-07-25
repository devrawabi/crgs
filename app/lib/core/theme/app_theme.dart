import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData? _lightCache;
  static ThemeData? _darkCache;

  static ThemeData light() => _lightCache ??= _buildLight();

  static ThemeData dark() => _darkCache ??= _buildDark();

  static ThemeData _buildLight() {
    const scheme = AppColors.lightScheme;
    final textTheme = _textTheme(Brightness.light);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceLight,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: const FadeUpwardsPageTransitionsBuilder(),
        },
      ),

      // App bar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: AppColors.white,
        shadowColor: AppColors.borderLight,
        iconTheme: const IconThemeData(color: AppColors.textPrimaryLight, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.textPrimaryLight, size: 22),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
      ),

      // Surfaces
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        color: AppColors.white,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: GoogleFonts.inter(color: AppColors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(color: AppColors.white, fontSize: 12),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondaryLight, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: AppColors.textSecondaryLight, fontSize: 14),
        floatingLabelStyle: GoogleFonts.inter(color: AppColors.primaryBlue, fontSize: 14),
        errorStyle: GoogleFonts.inter(color: AppColors.missingRed, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: AppColors.missingRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: const BorderSide(color: AppColors.missingRed, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          borderSide: BorderSide(color: AppColors.borderLight.withValues(alpha: 0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.borderLight,
          disabledForegroundColor: AppColors.textSecondaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.borderLight,
          disabledForegroundColor: AppColors.textSecondaryLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          disabledForegroundColor: AppColors.textSecondaryLight,
          side: const BorderSide(color: AppColors.primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          disabledForegroundColor: AppColors.textSecondaryLight,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          highlightColor: AppColors.primaryBlue.withValues(alpha: 0.08),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.white,
        elevation: 4,
        focusElevation: 6,
        hoverElevation: 6,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlueContainer;
            }
            return AppColors.surfaceLight;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryBlueDark;
            }
            return AppColors.textSecondaryLight;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.borderLight),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),

      // Navigation
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        height: 72,
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        shadowColor: AppColors.borderLight,
        indicatorColor: AppColors.primaryBlue.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryBlue : AppColors.textSecondaryLight,
            size: 24,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primaryBlue : AppColors.textSecondaryLight,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primaryBlue,
        unselectedLabelColor: AppColors.textSecondaryLight,
        indicatorColor: AppColors.primaryBlue,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.borderLight,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),

      // Lists & tiles
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primaryBlue,
        textColor: AppColors.textPrimaryLight,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimaryLight,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: AppColors.textSecondaryLight,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.primaryBlue,
        collapsedIconColor: AppColors.textSecondaryLight,
        backgroundColor: AppColors.white,
        collapsedBackgroundColor: AppColors.white,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedColor: AppColors.primaryBlueContainer,
        disabledColor: AppColors.borderLight,
        labelStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimaryLight),
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.badgeRadius),
          side: const BorderSide(color: AppColors.borderLight),
        ),
      ),

      // Controls
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryBlue;
          return AppColors.outlineVariantLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryBlue.withValues(alpha: 0.4);
          }
          return AppColors.surfaceContainerLight;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryBlue;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.white),
        side: const BorderSide(color: AppColors.outlineVariantLight, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryBlue;
          return AppColors.outlineVariantLight;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryBlue,
        linearTrackColor: AppColors.primaryBlueContainer,
        circularTrackColor: AppColors.primaryBlueContainer,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primaryBlue,
        inactiveTrackColor: AppColors.primaryBlueContainer,
        thumbColor: AppColors.primaryBlue,
        overlayColor: AppColors.primaryBlue.withValues(alpha: 0.12),
      ),

      // Menus & pickers
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: AppColors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 14),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: GoogleFonts.inter(color: AppColors.textPrimaryLight, fontSize: 14),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: AppColors.white,
        headerBackgroundColor: AppColors.primaryBlue,
        headerForegroundColor: AppColors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.white;
          return AppColors.textPrimaryLight;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primaryBlue;
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.all(AppColors.primaryBlue),
        todayBackgroundColor: WidgetStateProperty.all(AppColors.primaryBlueContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.white,
        hourMinuteColor: AppColors.surfaceLight,
        hourMinuteTextColor: AppColors.textPrimaryLight,
        dialHandColor: AppColors.primaryBlue,
        dialBackgroundColor: AppColors.primaryBlueContainer,
        entryModeIconColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Icons & dividers
      iconTheme: const IconThemeData(color: AppColors.textSecondaryLight, size: 22),
      primaryIconTheme: const IconThemeData(color: AppColors.primaryBlue, size: 22),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      dividerColor: AppColors.borderLight,
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.missingRed,
        textColor: AppColors.white,
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: AppColors.primaryBlueContainer,
        contentTextStyle: GoogleFonts.inter(color: AppColors.onPrimaryBlueContainer),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(
          AppColors.outlineVariantLight.withValues(alpha: 0.8),
        ),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
      ),
    );
  }

  static ThemeData _buildDark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryBlueLight,
      primary: AppColors.primaryBlueLight,
      secondary: AppColors.successGreenLight,
      surface: AppColors.surfaceDark,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceDark,
      textTheme: _textTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.cardDark,
        foregroundColor: AppColors.textPrimaryDark,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        color: AppColors.cardDark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryBlueLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlueLight,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlueLight,
        foregroundColor: AppColors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        height: 72,
        backgroundColor: AppColors.cardDark,
        indicatorColor: AppColors.primaryBlueLight.withValues(alpha: 0.2),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.borderDark),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? GoogleFonts.interTextTheme()
        : GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    final primary = brightness == Brightness.light
        ? AppColors.textPrimaryLight
        : AppColors.textPrimaryDark;
    final secondary = brightness == Brightness.light
        ? AppColors.textSecondaryLight
        : AppColors.textSecondaryDark;

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700, color: primary),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: primary),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, color: primary),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, color: primary),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: primary),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: primary),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: primary),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: primary),
      bodyLarge: base.bodyLarge?.copyWith(color: primary, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: primary, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: secondary, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: primary),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500, color: secondary),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w500, color: secondary),
    );
  }
}
