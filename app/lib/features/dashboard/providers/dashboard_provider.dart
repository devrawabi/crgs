import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import 'targets_provider.dart';

/// Live sales targets only — never fall back to mock KPI percentages.
final dashboardProvider = Provider<DashboardSummary>((ref) {
  const empty = DashboardSummary();
  final targetsAsync = ref.watch(executiveTargetsProvider);

  return targetsAsync.maybeWhen(
    data: (targets) {
      final daily = targets.salesFor(TargetPeriod.daily);
      final monthly = targets.salesFor(TargetPeriod.monthly);
      final hasDaily = daily != null && daily.target > 0;
      final hasMonthly = monthly != null && monthly.target > 0;

      return empty.copyWith(
        dailySalesTargetPercent: hasDaily ? daily.percent : 0,
        monthlyTargetPercent: hasMonthly ? monthly.percent : 0,
        dailyTargetAmount: hasDaily ? daily.target : 0,
        dailyAchievedAmount: hasDaily ? daily.achieved : 0,
        monthlyTargetAmount: hasMonthly ? monthly.target : 0,
        monthlyAchievedAmount: hasMonthly ? monthly.achieved : 0,
      );
    },
    orElse: () => empty,
  );
});

final notificationsProvider = Provider<List<NotificationModel>>((ref) {
  return MockData.notifications;
});
