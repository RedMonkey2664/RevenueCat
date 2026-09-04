import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/widgets/phase_placeholder.dart';

/// Daily Pivot tab. Phase 6 (ROADMAP.md).
///
/// Nothing here fakes a crowd percentage. DAILY_PIVOT.md requires the crowd
/// split to be a real cross-user Firestore aggregate; a placeholder number
/// would be indistinguishable from the finished feature on screen, which
/// CLAUDE.md forbids.
class PivotHome extends StatelessWidget {
  const PivotHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DAILY PIVOT',
          style: AppText.label(color: AppColors.textPrimary),
        ),
      ),
      body: const PhasePlaceholder(
        pillar: 'Daily Pivot',
        phase: 'Phase 6',
        summary:
            'One daily BTC question, a live crowd-sentiment reveal, and '
            'Discipline Points. Needs the Firestore vote tally and the two '
            'scheduled Cloud Functions first — the crowd split is a real '
            'aggregate or it is nothing.',
      ),
    );
  }
}
