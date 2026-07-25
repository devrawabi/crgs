import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/lottie/visit_timer_lottie.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../data/models/models.dart';
import '../../../shared/widgets/shad/shad_components.dart';
import '../../auth/providers/auth_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../../shared/services/location_service.dart';
import '../widgets/visit_location_card.dart';
import '../widgets/visit_ordered_items_section.dart';
import '../widgets/visit_details_form.dart';
import '../providers/visit_provider.dart';

class VisitTrackingScreen extends ConsumerStatefulWidget {
  const VisitTrackingScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<VisitTrackingScreen> createState() =>
      _VisitTrackingScreenState();
}

class _VisitTrackingScreenState extends ConsumerState<VisitTrackingScreen> {
  String? _selectedReason;
  final _remarksController = TextEditingController();
  final _expectedOrderController = TextEditingController();
  final _followUpController = TextEditingController();
  DateTime? _followUpDate;

  late double _visitLatitude;
  late double _visitLongitude;
  late String _visitAddress;
  bool _isLocating = false;
  bool _locationInitialized = false;
  bool _isEndingVisit = false;
  bool _isInitializing = true;
  bool _allowExit = false;
  final Set<String> _suggestedProductIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVisitScreen();
    });
  }

  Future<void> _initializeVisitScreen() async {
    // startVisit publishes an in-progress visit synchronously before its API
    // call completes. Reveal the page on that optimistic state instead of
    // holding the user behind the network request.
    final startFuture = _ensureVisitStarted();
    _initializeVisitLocation();
    await Future<void>.delayed(Duration.zero);
    if (mounted) setState(() => _isInitializing = false);
    await startFuture;
  }

  void _initializeVisitLocation() {
    final customer = ref.read(customerByIdProvider(widget.customerId));
    if (customer == null) return;

    final visit = ref.read(visitProvider);
    if (visit?.latitude != null && visit?.longitude != null) {
      setState(() {
        _visitLatitude = visit!.latitude!;
        _visitLongitude = visit.longitude!;
        _visitAddress = visit.currentLocation;
        _locationInitialized = true;
      });
      return;
    }

    final hasCustomerCoords = customer.latitude != 0 && customer.longitude != 0;
    setState(() {
      _visitLatitude = hasCustomerCoords ? customer.latitude : 25.2854;
      _visitLongitude = hasCustomerCoords ? customer.longitude : 51.5310;
      _visitAddress = customer.location;
      _locationInitialized = true;
    });

    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    final location = await LocationService.getCurrentVisitLocation();
    if (!mounted) return;

    if (location != null) {
      _applyVisitLocation(location);
    }

    setState(() => _isLocating = false);
  }

  void _applyVisitLocation(VisitLocation location) {
    setState(() {
      _visitLatitude = location.latitude;
      _visitLongitude = location.longitude;
      _visitAddress = location.address;
    });
    ref
        .read(visitProvider.notifier)
        .updateLocation(
          latitude: location.latitude,
          longitude: location.longitude,
          address: location.address,
        );
  }

  Future<void> _ensureVisitStarted() async {
    final customer = ref.read(customerByIdProvider(widget.customerId));
    if (customer == null) return;

    final user = ref.read(currentUserProvider);
    final employeeCode = user?.employeeCode.trim() ?? '';
    if (employeeCode.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Employee code missing. Please log in again.'),
        ),
      );
      return;
    }

    final visit = ref.read(visitProvider);
    final isActiveForCustomer =
        visit?.status == VisitStatus.inProgress &&
        visit?.customerId == widget.customerId;

    if (!isActiveForCustomer) {
      final route = customer.routeId.trim().isNotEmpty
          ? customer.routeId.trim()
          : customer.routeName.trim();
      try {
        await ref
            .read(visitProvider.notifier)
            .startVisit(
              employeeCode: employeeCode,
              customerId: widget.customerId,
              customerName: customer.name,
              route: route,
              location: customer.location,
            );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to save visit start: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _expectedOrderController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  Future<void> _pickFollowUpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _followUpDate = picked;
        _followUpController.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  void _setQuickFollowUp(int days) {
    final date = DateTime.now().add(Duration(days: days));
    setState(() {
      _followUpDate = date;
      _followUpController.text = DateFormat('dd MMM yyyy').format(date);
    });
  }

  Future<void> _endVisit() async {
    if (_isEndingVisit) return;
    setState(() => _isEndingVisit = true);

    try {
      await ref
          .read(visitProvider.notifier)
          .checkOut(
            reason: _selectedReason,
            remarks: _remarksController.text.trim(),
            followUp: _followUpDate,
          );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Visit completed successfully')),
      );
      setState(() => _allowExit = true);
      // Let PopScope rebuild with canPop=true before requesting the pop.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('Failed to save visit end: $error')),
      );
    } finally {
      if (mounted) setState(() => _isEndingVisit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref.watch(customerByIdProvider(widget.customerId));
    final visit = ref.watch(visitProvider);
    final reasons = ref.watch(recoveryReasonsProvider);
    final theme = ShadTheme.of(context);

    final isActive =
        visit?.status == VisitStatus.inProgress &&
        visit?.customerId == widget.customerId;
    final isPageLoading = _isInitializing && !isActive;
    final canEndVisit = isActive && (visit?.persisted ?? false);
    final canLeave = _allowExit || (!isPageLoading && !isActive);

    Widget page;
    if (isPageLoading) {
      page = const ShadPageScaffold(
        title: 'Visit in Progress',
        showBackButton: false,
        body: _VisitPageSkeleton(),
      );
    } else if (customer == null) {
      page = const ShadPageScaffold(
        title: 'Visit',
        showBackButton: false,
        body: Center(child: Text('Customer not found')),
      );
    } else {
      final duration = isActive ? visit!.duration : Duration.zero;

      page = ShadPageScaffold(
        title: 'Visit in Progress',
        subtitle: customer.name,
        showBackButton: false,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/products/${widget.customerId}'),
          icon: const Icon(AppIcons.add),
          label: const Text('Add Orders'),
        ),
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.background,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.border.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: ShadButton(
            onPressed: (canEndVisit && !_isEndingVisit) ? _endVisit : null,
            width: double.infinity,
            leading: (_isEndingVisit || (isActive && !canEndVisit))
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(AppIcons.logoutDoor, size: 18),
            child: Text(
              _isEndingVisit
                  ? 'Saving...'
                  : (isActive && !canEndVisit)
                  ? 'Starting visit...'
                  : 'End Visit',
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TimerCard(duration: duration, isActive: isActive),
              if (_locationInitialized) ...[
                const SizedBox(height: 12),
                VisitLocationCard(
                  customer: customer,
                  latitude: _visitLatitude,
                  longitude: _visitLongitude,
                  address: _visitAddress,
                  onLocationUpdated: _applyVisitLocation,
                ),
              ],
              const SizedBox(height: 20),
              VisitOrderedItemsSection(
                customerId: widget.customerId,
                suggestedProductIds: _suggestedProductIds,
                onSuggestionAdded: (productId) {
                  setState(() => _suggestedProductIds.add(productId));
                },
              ),
              const SizedBox(height: 20),
              VisitDetailsForm(
                reasons: reasons,
                selectedReason: _selectedReason,
                onReasonChanged: (v) => setState(() => _selectedReason = v),
                remarksController: _remarksController,
                expectedOrderController: _expectedOrderController,
                followUpController: _followUpController,
                followUpDate: _followUpDate,
                onPickFollowUpDate: _pickFollowUpDate,
                onQuickFollowUp: _setQuickFollowUp,
                suggestedProductCount: _suggestedProductIds.length,
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || canLeave || !mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('End the visit before leaving this page'),
          ),
        );
      },
      child: page,
    );
  }
}

class _VisitPageSkeleton extends StatelessWidget {
  const _VisitPageSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final fill = theme.colorScheme.mutedForeground.withValues(alpha: 0.12);

    Widget block({required double height, double? width}) => Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppDecorations.radiusMd),
      ),
    );

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        block(height: 118),
        const SizedBox(height: 12),
        block(height: 148),
        const SizedBox(height: 20),
        block(height: 18, width: 130),
        const SizedBox(height: 12),
        block(height: 86),
        const SizedBox(height: 20),
        block(height: 18, width: 110),
        const SizedBox(height: 12),
        block(height: 52),
        const SizedBox(height: 10),
        block(height: 88),
      ],
    );
  }
}

