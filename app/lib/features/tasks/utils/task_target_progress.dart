import '../../../data/models/models.dart';
import '../../../data/repositories/routes_repository.dart';

/// Progress metrics linked to a task via employee + route + type mapping.
class TaskTargetProgress {
  const TaskTargetProgress({
    this.targetCount,
    this.achievedCount,
    this.targetAmount,
    this.achievedAmount,
    this.label = '',
  });

  final double? targetCount;
  final double? achievedCount;
  final double? targetAmount;
  final double? achievedAmount;
  final String label;

  bool get hasCount =>
      (targetCount != null && targetCount! > 0) ||
      (achievedCount != null && achievedCount! > 0);

  bool get hasAmount =>
      (targetAmount != null && targetAmount! > 0) ||
      (achievedAmount != null && achievedAmount! > 0);

  bool get hasAny => hasCount || hasAmount;
}

/// Maps Oracle task TYPE → customer/product target TYPE.
String? customerTargetTypeForTask(String taskTypeCode) => switch (taskTypeCode) {
      'missing_customer_followup' => 'missing_recovery',
      'outstanding_collection_followup' => 'outstanding_collection',
      'customer_visit_campaign' => 'new_acquisition',
      _ => null,
    };

String? productTargetTypeForTask(String taskTypeCode) => switch (taskTypeCode) {
      'new_product_introduction' => 'new_promotion',
      'product_replacement_campaign' => 'replacement',
      'own_products' => 'own_products',
      _ => null,
    };

TaskTargetProgress? resolveTaskTargetProgress({
  required TaskModel task,
  required ExecutiveTargetsData targets,
}) {
  final routeNo = normalizeRouteNo(task.routeId ?? '');
  final typeCode = task.taskTypeCode.trim().toLowerCase();
  if (typeCode.isEmpty) return null;

  final customerType = customerTargetTypeForTask(typeCode);
  if (customerType != null) {
    final matches = targets.customerByPeriod.where((t) {
      if (t.type != customerType) return false;
      final targetRoutes = parseRouteNos(t.routeNo);
      if (routeNo.isEmpty || targetRoutes.isEmpty) return true;
      return targetRoutes.contains(routeNo);
    }).toList();

    if (matches.isEmpty) return null;

    var targetCount = 0.0;
    var achievedCount = 0.0;
    var targetAmount = 0.0;
    for (final match in matches) {
      targetCount += match.targetCount;
      achievedCount += match.achievedCount;
      targetAmount += match.targetAmount;
    }

    final progress = TaskTargetProgress(
      targetCount: targetCount > 0 ? targetCount : null,
      achievedCount: (targetCount > 0 || achievedCount > 0) ? achievedCount : null,
      targetAmount: targetAmount > 0 ? targetAmount : null,
      label: matches.first.typeLabel,
    );
    return progress.hasAny ? progress : null;
  }

  final productType = productTargetTypeForTask(typeCode);
  if (productType != null) {
    final matches = targets.productTargets.where((t) {
      if (t.type != productType) return false;
      final targetRoutes = parseRouteNos(t.routeNo);
      if (routeNo.isEmpty || targetRoutes.isEmpty) return true;
      return targetRoutes.contains(routeNo);
    }).toList();

    if (matches.isEmpty) return null;

    var targetValue = 0.0;
    var achievedValue = 0.0;
    for (final match in matches) {
      targetValue += match.targetValue;
      achievedValue += match.achievedValue;
    }

    // Product targets store a single metric — surface as count when present.
    final progress = TaskTargetProgress(
      targetCount: targetValue > 0 ? targetValue : null,
      achievedCount: (targetValue > 0 || achievedValue > 0) ? achievedValue : null,
      label: matches.first.typeLabel,
    );
    return progress.hasAny ? progress : null;
  }

  return null;
}

String formatTargetNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
