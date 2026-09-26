import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/widgets/hud.dart';
import '../../core/services/purchases_service.dart';
import '../simulator/campaign/level_repository.dart';

/// HistoX Pro (artboard 1k).
///
/// Shown at the natural moment — straight after a debrief, on the way into a
/// Pro level — and everywhere else a Pro feature is tapped. Its copy follows
/// MONETIZATION.md's honesty rule: it counts only levels that actually exist
/// and can be played, and prices come from the store or not at all.
///
/// Returns true from [show] when the player now has Pro access.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({
    this.score,
    this.practiceYear,
    this.backdrop,
    this.dismissLabel = 'NOT NOW',
    super.key,
  });

  /// The Discipline Score of the run just finished, if there was one.
  final int? score;

  /// "One 2008 was practice." — the year of the level just played.
  final String? practiceYear;

  /// Closes of the run just played, drawn faintly behind the pitch. Real
  /// data, never a decorative squiggle standing in for a chart.
  final List<double>? backdrop;

  final String dismissLabel;

  static Future<bool> show(
    BuildContext context, {
    int? score,
    String? practiceYear,
    List<double>? backdrop,
    String dismissLabel = 'NOT NOW',
  }) async {
    final bool? unlocked = await Navigator.of(context, rootNavigator: true)
        .push<bool>(
          MaterialPageRoute<bool>(
            fullscreenDialog: true,
            builder: (_) => PaywallScreen(
              score: score,
              practiceYear: practiceYear,
              backdrop: backdrop,
              dismissLabel: dismissLabel,
            ),
          ),
        );
    return unlocked ?? false;
  }

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProPlan _plan = ProPlan.yearly;
  List<PlanPrice> _prices = const <PlanPrice>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(purchasesServiceProvider).prices().then((List<PlanPrice> p) {
      if (mounted) setState(() => _prices = p);
    }).ignore();
  }

  PlanPrice? _priceFor(ProPlan plan) {
    for (final PlanPrice p in _prices) {
      if (p.plan == plan) return p;
    }
    return null;
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    try {
      final bool ok = await ref.read(purchasesServiceProvider).purchase(_plan);
      if (ok) {
        ref.read(proAccessProvider.notifier).markPurchased();
        if (mounted) Navigator.of(context).pop(true);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    try {
      final bool ok = await ref.read(purchasesServiceProvider).restore();
      if (!mounted) return;
      if (ok) {
        ref.read(proAccessProvider.notifier).markPurchased();
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Pro subscription to restore.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final PurchasesService store = ref.watch(purchasesServiceProvider);
    final List<LevelManifestEntry> manifest = ref
        .watch(levelManifestProvider)
        .maybeWhen(
          data: (List<LevelManifestEntry> all) => all,
          orElse: () => const <LevelManifestEntry>[],
        );

    // Only levels a Pro subscriber could actually open today. Counting the
    // ones still waiting on a data source would sell something that is not
    // there.
    final int proLevels = manifest
        .where((LevelManifestEntry e) => !e.isFree && e.dataStatus.isPlayable)
        .length;
    final bool storeReady = store.isConfigured;
    // Never in a release build: see kPreviewUnlockAllowed.
    final bool canPreview = !storeReady && kPreviewUnlockAllowed;
    final bool pricesLoaded = _prices.isNotEmpty;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          if (widget.backdrop != null && widget.backdrop!.length > 1)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BackdropPainter(closes: widget.backdrop!),
                ),
              ),
            ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 2,
                AppSpacing.md,
                AppSpacing.md + 2,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'HISTOX PRO',
                        style: AppText.label(size: 11, weight: FontWeight.w600),
                      ),
                      const Spacer(),
                      HudCloseButton(
                        boxed: true,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg + 4),
                  if (widget.score != null) ...<Widget>[
                    Text(
                      'SCORE ${widget.score} · YOU HELD YOUR NERVE',
                      style: AppText.label(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.accent,
                        letterSpacing: 11 * 0.24,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  Text(
                    proLevels > 0
                        ? 'KEEP YOUR NERVE ON $proLevels MORE CRASHES.'
                        : 'KEEP YOUR NERVE.',
                    style: AppText.display(
                      size: 44,
                      weight: FontWeight.w800,
                      height: 1.12,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md + 4),
                  Text(
                    _pitch(proLevels),
                    style: AppText.body(
                      size: 14.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Check(
                    on: true,
                    text: proLevels > 0
                        ? '$proLevels campaign levels · India, international, crypto'
                        : 'The full campaign · India, international, crypto',
                  ),
                  const _Check(
                    on: true,
                    text:
                        'Daily Pivot, Time Machine, Live Markets and custom '
                        'sims',
                  ),
                  const _Check(on: false, text: 'All modes stay free — always'),
                  const SizedBox(height: AppSpacing.xl + 8),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _PlanCard(
                            title: 'YEARLY',
                            tag: 'BEST VALUE',
                            price: _priceFor(ProPlan.yearly)?.priceLabel,
                            note:
                                _priceFor(ProPlan.yearly)?.perMonthLabel == null
                                ? null
                                : '≈ ${_priceFor(ProPlan.yearly)!.perMonthLabel} / month',
                            unloadedNote: '≈ ₹—— / month',
                            selected: _plan == ProPlan.yearly,
                            onTap: () => setState(() => _plan = ProPlan.yearly),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm + 4),
                        Expanded(
                          child: _PlanCard(
                            title: 'MONTHLY',
                            price: _priceFor(ProPlan.monthly)?.priceLabel,
                            note: 'cancel anytime',
                            unloadedNote: 'cancel anytime',
                            selected: _plan == ProPlan.monthly,
                            onTap: () =>
                                setState(() => _plan = ProPlan.monthly),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'PRICES LOAD FROM THE STORE · REGION-SPECIFIC',
                    style: AppText.label(size: 10, color: AppColors.textFaint),
                  ),
                  if (!storeReady) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Text(
                      'STORE NOT CONNECTED IN THIS BUILD',
                      style: AppText.label(
                        size: 10,
                        weight: FontWeight.w600,
                        color: AppColors.caution,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md + 4),
                  HudButton(
                    label: 'CONTINUE',
                    height: 60,
                    fontSize: 22,
                    letterSpacingEm: 0.3,
                    onPressed: storeReady && pricesLoaded && !_busy
                        ? _continue
                        : null,
                  ),
                  // PREVIEW BUILDS ONLY — see ProAccess.previewUnlocked. It
                  // exists because there is no way to buy yet, and it
                  // disappears the moment a store is connected.
                  if (canPreview) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm + 4),
                    HudButton(
                      label: 'PREVIEW BUILD · CONTINUE WITHOUT PRO',
                      style: HudButtonStyle.ghost,
                      height: 46,
                      fontSize: 12,
                      letterSpacingEm: 0.14,
                      onPressed: () {
                        ref.read(proAccessProvider.notifier).unlockPreview();
                        Navigator.of(context).pop(true);
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md + 4),
                  // Restore is an App Store requirement, and it is real only
                  // when there is a store to restore from — absent, not
                  // inert, until then (DESIGN.md).
                  if (storeReady)
                    Center(
                      child: _LinkText(
                        label: 'Restore purchases',
                        onTap: _restore,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(context).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Text(
                          widget.dismissLabel,
                          style: AppText.label(
                            size: 11,
                            color: AppColors.textFaint,
                            letterSpacing: 11 * 0.22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _pitch(int proLevels) {
    final String practice = widget.practiceYear == null
        ? 'The free levels were practice.'
        : 'One ${widget.practiceYear} was practice.';
    if (proLevels == 0) return practice;
    return '$practice The campaign has ${_spell(proLevels)} more, across '
        'India, international markets and crypto.';
  }

  static String _spell(int n) {
    const List<String> words = <String>[
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
      'twenty',
    ];
    return n < words.length ? words[n] : '$n';
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.on, required this.text});

  final bool on;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              border: Border.all(
                color: on ? AppColors.accent : AppColors.textFaint,
                width: 1.4,
              ),
            ),
            child: on ? const ColoredBox(color: AppColors.accent) : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppText.body(
                size: 15,
                color: on ? AppColors.textPrimary : AppColors.textFaint,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.note,
    required this.unloadedNote,
    required this.selected,
    required this.onTap,
    this.tag,
  });

  final String title;
  final String? tag;

  /// Null while the store has not supplied one — drawn as the wireframe's
  /// "₹ ———" placeholder, never as an invented figure.
  final String? price;
  final String? note;
  final String unloadedNote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color rail = selected ? AppColors.accent : AppColors.border;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title plan',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md + 4,
                AppSpacing.lg + 2,
                AppSpacing.md,
                AppSpacing.md + 4,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.06)
                    : AppColors.surface.withValues(alpha: 0.4),
                border: Border.all(color: rail, width: selected ? 1.3 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppText.label(
                      size: 11,
                      weight: FontWeight.w600,
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      letterSpacing: 11 * 0.24,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (price != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        price!,
                        style: AppText.display(
                          size: 30,
                          weight: FontWeight.w800,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: <Widget>[
                        Text(
                          '₹',
                          style: AppText.display(
                            size: 30,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Container(
                            height: 4,
                            color: selected
                                ? AppColors.accent
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    note ?? unloadedNote,
                    style: AppText.body(
                      size: 13,
                      color: AppColors.textFaint,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (tag != null)
              Positioned(
                left: AppSpacing.md + 4,
                top: -11,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 3,
                  ),
                  color: AppColors.accent,
                  child: Text(
                    tag!,
                    style: AppText.label(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppColors.onAccent,
                      letterSpacing: 10 * 0.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  const _LinkText({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            label,
            style: AppText.body(
              size: 13,
              color: AppColors.textSecondary,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}

/// The run just played, as a faint line behind the pitch.
class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({required this.closes});

  final List<double> closes;

  @override
  void paint(Canvas canvas, Size size) {
    double lo = closes.first;
    double hi = closes.first;
    for (final double c in closes) {
      if (c < lo) lo = c;
      if (c > hi) hi = c;
    }
    final double span = hi - lo == 0 ? 1 : hi - lo;
    final Path path = Path();
    for (int i = 0; i < closes.length; i++) {
      final double x = size.width * i / (closes.length - 1);
      final double y =
          size.height * 0.1 + size.height * 0.8 * (1 - (closes[i] - lo) / span);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.closes != closes;
}
