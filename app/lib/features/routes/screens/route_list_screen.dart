import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../customers/providers/customer_provider.dart';
import '../providers/route_provider.dart';

class RouteListScreen extends ConsumerWidget {
  const RouteListScreen({super.key});

  void _openRouteCustomers(
    WidgetRef ref,
    BuildContext context,
    String routeId,
  ) {
    // Stamp the filter before navigation so CustomerListScreen never mounts
    // against an empty/stale routeId (avoids open flash + initState writes).
    ref.read(customerFilterProvider.notifier).state = const CustomerFilter()
        .copyWith(routeId: routeId);
    context.push(RouteNames.routeCustomersPath(routeId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(assignedRoutesProvider);

    return ShadPageScaffold(
      showHeader: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeading(title: 'My Routes'),
          const SizedBox(height: 8),
          Expanded(
            child: routesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.missingRed),
                  ),
                ),
              ),
              data: (routes) {
                if (routes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No routes assigned to your account.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => _RouteCard(
                    route: routes[index],
                    onOpen: () =>
                        _openRouteCustomers(ref, context, routes[index].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.route, required this.onOpen});

  final RouteModel route;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            boxShadow: AppDecorations.cardShadow(theme.colorScheme.primary),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
            child: SizedBox(
              height: 176,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    route.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.brandContainer,
                            AppColors.brand.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          AppIcons.route,
                          size: 48,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black.withValues(alpha: 0.82),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(
                          AppDecorations.radiusPill,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'ID ${route.routeNumber}',
                        style: theme.textTheme.small.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        AppIcons.chevronRight,
                        color: Colors.white.withValues(alpha: 0.95),
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route.name,
                          style: theme.textTheme.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              AppIcons.mapPin,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Route ID: ${route.routeNumber}',
                                style: theme.textTheme.muted.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
