import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [CreditCardRecord]. Stores masked-only references:
/// network, last4, expiry, issuing bank. Full card number, CVV, and PIN
/// fields must never be added here (ADR 0009).
class CreditCardForm extends ConsumerStatefulWidget {
  const CreditCardForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<CreditCardForm> createState() => _CreditCardFormState();
}

class _CreditCardFormState extends ConsumerState<CreditCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _last4 = TextEditingController();
  final _expiryMonth = TextEditingController();
  final _expiryYear = TextEditingController();
  final _issuingBank = TextEditingController();
  CardNetwork _network = CardNetwork.visa;
  String? _nicknameError;
  String? _loadError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    try {
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = await repos.creditCards.getByNickname(widget.nickname!);
      if (!mounted) return;
      if (result.isFailure) {
        _setLoadError(result.failure.message);
        return;
      }
      final record = result.value;
      if (record == null) {
        _setLoadError('Credit card not found');
        return;
      }
      setState(() {
        _nickname.text = record.nickname;
        _last4.text = record.last4;
        _expiryMonth.text = '${record.expiryMonth}';
        _expiryYear.text = '${record.expiryYear}';
        _issuingBank.text = record.issuingBank;
        _network = record.cardNetwork;
        _loaded = true;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) _setLoadError('Failed to load credit card');
    }
  }

  void _setLoadError(String message) {
    setState(() {
      _loaded = true;
      _loadError = message;
    });
  }

  @override
  void dispose() {
    _nickname.dispose();
    _last4.dispose();
    _expiryMonth.dispose();
    _expiryYear.dispose();
    _issuingBank.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final record = CreditCardRecord(
        id: null,
        nickname: _nickname.text.trim(),
        cardNetwork: _network,
        last4: _last4.text.trim(),
        expiryMonth: int.parse(_expiryMonth.text.trim()),
        expiryYear: int.parse(_expiryYear.text.trim()),
        issuingBank: _issuingBank.text.trim(),
        createdAt: DateTime.now(),
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = _isEdit
          ? await repos.creditCards.update(record)
          : await repos.creditCards.create(record);
      if (!mounted) return;
      if (result.isFailure) {
        final failure = result.failure;
        if (failure is ValidationFailure && failure.field == 'nickname') {
          setState(() => _nicknameError = failure.message);
        } else {
          _showSnack(failure.message);
        }
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isEdit && !_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEdit && _loadError != null) {
      return Center(child: Text(_loadError!));
    }
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nickname,
            enabled: !_isEdit,
            decoration: InputDecoration(
              labelText: 'Nickname *',
              errorText: _nicknameError,
            ),
            validator: _required,
          ),
          DropdownButtonFormField<CardNetwork>(
            initialValue: _network,
            decoration: const InputDecoration(labelText: 'Network *'),
            items: [
              for (final network in CardNetwork.values)
                DropdownMenuItem(value: network, child: Text(network.name)),
            ],
            onChanged: (value) =>
                setState(() => _network = value ?? CardNetwork.visa),
          ),
          TextFormField(
            controller: _last4,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Last 4 digits *'),
            validator: (value) =>
                value == null || !RegExp(r'^\d{4}$').hasMatch(value.trim())
                ? 'Exactly 4 digits'
                : null,
          ),
          TextFormField(
            controller: _expiryMonth,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expiry month *'),
            validator: (value) {
              final month = int.tryParse(value?.trim() ?? '');
              return month == null || month < 1 || month > 12
                  ? 'Month 1-12'
                  : null;
            },
          ),
          TextFormField(
            controller: _expiryYear,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expiry year *'),
            validator: (value) {
              final year = int.tryParse(value?.trim() ?? '');
              final now = DateTime.now().year;
              return year == null || year < now || year > now + 30
                  ? 'Year $now-${now + 30}'
                  : null;
            },
          ),
          TextFormField(
            controller: _issuingBank,
            decoration: const InputDecoration(labelText: 'Issuing bank *'),
            validator: _required,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
