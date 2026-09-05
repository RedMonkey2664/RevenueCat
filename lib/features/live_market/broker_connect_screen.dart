import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/market/broker_credentials.dart';
import '../../core/market/market_data_service.dart';

/// Connect a Kotak Neo account for real-time NSE/BSE prices.
///
/// Optional by design. The app works fully without it — Indian equity falls
/// back to the public delayed source — so this screen is an upgrade path, not
/// a login wall. That is why it is reachable from an icon in the Live Markets
/// app bar rather than shown on first launch.
///
/// The screen is honest about not being finished: [KotakNeoProvider] cannot
/// make its calls until the official endpoint spec is available, and saying
/// so here is better than a Connect button that fails with a network error.
class BrokerConnectScreen extends ConsumerStatefulWidget {
  const BrokerConnectScreen({super.key});

  @override
  ConsumerState<BrokerConnectScreen> createState() =>
      _BrokerConnectScreenState();
}

class _BrokerConnectScreenState extends ConsumerState<BrokerConnectScreen> {
  final TextEditingController _key = TextEditingController();
  final TextEditingController _secret = TextEditingController();
  final TextEditingController _mobile = TextEditingController();

  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final BrokerCredentials? existing =
        ref.read(brokerCredentialStoreProvider).readCredentials();
    if (existing != null) {
      _key.text = existing.consumerKey;
      _secret.text = existing.consumerSecret;
      _mobile.text = existing.mobileNumber ?? '';
      _saved = existing.isComplete;
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _secret.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final BrokerCredentials credentials = BrokerCredentials(
      consumerKey: _key.text.trim(),
      consumerSecret: _secret.text.trim(),
      mobileNumber: _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
    );

    await ref
        .read(brokerCredentialStoreProvider)
        .writeCredentials(credentials);
    ref.read(brokerConnectionRevisionProvider.notifier).bump();

    if (!mounted) return;
    setState(() => _saved = credentials.isComplete);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credentials saved on this device.')),
    );
  }

  Future<void> _disconnect() async {
    await ref.read(brokerCredentialStoreProvider).clearAll();
    ref.read(brokerConnectionRevisionProvider.notifier).bump();

    if (!mounted) return;
    _key.clear();
    _secret.clear();
    _mobile.clear();
    setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CONNECT A BROKER',
          style: AppText.label(color: AppColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          const _NotFinishedNotice(),
          const SizedBox(height: AppSpacing.lg),
          Text('KOTAK NEO', style: AppText.label()),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Real-time NSE and BSE prices from your own Kotak account. '
            'Without it, Indian prices come from a free delayed source — '
            'everything else in the app works either way.',
            style: AppText.body(size: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          _field(
            controller: _key,
            label: 'Consumer key',
            hint: 'From Kotak’s developer portal',
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            controller: _secret,
            label: 'Consumer secret',
            hint: 'Kept on this device only',
            obscure: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            controller: _mobile,
            label: 'Registered mobile (optional)',
            hint: 'Saves retyping it at sign-in',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.chip,
                    ),
                  ),
                  onPressed: _save,
                  child: const Text('Save credentials'),
                ),
              ),
              if (_saved) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(
                  onPressed: _disconnect,
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SecurityNote(),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: AppText.label(size: 9)),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: AppText.mono(size: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.body(size: 12, color: AppColors.textFaint),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.sm + 2,
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.chip,
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.chip,
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotFinishedNotice extends StatelessWidget {
  const _NotFinishedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.simulatedBadge.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.simulatedBadge.withValues(alpha: 0.45),
        ),
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.construction,
                size: 15,
                color: AppColors.simulatedBadge,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'NOT FINISHED YET',
                style: AppText.label(
                  size: 9,
                  color: AppColors.simulatedBadge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You can save your credentials here now, but the Kotak Neo sign-in '
            'and price calls are not implemented — they need Kotak’s official '
            'API specification, which we do not have yet. Until then every '
            'Indian price in the app comes from the free delayed source, and '
            'says so on screen.',
            style: AppText.body(size: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('WHERE THIS IS STORED', style: AppText.label(size: 9)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your key and secret are saved on this device only — never sent '
            'anywhere except to Kotak. Your account password is never stored '
            'at all; only a short-lived session token is kept, and it is '
            'discarded when it expires.\n\n'
            'This app cannot place orders, move money, or see your holdings. '
            'It reads prices.',
            style: AppText.body(size: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
