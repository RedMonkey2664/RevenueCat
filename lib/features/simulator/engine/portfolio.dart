import 'package:flutter/foundation.dart';

import 'script_event_model.dart';

/// The simulated portfolio behind a run.
///
/// ₹1,00,000 of virtual capital, no real money anywhere (CLAUDE.md).
///
/// DECISION(somi) — the split below is not specified in ENGINE.md and I picked
/// a default so all three buttons are mechanically meaningful:
/// the run starts [initialDeployedFraction] deployed into the asset and the
/// rest in cash. Fully deployed (100%) would leave "Buy the Dip" with nothing
/// to buy; a large reserve would make the drawdown too painless to feel. 75/25
/// is the middle. Confirm or change [initialDeployedFraction] — it is the one
/// number that tunes how much a panic-sell actually costs.
@immutable
class Portfolio {
  const Portfolio({
    required this.cash,
    required this.units,
    required this.startingBalance,
  });

  /// Opens a position at [entryPrice] using the standard deployed/cash split.
  factory Portfolio.opening({
    required double startingBalance,
    required double entryPrice,
  }) {
    final double deployed = startingBalance * initialDeployedFraction;
    return Portfolio(
      cash: startingBalance - deployed,
      units: deployed / entryPrice,
      startingBalance: startingBalance,
    );
  }

  static const double initialDeployedFraction = 0.75;

  final double cash;

  /// Fractional units of the asset held. Fractional is fine — this is virtual
  /// capital, not a broker.
  final double units;

  final double startingBalance;

  double valueAt(double price) => cash + units * price;

  double pnlAt(double price) => valueAt(price) - startingBalance;

  double pnlPercentAt(double price) => pnlAt(price) / startingBalance * 100;

  bool get isFlat => units == 0;

  /// Buys with [fractionOfCash] (0..1) of the remaining cash at [price].
  ///
  /// Advanced mode's free trading is built from this and [sellFraction]; the
  /// beginner mode's three buttons are the same two operations at fraction 1.
  Portfolio buyFraction(double fractionOfCash, double price) {
    final double f = fractionOfCash.clamp(0.0, 1.0);
    final double spend = cash * f;
    if (spend <= 0 || price <= 0) return this;
    return Portfolio(
      cash: cash - spend,
      units: units + spend / price,
      startingBalance: startingBalance,
    );
  }

  /// Sells [fractionOfUnits] (0..1) of the held position at [price].
  Portfolio sellFraction(double fractionOfUnits, double price) {
    final double f = fractionOfUnits.clamp(0.0, 1.0);
    final double sold = units * f;
    if (sold <= 0) return this;
    return Portfolio(
      cash: cash + sold * price,
      units: units - sold,
      startingBalance: startingBalance,
    );
  }

  /// Share of total value currently held in the asset rather than cash.
  /// Advanced mode's Discipline Score reads exposure changes, not trade counts.
  double exposureAt(double price) {
    final double total = valueAt(price);
    if (total <= 0) return 0;
    return units * price / total;
  }

  /// Applies a decision at [price]. Returns the resulting portfolio.
  ///
  /// - Hold: nothing changes. Doing nothing is a real move here, not a no-op.
  /// - Sell All: the whole position becomes cash at [price] and stays cash
  ///   unless a later Buy the Dip redeploys it.
  /// - Buy the Dip: all remaining cash buys units at [price]. With no cash
  ///   left it degrades to a Hold rather than failing — the player's choice is
  ///   still recorded and still scored.
  Portfolio apply(DecisionAction action, double price) {
    switch (action) {
      case DecisionAction.hold:
        return this;
      case DecisionAction.sell:
        return sellFraction(1, price);
      case DecisionAction.buyDip:
        return buyFraction(1, price);
    }
  }
}
