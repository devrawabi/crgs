import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/repositories/market_research_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/common/app_widgets.dart';

final marketResearchRepositoryProvider = Provider<MarketResearchRepository>((ref) {
  return MarketResearchRepository(ref.watch(apiClientProvider));
});

class MarketResearchScreen extends ConsumerStatefulWidget {
  const MarketResearchScreen({super.key, this.routeId = ''});

  final String routeId;

  @override
  ConsumerState<MarketResearchScreen> createState() =>
      _MarketResearchScreenState();
}

class _MarketResearchScreenState extends ConsumerState<MarketResearchScreen> {
  final _trendsController = TextEditingController();
  final _fastMovingController = TextEditingController();
  final _slowMovingController = TextEditingController();
  final _compPromotionsController = TextEditingController();
  final _opportunitiesController = TextEditingController();
  final _notesController = TextEditingController();
  final _attachments = <String>[];
  bool _isSaving = false;

  @override
  void dispose() {
    _trendsController.dispose();
    _fastMovingController.dispose();
    _slowMovingController.dispose();
    _compPromotionsController.dispose();
    _opportunitiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _resolveRoute(String employeeRoute) {
    final fromQuery = widget.routeId.trim();
    if (fromQuery.isNotEmpty) return fromQuery;
    return employeeRoute.trim();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final user = ref.read(authProvider).user;
    final employeeCode = user?.employeeCode.trim() ?? '';
    final route = _resolveRoute(user?.assignedRouteId ?? '');

    if (employeeCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee session not found. Please log in again.')),
      );
      return;
    }
    if (route.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route is required for market research')),
      );
      return;
    }

    final marketTrend = _trendsController.text.trim();
    final fastMoving = _fastMovingController.text.trim();
    final slowMoving = _slowMovingController.text.trim();
    final competitorPromotions = _compPromotionsController.text.trim();
    final newOpportunities = _opportunitiesController.text.trim();
    final notes = _notesController.text.trim();

    if ([
      marketTrend,
      fastMoving,
      slowMoving,
      competitorPromotions,
      newOpportunities,
      notes,
    ].every((value) => value.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one research field')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(marketResearchRepositoryProvider).submitResearch(
            employeeCode: employeeCode,
            route: route,
            marketTrend: marketTrend,
            fastMovingProducts: fastMoving,
            slowMovingProducts: slowMoving,
            competitorPromotions: competitorPromotions,
            newOpportunities: newOpportunities,
            notes: notes,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Market research saved')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final route = _resolveRoute(user?.assignedRouteId ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Research'),
        bottom: route.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Route $route',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _trendsController,
              label: 'Market Trends',
              maxLines: 3,
              prefixIcon: AppIcons.trend,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _fastMovingController,
              label: 'Fast Moving Products',
              maxLines: 2,
              prefixIcon: AppIcons.speed,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _slowMovingController,
              label: 'Slow Moving Products',
              maxLines: 2,
              prefixIcon: AppIcons.timer,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _compPromotionsController,
              label: 'Competitor Promotions',
              maxLines: 3,
              prefixIcon: AppIcons.campaign,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _opportunitiesController,
              label: 'New Opportunities',
              maxLines: 3,
              prefixIcon: AppIcons.lightbulb,
            ),
            const SizedBox(height: 24),
            SectionHeader(title: 'Detailed Notes'),
            AppTextField(
              controller: _notesController,
              label: 'Notes',
              maxLines: 8,
            ),
            const SizedBox(height: 16),
            SectionHeader(title: 'Photo Attachments'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._attachments.map(
                  (a) => Chip(
                    avatar: const Icon(AppIcons.image, size: 18),
                    label: Text(a),
                    onDeleted: () => setState(() => _attachments.remove(a)),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(AppIcons.camera, size: 18),
                  label: const Text('Add Photo'),
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            _attachments.add('Photo ${_attachments.length + 1}');
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Research'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
