import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// User-facing labels for the ITR-driven document taxonomy.
const Map<DocumentCategory, String> documentCategoryLabels = {
  DocumentCategory.personalId: 'Personal ID (Aadhaar etc.)',
  DocumentCategory.incomeProof: 'Income proof (Form 16/16A)',
  DocumentCategory.taxCredit: 'Tax credit (26AS/AIS/TIS)',
  DocumentCategory.investmentProof: 'Investment proof (80C/80D)',
  DocumentCategory.hra: 'HRA / rent receipts',
  DocumentCategory.capitalGains: 'Capital gains',
  DocumentCategory.homeLoan: 'Home loan',
  DocumentCategory.other: 'Other',
};

/// Add/edit form for [SecureDocumentRecord]: category, optional linked bank
/// account, key-value custom fields, notes. Attachments are out of v1 scope.
class SecureDocumentForm extends ConsumerStatefulWidget {
  const SecureDocumentForm({super.key, this.nickname});

  final String? nickname;

  @override
  ConsumerState<SecureDocumentForm> createState() => _SecureDocumentFormState();
}

class _SecureDocumentFormState extends ConsumerState<SecureDocumentForm> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _notes = TextEditingController();
  final List<({TextEditingController key, TextEditingController value})>
  _customFields = [];
  DocumentCategory _category = DocumentCategory.incomeProof;
  String _linkedAccount = '';
  List<String> _accountNicknames = [];
  String? _nicknameError;
  String? _loadError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.nickname != null;
  bool get _isVaultUnlocked => ref.read(vaultSessionProvider) is VaultUnlocked;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    if (_isEdit) {
      _prefill();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadAccounts() async {
    final repos = await ref.read(vaultRepositoriesProvider.future);
    final result = await repos.bankAccounts.listAllSummaries();
    if (result.isSuccess && mounted) {
      setState(() {
        _accountNicknames = result.value.map((s) => s.nickname).toList();
      });
    }
  }

  Future<void> _prefill() async {
    try {
      final result = await ref.read(vaultSessionProvider.notifier).withKey((
        key,
      ) async {
        final repos = await ref.read(vaultRepositoriesProvider.future);
        return repos.secureDocuments.getByNickname(widget.nickname!, key);
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
        _setLoadError('Secure document not found');
        return;
      }
      setState(() {
        _nickname.text = record.nickname;
        _category = record.category;
        _linkedAccount = record.linkedAccountNickname ?? '';
        _notes.text = record.notes ?? '';
        for (final entry in record.customFields.entries) {
          _customFields.add((
            key: TextEditingController(text: entry.key),
            value: TextEditingController(text: entry.value),
          ));
        }
        _loaded = true;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) _setLoadError('Failed to load secure document');
    }
  }

  void _setLoadError(String message) {
    setState(() {
      _loaded = true;
      _loadError = message;
    });
  }

  void _clearSensitiveFields() {
    _notes.clear();
    for (final field in _customFields) {
      field.key.clear();
      field.value.clear();
    }
  }

  void _disposeCustomFields() {
    for (final field in _customFields) {
      field.key.dispose();
      field.value.dispose();
    }
    _customFields.clear();
  }

  @override
  void dispose() {
    _clearSensitiveFields();
    _disposeCustomFields();
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  void _addCustomField() {
    setState(() {
      _customFields.add((
        key: TextEditingController(),
        value: TextEditingController(),
      ));
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      final field = _customFields.removeAt(index);
      field.key.dispose();
      field.value.dispose();
    });
  }

  Map<String, String> _customFieldsMap() {
    final map = <String, String>{};
    for (final field in _customFields) {
      final key = field.key.text.trim();
      if (key.isNotEmpty) map[key] = field.value.text.trim();
    }
    return map;
  }

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
      final record = SecureDocumentRecord(
        id: null,
        nickname: _nickname.text.trim(),
        category: _category,
        createdAt: DateTime.now(),
        linkedAccountNickname: _linkedAccount.isEmpty ? null : _linkedAccount,
        customFields: _customFieldsMap(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = await ref.read(vaultSessionProvider.notifier).withKey((
        key,
      ) async {
        if (_isEdit) return repos.secureDocuments.update(record, key);
        final created = await repos.secureDocuments.create(record, key);
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

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEdit && _loadError != null) {
      return Center(child: Text(_loadError!));
    }

    final accountItems = [
      if (_linkedAccount.isNotEmpty &&
          !_accountNicknames.contains(_linkedAccount))
        _linkedAccount,
      ..._accountNicknames,
    ];

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
          DropdownButtonFormField<DocumentCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: [
              for (final category in DocumentCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(documentCategoryLabels[category]!),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _category = value ?? DocumentCategory.incomeProof;
              });
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _linkedAccount,
            decoration: const InputDecoration(labelText: 'Linked bank account'),
            items: [
              const DropdownMenuItem(value: '', child: Text('None')),
              for (final nickname in accountItems)
                DropdownMenuItem(value: nickname, child: Text(nickname)),
            ],
            onChanged: (value) {
              setState(() => _linkedAccount = value ?? '');
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custom fields',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add field'),
                onPressed: _addCustomField,
              ),
            ],
          ),
          for (var i = 0; i < _customFields.length; i++)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customFields[i].key,
                    decoration: const InputDecoration(labelText: 'Field name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _customFields[i].value,
                    decoration: const InputDecoration(labelText: 'Value'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeCustomField(i),
                ),
              ],
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
