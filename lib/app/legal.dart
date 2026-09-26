import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// The app's legal surface, in one place.
///
/// The App Store requires a subscription screen to link to Terms of Use and
/// a Privacy Policy, and a finance-themed app has to be unambiguous that it
/// is not advice and takes no real money. Both pages are generated from
/// `PRIVACY.md` and `TERMS.md` by `tool/build_legal_pages.py` and shipped
/// with the web build, so what the app links to and what the repository says
/// are the same text.
abstract final class Legal {
  static const String site = 'https://revenue-cat-redmonkey2664s-projects.vercel.app';
  static const String privacyUrl = '$site/privacy.html';
  static const String termsUrl = '$site/terms.html';

  /// Where a subscriber cancels. The stores own this screen; the app only
  /// points at it (an App Store review expectation, and honest besides).
  static const String appleSubscriptions =
      'https://apps.apple.com/account/subscriptions';
  static const String googleSubscriptions =
      'https://play.google.com/store/account/subscriptions';

  /// One sentence, everywhere money-shaped numbers appear.
  static const String shortDisclaimer =
      'Educational simulator. Virtual capital, no real trades, not '
      'investment advice.';

  /// The longer form, for the About screen and first launch.
  static const String longDisclaimer =
      'HistoX replays real historical prices so you can see how you behave '
      'when a market falls. Every position is virtual: the app cannot place '
      'a trade, no real money is ever at risk, and Discipline Points have no '
      'cash value.\n\n'
      'The "historically optimal move" is a hindsight benchmark — it is '
      'worked out after the fact, from what price did next. It is not a '
      'signal and it is not advice.\n\n'
      'Past performance does not predict future results. A high Discipline '
      'Score says you played this game consistently; it does not measure '
      'investing skill, and it is not a psychological assessment.';

  /// Opens [url] in the browser. Returns false when the platform refuses,
  /// so a caller can say so rather than appearing to do nothing.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      return false;
    }
  }
}

/// A small underlined link, used for the legal row and Restore.
class LegalLink extends StatelessWidget {
  const LegalLink({required this.label, required this.url, super.key});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final bool ok = await Legal.open(url);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open $url')),
            );
          }
        },
        child: Padding(
          // Keeps the tap target at the 44pt minimum without making the
          // text itself large enough to compete with the price.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md - 2,
          ),
          child: Text(
            label,
            style: AppText.body(
              size: 12,
              color: AppColors.textFaint,
            ).copyWith(decoration: TextDecoration.underline),
          ),
        ),
      ),
    );
  }
}