class _TimerCard extends StatefulWidget {
  const _TimerCard({required this.duration, required this.isActive});

  final Duration duration;
  final bool isActive;

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isActive) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_TimerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isActive) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isActive = widget.isActive;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDecorations.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  AppColors.brandContainer,
                  AppColors.successGreenContainer,
                  Colors.white,
                ]
              : [
                  theme.colorScheme.muted.withValues(alpha: 0.35),
                  theme.colorScheme.card,
                ],
        ),
        border: Border.all(
          color: isActive
              ? AppColors.brand.withValues(alpha: 0.35)
              : theme.colorScheme.border,
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
            child: Row(
              children: [
                VisitTimerLottie(isActive: isActive),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _format(widget.duration),
                        style: theme.textTheme.h1.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isActive
                              ? AppColors.brandDark
                              : theme.colorScheme.foreground,
                          letterSpacing: 2,
                          height: 1,
                          fontSize: 36,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isActive ? 'Visit Duration' : 'Starting visit...',
                        style: theme.textTheme.muted.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Positioned(
              top: 14,
              right: 14,
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.65, end: 1).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppDecorations.radiusPill,
                    ),
                    border: Border.all(
                      color: AppColors.successGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.successGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live',
                        style: theme.textTheme.small.copyWith(
                          color: AppColors.successGreenDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
