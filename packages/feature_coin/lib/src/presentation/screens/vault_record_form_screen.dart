import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/screen_security.dart';
import '../../application/vault_session.dart';
import '../../domain/vault_record_type.dart';
import '../widgets/vault_lifecycle_observer.dart';
import '../widgets/forms/bank_account_form.dart';
import '../widgets/forms/credit_card_form.dart';
import '../widgets/forms/pan_card_form.dart';
import '../widgets/forms/secure_document_form.dart';
import 'vault_lock_screen.dart';

/// Add/edit host routed at `/money/vault/add/:type` and
/// `/money/vault/edit/:type/:key`. Dispatches to the per-type form.
class VaultRecordFormScreen extends ConsumerStatefulWidget {
  const VaultRecordFormScreen({
    super.key,
    required this.recordType,
    this.recordKey,
  });

  final VaultRecordType recordType;

  /// Nickname, or PAN row id as a decimal string. Null means add mode.
  final String? recordKey;

  @override
  ConsumerState<VaultRecordFormScreen> createState() =>
      _VaultRecordFormScreenState();
}

class _VaultRecordFormScreenState extends ConsumerState<VaultRecordFormScreen> {
  late final VaultScreenSecurity _screenSecurity;

  @override
  void initState() {
    super.initState();
    _screenSecurity = ref.read(screenSecurityProvider);
    Future<void>.microtask(_screenSecurity.protect);
    Future.microtask(() => ref.read(vaultSessionProvider.notifier).unlock());
  }

  @override
  void dispose() {
    Future<void>.microtask(_screenSecurity.unprotect);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultSessionProvider);
    final body = switch (session) {
      VaultUnlocked() => _buildFormScaffold(),
      VaultUnavailable() => const VaultUnavailableView(),
      VaultAuthError(:final failure) => VaultAuthErrorView(failure: failure),
      _ => const VaultLockScreen(),
    };
    return VaultLifecycleObserver(child: body);
  }

  Widget _buildFormScaffold() {
    final panRecordId =
        widget.recordType == VaultRecordType.panCard && widget.recordKey != null
        ? int.tryParse(widget.recordKey!)
        : null;
    final typeLabel = switch (widget.recordType) {
      VaultRecordType.bankAccount => 'Bank account',
      VaultRecordType.panCard => 'PAN card',
      VaultRecordType.creditCard => 'Card (masked)',
      VaultRecordType.secureDocument => 'Secure document',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.recordKey == null ? 'Add' : 'Edit'} $typeLabel'),
      ),
      body: switch (widget.recordType) {
        VaultRecordType.bankAccount => BankAccountForm(
          nickname: widget.recordKey,
        ),
        VaultRecordType.panCard =>
          widget.recordKey != null && panRecordId == null
              ? const Center(child: Text('Invalid PAN record key'))
              : PanCardForm(recordId: panRecordId),
        VaultRecordType.creditCard => CreditCardForm(
          nickname: widget.recordKey,
        ),
        VaultRecordType.secureDocument => SecureDocumentForm(
          nickname: widget.recordKey,
        ),
      },
    );
  }
}
