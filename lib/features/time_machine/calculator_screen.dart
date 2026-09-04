import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme.dart';
import '../../core/services/crypto_api_service.dart';
import 'services/historical_price_lookup.dart';
import 'widgets/result_graphic.dart';

/// Time Machine — the growth loop.
///
/// No login, no gameplay state, no dependency on the Simulator: someone
/// arriving from a shared story gets value in seconds (TIME_MACHINE.md).
class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final TextEditingController _amount =
      TextEditingController(text: '80000');
  final TextEditingController _label =
      TextEditingController(text: 'a Royal Enfield');
  final GlobalKey _cardKey = GlobalKey();

  DateTime _date = DateTime(2018);
  TimeMachineResult? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  DateTime get _earliest => CryptoApiService.earliestDate;

  Future<void> _calculate() async {
    final double? amount = double.tryParse(_amount.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final TimeMachineResult result =
          await ref.read(historicalPriceLookupProvider).calculate(
                amountInr: amount,
                label: _label.text.trim().isEmpty
                    ? 'that purchase'
                    : _label.text.trim(),
                date: _date,
              );
      if (!mounted) return;
      setState(() {
        _result = result;
        _busy = false;
      });
    } on PriceLookupException catch (e) {
      if (!mounted) return;
      // No fallback number, ever. An unavailable price shows as unavailable.
      setState(() {
        _error = e.message;
        _result = null;
        _busy = false;
      });
    }
  }

  Future<void> _share() async {
    final RenderRepaintBoundary? boundary = _cardKey.currentContext
        ?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    try {
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData? bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      final Directory dir = await getTemporaryDirectory();
      final File file = File('${dir.path}/market_nerve_time_machine.png');
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          text: 'What did waiting cost you? — Market Nerve',
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceRaised,
          content: Text(
            'Could not create the image: $error',
            style: AppText.body(size: 12),
          ),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // Bounded to what the sources actually cover (TIME_MACHINE.md).
      firstDate: _earliest,
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final TimeMachineResult? result = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TIME MACHINE',
          style: AppText.label(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Text(
            'What did waiting cost you?',
            style: AppText.title(size: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Look up what an amount would have become if it had gone into '
            'Bitcoin on a past date. Real prices, looked at backwards.',
            style: AppText.body(size: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'AMOUNT (₹)',
            child: TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              style: AppText.mono(size: 18, weight: FontWeight.w700),
              decoration: _inputDecoration('80000'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'WHAT YOU BOUGHT INSTEAD',
            child: TextField(
              controller: _label,
              style: AppText.body(size: 15),
              decoration: _inputDecoration('a Royal Enfield'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Field(
            label: 'DATE',
            child: InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: AppRadius.chip,
                ),
                child: Row(
                  children: <Widget>[
                    Text(
                      _dateLabel(_date),
                      style: AppText.mono(size: 16, weight: FontWeight.w700),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const _AssetSelector(),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _busy ? null : _calculate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              disabledBackgroundColor: AppColors.border,
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.chip,
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              minimumSize: const Size.fromHeight(kMinTouchTarget + 8),
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.background,
                    ),
                  )
                : Text(
                    'CALCULATE',
                    style: AppText.mono(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.background,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _ErrorPanel(message: _error!),
          ],
          if (result != null) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            // The exported image is captured from this exact widget, so what
            // is shared is what was seen.
            // Rounded on screen, square in the export: Instagram crops a
            // rounded card badly, so only the preview is clipped.
            ClipRRect(
              borderRadius: AppRadius.card,
              child: RepaintBoundary(
                key: _cardKey,
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ResultGraphic(result: result),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _share,
              icon: const Icon(Icons.ios_share, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.chip,
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size.fromHeight(kMinTouchTarget + 8),
              ),
              label: Text(
                'SHARE',
                style: AppText.mono(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Disclosure(result: result),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(size: 15, color: AppColors.textFaint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.chip,
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.chip,
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.chip,
          borderSide: BorderSide(color: AppColors.accent, width: 1.6),
        ),
      );

  static String _dateLabel(DateTime d) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppText.label()),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}

/// The one reasonable dummy element in this tab (DESIGN.md): BTC is real,
/// everything else is honestly marked as not built.
class _AssetSelector extends StatelessWidget {
  const _AssetSelector();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.accent),
            borderRadius: AppRadius.chip,
          ),
          child: Text(
            'BITCOIN',
            style: AppText.mono(
              size: 11,
              weight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadius.chip,
          ),
          child: Text('MORE ASSETS SOON', style: AppText.label()),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: cardDecoration(
        borderColor: AppColors.down.withValues(alpha: 0.5),
      ),
      child: Text(
        message,
        style: AppText.body(size: 13, color: AppColors.down),
      ),
    );
  }
}

/// "How we calculated this" (TIME_MACHINE.md).
///
/// A persuasive, emotional tool has to stay honest about being illustrative —
/// so it shows its sources and its own arithmetic.
class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.result});

  final TimeMachineResult result;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.md),
        title: Text('How we calculated this', style: AppText.label()),
        children: <Widget>[
          _line(
            'Bitcoin closed at \$${result.btcThenUsd.toStringAsFixed(2)} on '
            'your chosen date, and is \$${result.btcNowUsd.toStringAsFixed(2)} '
            'now (Binance, BTC/USDT daily close).',
          ),
          _line(
            'Converted at ₹${result.fxThen.usdToInr.toStringAsFixed(2)}/\$ '
            'then and ₹${result.fxNow.usdToInr.toStringAsFixed(2)}/\$ now '
            '(European Central Bank reference rates). Rates publish on '
            'business days, so a weekend date uses the previous working day.',
          ),
          _line(
            'Your amount is multiplied by the ratio of those two rupee '
            'prices — ${result.multiple.toStringAsFixed(2)}x. This is what '
            'the price actually did between the two dates. It is not a '
            'compound-interest formula and assumes no annual rate.',
          ),
          _line(
            'USDT is treated as a dollar proxy. No fees, taxes or spreads '
            'are modelled.',
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.simulatedBadge.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.simulatedBadge.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Illustrative and retrospective only. This is what happened, '
              'not what will happen. Nothing here is investment advice, and '
              'no future return is implied or guaranteed.',
              style: AppText.body(
                size: 12,
                color: AppColors.simulatedBadge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          '· $text',
          style: AppText.body(size: 12, color: AppColors.textSecondary),
        ),
      );
}
