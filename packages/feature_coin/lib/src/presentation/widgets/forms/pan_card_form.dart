import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../../application/vault_providers.dart';
import '../../../application/vault_session.dart';
import '../../../application/vault_summaries_provider.dart';

/// Add/edit form for [PanCardRecord]. Edit mode is keyed by row id.
class PanCardForm extends ConsumerStatefulWidget {
  const PanCardForm({super.key, this.recordId});

  final int? recordId;

  @override
  ConsumerState<PanCardForm> createState() => _PanCardFormState();
}

class _PanCardFormState extends ConsumerState<PanCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameOnCard = TextEditingController();
  final _panNumber = TextEditingController();
  final _fathersName = TextEditingController();
  PanCardRecord? _loadedRecord;
  DateTime? _dob;
  String? _loadError;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.recordId != null;
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
        return repos.panCards.getById(widget.recordId!, key);
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
        _setLoadError('PAN card not found');
        return;
      }
      setState(() {
        _loadedRecord = record;
        _loadError = null;
        _nameOnCard.text = record.nameOnCard;
        _panNumber.text = record.panNumber;
        _fathersName.text = record.fathersName ?? '';
        _dob = record.dateOfBirth;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) _setLoadError('Failed to load PAN card');
    }
  }

  void _setLoadError(String message) {
    setState(() {
      _loaded = true;
      _loadError = message;
    });
  }

  void _clearSensitiveFields() {
    _panNumber.clear();
    _loadedRecord = null;
  }

  @override
  void dispose() {
    _clearSensitiveFields();
    _nameOnCard.dispose();
    _panNumber.dispose();
    _fathersName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isVaultUnlocked) {
      _clearSensitiveFields();
      _showSnack('Vault is locked - unlock and try again');
      return;
    }
    setState(() => _saving = true);
    try {
      final record = PanCardRecord(
        id: widget.recordId,
        panNumber: _panNumber.text.trim().toUpperCase(),
        nameOnCard: _nameOnCard.text.trim(),
        fathersName: _fathersName.text.trim().isEmpty
            ? null
            : _fathersName.text.trim(),
        dateOfBirth: _dob,
        cardImageBlob: _loadedRecord?.cardImageBlob,
        createdAt: _loadedRecord?.createdAt,
      );
      final repos = await ref.read(vaultRepositoriesProvider.future);
      final result = await ref.read(vaultSessionProvider.notifier).withKey((
        key,
      ) async {
        if (_isEdit) return repos.panCards.update(record, key);
        final created = await repos.panCards.create(record, key);
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
        _showSnack(result.failure.message);
      } else {
        ref.invalidate(vaultSummariesProvider);
        Navigator.of(context).maybePop();
      }
    } on ArgumentError {
      _showSnack('Invalid PAN number');
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
            controller: _nameOnCard,
            decoration: const InputDecoration(labelText: 'Name on card *'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: _panNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'PAN *'),
            validator: (value) =>
                value == null || !isValidPan(value.trim().toUpperCase())
                ? 'Invalid PAN (e.g. ABCDE1234F)'
                : null,
          ),
          TextFormField(
            controller: _fathersName,
            decoration: const InputDecoration(labelText: "Father's name"),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _dob == null
                  ? 'Date of birth (optional)'
                  : 'DOB: ${_dob!.toLocal().toIso8601String().split('T').first}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _dob = picked);
            },
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
