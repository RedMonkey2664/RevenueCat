import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/market/instrument.dart';
import '../../../core/market/market_data_service.dart';

/// Symbol picker.
///
/// Searches the bundled catalog instantly and the provider's own endpoint
/// after a pause, so typing stays responsive and the network is not hit on
/// every keystroke.
class InstrumentSearchSheet extends StatefulWidget {
  const InstrumentSearchSheet({
    required this.service,
    required this.alreadyAdded,
    super.key,
  });

  final MarketDataService service;

  /// Ids already on the watchlist, shown as added rather than offered twice.
  final Set<String> alreadyAdded;

  @override
  State<InstrumentSearchSheet> createState() => _InstrumentSearchSheetState();
}

class _InstrumentSearchSheetState extends State<InstrumentSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  MarketRegion? _region;
  List<Instrument> _results = const <Instrument>[];
  bool _searching = false;

  /// Bumped per search so a slow earlier request cannot overwrite the
  /// results of a later, faster one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _run(value));
  }

  Future<void> _run(String query) async {
    final int generation = ++_generation;
    setState(() => _searching = true);

    try {
      final List<Instrument> found =
          await widget.service.search(query, region: _region);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    } on Object catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                style: AppText.mono(size: 14),
                decoration: InputDecoration(
                  hintText: 'Search symbol or name',
                  hintStyle:
                      AppText.body(size: 14, color: AppColors.textFaint),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.chip,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.chip,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: <Widget>[
                  _filter(null, 'All'),
                  for (final MarketRegion r in MarketRegion.values)
                    _filter(r, r.label),
                ],
              ),
            ),
            if (_searching) const LinearProgressIndicator(minHeight: 1),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searching ? 'Searching…' : 'Nothing found.',
                        style: AppText.body(
                          size: 13,
                          color: AppColors.textFaint,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Instrument instrument = _results[i];
                        final bool added =
                            widget.alreadyAdded.contains(instrument.id);
                        return ListTile(
                          dense: true,
                          title: Text(
                            instrument.ticker,
                            style: AppText.mono(
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${instrument.name} · ${instrument.region.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              size: 11,
                              color: AppColors.textFaint,
                            ),
                          ),
                          trailing: Icon(
                            added ? Icons.check : Icons.add,
                            size: 18,
                            color: added
                                ? AppColors.up
                                : AppColors.textSecondary,
                          ),
                          onTap: added
                              ? null
                              : () => Navigator.of(context).pop(instrument),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(MarketRegion? region, String label) {
    final bool selected = _region == region;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: () {
          setState(() => _region = region);
          _run(_controller.text);
        },
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.14)
                : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
            borderRadius: AppRadius.chip,
          ),
          child: Text(
            label.toUpperCase(),
            style: AppText.label(
              size: 9,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
