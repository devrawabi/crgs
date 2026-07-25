import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';

class OnboardingState {
  const OnboardingState({
    this.isLoaded = false,
    this.isCompleted = false,
  });

  final bool isLoaded;
  final bool isCompleted;
}

/// Onboarding completion is stored in CRGS_USER.ONBOARD_FLAG via login response.
final onboardingProvider = Provider<OnboardingState>((ref) {
  final auth = ref.watch(authProvider);

  if (auth.isRestoring) {
    return const OnboardingState();
  }

  if (!auth.isAuthenticated || auth.user == null) {
    return const OnboardingState(isLoaded: true);
  }

  return OnboardingState(
    isLoaded: true,
    isCompleted: auth.user!.onboardingCompleted,
  );
});
