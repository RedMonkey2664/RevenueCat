import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/legal.dart';
import '../../app/theme.dart';
import '../../app/widgets/hud.dart';

/// About and disclaimer.
///
/// A finance-themed app has to be unambiguous about three things: it takes
/// no real money, it gives no advice, and a score inside a replay of the
/// past says nothing about the future. The onboarding says the first on
/// launch; this screen says all three, and is where the store links,
/// licences and data sources live.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HudTopBar(
        title: 'ABOUT',
        titleColor: AppColors.textPrimary,
        leading: HudBackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md + 4,
          AppSpacing.lg,
          AppSpacing.md + 4,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          Text(
            'HistoX',
            style: AppText.railLabel(size: 26, weight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'A behavioural finance simulator.',
            style: AppText.body(size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          _Section(
            title: 'WHAT THIS IS',
            body: Legal.longDisclaimer,
          ),

          _Section(
            title: 'WHERE THE PRICES COME FROM',
            body:
                'Crypto prices come from Binance and are real time. US and '
                'Indian equity prices come from Yahoo Finance and may be '
                'delayed. Every price on screen names its source.\n\n'
                'The campaign levels replay historical series bundled with '
                'the app. Prices, dates and the optimal move are computed '
                'from those series, never typed by hand.',
          ),

          _Section(
            title: 'YOUR DATA',
            body:
                'There is no account and no sign-in. Progress, scores and '
                'run history are stored on this device only, and deleting '
                'the app deletes them. The app has no analytics and no '
                'advertising.',
          ),

          const SizedBox(height: AppSpacing.md),
          const LegalLink(label: 'Privacy Policy', url: Legal.privacyUrl),
          const LegalLink(label: 'Terms of Use', url: Legal.termsUrl),
          if (!kIsWeb && (Platform.isIOS || Platform.isAndroid))
            LegalLink(
              label: 'Manage subscription',
              url: Platform.isIOS
                  ? Legal.appleSubscriptions
                  : Legal.googleSubscriptions,
            ),

          const SizedBox(height: AppSpacing.lg),
          TextButton(
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md - 2,
              ),
            ),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'HistoX',
              applicationLegalese:
                  'Fonts: Inter and JetBrains Mono, SIL Open Font License.',
            ),
            child: Text(
              'Open-source licences',
              style: AppText.body(
                size: 12,
                color: AppColors.textFaint,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: AppText.label(size: 11, letterSpacing: 11 * 0.2)),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            body,
            style: AppText.body(
              size: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
