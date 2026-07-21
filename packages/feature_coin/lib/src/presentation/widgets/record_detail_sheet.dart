import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/clipboard_service.dart';
import '../../application/vault_providers.dart';
import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';
import '../../domain/vault_record_type.dart';
import 'masked_vault_field.dart';

/// Bottom sheet showing one vault record. Plain fields render from the
/// key-free [summary]; sensitive fields stay masked until the user reveals
/// them, which fetches and decrypts the full record once via
/// `VaultSession.withKey`.
class RecordDetailSheet extends ConsumerStatefulWidget {
  const RecordDetailSheet({
    super.key,
    required this.recordType,
    required this.recordKey,
    required this.summary,
  });

  final VaultRecordType recordType;

  /// Nickname for bank/card/document records; decimal row id for PAN cards.
  final String recordKey;

  /// Key-free projection used for plain (unencrypted) fields.
  final VaultEntrySummary summary;

  @override
  ConsumerState<RecordDetailSheet> createState() => _RecordDetailSheetState();
}

class _RecordDetailSheetState extends ConsumerState<RecordDetailSheet> {
  Object? _record;
  bool _loadingRecord = false;
  bool _deleting = false;
  final Set<String> _revealedFields = {};

  bool get _isVaultUnlocked => ref.read(vaultSessionProvider) is VaultUnlocked;

