import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme_extensions.dart';
import '../../../data/mock/mock_data.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/dashboard/providers/dashboard_provider.dart';
import '../maps/app_map_tile_layer.dart';
import '../maps/map_pin_marker.dart';
import '../navigation/sidebar_provider.dart';
import '../shad/shad_components.dart';

class RouteMasterAppBar extends StatelessWidget {
  const RouteMasterAppBar({
    super.key,
    required this.initials,
    required this.unread,
    this.userName,
    this.onMenu,
    this.onNotifications,
    this.onAvatar,
  });

  final String initials;
  final int unread;
  final String? userName;
  final VoidCallback? onMenu;
  final VoidCallback? onNotifications;
  final VoidCallback? onAvatar;

  String get _title {
    if (userName == null || userName!.isEmpty) return 'Welcome back!';
    final first = userName!.trim().split(' ').first;
    return 'Welcome, $first!';
  }

  @override
  Widget build(BuildContext context) {
    return LoginStyleNavBar(
      title: _title,
      subtitle: AppConstants.appShortName,
      leading: IconButton(
        onPressed: onMenu,
        icon: const Icon(AppIcons.list, color: Colors.white, size: 22),
      ),
      actions: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotifications,
              icon: const Icon(AppIcons.bell, color: Colors.white, size: 22),
            ),
            if (unread > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.missingRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: onAvatar,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String initialsFromName(String? name) {
  if (name == null || name.isEmpty) return 'EX';
  final parts = name.trim().split(' ');
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
  return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
}

void showAppNotificationsSheet(BuildContext context, List notifications) {
  final theme = ShadTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (_, i) {
        final n = notifications[i];
        return ListTile(
          leading: Icon(
            n.isRead ? AppIcons.notificationNone : AppIcons.notificationActive,
            color: n.isRead ? null : RouteMasterColors.titleBlue,
          ),
          title: Text(n.title),
          subtitle: Text(n.body),
        );
      },
    ),
  );
}

/// Default shell header with profile, menu, and notifications.
class DefaultAppHeader extends ConsumerWidget {
  const DefaultAppHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final notifications = ref.watch(notificationsProvider);
    final unread = notifications.where((n) => !n.isRead).length;

    return RouteMasterAppBar(
      initials: initialsFromName(user?.name),
      unread: unread,
      userName: user?.name,
      onMenu: () => toggleSidebar(ref),
      onNotifications: () => showAppNotificationsSheet(context, notifications),
      onAvatar: () => context.go(RouteNames.profile),
    );
  }
}

class TodaysRouteMap extends StatefulWidget {
  const TodaysRouteMap({super.key});

  @override
  State<TodaysRouteMap> createState() => _TodaysRouteMapState();
}

class _TodaysRouteMapState extends State<TodaysRouteMap> {
  final _mapController = MapController();

  static const _activeStopIndex = 2;

  List<LatLng> get _routePoints => MockData.customers
      .where((c) => c.latitude != 0 && c.longitude != 0)
      .map((c) => LatLng(c.latitude, c.longitude))
      .toList();

  LatLng get _routeCenter {
    if (_routePoints.isEmpty) return const LatLng(25.2854, 51.5310);
    final lat = _routePoints.map((p) => p.latitude).reduce((a, b) => a + b) /
        _routePoints.length;
    final lng = _routePoints.map((p) => p.longitude).reduce((a, b) => a + b) /
        _routePoints.length;
    return LatLng(lat, lng);
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom - 1);
  }

  void _focusOnRoute() {
    if (_routePoints.isEmpty) return;
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: _routePoints,
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: RouteMasterColors.mapSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RouteMasterColors.border(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _routeCenter,
              initialZoom: 12,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              const AppMapTileLayer(),
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: RouteMasterColors.mapRoute,
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (var i = 0; i < _routePoints.length; i++)
                    _routeMarker(_routePoints[i], isActive: i == _activeStopIndex),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _ZoomButton(icon: Icons.add, onTap: _zoomIn),
                const SizedBox(height: 4),
                _ZoomButton(icon: Icons.remove, onTap: _zoomOut),
              ],
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Material(
              color: RouteMasterColors.card(context),
              elevation: 2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: _focusOnRoute,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.route, size: 16, color: RouteMasterColors.titleBlue),
                      const SizedBox(width: 6),
                      Text(
                        'Focus on Route',
                        style: ShadTheme.of(context).textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: RouteMasterColors.titleBlue,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _routeMarker(LatLng point, {required bool isActive}) {
    return buildMapPinMarker(
      point: point,
      style: isActive ? MapPinStyle.active : MapPinStyle.stop,
      width: isActive ? 34 : 24,
      height: isActive ? 54 : 40,
      showShadow: isActive,
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RouteMasterColors.card(context),
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: RouteMasterColors.titleBlue),
        ),
      ),
    );
  }
}

class NextVisitCard extends StatelessWidget {
  const NextVisitCard({
    super.key,
    required this.minutes,
    required this.customerName,
    this.onTap,
  });

  final int minutes;
  final String customerName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: RouteMasterColors.nextVisitBlue,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  AppIcons.clock,
                  size: 72,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Visit In',
                    style: theme.textTheme.muted.copyWith(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$minutes Minutes',
                    style: theme.textTheme.h2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    customerName,
                    style: theme.textTheme.small.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoutePerformancePanel extends StatelessWidget {
  const RoutePerformancePanel({
    super.key,
    required this.values,
    this.highlightIndex = 4,
  });

  final List<double> values;
  final int highlightIndex;

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RouteMasterColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RouteMasterColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDarkTheme ? 0.24 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: RouteMasterColors.border(context)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This Week',
                    style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 100,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= _days.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _days[i],
                            style: theme.textTheme.muted.copyWith(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(values.length, (i) {
                  final isHighlight = i == highlightIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        color: isHighlight
                            ? RouteMasterColors.chartHighlight
                            : RouteMasterColors.chartLight,
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendChip(
                color: RouteMasterColors.chartHighlight,
                label: 'Visits Completed',
              ),
              const SizedBox(width: 20),
              _LegendChip(
                color: RouteMasterColors.chartLight,
                label: 'Average Efficiency',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: ShadTheme.of(context).textTheme.muted.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}
