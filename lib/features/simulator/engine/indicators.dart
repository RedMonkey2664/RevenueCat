/// The Simulator's indicators.
///
/// The implementations moved to `lib/core/indicators/indicators.dart` when the
/// pro chart became shared infrastructure — SMA and RSI are now drawn by the
/// Simulator, Live Markets and Custom Simulation alike, and ARCHITECTURE.md
/// keeps one feature folder from importing another.
///
/// This file stays as the engine's import point so existing engine code and
/// `test/engine/indicators_test.dart` are unchanged.
library;

export '../../../core/indicators/indicators.dart';
