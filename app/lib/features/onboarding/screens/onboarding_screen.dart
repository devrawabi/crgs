import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPageData(
      illustration: 'assets/images/Operations-Executive-Line-Art-6-removebg-preview.png',
      title: 'Welcome to ${AppConstants.appShortName}',
      text:
          'Your mobile companion for sales recovery and route management in the field.',
      enterDuration: Duration(milliseconds: 650),
      exitDuration: Duration(milliseconds: 320),
      pageTransitionDuration: Duration(milliseconds: 420),
    ),
    _OnboardingPageData(
      illustration: 'assets/images/onboard-avatar-2.png',
      title: 'Manage Your Routes',
      text:
          'View assigned routes, customer lists, and visit priorities before you head out.',
      enterDuration: Duration(milliseconds: 720),
      exitDuration: Duration(milliseconds: 360),
      pageTransitionDuration: Duration(milliseconds: 480),
    ),
    _OnboardingPageData(
      illustration: 'assets/images/avatar-dashboard-card.png',
      title: 'Track Visits & Recovery',
      text:
          'Log visits, complete tasks, follow up with customers, and collect outstanding payments.',
      enterDuration: Duration(milliseconds: 680),
      exitDuration: Duration(milliseconds: 340),
      pageTransitionDuration: Duration(milliseconds: 450),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await ref.read(authProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go(RouteNames.routes);
  }

  void _onPrimaryAction() {
    if (_currentPage < _pages.length - 1) {
      final nextPage = _currentPage + 1;
      _pageController.nextPage(
        duration: _pages[nextPage].pageTransitionDuration,
        curve: Curves.easeInOutCubic,
      );
      return;
    }
    _finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  'Skip',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            Expanded(
              flex: 14,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _currentPage = value),
                itemBuilder: (context, index) => _AnimatedOnboardSlide(
                  key: ValueKey(index),
                  index: index,
                  controller: _pageController,
                  data: _pages[index],
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _DotIndicator(isActive: index == _currentPage),
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _onPrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.illustration,
    required this.title,
    required this.text,
    required this.enterDuration,
    required this.exitDuration,
    required this.pageTransitionDuration,
  });

  final String illustration;
  final String title;
  final String text;
  final Duration enterDuration;
  final Duration exitDuration;
  final Duration pageTransitionDuration;
}

class _AnimatedOnboardSlide extends StatefulWidget {
  const _AnimatedOnboardSlide({
    super.key,
    required this.index,
    required this.controller,
    required this.data,
  });

  final int index;
  final PageController controller;
  final _OnboardingPageData data;

  @override
  State<_AnimatedOnboardSlide> createState() => _AnimatedOnboardSlideState();
}

class _AnimatedOnboardSlideState extends State<_AnimatedOnboardSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<double> _imageOpacity;
  late Animation<Offset> _imageSlide;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  int _lastActivePage = -1;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: widget.data.enterDuration,
    );
    _buildEnterAnimations();
    widget.controller.addListener(_handlePageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePageScroll());
  }

  @override
  void didUpdateWidget(covariant _AnimatedOnboardSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.enterDuration != widget.data.enterDuration) {
      _enterController.duration = widget.data.enterDuration;
      _buildEnterAnimations();
    }
  }

  void _buildEnterAnimations() {
    _imageOpacity = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _imageSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _titleOpacity = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.22, 0.72, curve: Curves.easeOutCubic),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.22, 0.78, curve: Curves.easeOutCubic),
    ));

    _textOpacity = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  void _handlePageScroll() {
    if (!widget.controller.hasClients) return;

    final page = widget.controller.page ?? widget.index.toDouble();
    final isActive = (page - widget.index).abs() < 0.01;

    if (isActive && _lastActivePage != widget.index) {
      _lastActivePage = widget.index;
      _enterController.forward(from: 0);
    } else if (!isActive && (page - widget.index).abs() > 0.35) {
      if (_lastActivePage == widget.index) {
        _lastActivePage = -1;
      }
      if (_enterController.value > 0) {
        _enterController.reverse();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handlePageScroll);
    _enterController.dispose();
    super.dispose();
  }

  double _pageDelta() {
    if (!widget.controller.hasClients) return 0;
    final page = widget.controller.page ?? widget.index.toDouble();
    return page - widget.index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = _pageDelta();
    final swipeOpacity = (1 - delta.abs() * 0.72).clamp(0.0, 1.0);
    final swipeTranslateX = delta * 72;
    final swipeScale = (0.9 + (1 - delta.abs().clamp(0.0, 1.0)) * 0.1)
        .clamp(0.9, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Transform.translate(
        offset: Offset(swipeTranslateX, 0),
        child: Opacity(
          opacity: swipeOpacity,
          child: Transform.scale(
            scale: swipeScale,
            child: Column(
              children: [
                Expanded(
                  child: FadeTransition(
                    opacity: _imageOpacity,
                    child: SlideTransition(
                      position: _imageSlide,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            widget.data.illustration,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                            cacheWidth: 768,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _titleOpacity,
                  child: SlideTransition(
                    position: _titleSlide,
                    child: Text(
                      widget.data.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Text(
                      widget.data.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({
    this.isActive = false,
  });

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 5,
      width: isActive ? 20 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.brand
            : AppColors.textSecondaryLight.withValues(alpha: 0.25),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
    );
  }
}
