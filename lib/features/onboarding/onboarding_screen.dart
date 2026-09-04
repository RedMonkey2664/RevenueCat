import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/services/progress_service.dart';

/// Whether onboarding has been completed on this device.
final NotifierProvider<OnboardingNotifier, bool> onboardingSeenProvider =
    NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

class OnboardingNotifier extends Notifier<bool> {
  static const String _key = 'mn.onboarding.seen.v1';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> complete() async {
    state = true;
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
  }
}

/// Three screens, shown once (DESIGN.md).
///
/// This is not decoration. CLAUDE.md and DESIGN.md both make the "no real
/// money" framing non-negotiable, and ROADMAP.md's cut list explicitly
/// forbids cutting it because of store-review risk in a finance-adjacent
/// category. Each pillar states its own disclaimer in its own words, because
/// a single generic disclaimer is easy to skim past.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<_Slide> _slides = <_Slide>[
    _Slide(
      icon: Icons.candlestick_chart,
      title: 'Survive real crashes.',
      body: 'You are dropped into a real historical market drawdown with the '
          'asset and the dates hidden, and asked what you would do. You are '
          'graded on discipline, not on luck.',
      disclaimer: 'Every run uses ₹1,00,000 of virtual capital. No real '
          'money, no real trading, no brokerage account, ever.',
    ),
    _Slide(
      icon: Icons.swap_vert_circle_outlined,
      title: 'One call a day.',
      body: 'A single yes/no question on Bitcoin each morning, then see how '
          'the crowd voted and whether you had the nerve to disagree.',
      disclaimer: 'Correct calls earn Discipline Points — an in-app score '
          'only. Points are not money and can never be withdrawn, exchanged '
          'or cashed out.',
    ),
    _Slide(
      icon: Icons.history_toggle_off,
      title: 'What did waiting cost you?',
      body: 'Look up what an amount would have become if it had gone into '
          'Bitcoin on a past date, and share the result.',
      disclaimer: 'Those figures are illustrative and retrospective — real '
          'past prices, not a forecast. Nothing in this app is investment '
          'advice, and no future return is implied or guaranteed.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (int i) => setState(() => _page = i),
                itemBuilder: (BuildContext context, int i) =>
                    _SlideView(slide: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (int i = 0; i < _slides.length; i++)
                        Container(
                          width: i == _page ? 18 : 6,
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          color: i == _page
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (_isLast) {
                          ref
                              .read(onboardingSeenProvider.notifier)
                              .complete();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: Text(
                        _isLast ? 'I UNDERSTAND' : 'NEXT',
                        style: AppText.mono(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.background,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    required this.disclaimer,
  });

  final IconData icon;
  final String title;
  final String body;
  final String disclaimer;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(slide.icon, size: 44, color: AppColors.accent),
          const SizedBox(height: AppSpacing.lg),
          Text(
            slide.title,
            style: AppText.body(size: 28, weight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            style: AppText.body(
              size: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.simulatedBadge.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.simulatedBadge.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              slide.disclaimer,
              style: AppText.body(
                size: 12,
                color: AppColors.simulatedBadge,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
