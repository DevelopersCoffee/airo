// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'canonical_channel_database.dart';

// ignore_for_file: type=lint
class $CanonicalChannelsTable extends CanonicalChannels
    with TableInfo<$CanonicalChannelsTable, CanonicalChannel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanonicalChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _canonicalChannelIdMeta =
      const VerificationMeta('canonicalChannelId');
  @override
  late final GeneratedColumn<String> canonicalChannelId =
      GeneratedColumn<String>(
        'canonical_channel_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _logoFingerprintMeta = const VerificationMeta(
    'logoFingerprint',
  );
  @override
  late final GeneratedColumn<String> logoFingerprint = GeneratedColumn<String>(
    'logo_fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    canonicalChannelId,
    displayName,
    normalizedName,
    language,
    country,
    category,
    logoFingerprint,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canonical_channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<CanonicalChannel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('canonical_channel_id')) {
      context.handle(
        _canonicalChannelIdMeta,
        canonicalChannelId.isAcceptableOrUnknown(
          data['canonical_channel_id']!,
          _canonicalChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalChannelIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('logo_fingerprint')) {
      context.handle(
        _logoFingerprintMeta,
        logoFingerprint.isAcceptableOrUnknown(
          data['logo_fingerprint']!,
          _logoFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {canonicalChannelId};
  @override
  CanonicalChannel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanonicalChannel(
      canonicalChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_channel_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      logoFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}logo_fingerprint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CanonicalChannelsTable createAlias(String alias) {
    return $CanonicalChannelsTable(attachedDatabase, alias);
  }
}

class CanonicalChannel extends DataClass
    implements Insertable<CanonicalChannel> {
  final String canonicalChannelId;
  final String displayName;
  final String normalizedName;
  final String? language;
  final String? country;
  final String? category;
  final String? logoFingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;
  const CanonicalChannel({
    required this.canonicalChannelId,
    required this.displayName,
    required this.normalizedName,
    this.language,
    this.country,
    this.category,
    this.logoFingerprint,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['canonical_channel_id'] = Variable<String>(canonicalChannelId);
    map['display_name'] = Variable<String>(displayName);
    map['normalized_name'] = Variable<String>(normalizedName);
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || logoFingerprint != null) {
      map['logo_fingerprint'] = Variable<String>(logoFingerprint);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CanonicalChannelsCompanion toCompanion(bool nullToAbsent) {
    return CanonicalChannelsCompanion(
      canonicalChannelId: Value(canonicalChannelId),
      displayName: Value(displayName),
      normalizedName: Value(normalizedName),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      logoFingerprint: logoFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(logoFingerprint),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory CanonicalChannel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanonicalChannel(
      canonicalChannelId: serializer.fromJson<String>(
        json['canonicalChannelId'],
      ),
      displayName: serializer.fromJson<String>(json['displayName']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      language: serializer.fromJson<String?>(json['language']),
      country: serializer.fromJson<String?>(json['country']),
      category: serializer.fromJson<String?>(json['category']),
      logoFingerprint: serializer.fromJson<String?>(json['logoFingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'canonicalChannelId': serializer.toJson<String>(canonicalChannelId),
      'displayName': serializer.toJson<String>(displayName),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'language': serializer.toJson<String?>(language),
      'country': serializer.toJson<String?>(country),
      'category': serializer.toJson<String?>(category),
      'logoFingerprint': serializer.toJson<String?>(logoFingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CanonicalChannel copyWith({
    String? canonicalChannelId,
    String? displayName,
    String? normalizedName,
    Value<String?> language = const Value.absent(),
    Value<String?> country = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<String?> logoFingerprint = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CanonicalChannel(
    canonicalChannelId: canonicalChannelId ?? this.canonicalChannelId,
    displayName: displayName ?? this.displayName,
    normalizedName: normalizedName ?? this.normalizedName,
    language: language.present ? language.value : this.language,
    country: country.present ? country.value : this.country,
    category: category.present ? category.value : this.category,
    logoFingerprint: logoFingerprint.present
        ? logoFingerprint.value
        : this.logoFingerprint,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CanonicalChannel copyWithCompanion(CanonicalChannelsCompanion data) {
    return CanonicalChannel(
      canonicalChannelId: data.canonicalChannelId.present
          ? data.canonicalChannelId.value
          : this.canonicalChannelId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      language: data.language.present ? data.language.value : this.language,
      country: data.country.present ? data.country.value : this.country,
      category: data.category.present ? data.category.value : this.category,
      logoFingerprint: data.logoFingerprint.present
          ? data.logoFingerprint.value
          : this.logoFingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalChannel(')
          ..write('canonicalChannelId: $canonicalChannelId, ')
          ..write('displayName: $displayName, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('language: $language, ')
          ..write('country: $country, ')
          ..write('category: $category, ')
          ..write('logoFingerprint: $logoFingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    canonicalChannelId,
    displayName,
    normalizedName,
    language,
    country,
    category,
    logoFingerprint,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanonicalChannel &&
          other.canonicalChannelId == this.canonicalChannelId &&
          other.displayName == this.displayName &&
          other.normalizedName == this.normalizedName &&
          other.language == this.language &&
          other.country == this.country &&
          other.category == this.category &&
          other.logoFingerprint == this.logoFingerprint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CanonicalChannelsCompanion extends UpdateCompanion<CanonicalChannel> {
  final Value<String> canonicalChannelId;
  final Value<String> displayName;
  final Value<String> normalizedName;
  final Value<String?> language;
  final Value<String?> country;
  final Value<String?> category;
  final Value<String?> logoFingerprint;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CanonicalChannelsCompanion({
    this.canonicalChannelId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.language = const Value.absent(),
    this.country = const Value.absent(),
    this.category = const Value.absent(),
    this.logoFingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanonicalChannelsCompanion.insert({
    required String canonicalChannelId,
    required String displayName,
    required String normalizedName,
    this.language = const Value.absent(),
    this.country = const Value.absent(),
    this.category = const Value.absent(),
    this.logoFingerprint = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : canonicalChannelId = Value(canonicalChannelId),
       displayName = Value(displayName),
       normalizedName = Value(normalizedName),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<CanonicalChannel> custom({
    Expression<String>? canonicalChannelId,
    Expression<String>? displayName,
    Expression<String>? normalizedName,
    Expression<String>? language,
    Expression<String>? country,
    Expression<String>? category,
    Expression<String>? logoFingerprint,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (canonicalChannelId != null)
        'canonical_channel_id': canonicalChannelId,
      if (displayName != null) 'display_name': displayName,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (language != null) 'language': language,
      if (country != null) 'country': country,
      if (category != null) 'category': category,
      if (logoFingerprint != null) 'logo_fingerprint': logoFingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanonicalChannelsCompanion copyWith({
    Value<String>? canonicalChannelId,
    Value<String>? displayName,
    Value<String>? normalizedName,
    Value<String?>? language,
    Value<String?>? country,
    Value<String?>? category,
    Value<String?>? logoFingerprint,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CanonicalChannelsCompanion(
      canonicalChannelId: canonicalChannelId ?? this.canonicalChannelId,
      displayName: displayName ?? this.displayName,
      normalizedName: normalizedName ?? this.normalizedName,
      language: language ?? this.language,
      country: country ?? this.country,
      category: category ?? this.category,
      logoFingerprint: logoFingerprint ?? this.logoFingerprint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (canonicalChannelId.present) {
      map['canonical_channel_id'] = Variable<String>(canonicalChannelId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (logoFingerprint.present) {
      map['logo_fingerprint'] = Variable<String>(logoFingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanonicalChannelsCompanion(')
          ..write('canonicalChannelId: $canonicalChannelId, ')
          ..write('displayName: $displayName, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('language: $language, ')
          ..write('country: $country, ')
          ..write('category: $category, ')
          ..write('logoFingerprint: $logoFingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderChannelAliasesTable extends ProviderChannelAliases
    with TableInfo<$ProviderChannelAliasesTable, ProviderChannelAlias> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderChannelAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerChannelIdMeta = const VerificationMeta(
    'providerChannelId',
  );
  @override
  late final GeneratedColumn<String> providerChannelId =
      GeneratedColumn<String>(
        'provider_channel_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _canonicalChannelIdMeta =
      const VerificationMeta('canonicalChannelId');
  @override
  late final GeneratedColumn<String> canonicalChannelId =
      GeneratedColumn<String>(
        'canonical_channel_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _providerNameMeta = const VerificationMeta(
    'providerName',
  );
  @override
  late final GeneratedColumn<String> providerName = GeneratedColumn<String>(
    'provider_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedProviderNameMeta =
      const VerificationMeta('normalizedProviderName');
  @override
  late final GeneratedColumn<String> normalizedProviderName =
      GeneratedColumn<String>(
        'normalized_provider_name',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _tvgIdMeta = const VerificationMeta('tvgId');
  @override
  late final GeneratedColumn<int> tvgId = GeneratedColumn<int>(
    'tvg_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupTitleMeta = const VerificationMeta(
    'groupTitle',
  );
  @override
  late final GeneratedColumn<String> groupTitle = GeneratedColumn<String>(
    'group_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streamUrlFingerprintMeta =
      const VerificationMeta('streamUrlFingerprint');
  @override
  late final GeneratedColumn<String> streamUrlFingerprint =
      GeneratedColumn<String>(
        'stream_url_fingerprint',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isVodMeta = const VerificationMeta('isVod');
  @override
  late final GeneratedColumn<bool> isVod = GeneratedColumn<bool>(
    'is_vod',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_vod" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isRadioMeta = const VerificationMeta(
    'isRadio',
  );
  @override
  late final GeneratedColumn<bool> isRadio = GeneratedColumn<bool>(
    'is_radio',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_radio" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isAdultMeta = const VerificationMeta(
    'isAdult',
  );
  @override
  late final GeneratedColumn<bool> isAdult = GeneratedColumn<bool>(
    'is_adult',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_adult" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _matchConfidenceMeta = const VerificationMeta(
    'matchConfidence',
  );
  @override
  late final GeneratedColumn<String> matchConfidence = GeneratedColumn<String>(
    'match_confidence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceId,
    providerChannelId,
    canonicalChannelId,
    providerName,
    normalizedProviderName,
    tvgId,
    groupTitle,
    streamUrlFingerprint,
    resolution,
    isVod,
    isRadio,
    isAdult,
    matchConfidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_channel_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderChannelAlias> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('provider_channel_id')) {
      context.handle(
        _providerChannelIdMeta,
        providerChannelId.isAcceptableOrUnknown(
          data['provider_channel_id']!,
          _providerChannelIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerChannelIdMeta);
    }
    if (data.containsKey('canonical_channel_id')) {
      context.handle(
        _canonicalChannelIdMeta,
        canonicalChannelId.isAcceptableOrUnknown(
          data['canonical_channel_id']!,
          _canonicalChannelIdMeta,
        ),
      );
    }
    if (data.containsKey('provider_name')) {
      context.handle(
        _providerNameMeta,
        providerName.isAcceptableOrUnknown(
          data['provider_name']!,
          _providerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_providerNameMeta);
    }
    if (data.containsKey('normalized_provider_name')) {
      context.handle(
        _normalizedProviderNameMeta,
        normalizedProviderName.isAcceptableOrUnknown(
          data['normalized_provider_name']!,
          _normalizedProviderNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedProviderNameMeta);
    }
    if (data.containsKey('tvg_id')) {
      context.handle(
        _tvgIdMeta,
        tvgId.isAcceptableOrUnknown(data['tvg_id']!, _tvgIdMeta),
      );
    }
    if (data.containsKey('group_title')) {
      context.handle(
        _groupTitleMeta,
        groupTitle.isAcceptableOrUnknown(data['group_title']!, _groupTitleMeta),
      );
    }
    if (data.containsKey('stream_url_fingerprint')) {
      context.handle(
        _streamUrlFingerprintMeta,
        streamUrlFingerprint.isAcceptableOrUnknown(
          data['stream_url_fingerprint']!,
          _streamUrlFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_streamUrlFingerprintMeta);
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('is_vod')) {
      context.handle(
        _isVodMeta,
        isVod.isAcceptableOrUnknown(data['is_vod']!, _isVodMeta),
      );
    }
    if (data.containsKey('is_radio')) {
      context.handle(
        _isRadioMeta,
        isRadio.isAcceptableOrUnknown(data['is_radio']!, _isRadioMeta),
      );
    }
    if (data.containsKey('is_adult')) {
      context.handle(
        _isAdultMeta,
        isAdult.isAcceptableOrUnknown(data['is_adult']!, _isAdultMeta),
      );
    }
    if (data.containsKey('match_confidence')) {
      context.handle(
        _matchConfidenceMeta,
        matchConfidence.isAcceptableOrUnknown(
          data['match_confidence']!,
          _matchConfidenceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceId, providerChannelId};
  @override
  ProviderChannelAlias map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderChannelAlias(
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      providerChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_channel_id'],
      )!,
      canonicalChannelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_channel_id'],
      ),
      providerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_name'],
      )!,
      normalizedProviderName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_provider_name'],
      )!,
      tvgId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tvg_id'],
      ),
      groupTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_title'],
      ),
      streamUrlFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url_fingerprint'],
      )!,
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      ),
      isVod: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_vod'],
      )!,
      isRadio: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_radio'],
      )!,
      isAdult: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_adult'],
      )!,
      matchConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_confidence'],
      ),
    );
  }

  @override
  $ProviderChannelAliasesTable createAlias(String alias) {
    return $ProviderChannelAliasesTable(attachedDatabase, alias);
  }
}

class ProviderChannelAlias extends DataClass
    implements Insertable<ProviderChannelAlias> {
  final String sourceId;
  final String providerChannelId;
  final String? canonicalChannelId;
  final String providerName;
  final String normalizedProviderName;
  final int? tvgId;
  final String? groupTitle;
  final String streamUrlFingerprint;
  final String? resolution;
  final bool isVod;
  final bool isRadio;
  final bool isAdult;
  final String? matchConfidence;
  const ProviderChannelAlias({
    required this.sourceId,
    required this.providerChannelId,
    this.canonicalChannelId,
    required this.providerName,
    required this.normalizedProviderName,
    this.tvgId,
    this.groupTitle,
    required this.streamUrlFingerprint,
    this.resolution,
    required this.isVod,
    required this.isRadio,
    required this.isAdult,
    this.matchConfidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_id'] = Variable<String>(sourceId);
    map['provider_channel_id'] = Variable<String>(providerChannelId);
    if (!nullToAbsent || canonicalChannelId != null) {
      map['canonical_channel_id'] = Variable<String>(canonicalChannelId);
    }
    map['provider_name'] = Variable<String>(providerName);
    map['normalized_provider_name'] = Variable<String>(normalizedProviderName);
    if (!nullToAbsent || tvgId != null) {
      map['tvg_id'] = Variable<int>(tvgId);
    }
    if (!nullToAbsent || groupTitle != null) {
      map['group_title'] = Variable<String>(groupTitle);
    }
    map['stream_url_fingerprint'] = Variable<String>(streamUrlFingerprint);
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<String>(resolution);
    }
    map['is_vod'] = Variable<bool>(isVod);
    map['is_radio'] = Variable<bool>(isRadio);
    map['is_adult'] = Variable<bool>(isAdult);
    if (!nullToAbsent || matchConfidence != null) {
      map['match_confidence'] = Variable<String>(matchConfidence);
    }
    return map;
  }

  ProviderChannelAliasesCompanion toCompanion(bool nullToAbsent) {
    return ProviderChannelAliasesCompanion(
      sourceId: Value(sourceId),
      providerChannelId: Value(providerChannelId),
      canonicalChannelId: canonicalChannelId == null && nullToAbsent
          ? const Value.absent()
          : Value(canonicalChannelId),
      providerName: Value(providerName),
      normalizedProviderName: Value(normalizedProviderName),
      tvgId: tvgId == null && nullToAbsent
          ? const Value.absent()
          : Value(tvgId),
      groupTitle: groupTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(groupTitle),
      streamUrlFingerprint: Value(streamUrlFingerprint),
      resolution: resolution == null && nullToAbsent
          ? const Value.absent()
          : Value(resolution),
      isVod: Value(isVod),
      isRadio: Value(isRadio),
      isAdult: Value(isAdult),
      matchConfidence: matchConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(matchConfidence),
    );
  }

  factory ProviderChannelAlias.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderChannelAlias(
      sourceId: serializer.fromJson<String>(json['sourceId']),
      providerChannelId: serializer.fromJson<String>(json['providerChannelId']),
      canonicalChannelId: serializer.fromJson<String?>(
        json['canonicalChannelId'],
      ),
      providerName: serializer.fromJson<String>(json['providerName']),
      normalizedProviderName: serializer.fromJson<String>(
        json['normalizedProviderName'],
      ),
      tvgId: serializer.fromJson<int?>(json['tvgId']),
      groupTitle: serializer.fromJson<String?>(json['groupTitle']),
      streamUrlFingerprint: serializer.fromJson<String>(
        json['streamUrlFingerprint'],
      ),
      resolution: serializer.fromJson<String?>(json['resolution']),
      isVod: serializer.fromJson<bool>(json['isVod']),
      isRadio: serializer.fromJson<bool>(json['isRadio']),
      isAdult: serializer.fromJson<bool>(json['isAdult']),
      matchConfidence: serializer.fromJson<String?>(json['matchConfidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceId': serializer.toJson<String>(sourceId),
      'providerChannelId': serializer.toJson<String>(providerChannelId),
      'canonicalChannelId': serializer.toJson<String?>(canonicalChannelId),
      'providerName': serializer.toJson<String>(providerName),
      'normalizedProviderName': serializer.toJson<String>(
        normalizedProviderName,
      ),
      'tvgId': serializer.toJson<int?>(tvgId),
      'groupTitle': serializer.toJson<String?>(groupTitle),
      'streamUrlFingerprint': serializer.toJson<String>(streamUrlFingerprint),
      'resolution': serializer.toJson<String?>(resolution),
      'isVod': serializer.toJson<bool>(isVod),
      'isRadio': serializer.toJson<bool>(isRadio),
      'isAdult': serializer.toJson<bool>(isAdult),
      'matchConfidence': serializer.toJson<String?>(matchConfidence),
    };
  }

  ProviderChannelAlias copyWith({
    String? sourceId,
    String? providerChannelId,
    Value<String?> canonicalChannelId = const Value.absent(),
    String? providerName,
    String? normalizedProviderName,
    Value<int?> tvgId = const Value.absent(),
    Value<String?> groupTitle = const Value.absent(),
    String? streamUrlFingerprint,
    Value<String?> resolution = const Value.absent(),
    bool? isVod,
    bool? isRadio,
    bool? isAdult,
    Value<String?> matchConfidence = const Value.absent(),
  }) => ProviderChannelAlias(
    sourceId: sourceId ?? this.sourceId,
    providerChannelId: providerChannelId ?? this.providerChannelId,
    canonicalChannelId: canonicalChannelId.present
        ? canonicalChannelId.value
        : this.canonicalChannelId,
    providerName: providerName ?? this.providerName,
    normalizedProviderName:
        normalizedProviderName ?? this.normalizedProviderName,
    tvgId: tvgId.present ? tvgId.value : this.tvgId,
    groupTitle: groupTitle.present ? groupTitle.value : this.groupTitle,
    streamUrlFingerprint: streamUrlFingerprint ?? this.streamUrlFingerprint,
    resolution: resolution.present ? resolution.value : this.resolution,
    isVod: isVod ?? this.isVod,
    isRadio: isRadio ?? this.isRadio,
    isAdult: isAdult ?? this.isAdult,
    matchConfidence: matchConfidence.present
        ? matchConfidence.value
        : this.matchConfidence,
  );
  ProviderChannelAlias copyWithCompanion(ProviderChannelAliasesCompanion data) {
    return ProviderChannelAlias(
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      providerChannelId: data.providerChannelId.present
          ? data.providerChannelId.value
          : this.providerChannelId,
      canonicalChannelId: data.canonicalChannelId.present
          ? data.canonicalChannelId.value
          : this.canonicalChannelId,
      providerName: data.providerName.present
          ? data.providerName.value
          : this.providerName,
      normalizedProviderName: data.normalizedProviderName.present
          ? data.normalizedProviderName.value
          : this.normalizedProviderName,
      tvgId: data.tvgId.present ? data.tvgId.value : this.tvgId,
      groupTitle: data.groupTitle.present
          ? data.groupTitle.value
          : this.groupTitle,
      streamUrlFingerprint: data.streamUrlFingerprint.present
          ? data.streamUrlFingerprint.value
          : this.streamUrlFingerprint,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      isVod: data.isVod.present ? data.isVod.value : this.isVod,
      isRadio: data.isRadio.present ? data.isRadio.value : this.isRadio,
      isAdult: data.isAdult.present ? data.isAdult.value : this.isAdult,
      matchConfidence: data.matchConfidence.present
          ? data.matchConfidence.value
          : this.matchConfidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderChannelAlias(')
          ..write('sourceId: $sourceId, ')
          ..write('providerChannelId: $providerChannelId, ')
          ..write('canonicalChannelId: $canonicalChannelId, ')
          ..write('providerName: $providerName, ')
          ..write('normalizedProviderName: $normalizedProviderName, ')
          ..write('tvgId: $tvgId, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('streamUrlFingerprint: $streamUrlFingerprint, ')
          ..write('resolution: $resolution, ')
          ..write('isVod: $isVod, ')
          ..write('isRadio: $isRadio, ')
          ..write('isAdult: $isAdult, ')
          ..write('matchConfidence: $matchConfidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    providerChannelId,
    canonicalChannelId,
    providerName,
    normalizedProviderName,
    tvgId,
    groupTitle,
    streamUrlFingerprint,
    resolution,
    isVod,
    isRadio,
    isAdult,
    matchConfidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderChannelAlias &&
          other.sourceId == this.sourceId &&
          other.providerChannelId == this.providerChannelId &&
          other.canonicalChannelId == this.canonicalChannelId &&
          other.providerName == this.providerName &&
          other.normalizedProviderName == this.normalizedProviderName &&
          other.tvgId == this.tvgId &&
          other.groupTitle == this.groupTitle &&
          other.streamUrlFingerprint == this.streamUrlFingerprint &&
          other.resolution == this.resolution &&
          other.isVod == this.isVod &&
          other.isRadio == this.isRadio &&
          other.isAdult == this.isAdult &&
          other.matchConfidence == this.matchConfidence);
}

class ProviderChannelAliasesCompanion
    extends UpdateCompanion<ProviderChannelAlias> {
  final Value<String> sourceId;
  final Value<String> providerChannelId;
  final Value<String?> canonicalChannelId;
  final Value<String> providerName;
  final Value<String> normalizedProviderName;
  final Value<int?> tvgId;
  final Value<String?> groupTitle;
  final Value<String> streamUrlFingerprint;
  final Value<String?> resolution;
  final Value<bool> isVod;
  final Value<bool> isRadio;
  final Value<bool> isAdult;
  final Value<String?> matchConfidence;
  final Value<int> rowid;
  const ProviderChannelAliasesCompanion({
    this.sourceId = const Value.absent(),
    this.providerChannelId = const Value.absent(),
    this.canonicalChannelId = const Value.absent(),
    this.providerName = const Value.absent(),
    this.normalizedProviderName = const Value.absent(),
    this.tvgId = const Value.absent(),
    this.groupTitle = const Value.absent(),
    this.streamUrlFingerprint = const Value.absent(),
    this.resolution = const Value.absent(),
    this.isVod = const Value.absent(),
    this.isRadio = const Value.absent(),
    this.isAdult = const Value.absent(),
    this.matchConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderChannelAliasesCompanion.insert({
    required String sourceId,
    required String providerChannelId,
    this.canonicalChannelId = const Value.absent(),
    required String providerName,
    required String normalizedProviderName,
    this.tvgId = const Value.absent(),
    this.groupTitle = const Value.absent(),
    required String streamUrlFingerprint,
    this.resolution = const Value.absent(),
    this.isVod = const Value.absent(),
    this.isRadio = const Value.absent(),
    this.isAdult = const Value.absent(),
    this.matchConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sourceId = Value(sourceId),
       providerChannelId = Value(providerChannelId),
       providerName = Value(providerName),
       normalizedProviderName = Value(normalizedProviderName),
       streamUrlFingerprint = Value(streamUrlFingerprint);
  static Insertable<ProviderChannelAlias> custom({
    Expression<String>? sourceId,
    Expression<String>? providerChannelId,
    Expression<String>? canonicalChannelId,
    Expression<String>? providerName,
    Expression<String>? normalizedProviderName,
    Expression<int>? tvgId,
    Expression<String>? groupTitle,
    Expression<String>? streamUrlFingerprint,
    Expression<String>? resolution,
    Expression<bool>? isVod,
    Expression<bool>? isRadio,
    Expression<bool>? isAdult,
    Expression<String>? matchConfidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceId != null) 'source_id': sourceId,
      if (providerChannelId != null) 'provider_channel_id': providerChannelId,
      if (canonicalChannelId != null)
        'canonical_channel_id': canonicalChannelId,
      if (providerName != null) 'provider_name': providerName,
      if (normalizedProviderName != null)
        'normalized_provider_name': normalizedProviderName,
      if (tvgId != null) 'tvg_id': tvgId,
      if (groupTitle != null) 'group_title': groupTitle,
      if (streamUrlFingerprint != null)
        'stream_url_fingerprint': streamUrlFingerprint,
      if (resolution != null) 'resolution': resolution,
      if (isVod != null) 'is_vod': isVod,
      if (isRadio != null) 'is_radio': isRadio,
      if (isAdult != null) 'is_adult': isAdult,
      if (matchConfidence != null) 'match_confidence': matchConfidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderChannelAliasesCompanion copyWith({
    Value<String>? sourceId,
    Value<String>? providerChannelId,
    Value<String?>? canonicalChannelId,
    Value<String>? providerName,
    Value<String>? normalizedProviderName,
    Value<int?>? tvgId,
    Value<String?>? groupTitle,
    Value<String>? streamUrlFingerprint,
    Value<String?>? resolution,
    Value<bool>? isVod,
    Value<bool>? isRadio,
    Value<bool>? isAdult,
    Value<String?>? matchConfidence,
    Value<int>? rowid,
  }) {
    return ProviderChannelAliasesCompanion(
      sourceId: sourceId ?? this.sourceId,
      providerChannelId: providerChannelId ?? this.providerChannelId,
      canonicalChannelId: canonicalChannelId ?? this.canonicalChannelId,
      providerName: providerName ?? this.providerName,
      normalizedProviderName:
          normalizedProviderName ?? this.normalizedProviderName,
      tvgId: tvgId ?? this.tvgId,
      groupTitle: groupTitle ?? this.groupTitle,
      streamUrlFingerprint: streamUrlFingerprint ?? this.streamUrlFingerprint,
      resolution: resolution ?? this.resolution,
      isVod: isVod ?? this.isVod,
      isRadio: isRadio ?? this.isRadio,
      isAdult: isAdult ?? this.isAdult,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (providerChannelId.present) {
      map['provider_channel_id'] = Variable<String>(providerChannelId.value);
    }
    if (canonicalChannelId.present) {
      map['canonical_channel_id'] = Variable<String>(canonicalChannelId.value);
    }
    if (providerName.present) {
      map['provider_name'] = Variable<String>(providerName.value);
    }
    if (normalizedProviderName.present) {
      map['normalized_provider_name'] = Variable<String>(
        normalizedProviderName.value,
      );
    }
    if (tvgId.present) {
      map['tvg_id'] = Variable<int>(tvgId.value);
    }
    if (groupTitle.present) {
      map['group_title'] = Variable<String>(groupTitle.value);
    }
    if (streamUrlFingerprint.present) {
      map['stream_url_fingerprint'] = Variable<String>(
        streamUrlFingerprint.value,
      );
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (isVod.present) {
      map['is_vod'] = Variable<bool>(isVod.value);
    }
    if (isRadio.present) {
      map['is_radio'] = Variable<bool>(isRadio.value);
    }
    if (isAdult.present) {
      map['is_adult'] = Variable<bool>(isAdult.value);
    }
    if (matchConfidence.present) {
      map['match_confidence'] = Variable<String>(matchConfidence.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderChannelAliasesCompanion(')
          ..write('sourceId: $sourceId, ')
          ..write('providerChannelId: $providerChannelId, ')
          ..write('canonicalChannelId: $canonicalChannelId, ')
          ..write('providerName: $providerName, ')
          ..write('normalizedProviderName: $normalizedProviderName, ')
          ..write('tvgId: $tvgId, ')
          ..write('groupTitle: $groupTitle, ')
          ..write('streamUrlFingerprint: $streamUrlFingerprint, ')
          ..write('resolution: $resolution, ')
          ..write('isVod: $isVod, ')
          ..write('isRadio: $isRadio, ')
          ..write('isAdult: $isAdult, ')
          ..write('matchConfidence: $matchConfidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CanonicalChannelDatabase extends GeneratedDatabase {
  _$CanonicalChannelDatabase(QueryExecutor e) : super(e);
  $CanonicalChannelDatabaseManager get managers =>
      $CanonicalChannelDatabaseManager(this);
  late final $CanonicalChannelsTable canonicalChannels =
      $CanonicalChannelsTable(this);
  late final $ProviderChannelAliasesTable providerChannelAliases =
      $ProviderChannelAliasesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    canonicalChannels,
    providerChannelAliases,
  ];
}

typedef $$CanonicalChannelsTableCreateCompanionBuilder =
    CanonicalChannelsCompanion Function({
      required String canonicalChannelId,
      required String displayName,
      required String normalizedName,
      Value<String?> language,
      Value<String?> country,
      Value<String?> category,
      Value<String?> logoFingerprint,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CanonicalChannelsTableUpdateCompanionBuilder =
    CanonicalChannelsCompanion Function({
      Value<String> canonicalChannelId,
      Value<String> displayName,
      Value<String> normalizedName,
      Value<String?> language,
      Value<String?> country,
      Value<String?> category,
      Value<String?> logoFingerprint,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CanonicalChannelsTableFilterComposer
    extends Composer<_$CanonicalChannelDatabase, $CanonicalChannelsTable> {
  $$CanonicalChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get logoFingerprint => $composableBuilder(
    column: $table.logoFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CanonicalChannelsTableOrderingComposer
    extends Composer<_$CanonicalChannelDatabase, $CanonicalChannelsTable> {
  $$CanonicalChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get logoFingerprint => $composableBuilder(
    column: $table.logoFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CanonicalChannelsTableAnnotationComposer
    extends Composer<_$CanonicalChannelDatabase, $CanonicalChannelsTable> {
  $$CanonicalChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get logoFingerprint => $composableBuilder(
    column: $table.logoFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CanonicalChannelsTableTableManager
    extends
        RootTableManager<
          _$CanonicalChannelDatabase,
          $CanonicalChannelsTable,
          CanonicalChannel,
          $$CanonicalChannelsTableFilterComposer,
          $$CanonicalChannelsTableOrderingComposer,
          $$CanonicalChannelsTableAnnotationComposer,
          $$CanonicalChannelsTableCreateCompanionBuilder,
          $$CanonicalChannelsTableUpdateCompanionBuilder,
          (
            CanonicalChannel,
            BaseReferences<
              _$CanonicalChannelDatabase,
              $CanonicalChannelsTable,
              CanonicalChannel
            >,
          ),
          CanonicalChannel,
          PrefetchHooks Function()
        > {
  $$CanonicalChannelsTableTableManager(
    _$CanonicalChannelDatabase db,
    $CanonicalChannelsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanonicalChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanonicalChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanonicalChannelsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> canonicalChannelId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> logoFingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CanonicalChannelsCompanion(
                canonicalChannelId: canonicalChannelId,
                displayName: displayName,
                normalizedName: normalizedName,
                language: language,
                country: country,
                category: category,
                logoFingerprint: logoFingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String canonicalChannelId,
                required String displayName,
                required String normalizedName,
                Value<String?> language = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> logoFingerprint = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CanonicalChannelsCompanion.insert(
                canonicalChannelId: canonicalChannelId,
                displayName: displayName,
                normalizedName: normalizedName,
                language: language,
                country: country,
                category: category,
                logoFingerprint: logoFingerprint,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CanonicalChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$CanonicalChannelDatabase,
      $CanonicalChannelsTable,
      CanonicalChannel,
      $$CanonicalChannelsTableFilterComposer,
      $$CanonicalChannelsTableOrderingComposer,
      $$CanonicalChannelsTableAnnotationComposer,
      $$CanonicalChannelsTableCreateCompanionBuilder,
      $$CanonicalChannelsTableUpdateCompanionBuilder,
      (
        CanonicalChannel,
        BaseReferences<
          _$CanonicalChannelDatabase,
          $CanonicalChannelsTable,
          CanonicalChannel
        >,
      ),
      CanonicalChannel,
      PrefetchHooks Function()
    >;
typedef $$ProviderChannelAliasesTableCreateCompanionBuilder =
    ProviderChannelAliasesCompanion Function({
      required String sourceId,
      required String providerChannelId,
      Value<String?> canonicalChannelId,
      required String providerName,
      required String normalizedProviderName,
      Value<int?> tvgId,
      Value<String?> groupTitle,
      required String streamUrlFingerprint,
      Value<String?> resolution,
      Value<bool> isVod,
      Value<bool> isRadio,
      Value<bool> isAdult,
      Value<String?> matchConfidence,
      Value<int> rowid,
    });
typedef $$ProviderChannelAliasesTableUpdateCompanionBuilder =
    ProviderChannelAliasesCompanion Function({
      Value<String> sourceId,
      Value<String> providerChannelId,
      Value<String?> canonicalChannelId,
      Value<String> providerName,
      Value<String> normalizedProviderName,
      Value<int?> tvgId,
      Value<String?> groupTitle,
      Value<String> streamUrlFingerprint,
      Value<String?> resolution,
      Value<bool> isVod,
      Value<bool> isRadio,
      Value<bool> isAdult,
      Value<String?> matchConfidence,
      Value<int> rowid,
    });

class $$ProviderChannelAliasesTableFilterComposer
    extends Composer<_$CanonicalChannelDatabase, $ProviderChannelAliasesTable> {
  $$ProviderChannelAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerChannelId => $composableBuilder(
    column: $table.providerChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedProviderName => $composableBuilder(
    column: $table.normalizedProviderName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrlFingerprint => $composableBuilder(
    column: $table.streamUrlFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isVod => $composableBuilder(
    column: $table.isVod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRadio => $composableBuilder(
    column: $table.isRadio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAdult => $composableBuilder(
    column: $table.isAdult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchConfidence => $composableBuilder(
    column: $table.matchConfidence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderChannelAliasesTableOrderingComposer
    extends Composer<_$CanonicalChannelDatabase, $ProviderChannelAliasesTable> {
  $$ProviderChannelAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerChannelId => $composableBuilder(
    column: $table.providerChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedProviderName => $composableBuilder(
    column: $table.normalizedProviderName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tvgId => $composableBuilder(
    column: $table.tvgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrlFingerprint => $composableBuilder(
    column: $table.streamUrlFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isVod => $composableBuilder(
    column: $table.isVod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRadio => $composableBuilder(
    column: $table.isRadio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAdult => $composableBuilder(
    column: $table.isAdult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchConfidence => $composableBuilder(
    column: $table.matchConfidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderChannelAliasesTableAnnotationComposer
    extends Composer<_$CanonicalChannelDatabase, $ProviderChannelAliasesTable> {
  $$ProviderChannelAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get providerChannelId => $composableBuilder(
    column: $table.providerChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalChannelId => $composableBuilder(
    column: $table.canonicalChannelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerName => $composableBuilder(
    column: $table.providerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalizedProviderName => $composableBuilder(
    column: $table.normalizedProviderName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tvgId =>
      $composableBuilder(column: $table.tvgId, builder: (column) => column);

  GeneratedColumn<String> get groupTitle => $composableBuilder(
    column: $table.groupTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get streamUrlFingerprint => $composableBuilder(
    column: $table.streamUrlFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isVod =>
      $composableBuilder(column: $table.isVod, builder: (column) => column);

  GeneratedColumn<bool> get isRadio =>
      $composableBuilder(column: $table.isRadio, builder: (column) => column);

  GeneratedColumn<bool> get isAdult =>
      $composableBuilder(column: $table.isAdult, builder: (column) => column);

  GeneratedColumn<String> get matchConfidence => $composableBuilder(
    column: $table.matchConfidence,
    builder: (column) => column,
  );
}

class $$ProviderChannelAliasesTableTableManager
    extends
        RootTableManager<
          _$CanonicalChannelDatabase,
          $ProviderChannelAliasesTable,
          ProviderChannelAlias,
          $$ProviderChannelAliasesTableFilterComposer,
          $$ProviderChannelAliasesTableOrderingComposer,
          $$ProviderChannelAliasesTableAnnotationComposer,
          $$ProviderChannelAliasesTableCreateCompanionBuilder,
          $$ProviderChannelAliasesTableUpdateCompanionBuilder,
          (
            ProviderChannelAlias,
            BaseReferences<
              _$CanonicalChannelDatabase,
              $ProviderChannelAliasesTable,
              ProviderChannelAlias
            >,
          ),
          ProviderChannelAlias,
          PrefetchHooks Function()
        > {
  $$ProviderChannelAliasesTableTableManager(
    _$CanonicalChannelDatabase db,
    $ProviderChannelAliasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderChannelAliasesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ProviderChannelAliasesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProviderChannelAliasesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sourceId = const Value.absent(),
                Value<String> providerChannelId = const Value.absent(),
                Value<String?> canonicalChannelId = const Value.absent(),
                Value<String> providerName = const Value.absent(),
                Value<String> normalizedProviderName = const Value.absent(),
                Value<int?> tvgId = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                Value<String> streamUrlFingerprint = const Value.absent(),
                Value<String?> resolution = const Value.absent(),
                Value<bool> isVod = const Value.absent(),
                Value<bool> isRadio = const Value.absent(),
                Value<bool> isAdult = const Value.absent(),
                Value<String?> matchConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderChannelAliasesCompanion(
                sourceId: sourceId,
                providerChannelId: providerChannelId,
                canonicalChannelId: canonicalChannelId,
                providerName: providerName,
                normalizedProviderName: normalizedProviderName,
                tvgId: tvgId,
                groupTitle: groupTitle,
                streamUrlFingerprint: streamUrlFingerprint,
                resolution: resolution,
                isVod: isVod,
                isRadio: isRadio,
                isAdult: isAdult,
                matchConfidence: matchConfidence,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceId,
                required String providerChannelId,
                Value<String?> canonicalChannelId = const Value.absent(),
                required String providerName,
                required String normalizedProviderName,
                Value<int?> tvgId = const Value.absent(),
                Value<String?> groupTitle = const Value.absent(),
                required String streamUrlFingerprint,
                Value<String?> resolution = const Value.absent(),
                Value<bool> isVod = const Value.absent(),
                Value<bool> isRadio = const Value.absent(),
                Value<bool> isAdult = const Value.absent(),
                Value<String?> matchConfidence = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderChannelAliasesCompanion.insert(
                sourceId: sourceId,
                providerChannelId: providerChannelId,
                canonicalChannelId: canonicalChannelId,
                providerName: providerName,
                normalizedProviderName: normalizedProviderName,
                tvgId: tvgId,
                groupTitle: groupTitle,
                streamUrlFingerprint: streamUrlFingerprint,
                resolution: resolution,
                isVod: isVod,
                isRadio: isRadio,
                isAdult: isAdult,
                matchConfidence: matchConfidence,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderChannelAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$CanonicalChannelDatabase,
      $ProviderChannelAliasesTable,
      ProviderChannelAlias,
      $$ProviderChannelAliasesTableFilterComposer,
      $$ProviderChannelAliasesTableOrderingComposer,
      $$ProviderChannelAliasesTableAnnotationComposer,
      $$ProviderChannelAliasesTableCreateCompanionBuilder,
      $$ProviderChannelAliasesTableUpdateCompanionBuilder,
      (
        ProviderChannelAlias,
        BaseReferences<
          _$CanonicalChannelDatabase,
          $ProviderChannelAliasesTable,
          ProviderChannelAlias
        >,
      ),
      ProviderChannelAlias,
      PrefetchHooks Function()
    >;

class $CanonicalChannelDatabaseManager {
  final _$CanonicalChannelDatabase _db;
  $CanonicalChannelDatabaseManager(this._db);
  $$CanonicalChannelsTableTableManager get canonicalChannels =>
      $$CanonicalChannelsTableTableManager(_db, _db.canonicalChannels);
  $$ProviderChannelAliasesTableTableManager get providerChannelAliases =>
      $$ProviderChannelAliasesTableTableManager(
        _db,
        _db.providerChannelAliases,
      );
}
