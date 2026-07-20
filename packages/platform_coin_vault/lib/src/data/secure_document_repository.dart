import 'dart:convert';

import 'package:core_domain/core_domain.dart';
import 'package:sqflite/sqflite.dart';

import '../crypto/field_cipher.dart';
import '../domain/entities/secure_document_record.dart';
import 'vault_database.dart';

class SecureDocumentRepository {
  SecureDocumentRepository({required VaultDatabase database, required FieldCipher fieldCipher})
    : _database = database,
      _fieldCipher = fieldCipher;

  final VaultDatabase _database;
  final FieldCipher _fieldCipher;

  Future<Result<int>> create(SecureDocumentRecord record, List<int> keyBytes) async {
    try {
      final customFieldsEnc = record.customFields.isEmpty
          ? null
          : await _fieldCipher.encryptField(jsonEncode(record.customFields), keyBytes);
      final notesEnc = record.notes == null
          ? null
          : await _fieldCipher.encryptField(record.notes!, keyBytes);
      final attachmentEnc = record.attachmentBlob == null
          ? null
          : await _fieldCipher.encryptField(
              String.fromCharCodes(record.attachmentBlob!),
              keyBytes,
            );

      final id = await _database.db.insert(VaultTables.secureDocuments, {
        'nickname': record.nickname,
        'category': record.category.name,
        'linked_account_nickname': record.linkedAccountNickname,
        'custom_fields_enc': customFieldsEnc,
        'attachment_blob_enc': attachmentEnc,
        'notes_enc': notesEnc,
        'created_at': record.createdAt.millisecondsSinceEpoch,
      });
      return Success(id);
    } on DatabaseException catch (e) {
      return Failure(ValidationFailure(
        message: 'A document with nickname "${record.nickname}" already exists',
        field: 'nickname',
        cause: e,
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to create secure document', cause: e));
    }
  }

  Future<Result<SecureDocumentRecord?>> getByNickname(
    String nickname,
    List<int> keyBytes,
  ) async {
    try {
      final rows = await _database.db.query(
        VaultTables.secureDocuments,
        where: 'nickname = ?',
        whereArgs: [nickname],
        limit: 1,
      );
      if (rows.isEmpty) return const Success(null);

      final row = rows.single;
      final customFieldsEnc = row['custom_fields_enc'] as String?;
      final notesEnc = row['notes_enc'] as String?;
      final attachmentEnc = row['attachment_blob_enc'] as String?;

      final customFields = customFieldsEnc == null
          ? <String, String>{}
          : Map<String, String>.from(
              jsonDecode(await _fieldCipher.decryptField(customFieldsEnc, keyBytes)) as Map,
            );

      return Success(SecureDocumentRecord(
        id: row['id'] as int,
        nickname: row['nickname'] as String,
        category: DocumentCategory.values.byName(row['category'] as String),
        linkedAccountNickname: row['linked_account_nickname'] as String?,
        customFields: customFields,
        attachmentBlob: attachmentEnc == null
            ? null
            : (await _fieldCipher.decryptField(attachmentEnc, keyBytes)).codeUnits,
        notes: notesEnc == null ? null : await _fieldCipher.decryptField(notesEnc, keyBytes),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      ));
    } catch (e) {
      return Failure(DatabaseFailure(message: 'Failed to read secure document', cause: e));
    }
  }
}
