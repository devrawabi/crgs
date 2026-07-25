import '../config/api_config.dart';

abstract final class AppConstants {
  static const String appName = 'REX APP';
  static const String appShortName = 'REX APP';
  static const String appVersion = '1.0.0';
  static const String companyName = 'Field Sales Platform';

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration pageTransitionDuration = Duration(milliseconds: 350);

  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;

  static const double cardRadius = 0;
  static const double buttonRadius = 0;
  static const double badgeRadius = 0;

  static const double defaultPadding = 16;
  static const double sectionSpacing = 24;
}

abstract final class ApiEndpoints {
  static String get baseUrl => ApiConfig.baseUrl;

  // Auth (CRGS-Admin backend)
  static const String login = '/auth/login';
  static const String onboarding = '/auth/onboarding';

  // Users (CRGS-Admin backend)
  static const String users = '/users';
  static const String userRoutes = '/users/routes';
  static const String userStatus = '/users/status';

  // Routes (CRGS-Admin backend)
  static const String routes = '/routes';

  // Customers (CRGS-Admin backend)
  static const String customers = '/customers';
  static const String customerStats = '/customers/stats';
  static const String customerLastOrder = '/customers/last-order';
  static const String customerBillItems = '/customers/bill-items';
  static const String customerContactInfo = '/customers/contact-info';
  static String customerByCode(String custCode) =>
      '/customers/${Uri.encodeComponent(custCode)}';

  // Tasks (CRGS-Admin backend — CRGS_TASK table)
  static const String tasks = '/tasks';
  static const String taskStatus = '/tasks/status';

  // Visits (CRGS-Admin backend — CRGS_VISITDETAILS table)
  static const String visits = '/visits';
  static const String visitsStart = '/visits/start';
  static const String visitsEnd = '/visits/end';

  // Orders (CRGS-Admin backend — CRGS_ORDERHDR table)
  static const String orders = '/orders';

  // Product reviews / item name issues (CRGS_PRODUCTREVIEW)
  static const String productReviews = '/product-reviews';

  // Market research (CRGS-Admin backend — CRGS_MARKETRESEARCH)
  static const String marketResearch = '/market-research';

  // Targets (CRGS-Admin backend)
  static const String salesTargets = '/targets/sales';
  static const String productTargets = '/targets/products';
  static const String customerTargets = '/targets/customers';

  // Items (CRGS-Admin backend — ITEMMASTER)
  static const String items = '/items';

  // Health
  static const String health = '/health';
}
