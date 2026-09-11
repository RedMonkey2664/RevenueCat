import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../app/widgets/discipline_badge.dart';
import '../../app/widgets/hud.dart';
import '../../app/widgets/nerve_avatar.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/purchases_service.dart';
import '../../core/services/run_history_service.dart';
import '../paywall/paywall_screen.dart';
import 'model/nerve_profile.dart';
import 'widgets/nerve_share_card.dart';

/// The Nerve Profile — a behavioural read built from the player's own runs.
///
/// Three states, one screen:
///
///   * **building** — fewer than [NerveProfile.unlockLevels] distinct levels
///     played. Says how many more, and shows them filling in.
///   * **locked** — enough data, no Pro. The archetype and the overall score
///     are free; the traits behind them are the Pro report.
///   * **full** — every trait, and the shareable card.
///
/// It also carries what the old Profile sheet did: the shared Discipline
/// Points total and the no-real-money note, which DESIGN.md and CLAUDE.md
/// require wherever points are shown.
class NerveProfileScreen extends ConsumerWidget {
  const NerveProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RunRecord> runs = ref.watch(runHistoryProvider);
    final NerveProfile profile = NerveProfile.from(runs);
    final bool pro = ref.watch(proAccessProvider).hasPro;
    final bool full = profile.isUnlocked && pro;

    return Scaffold(
      appBar: HudTopBar(
        title: 'NERVE PROFILE',
        titleColor: AppColors.textPrimary,
        leading: const HudBackButton(),
        trailing: full
            ? IconButton(
                tooltip: 'Share your profile',
                onPressed: () => _openShare(context, profile),
                icon: const Icon(
                  Icons.hexagon_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 4,
          AppSpacing.md,
          AppSpacing.md + 4,
          AppSpacing.xl,
        ),
        children: <Widget>[
          if (!profile.isUnlocked)
            _Building(profile: profile, runs: runs)
          else if (!pro)
            _Locked(profile: profile)
          else
            _Full(profile: profile, runs: runs),
          const SizedBox(height: AppSpacing.xl),
          const _Account(),
        ],
      ),
    );
  }

  static Future<void> _openShare(BuildContext context, NerveProfile profile) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => _ShareSheet(profile: profile),
    );
  }
}

/// "Based on 8 levels, 47 decisions" — the figures in white, the words dim.
class _Basis extends StatelessWidget {
  const _Basis({required this.profile});

  final NerveProfile profile;

