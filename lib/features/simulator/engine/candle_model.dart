/// The Simulator's bar model.
///
/// The implementation moved to `lib/core/market/candle.dart` when live market
/// data arrived: the market-data layer, the shared chart and this engine all
/// need one definition of a bar, and `core/` is the only place all three may
/// import from (ARCHITECTURE.md).
///
/// This file stays as the engine's import point so existing engine code and
/// the tests under `test/engine/` are unchanged.
library;

export '../../../core/market/candle.dart';