  void _clearSensitiveCache() {
    if (_record == null && _revealedFields.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _record = null;
      _revealedFields.clear();
    });
  }

  Future<bool> _ensureRecord() async {
    if (!_isVaultUnlocked) {
      _clearSensitiveCache();
      _showSnack('Vault is locked - unlock and try again');
      return false;
    }
    if (_record != null) return true;
    if (_loadingRecord) return false;
    setState(() => _loadingRecord = true);
    try {
      final result = await _fetchRecord();
      if (!mounted) return false;
      if (!_isVaultUnlocked) {
        _clearSensitiveCache();
        return false;
      }
      if (result == null) {
        _showSnack('Vault is locked - unlock and try again');
        return false;
      }
      if (result.isFailure) {
        _showSnack(result.failure.message);
        return false;
      }
      final record = result.value;
      if (record == null) {
        _showSnack('Record not found');
        return false;
      }
      _record = record;
      return true;
    } finally {
      if (mounted) setState(() => _loadingRecord = false);
    }
  }

  Future<Result<Object?>?> _fetchRecord() async {
    final repos = await ref.read(vaultRepositoriesProvider.future);
    final session = ref.read(vaultSessionProvider.notifier);
    switch (widget.recordType) {
      case VaultRecordType.bankAccount:
        return session.withKey<Result<Object?>>((key) async {
          final result = await repos.bankAccounts.getByNickname(
            widget.recordKey,
            key,
          );
          return _asObjectResult(result);
        });
      case VaultRecordType.panCard:
        final id = int.tryParse(widget.recordKey);
        if (id == null) {
          return const Failure<Object?>(
            ValidationFailure(message: 'Invalid PAN record key'),
          );
        }
        return session.withKey<Result<Object?>>((key) async {
          final result = await repos.panCards.getById(id, key);
          return _asObjectResult(result);
        });
      case VaultRecordType.creditCard:
        return _asObjectResult(
          await repos.creditCards.getByNickname(widget.recordKey),
        );
      case VaultRecordType.secureDocument:
        return session.withKey<Result<Object?>>((key) async {
          final result = await repos.secureDocuments.getByNickname(
            widget.recordKey,
            key,
          );
          return _asObjectResult(result);
        });
    }
  }

  Result<Object?> _asObjectResult<T>(Result<T?> result) {
    if (result.isFailure) return Failure<Object?>(result.failure);
    return Success<Object?>(result.value);
  }

  Future<void> _toggleReveal(String field) async {
    if (_revealedFields.contains(field)) {
      setState(() => _revealedFields.remove(field));
      return;
    }
    if (await _ensureRecord() && mounted && _isVaultUnlocked) {
      setState(() => _revealedFields.add(field));
    }
  }

  Future<void> _copySensitive(String? Function(Object record) extract) async {
    if (!await _ensureRecord()) return;
    if (!_isVaultUnlocked) {
      _clearSensitiveCache();
      _showSnack('Vault is locked - unlock and try again');
      return;
    }
    final record = _record;
    if (record == null) return;
    final value = extract(record) ?? '';
    await ref.read(clipboardServiceProvider).copyWithAutoClear(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied - clipboard clears in 30 seconds'),
        ),
      );
    }
  }

  Future<void> _copyPlain(String value) async {
    await ref.read(clipboardServiceProvider).copyWithAutoClear(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied - clipboard clears in 30 seconds'),
        ),
      );
    }
  }

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _deleting = false);
      return;
    }

    try {
      final authenticated = await ref
          .read(localAuthenticationProvider)
          .authenticate(
            localizedReason: 'Confirm deletion of this vault record',
          );
      if (!mounted) return;
      if (!authenticated) {
        _showSnack('Could not confirm deletion');
        return;
      }

      final repos = await ref.read(vaultRepositoriesProvider.future);
      final panRecordId = widget.recordType == VaultRecordType.panCard
          ? int.tryParse(widget.recordKey)
          : null;
      if (widget.recordType == VaultRecordType.panCard && panRecordId == null) {
        _showSnack('Invalid PAN record key');
        return;
      }
      final result = switch (widget.recordType) {
        VaultRecordType.bankAccount =>
          await repos.bankAccounts.deleteByNickname(widget.recordKey),
        VaultRecordType.panCard => await repos.panCards.deleteById(
          panRecordId!,
        ),
        VaultRecordType.creditCard => await repos.creditCards.deleteByNickname(
          widget.recordKey,
        ),
        VaultRecordType.secureDocument =>
          await repos.secureDocuments.deleteByNickname(widget.recordKey),
      };
      if (!mounted) return;
      if (result.isFailure) {
        _showSnack(result.failure.message);
        return;
      }
      ref.invalidate(vaultSummariesProvider);
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } on PlatformException {
      if (mounted) _showSnack('Could not confirm deletion');
    } catch (_) {
      if (mounted) _showSnack('Could not delete record');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _edit() {
    final encodedKey = Uri.encodeComponent(widget.recordKey);
    context.push('/money/vault/edit/${widget.recordType.name}/$encodedKey');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _title => switch (widget.summary) {
    BankAccountSummary(:final nickname) => nickname,
    PanCardSummary(:final nameOnCard) => nameOnCard,
    CreditCardSummary(:final nickname) => nickname,
    SecureDocumentSummary(:final nickname) => nickname,
  };

  String get _typeLabel => switch (widget.recordType) {
    VaultRecordType.bankAccount => 'Bank account',
    VaultRecordType.panCard => 'PAN card',
    VaultRecordType.creditCard => 'Card (masked)',
    VaultRecordType.secureDocument => 'Secure document',
  };

  @override
  Widget build(BuildContext context) {
    ref.listen<VaultSessionState>(vaultSessionProvider, (_, next) {
      if (next is! VaultUnlocked) {
        _clearSensitiveCache();
      }
    });

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(_title),
            subtitle: Text(_typeLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit record',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _deleting ? null : _edit,
                ),
                IconButton(
                  tooltip: 'Delete record',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _loadingRecord || _deleting
                      ? null
                      : () => unawaited(_delete()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(child: ListView(shrinkWrap: true, children: _rows)),
        ],
      ),
    );
  }

  List<Widget> get _rows => switch (widget.recordType) {
    VaultRecordType.bankAccount => _bankRows(
      widget.summary as BankAccountSummary,
    ),
    VaultRecordType.panCard => _panRows(widget.summary as PanCardSummary),
    VaultRecordType.creditCard => _cardRows(
      widget.summary as CreditCardSummary,
    ),
    VaultRecordType.secureDocument => _docRows(
      widget.summary as SecureDocumentSummary,
    ),
  };

  List<Widget> _bankRows(BankAccountSummary s) {
    final record = _record is BankAccountRecord
        ? _record as BankAccountRecord
        : null;
    return [
      MaskedVaultField(
        label: 'Bank',
        value: s.bankName,
        onCopy: () => _copyPlain(s.bankName),
      ),
      MaskedVaultField(label: 'Account holder', value: s.accountHolderName),
      MaskedVaultField(
        label: 'IFSC',
        value: s.ifscCode,
        onCopy: () => _copyPlain(s.ifscCode),
      ),
      MaskedVaultField(label: 'Account type', value: s.accountType),
      MaskedVaultField(
        label: 'Account number',
        value: '•••• •••• ••••',
        isRevealed: _revealedFields.contains('accountNumber'),
        revealedValue: record?.accountNumber,
        onReveal: () => _toggleReveal('accountNumber'),
        onCopy: () => _copySensitive(
          (record) => (record as BankAccountRecord).accountNumber,
        ),
      ),
      MaskedVaultField(
        label: 'Notes',
        value: '••••',
        isRevealed: _revealedFields.contains('notes'),
        revealedValue: record?.notes ?? '-',
        onReveal: () => _toggleReveal('notes'),
      ),
    ];
  }

  List<Widget> _panRows(PanCardSummary s) {
    final record = _record is PanCardRecord ? _record as PanCardRecord : null;
    return [
      MaskedVaultField(label: 'Name on card', value: s.nameOnCard),
      if (s.fathersName != null)
        MaskedVaultField(label: "Father's name", value: s.fathersName!),
      MaskedVaultField(
        label: 'PAN',
        value: '••••••••••',
        isRevealed: _revealedFields.contains('panNumber'),
        revealedValue: record?.panNumber,
        onReveal: () => _toggleReveal('panNumber'),
        onCopy: () =>
            _copySensitive((record) => (record as PanCardRecord).panNumber),
      ),
    ];
  }

  List<Widget> _cardRows(CreditCardSummary s) {
    return [
      MaskedVaultField(label: 'Network', value: s.cardNetwork.name),
      MaskedVaultField(
        label: 'Card number',
        value: '•••• •••• •••• ${s.last4}',
        onCopy: () => _copyPlain(s.last4),
      ),
      MaskedVaultField(
        label: 'Expiry',
        value: '${s.expiryMonth.toString().padLeft(2, '0')}/${s.expiryYear}',
      ),
      MaskedVaultField(label: 'Issuing bank', value: s.issuingBank),
    ];
  }

  List<Widget> _docRows(SecureDocumentSummary s) {
    final record = _record is SecureDocumentRecord
        ? _record as SecureDocumentRecord
        : null;
    return [
      MaskedVaultField(label: 'Category', value: s.category.name),
      if (s.linkedAccountNickname != null)
        MaskedVaultField(
          label: 'Linked account',
          value: s.linkedAccountNickname!,
        ),
      MaskedVaultField(
        label: 'Custom fields',
        value: '••••',
        isRevealed: _revealedFields.contains('customFields'),
        revealedValue: record == null || record.customFields.isEmpty
            ? '-'
            : record.customFields.entries
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n'),
        onReveal: () => _toggleReveal('customFields'),
      ),
      MaskedVaultField(
        label: 'Notes',
        value: '••••',
        isRevealed: _revealedFields.contains('notes'),
        revealedValue: record?.notes ?? '-',
        onReveal: () => _toggleReveal('notes'),
      ),
    ];
  }
}
