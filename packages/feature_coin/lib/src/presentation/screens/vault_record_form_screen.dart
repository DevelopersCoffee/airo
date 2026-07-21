import 'package:core_domain/core_domain.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

import '../../application/vault_providers.dart';
import '../../application/vault_record_ref.dart';
import '../../application/vault_session.dart';
import '../../application/vault_summaries_provider.dart';

class VaultRecordFormScreen extends ConsumerStatefulWidget {
  const VaultRecordFormScreen({
    super.key,
    required this.type,
    this.editRef,
    this.onSaved,
  });

  final VaultRecordType type;
  final VaultRecordRef? editRef;
  final VoidCallback? onSaved;

  @override
  ConsumerState<VaultRecordFormScreen> createState() =>
      _VaultRecordFormScreenState();
}

class _VaultRecordFormScreenState extends ConsumerState<VaultRecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  var _saving = false;
  String? _formError;
  String? _nicknameError;
  DocumentCategory _documentCategory = DocumentCategory.other;
  CardNetwork _cardNetwork = CardNetwork.visa;

  bool get _isEditing => widget.editRef != null;

  @override
  void initState() {
    super.initState();
    for (final key in _fieldKeys) {
      _controllers[key] = TextEditingController();
    }
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadForEdit());
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _fieldKeys => const [
    'nickname',
    'bankName',
    'accountHolderName',
    'accountNumber',
    'ifscCode',
    'accountType',
    'branchName',
    'notes',
    'panNumber',
    'nameOnCard',
    'fathersName',
    'dateOfBirth',
    'last4',
    'expiryMonth',
    'expiryYear',
    'issuingBank',
    'linkedAccountNickname',
    'customFields',
  ];

  TextEditingController _c(String key) => _controllers[key]!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.paddingMd,
          children: [
            if (_formError != null) ...[
              InlineError(message: _formError!),
              const SizedBox(height: AppSpacing.md),
            ],
            ..._fieldsForType(),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const ValueKey('vault_save_record_button'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving' : 'Save record'),
            ),
          ],
        ),
      ),
    );
  }

  String get _title {
    final action = _isEditing ? 'Edit' : 'Add';
    return switch (widget.type) {
      VaultRecordType.bankAccount => '$action bank account',
      VaultRecordType.panCard => '$action PAN card',
      VaultRecordType.creditCard => '$action masked card',
      VaultRecordType.secureDocument => '$action secure document',
    };
  }

  List<Widget> _fieldsForType() {
    return switch (widget.type) {
      VaultRecordType.bankAccount => [
        _text('nickname', 'Nickname', required: true, enabled: !_isEditing),
        _text('bankName', 'Bank name', required: true),
        _text('accountHolderName', 'Account holder name', required: true),
        _text('accountNumber', 'Account number', required: true),
        _text('ifscCode', 'IFSC code', required: true),
        _text('accountType', 'Account type', required: true),
        _text('branchName', 'Branch name'),
        _text('notes', 'Notes', maxLines: 3),
      ],
      VaultRecordType.panCard => [
        _text('panNumber', 'PAN number', required: true),
        _text('nameOnCard', 'Name on card', required: true),
        _text('fathersName', 'Father name'),
        _text('dateOfBirth', 'Date of birth (YYYY-MM-DD)'),
      ],
      VaultRecordType.creditCard => [
        _text('nickname', 'Nickname', required: true, enabled: !_isEditing),
        DropdownButtonFormField<CardNetwork>(
          initialValue: _cardNetwork,
          decoration: const InputDecoration(labelText: 'Network'),
          items: [
            for (final network in CardNetwork.values)
              DropdownMenuItem(
                value: network,
                child: Text(network.name.toUpperCase()),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _cardNetwork = value);
          },
        ),
        _text('last4', 'Last 4 digits', required: true),
        _text('expiryMonth', 'Expiry month', required: true),
        _text('expiryYear', 'Expiry year', required: true),
        _text('issuingBank', 'Issuing bank', required: true),
      ],
      VaultRecordType.secureDocument => [
        _text('nickname', 'Nickname', required: true, enabled: !_isEditing),
        DropdownButtonFormField<DocumentCategory>(
          initialValue: _documentCategory,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final category in DocumentCategory.values)
              DropdownMenuItem(value: category, child: Text(category.name)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _documentCategory = value);
          },
        ),
        _text('linkedAccountNickname', 'Linked account nickname'),
        _text(
          'customFields',
          'Custom fields (one key=value per line)',
          maxLines: 4,
        ),
        _text('notes', 'Notes', maxLines: 3),
      ],
    };
  }

  Widget _text(
    String key,
    String label, {
    bool required = false,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        key: ValueKey('vault_${key}_field'),
        controller: _c(key),
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          errorText: key == 'nickname' ? _nicknameError : null,
        ),
        validator: required
            ? (value) => _trim(value).isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  Future<void> _loadForEdit() async {
    final editRef = widget.editRef;
    if (editRef == null) return;
    final repositories = await ref.read(vaultRepositoriesProvider.future);
    final result = await ref.read(vaultSessionProvider.notifier).withKey((
      keyBytes,
    ) async {
      return switch (editRef.type) {
        VaultRecordType.bankAccount => repositories.bankAccounts.getByNickname(
          editRef.nickname!,
          keyBytes,
        ),
        VaultRecordType.panCard => repositories.panCards.getById(
          editRef.id!,
          keyBytes,
        ),
        VaultRecordType.secureDocument =>
          repositories.secureDocuments.getByNickname(
            editRef.nickname!,
            keyBytes,
          ),
        VaultRecordType.creditCard => repositories.creditCards.getByNickname(
          editRef.nickname!,
        ),
      };
    });
    if (!mounted || result == null || result.isFailure) return;
    final record = result.valueOrNull;
    if (record == null) return;
    setState(() => _fillFromRecord(record));
  }

  void _fillFromRecord(Object record) {
    switch (record) {
      case BankAccountRecord():
        _c('nickname').text = record.nickname;
        _c('bankName').text = record.bankName;
        _c('accountHolderName').text = record.accountHolderName;
        _c('accountNumber').text = record.accountNumber;
        _c('ifscCode').text = record.ifscCode;
        _c('accountType').text = record.accountType;
        _c('branchName').text = record.branchName ?? '';
        _c('notes').text = record.notes ?? '';
      case PanCardRecord():
        _c('panNumber').text = record.panNumber;
        _c('nameOnCard').text = record.nameOnCard;
        _c('fathersName').text = record.fathersName ?? '';
        _c('dateOfBirth').text = _formatDate(record.dateOfBirth);
      case CreditCardRecord():
        _c('nickname').text = record.nickname;
        _cardNetwork = record.cardNetwork;
        _c('last4').text = record.last4;
        _c('expiryMonth').text = '${record.expiryMonth}';
        _c('expiryYear').text = '${record.expiryYear}';
        _c('issuingBank').text = record.issuingBank;
      case SecureDocumentRecord():
        _c('nickname').text = record.nickname;
        _documentCategory = record.category;
        _c('linkedAccountNickname').text = record.linkedAccountNickname ?? '';
        _c('customFields').text = record.customFields.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('\n');
        _c('notes').text = record.notes ?? '';
    }
  }

  Future<void> _save() async {
    setState(() {
      _formError = null;
      _nicknameError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final preflightError = _platformValidationError();
    if (preflightError != null) {
      setState(() => _formError = preflightError);
      return;
    }

    setState(() => _saving = true);
    try {
      final repositories = await ref.read(vaultRepositoriesProvider.future);
      final result = await _saveForType(repositories);
      if (!mounted) return;
      if (result.isFailure) {
        final failure = result.failure;
        setState(() {
          if (failure is ValidationFailure && failure.field == 'nickname') {
            _nicknameError = failure.message;
          } else {
            _formError = failure.message;
          }
        });
        return;
      }
      ref.invalidate(vaultSummariesProvider);
      widget.onSaved?.call();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } on ArgumentError catch (error) {
      setState(
        () => _formError = error.message?.toString() ?? error.toString(),
      );
    } on FormatException catch (error) {
      setState(() => _formError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Result<void>> _saveForType(VaultRepositories repositories) async {
    return switch (widget.type) {
      VaultRecordType.bankAccount => _withKey((keyBytes) async {
        final record = BankAccountRecord(
          id: null,
          nickname: _trimText('nickname'),
          bankName: _trimText('bankName'),
          accountHolderName: _trimText('accountHolderName'),
          accountNumber: _trimText('accountNumber'),
          ifscCode: _trimText('ifscCode').toUpperCase(),
          accountType: _trimText('accountType'),
          branchName: _optionalText('branchName'),
          notes: _optionalText('notes'),
        );
        return _isEditing
            ? repositories.bankAccounts.update(record, keyBytes)
            : _voidFromId(repositories.bankAccounts.create(record, keyBytes));
      }),
      VaultRecordType.panCard => _withKey((keyBytes) async {
        final record = PanCardRecord(
          id: widget.editRef?.id,
          panNumber: _trimText('panNumber').toUpperCase(),
          nameOnCard: _trimText('nameOnCard'),
          fathersName: _optionalText('fathersName'),
          dateOfBirth: _optionalDate('dateOfBirth'),
        );
        return _isEditing
            ? repositories.panCards.update(record, keyBytes)
            : _voidFromId(repositories.panCards.create(record, keyBytes));
      }),
      VaultRecordType.creditCard => _saveCreditCard(repositories),
      VaultRecordType.secureDocument => _withKey((keyBytes) async {
        final record = SecureDocumentRecord(
          id: null,
          nickname: _trimText('nickname'),
          category: _documentCategory,
          linkedAccountNickname: _optionalText('linkedAccountNickname'),
          customFields: _parseCustomFields(_c('customFields').text),
          notes: _optionalText('notes'),
          createdAt: DateTime.now(),
        );
        return _isEditing
            ? repositories.secureDocuments.update(record, keyBytes)
            : _voidFromId(
                repositories.secureDocuments.create(record, keyBytes),
              );
      }),
    };
  }

  String? _platformValidationError() {
    return switch (widget.type) {
      VaultRecordType.bankAccount =>
        isValidIfsc(_trimText('ifscCode').toUpperCase())
            ? null
            : 'Not a valid IFSC code',
      VaultRecordType.panCard =>
        isValidPan(_trimText('panNumber').toUpperCase())
            ? null
            : 'Not a valid PAN number',
      VaultRecordType.creditCard || VaultRecordType.secureDocument => null,
    };
  }

  Future<Result<void>> _saveCreditCard(VaultRepositories repositories) {
    final record = CreditCardRecord(
      id: null,
      nickname: _trimText('nickname'),
      cardNetwork: _cardNetwork,
      last4: _trimText('last4'),
      expiryMonth: int.parse(_trimText('expiryMonth')),
      expiryYear: int.parse(_trimText('expiryYear')),
      issuingBank: _trimText('issuingBank'),
      createdAt: DateTime.now(),
    );
    return _isEditing
        ? repositories.creditCards.update(record)
        : _voidFromId(repositories.creditCards.create(record));
  }

  Future<Result<void>> _withKey(
    Future<Result<void>> Function(List<int> keyBytes) operation,
  ) async {
    final result = await ref
        .read(vaultSessionProvider.notifier)
        .withKey(operation);
    return result ??
        const Failure(AuthFailure(message: 'Unlock the vault before saving.'));
  }

  Future<Result<void>> _voidFromId(Future<Result<int>> resultFuture) async {
    final result = await resultFuture;
    if (result.isFailure) return Failure(result.failure);
    return const Success(null);
  }

  String _trimText(String key) => _trim(_c(key).text);

  String? _optionalText(String key) {
    final value = _trimText(key);
    return value.isEmpty ? null : value;
  }

  DateTime? _optionalDate(String key) {
    final value = _trimText(key);
    if (value.isEmpty) return null;
    return DateTime.parse(value);
  }

  Map<String, String> _parseCustomFields(String raw) {
    final fields = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final separator = trimmed.indexOf('=');
      if (separator <= 0) {
        throw const FormatException('Custom fields must use key=value lines');
      }
      fields[trimmed.substring(0, separator).trim()] = trimmed
          .substring(separator + 1)
          .trim();
    }
    return fields;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

String _trim(String? value) => value?.trim() ?? '';
