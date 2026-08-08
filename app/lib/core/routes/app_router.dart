import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/onboarding/providers/onboarding_provider.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/customers/screens/customer_detail_screen.dart';
import '../../features/customers/screens/customer_list_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/follow_up/screens/follow_up_screen.dart';
import '../../features/market_research/screens/market_research_screen.dart';
import '../../features/new_customer/screens/new_customer_screen.dart';
import '../../features/activity/screens/activity_screen.dart';
import '../../features/outstanding/screens/outstanding_collection_screen.dart';
import '../../features/products/screens/product_intro_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/recovery/screens/recovery_form_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/routes/screens/route_list_screen.dart';
import '../../features/routes/screens/others_customers_screen.dart';
import '../../features/tasks/screens/task_management_screen.dart';
import '../../features/visit/screens/visit_tracking_screen.dart';
import '../../shared/widgets/navigation/main_shell.dart';
import 'route_names.dart';

/// Keeps [GoRouter] alive while auth changes trigger redirect re-evaluation.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);

  ref.listen(authProvider, (_, _) {
    refreshNotifier.value++;
  });

  ref.listen(onboardingProvider, (_, _) {
    refreshNotifier.value++;
  });

  ref.onDispose(refreshNotifier.dispose);

  final router = GoRouter(
    initialLocation: RouteNames.login,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isRestoring) return null;

      final onboardingState = ref.read(onboardingProvider);
      final isLoggedIn = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == RouteNames.login;
      final isOnboardingRoute = state.matchedLocation == RouteNames.onboarding;

      if (!isLoggedIn && !isLoginRoute) return RouteNames.login;

      if (isLoggedIn && !onboardingState.isLoaded) return null;

      if (isLoggedIn && !onboardingState.isCompleted) {
        if (!isOnboardingRoute) return RouteNames.onboarding;
        return null;
      }

      if (isLoggedIn && onboardingState.isCompleted && isOnboardingRoute) {
        return RouteNames.routes;
      }

      if (isLoggedIn && isLoginRoute) {
        return onboardingState.isCompleted
            ? RouteNames.routes
            : RouteNames.onboarding;
      }

      return null;
    },
    routes: [
      GoRoute(path: RouteNames.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: RouteNames.onboarding,
        pageBuilder: (_, state) => _fadePage(state, const OnboardingScreen()),
      ),
      ShellRoute(
        builder: (_, _, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.dashboard,
            pageBuilder: (_, state) =>
                _fadePage(state, const DashboardScreen()),
          ),
          GoRoute(
            path: RouteNames.routes,
            pageBuilder: (_, state) =>
                _fadePage(state, const RouteListScreen()),
          ),
          GoRoute(
            path: RouteNames.othersCustomers,
            pageBuilder: (_, state) => _slideFromRightPage(
              state,
              const OthersCustomersScreen(),
            ),
          ),
          GoRoute(
            path: RouteNames.routeCustomers,
            pageBuilder: (_, state) => _slideFromRightPage(
              state,
              CustomerListScreen(routeId: state.pathParameters['routeId']!),
            ),
          ),
          GoRoute(
            path: RouteNames.tasks,
            pageBuilder: (_, state) =>
                _fadePage(state, const TaskManagementScreen()),
          ),
          GoRoute(
            path: RouteNames.orders,
            pageBuilder: (_, state) =>
                _fadePage(state, const ActivityScreen()),
          ),
          GoRoute(
            path: RouteNames.reports,
            pageBuilder: (_, state) => _fadePage(state, const ReportsScreen()),
          ),
          GoRoute(
            path: RouteNames.profile,
            pageBuilder: (_, state) => _fadePage(state, const ProfileScreen()),
          ),
        ],
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (_, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/visit/:customerId',
        builder: (_, state) => VisitTrackingScreen(
          customerId: state.pathParameters['customerId']!,
        ),
      ),
      GoRoute(
        path: '/recovery/:customerId',
        builder: (_, state) =>
            RecoveryFormScreen(customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(
        path: '/products/:customerId',
        builder: (_, state) =>
            ProductIntroScreen(customerId: state.pathParameters['customerId']!),
      ),
      GoRoute(
        path: RouteNames.followUp,
        builder: (_, _) => const FollowUpScreen(),
      ),
      GoRoute(
        path: RouteNames.marketResearch,
        builder: (_, state) => MarketResearchScreen(
          routeId: state.uri.queryParameters['routeId'] ?? '',
        ),
      ),
      GoRoute(
        path: RouteNames.newCustomer,
        builder: (_, _) => const NewCustomerScreen(),
      ),
      GoRoute(
        path: RouteNames.outstanding,
        builder: (_, _) => const OutstandingCollectionScreen(),
      ),
      GoRoute(
        path: RouteNames.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Push-style transition for nested route pages (avoids fade+header jump).
CustomTransitionPage<void> _slideFromRightPage(
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final primary = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final secondary = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.08, 0),
        ).animate(secondary),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(primary),
          child: child,
        ),
      );
    },
  );
}