  @override
  Widget build(BuildContext context) {
    final TextStyle dim = AppText.body(
      size: 14,
      color: AppColors.textFaint,
      letterSpacing: 14 * 0.06,
    );
    final TextStyle strong = dim.copyWith(color: AppColors.textPrimary);
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: 'Based on ', style: dim),
          TextSpan(text: '${profile.levelsPlayed}', style: strong),
          TextSpan(
            text: ' level${profile.levelsPlayed == 1 ? '' : 's'}, ',
            style: dim,
          ),
          TextSpan(text: '${profile.decisions}', style: strong),
          TextSpan(
            text: ' decision${profile.decisions == 1 ? '' : 's'}',
            style: dim,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.profile, this.avatar = 140});

  final NerveProfile profile;
  final double avatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        NerveAvatar(size: avatar),
        const SizedBox(height: AppSpacing.lg),
        Text(
          profile.archetype.title,
          textAlign: TextAlign.center,
          style: AppText.headline(size: 40, letterSpacing: 40 * 0.1),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          profile.archetype.description,
          textAlign: TextAlign.center,
          style: AppText.body(size: 15, color: AppColors.accent),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ building

class _Building extends StatelessWidget {
  const _Building({required this.profile, required this.runs});

  final NerveProfile profile;
  final List<RunRecord> runs;

  /// The level-map candy palette, so a finished level looks the same here as
  /// on the map it came from.
  static const List<List<Color>> _candy = <List<Color>>[
    <Color>[Color(0xFF58D68D), Color(0xFF2ECC71), Color(0xFF1E8449)],
    <Color>[Color(0xFFF5B041), Color(0xFFE67E22), Color(0xFFAF601A)],
    <Color>[Color(0xFF5DADE2), Color(0xFF2E86C1), Color(0xFF1B4F72)],
  ];

  @override
  Widget build(BuildContext context) {
    final int done = profile.levelsPlayed;
    const int goal = NerveProfile.unlockLevels;
    final int left = profile.levelsToUnlock;

    return Column(
      children: <Widget>[
        const SizedBox(height: AppSpacing.xxl + 16),
        const NerveAvatar(size: 150),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Your Nerve Profile is building.',
          textAlign: TextAlign.center,
          style: AppText.title(
            size: 29,
            weight: FontWeight.w800,
            letterSpacing: 29 * 0.06,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text.rich(
          TextSpan(
            style: AppText.body(size: 15, color: AppColors.textSecondary),
            children: <InlineSpan>[
              const TextSpan(text: 'Complete '),
              TextSpan(
                text: '$left more level${left == 1 ? '' : 's'}',
                style: AppText.body(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              const TextSpan(text: ' to unlock your behavioral report.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        FractionallySizedBox(
          widthFactor: 0.78,
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('PROGRESS', style: AppText.label(size: 11)),
                  const Spacer(),
                  Text('$done / $goal LEVELS', style: AppText.label(size: 11)),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              ClipRRect(
                child: LinearProgressIndicator(
                  value: done / goal,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (int i = 0; i < goal; i++)
                    i < done
                        ? _DoneDot(colors: _candy[i % _candy.length])
                        : const _PendingDot(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneDot extends StatelessWidget {
  const _DoneDot({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[colors[0], colors[1]],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: colors[2], offset: const Offset(0, 4)),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
    );
  }
}

class _PendingDot extends StatelessWidget {
  const _PendingDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: const _DashedCirclePainter(),
        child: Center(
          child: Text(
            '?',
            style: AppText.body(size: 16, color: AppColors.textFaint),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final Rect r = (Offset.zero & size).deflate(1);
    const int dashes = 18;
    for (int i = 0; i < dashes; i++) {
      canvas.drawArc(r, i * 2 * 3.14159 / dashes, 3.14159 / dashes, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => false;
}

// -------------------------------------------------------------------- locked

class _Locked extends StatelessWidget {
  const _Locked({required this.profile});

  final NerveProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _Basis(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        _Identity(profile: profile, avatar: 120),
        const SizedBox(height: AppSpacing.lg),
        _OverallCard(profile: profile, showChange: false),
        const SizedBox(height: AppSpacing.xxl),
        const Icon(Icons.lock, size: 40, color: AppColors.caution),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Your full behavioral profile is ready.',
          textAlign: TextAlign.center,
          style: AppText.title(
            size: 23,
            weight: FontWeight.w800,
            letterSpacing: 23 * 0.06,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'See your panic threshold, decision speed, crash sensitivity, and '
          'how you\'re improving.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        HudButton(
          label: 'UNLOCK WITH PREMIUM',
          style: HudButtonStyle.filled,
          height: 58,
          fontSize: 17,
          onPressed: () => PaywallScreen.show(context),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------- full

class _Full extends StatelessWidget {
  const _Full({required this.profile, required this.runs});

  final NerveProfile profile;
  final List<RunRecord> runs;

  @override
  Widget build(BuildContext context) {
    final NerveTrait? shifted = NerveProfile.shiftedBy(runs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Basis(profile: profile),
        if (shifted != null && runs.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          HudPanel(
            color: AppColors.accent.withValues(alpha: 0.35),
            fill: AppColors.accent.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md - 2,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.arrow_upward,
                  size: 15,
                  color: AppColors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Updated after ${runs.last.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${shifted.long} shifted',
                  style: AppText.label(size: 9, color: AppColors.textFaint),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _Identity(profile: profile),
        const SizedBox(height: AppSpacing.xl),
        _OverallCard(profile: profile, showChange: true),
        const SizedBox(height: AppSpacing.md + 4),
        _PanicCard(profile: profile),
        const SizedBox(height: AppSpacing.md + 4),
        _SensitivityCard(profile: profile),
        const SizedBox(height: AppSpacing.md + 4),
        _TraitCard(
          title: 'DECISION SPEED',
          value: profile.medianSeconds == null
              ? '—'
              : '${profile.medianSeconds!.toStringAsFixed(1)}s',
          body: profile.medianSeconds == null
              ? 'Measured on the calls a beginner run halts for. Play one to '
                    'see how long you look at a falling tape before acting.'
              : 'Your median time on a halted tape before making the call.',
        ),
        const SizedBox(height: AppSpacing.md + 4),
        _TraitCard(
          title: 'DIP BUYING',
          value: '${(profile.dipRate * 100).round()}%',
          body:
              'Of the moments your nerve was tested, the share where you '
              'bought into the fall.',
        ),
        const SizedBox(height: AppSpacing.md + 4),
        _TraitCard(
          title: 'LEARNING',
          value: profile.learningDelta == null
              ? '—'
              : '${profile.learningDelta! >= 0 ? '+' : '−'}'
                    '${profile.learningDelta!.abs().round()}',
          body: profile.learningDelta == null
              ? 'Needs four scored runs to compare your first three with your '
                    'latest three.'
              : 'Points between the average of your first three runs and '
                    'your latest three.',
        ),
        const SizedBox(height: AppSpacing.lg),
        HudButton(
          label: 'SHARE YOUR PROFILE',
          height: 54,
          fontSize: 15,
          onPressed: () => NerveProfileScreen._openShare(context, profile),
        ),
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.profile, required this.showChange});

  final NerveProfile profile;
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    final int? overall = profile.overall;
    final int? start = profile.startingOverall;
    final bool up = start != null && overall != null && overall >= start;
    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('OVERALL DISCIPLINE', style: AppText.label(size: 11)),
              const SizedBox(width: AppSpacing.md),
              if (showChange &&
                  start != null &&
                  overall != null &&
                  start != overall)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Icon(
                        up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: up ? const Color(0xFF6BCB77) : AppColors.down,
                        size: 22,
                      ),
                      Flexible(
                        child: Text(
                          '${up ? 'Up' : 'Down'} from $start when you started',
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          style: AppText.body(
                            size: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${overall ?? '—'}',
                style: AppText.headline(
                  size: 64,
                  color: DisciplineVisuals.colorFor(overall),
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '/100',
                style: AppText.body(size: 22, color: AppColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 4),
          _GradientMeter(value: (overall ?? 0) / 100),
        ],
      ),
    );
  }
}

/// Red through amber to sage, filled to the score, with a white tick.
class _GradientMeter extends StatelessWidget {
  const _GradientMeter({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = c.maxWidth * value.clamp(0.0, 1.0);
          return Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF070A0E),
                  border: Border.all(color: AppColors.border),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Color(0xFFEF5350),
                        Color(0xFFF5A33B),
                        Color(0xFFF3C04F),
                        Color(0xFFA8C48A),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: (w - 2).clamp(0.0, c.maxWidth - 3),
                top: 0,
                bottom: 0,
                width: 3,
                child: const ColoredBox(color: Colors.white),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanicCard extends StatelessWidget {
  const _PanicCard({required this.profile});

  final NerveProfile profile;

  @override
  Widget build(BuildContext context) {
    final double? t = profile.panicThreshold;
    final double? early = profile.earlyPanicThreshold;
    final String zone = t == null
        ? ''
        : t >= 0.30
        ? 'You hold deep into a fall before breaking. '
        : t >= 0.15
        ? 'You break partway down a fall. '
        : 'You tend to break early in a fall. ';

    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('PANIC THRESHOLD', style: AppText.label(size: 11)),
          const SizedBox(height: AppSpacing.md),
          Text(
            t == null ? 'NONE YET' : '−${(t * 100).round()}%',
            style: AppText.headline(
              size: t == null ? 34 : 54,
              color: AppColors.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ZoneSlider(value: t),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'EARLY 0%',
                style: AppText.label(size: 10, color: AppColors.down),
              ),
              Text(
                'MID −15%',
                style: AppText.label(size: 10, color: AppColors.caution),
              ),
              Text(
                'DEEP −50%',
                style: AppText.label(size: 10, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 4),
          Text(
            t == null
                ? 'You have not sold into a fall yet. Your threshold appears '
                      'the first time you do.'
                : '${zone}Your average first sell happens at a '
                      '${(t * 100).round()}% drawdown.',
            style: AppText.body(size: 15, color: AppColors.textSecondary),
          ),
          if (t != null &&
              early != null &&
              (early - t).abs() >= 0.01) ...<Widget>[
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              'Was −${(early * 100).round()}% after your first 3 levels',
              style: AppText.body(size: 12.5, color: AppColors.textFaint),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three zones — early, mid, deep — on a 0 to 50% drawdown scale, with a
/// thumb at the player's threshold.
class _ZoneSlider extends StatelessWidget {
  const _ZoneSlider({required this.value});

  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double w = c.maxWidth;
          return Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              SizedBox(
                height: 12,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: 30,
                      child: ColoredBox(
                        color: AppColors.down.withValues(alpha: 0.28),
                      ),
                    ),
                    Expanded(
                      flex: 30,
                      child: ColoredBox(
                        color: AppColors.caution.withValues(alpha: 0.24),
                      ),
                    ),
                    Expanded(
                      flex: 40,
                      child: ColoredBox(
                        color: AppColors.accent.withValues(alpha: 0.28),
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null)
                Positioned(
                  left: (w * (value! / 0.5).clamp(0.0, 1.0) - 8).clamp(
                    0.0,
                    w - 16,
                  ),
                  child: Container(
                    width: 16,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({required this.profile});

  final NerveProfile profile;

  @override
  Widget build(BuildContext context) {
    final double? fast = profile.fastPanicRate;
    final double? slow = profile.slowPanicRate;
    final bool known = fast != null && slow != null;

    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('CRASH SPEED SENSITIVITY', style: AppText.label(size: 11)),
          const SizedBox(height: AppSpacing.md),
          if (!known)
            Text(
              'Needs both a sudden crash and a slow decline in your history to '
              'compare how you sell in each.',
              style: AppText.body(size: 14, color: AppColors.textSecondary),
            )
          else ...<Widget>[
            _RateBar(label: 'SUDDEN DROPS', rate: fast),
            const SizedBox(height: AppSpacing.sm + 4),
            _RateBar(label: 'SLOW DECLINES', rate: slow),
            const SizedBox(height: AppSpacing.md),
            Text(
              fast - slow > 0.15
                  ? 'You sell a sudden drop far more often than a slow one.'
                  : slow - fast > 0.15
                  ? 'Slow grinds wear you down more than sharp crashes.'
                  : 'A crash\'s speed barely changes how you respond.',
              style: AppText.body(size: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({required this.label, required this.rate});

  final String label;
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(label, style: AppText.label(size: 10)),
        ),
        Expanded(
          child: ClipRRect(
            child: LinearProgressIndicator(
              value: rate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.down),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        SizedBox(
          width: 88,
          child: Text(
            'SOLD ${(rate * 100).round()}%',
            textAlign: TextAlign.right,
            style: AppText.mono(size: 11, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _TraitCard extends StatelessWidget {
  const _TraitCard({
    required this.title,
    required this.value,
    required this.body,
  });

  final String title;
  final String value;
  final String body;

  @override
  Widget build(BuildContext context) {
    return HudPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppText.label(size: 11)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  body,
                  style: AppText.body(
                    size: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            value,
            style: AppText.headline(
              size: 34,
              color: AppColors.accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- account

/// The cross-pillar totals and the framing note that used to be the Profile
/// sheet. Restore Purchases lives here too once a store exists to restore
/// from (MONETIZATION.md) — until then it is absent, not inert.
class _Account extends ConsumerWidget {
  const _Account();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProgressState progress = ref.watch(progressProvider);
    final PurchasesService store = ref.watch(purchasesServiceProvider);

    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppText.label(size: 10.5))),
          Text(
            value,
            style: AppText.display(
              size: 18,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'ACCOUNT',
          style: AppText.railLabel(size: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        HudPanel(
          child: Column(
            children: <Widget>[
              row(
                'TOTAL DISCIPLINE POINTS',
                '${progress.totalDisciplinePoints}',
                color: AppColors.accent,
              ),
              row('LEVELS CLEARED', '${progress.clearedCount}'),
              row('DAILY PIVOT POINTS', '${progress.pivotBonusPoints}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (store.isConfigured) ...<Widget>[
          HudButton(
            label: 'RESTORE PURCHASES',
            style: HudButtonStyle.ghost,
            height: 48,
            fontSize: 13,
            onPressed: () async {
              final ScaffoldMessengerState m = ScaffoldMessenger.of(context);
              try {
                final bool ok = await store.restore();
                if (ok) ref.read(proAccessProvider.notifier).markPurchased();
                m.showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Pro restored.' : 'No Pro subscription to restore.',
                    ),
                  ),
                );
              } on Object catch (e) {
                m.showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: statePanelDecoration(
            AppColors.simulatedBadge,
            fillOpacity: 0.06,
            borderOpacity: 0.4,
          ),
          child: Text(
            'Discipline Points are an in-app score only. They are not money, '
            'cannot be withdrawn, exchanged or cashed out, and have no value '
            'outside this app. Every run uses virtual capital.',
            style: AppText.body(size: 12, color: AppColors.simulatedBadge),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- share

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.profile});

  final NerveProfile profile;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _card = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    final RenderRepaintBoundary? boundary =
        _card.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _busy = true);
    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'market_nerve_profile.png',
            ),
          ],
          text: 'My Nerve Profile — Market Nerve',
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create the image: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RepaintBoundary(
              key: _card,
              child: NerveShareCard(profile: widget.profile),
            ),
            const SizedBox(height: AppSpacing.lg),
            HudButton(
              label: _busy ? 'PREPARING…' : 'SHARE',
              style: HudButtonStyle.filled,
              height: 52,
              fontSize: 16,
              onPressed: _busy ? null : _share,
            ),
          ],
        ),
      ),
    );
  }
}
