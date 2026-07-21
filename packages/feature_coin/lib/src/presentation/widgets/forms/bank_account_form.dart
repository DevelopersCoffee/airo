import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [BankAccountRecord]. Edit mode is keyed by nickname,
/// which is the immutable cross-record handle.
class BankAccountForm extends ConsumerStatefulWidget {
  const BankAccountForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends ConsumerState<BankAccountForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _bankName = TextEditingController();
  final _holder = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _branch = TextEditingController();
  final _notes = TextEditingController();
  BankAccountRecord? _loadedRecord;
  String _accountType = 'savings';
  String? _nicknameError;
  String? _loadError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;
  bool get _isVaultUnlocked => ref.read(vaultSessionProvider) is VaultUnlocked;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefill();
  }

  Future<void> _prefill() async {
    try {
      final result = await ref.read(vaultSessionProvider.notifier).withKey((
        key,
      ) async {
        final repos = await ref.read(vaultRepositoriesProvider.future);
        return repos.bankAccounts.getByNickname(widget.nickname!, key);
      });
      if (!mounted) return;
      if (!_isVaultUnlocked) {
        _clearSensitiveFields();
        _setLoadError('Vault is locked - unlock and try again');
        return;
      }
      if (result == null) {
        _setLoadError('Vault is locked - unlock and try again');
        return;
      }
      if (result.isFailure) {
        _setLoadError(result.failure.message);
        return;
      }
      final record = result.value;
      if (record == null) {
        _setLoadError('Bank account not found');
        return;
      }
      setState(() {
        _loadedRecord = record;
        _loadError = null;
        _nickname.text = record.nickname;
        _bankName.text = record.bankName;
        _holder.text = record.accountHolderName;
        _accountNumber.text = record.accountNumber;
        _ifsc.text = record.ifscCode;
        _accountType = record.accountType;
        _branch.text = record.branchName ?? '';
        _notes.text = record.notes ?? '';
        _loaded = true;
      });
    } catch (_) {
      if (mounted) _setLoadError('Failed to load bank account');
    }
  }

  void _setLoadError(String message) {
    setState(() {
      _loaded = true;
      _loadError = message;
    });
  }

  void _clearSensitiveFields() {
    _accountNumber.clear();
    _notes.clear();
    _loadedRecord = null;
  }

  @override
  void dispose() {
    _clearSensitiveFields();
    _nickname.dispose();
    _bankName.dispose();
    _holder.dispose();
    _accountNumber.dispose();
    _ifsc.dispose();
    _branch.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Required' : null;

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_isVaultUnlocked) {
      _clearSensitiveFields();
      _showSnack('Vault is locked - unlock and try again');
      return;
    }
    setState(() => _saving = true);
    try {
      final record = BankAccountRecord(
        id: _loadedRecord?.id,
        nickname: _nickname.text.trim(),
        bankName: _bankName.text.trim(),
        accountHolderName: _holder.text.trim(),
        accountNumber: _accountNumber.text.trim(),
        ifscCode: _ifsc.text.trim().toUpperCase(),
        accountType: _accountType,
        branchName: _branch.text.trim().isEmpty ? null : _branch.text.trim(),
        micrCode: _loadedRecord?.micrCode,
        swiftIban: _loadedRecord?.swiftIban,
        customerId: _loadedRecord?.customerId,
        upiIds: _loadedRecord?.upiIds,
        linkedMobile: _loadedRecord?.linkedMobile,
        linkedEmail: _loadedRecord?.linkedEmail,
        nomineeName: _loadedRecord?.nomineeName,
        debitCardLast4: _loadedRecord?.debitCardLast4,
        debitCardExpiry: _loadedRecord?.debitCardExpiry,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        createdAt: _loadedRecord?.createdAt,
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = await ref.read(vaultSessionProvider.notifier).withKey((
        key,
      ) async {
        if (_isEdit) return repos.bankAccounts.update(record, key);
        final created = await repos.bankAccounts.create(record, key);
        return created.isSuccess
            ? const Success<void>(null)
            : Failure<void>(created.failure);
      });
      if (!mounted) return;
      if (!_isVaultUnlocked) {
        _clearSensitiveFields();
        _showSnack('Vault is locked - unlock and try again');
      } else if (result == null) {
        _showSnack('Vault is locked - unlock and try again');
      } else if (result.isFailure) {
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
    } on ArgumentError {
      _showSnack('Invalid IFSC code');
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
    ref.listen<VaultSessionState>(vaultSessionProvider, (_, next) {
      if (next is! VaultUnlocked) {
        _clearSensitiveFields();
        if (_isEdit && _loadError == null) {
          _setLoadError('Vault is locked - unlock and try again');
        }
      }
    });

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
          TextFormField(
            controller: _bankName,
            decoration: const InputDecoration(labelText: 'Bank name *'),
            validator: _required,
          ),
          TextFormField(
            controller: _holder,
            decoration: const InputDecoration(
              labelText: 'Account holder name *',
            ),
            validator: _required,
          ),
          TextFormField(
            controller: _accountNumber,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Account number *'),
            validator: _required,
          ),
          TextFormField(
            controller: _ifsc,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'IFSC *'),
            validator: (value) =>
                value == null || !isValidIfsc(value.trim().toUpperCase())
                ? 'Invalid IFSC (e.g. HDFC0001234)'
                : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _accountType,
            decoration: const InputDecoration(labelText: 'Account type *'),
            items: const [
              DropdownMenuItem(value: 'savings', child: Text('Savings')),
              DropdownMenuItem(value: 'current', child: Text('Current')),
            ],
            onChanged: (value) =>
                setState(() => _accountType = value ?? 'savings'),
          ),
          TextFormField(
            controller: _branch,
            decoration: const InputDecoration(labelText: 'Branch'),
          ),
          TextFormField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
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
