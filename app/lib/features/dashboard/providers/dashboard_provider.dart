import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/models.dart';
import 'targets_provider.dart';

final dashboardProvider = Provider<DashboardSummary>((ref) {
  final base = MockData.dashboardSummary;
  final targetsAsync = ref.watch(executiveTargetsProvider);

  return targetsAsync.maybeWhen(
    data: (targets) {
      final daily = targets.salesFor(TargetPeriod.daily);
      final monthly = targets.salesFor(TargetPeriod.monthly);
      final hasDaily = daily != null && daily.target > 0;
      final hasMonthly = monthly != null && monthly.target > 0;

      return base.copyWith(
        dailySalesTargetPercent:
            hasDaily ? daily.percent : base.dailySalesTargetPercent,
        monthlyTargetPercent:
            hasMonthly ? monthly.percent : base.monthlyTargetPercent,
        dailyTargetAmount: hasDaily ? daily.target : base.dailyTargetAmount,
        dailyAchievedAmount:
            hasDaily ? daily.achieved : base.dailyAchievedAmount,
        monthlyTargetAmount:
            hasMonthly ? monthly.target : base.monthlyTargetAmount,
        monthlyAchievedAmount:
            hasMonthly ? monthly.achieved : base.monthlyAchievedAmount,
      );
    },
    orElse: () => base,
  );
});

final activitiesProvider = Provider<List<ActivityModel>>((ref) {
  return MockData.activities;
});

final notificationsProvider = Provider<List<NotificationModel>>((ref) {
  return MockData.notifications;
});
