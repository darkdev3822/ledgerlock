// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LedgerEntriesTable extends LedgerEntries with TableInfo<$LedgerEntriesTable, LedgerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _isIncomeMeta = const VerificationMeta('isIncome');
  @override
  late final GeneratedColumn<bool> isIncome = GeneratedColumn<bool>(
    'is_income',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_income" IN (0, 1))'),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(minTextLength: 10, maxTextLength: 10),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feeCentsMeta = const VerificationMeta('feeCents');
  @override
  late final GeneratedColumn<int> feeCents = GeneratedColumn<int>(
    'fee_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _businessPctMeta = const VerificationMeta('businessPct');
  @override
  late final GeneratedColumn<int> businessPct = GeneratedColumn<int>(
    'business_pct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partyMeta = const VerificationMeta('party');
  @override
  late final GeneratedColumn<String> party = GeneratedColumn<String>(
    'party',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta('platform');
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isIncome,
    date,
    amountCents,
    feeCents,
    businessPct,
    category,
    party,
    platform,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_entries';
  @override
  VerificationContext validateIntegrity(Insertable<LedgerEntry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('is_income')) {
      context.handle(_isIncomeMeta, isIncome.isAcceptableOrUnknown(data['is_income']!, _isIncomeMeta));
    } else if (isInserting) {
      context.missing(_isIncomeMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('fee_cents')) {
      context.handle(_feeCentsMeta, feeCents.isAcceptableOrUnknown(data['fee_cents']!, _feeCentsMeta));
    }
    if (data.containsKey('business_pct')) {
      context.handle(
        _businessPctMeta,
        businessPct.isAcceptableOrUnknown(data['business_pct']!, _businessPctMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta, category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('party')) {
      context.handle(_partyMeta, party.isAcceptableOrUnknown(data['party']!, _partyMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(_platformMeta, platform.isAcceptableOrUnknown(data['platform']!, _platformMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerEntry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      isIncome: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_income'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      feeCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}fee_cents'])!,
      businessPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}business_pct'],
      )!,
      category: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      party: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}party'])!,
      platform: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}platform'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LedgerEntriesTable createAlias(String alias) {
    return $LedgerEntriesTable(attachedDatabase, alias);
  }
}

class LedgerEntry extends DataClass implements Insertable<LedgerEntry> {
  final int id;
  final bool isIncome;
  final String date;
  final int amountCents;
  final int feeCents;
  final int businessPct;
  final String category;
  final String party;
  final String platform;
  final String notes;
  final DateTime createdAt;
  const LedgerEntry({
    required this.id,
    required this.isIncome,
    required this.date,
    required this.amountCents,
    required this.feeCents,
    required this.businessPct,
    required this.category,
    required this.party,
    required this.platform,
    required this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['is_income'] = Variable<bool>(isIncome);
    map['date'] = Variable<String>(date);
    map['amount_cents'] = Variable<int>(amountCents);
    map['fee_cents'] = Variable<int>(feeCents);
    map['business_pct'] = Variable<int>(businessPct);
    map['category'] = Variable<String>(category);
    map['party'] = Variable<String>(party);
    map['platform'] = Variable<String>(platform);
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return LedgerEntriesCompanion(
      id: Value(id),
      isIncome: Value(isIncome),
      date: Value(date),
      amountCents: Value(amountCents),
      feeCents: Value(feeCents),
      businessPct: Value(businessPct),
      category: Value(category),
      party: Value(party),
      platform: Value(platform),
      notes: Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory LedgerEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerEntry(
      id: serializer.fromJson<int>(json['id']),
      isIncome: serializer.fromJson<bool>(json['isIncome']),
      date: serializer.fromJson<String>(json['date']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      feeCents: serializer.fromJson<int>(json['feeCents']),
      businessPct: serializer.fromJson<int>(json['businessPct']),
      category: serializer.fromJson<String>(json['category']),
      party: serializer.fromJson<String>(json['party']),
      platform: serializer.fromJson<String>(json['platform']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isIncome': serializer.toJson<bool>(isIncome),
      'date': serializer.toJson<String>(date),
      'amountCents': serializer.toJson<int>(amountCents),
      'feeCents': serializer.toJson<int>(feeCents),
      'businessPct': serializer.toJson<int>(businessPct),
      'category': serializer.toJson<String>(category),
      'party': serializer.toJson<String>(party),
      'platform': serializer.toJson<String>(platform),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LedgerEntry copyWith({
    int? id,
    bool? isIncome,
    String? date,
    int? amountCents,
    int? feeCents,
    int? businessPct,
    String? category,
    String? party,
    String? platform,
    String? notes,
    DateTime? createdAt,
  }) => LedgerEntry(
    id: id ?? this.id,
    isIncome: isIncome ?? this.isIncome,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    feeCents: feeCents ?? this.feeCents,
    businessPct: businessPct ?? this.businessPct,
    category: category ?? this.category,
    party: party ?? this.party,
    platform: platform ?? this.platform,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  LedgerEntry copyWithCompanion(LedgerEntriesCompanion data) {
    return LedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      isIncome: data.isIncome.present ? data.isIncome.value : this.isIncome,
      date: data.date.present ? data.date.value : this.date,
      amountCents: data.amountCents.present ? data.amountCents.value : this.amountCents,
      feeCents: data.feeCents.present ? data.feeCents.value : this.feeCents,
      businessPct: data.businessPct.present ? data.businessPct.value : this.businessPct,
      category: data.category.present ? data.category.value : this.category,
      party: data.party.present ? data.party.value : this.party,
      platform: data.platform.present ? data.platform.value : this.platform,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntry(')
          ..write('id: $id, ')
          ..write('isIncome: $isIncome, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('feeCents: $feeCents, ')
          ..write('businessPct: $businessPct, ')
          ..write('category: $category, ')
          ..write('party: $party, ')
          ..write('platform: $platform, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    isIncome,
    date,
    amountCents,
    feeCents,
    businessPct,
    category,
    party,
    platform,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerEntry &&
          other.id == this.id &&
          other.isIncome == this.isIncome &&
          other.date == this.date &&
          other.amountCents == this.amountCents &&
          other.feeCents == this.feeCents &&
          other.businessPct == this.businessPct &&
          other.category == this.category &&
          other.party == this.party &&
          other.platform == this.platform &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class LedgerEntriesCompanion extends UpdateCompanion<LedgerEntry> {
  final Value<int> id;
  final Value<bool> isIncome;
  final Value<String> date;
  final Value<int> amountCents;
  final Value<int> feeCents;
  final Value<int> businessPct;
  final Value<String> category;
  final Value<String> party;
  final Value<String> platform;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  const LedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.isIncome = const Value.absent(),
    this.date = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.feeCents = const Value.absent(),
    this.businessPct = const Value.absent(),
    this.category = const Value.absent(),
    this.party = const Value.absent(),
    this.platform = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LedgerEntriesCompanion.insert({
    this.id = const Value.absent(),
    required bool isIncome,
    required String date,
    required int amountCents,
    this.feeCents = const Value.absent(),
    this.businessPct = const Value.absent(),
    required String category,
    this.party = const Value.absent(),
    this.platform = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : isIncome = Value(isIncome),
       date = Value(date),
       amountCents = Value(amountCents),
       category = Value(category);
  static Insertable<LedgerEntry> custom({
    Expression<int>? id,
    Expression<bool>? isIncome,
    Expression<String>? date,
    Expression<int>? amountCents,
    Expression<int>? feeCents,
    Expression<int>? businessPct,
    Expression<String>? category,
    Expression<String>? party,
    Expression<String>? platform,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isIncome != null) 'is_income': isIncome,
      if (date != null) 'date': date,
      if (amountCents != null) 'amount_cents': amountCents,
      if (feeCents != null) 'fee_cents': feeCents,
      if (businessPct != null) 'business_pct': businessPct,
      if (category != null) 'category': category,
      if (party != null) 'party': party,
      if (platform != null) 'platform': platform,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LedgerEntriesCompanion copyWith({
    Value<int>? id,
    Value<bool>? isIncome,
    Value<String>? date,
    Value<int>? amountCents,
    Value<int>? feeCents,
    Value<int>? businessPct,
    Value<String>? category,
    Value<String>? party,
    Value<String>? platform,
    Value<String>? notes,
    Value<DateTime>? createdAt,
  }) {
    return LedgerEntriesCompanion(
      id: id ?? this.id,
      isIncome: isIncome ?? this.isIncome,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      feeCents: feeCents ?? this.feeCents,
      businessPct: businessPct ?? this.businessPct,
      category: category ?? this.category,
      party: party ?? this.party,
      platform: platform ?? this.platform,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isIncome.present) {
      map['is_income'] = Variable<bool>(isIncome.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (feeCents.present) {
      map['fee_cents'] = Variable<int>(feeCents.value);
    }
    if (businessPct.present) {
      map['business_pct'] = Variable<int>(businessPct.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (party.present) {
      map['party'] = Variable<String>(party.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('isIncome: $isIncome, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('feeCents: $feeCents, ')
          ..write('businessPct: $businessPct, ')
          ..write('category: $category, ')
          ..write('party: $party, ')
          ..write('platform: $platform, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _folderMeta = const VerificationMeta('folder');
  @override
  late final GeneratedColumn<String> folder = GeneratedColumn<String>(
    'folder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta('entryId');
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ledger_entries (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbIdMeta = const VerificationMeta('thumbId');
  @override
  late final GeneratedColumn<String> thumbId = GeneratedColumn<String>(
    'thumb_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folder,
    year,
    entryId,
    fileId,
    thumbId,
    name,
    mime,
    sizeBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(Insertable<Attachment> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder')) {
      context.handle(_folderMeta, folder.isAcceptableOrUnknown(data['folder']!, _folderMeta));
    } else if (isInserting) {
      context.missing(_folderMeta);
    }
    if (data.containsKey('year')) {
      context.handle(_yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(_entryIdMeta, entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta));
    }
    if (data.containsKey('file_id')) {
      context.handle(_fileIdMeta, fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta));
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('thumb_id')) {
      context.handle(_thumbIdMeta, thumbId.isAcceptableOrUnknown(data['thumb_id']!, _thumbIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('mime')) {
      context.handle(_mimeMeta, mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta));
    } else if (isInserting) {
      context.missing(_mimeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta, sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      folder: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}folder'])!,
      year: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}year'])!,
      entryId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}entry_id']),
      fileId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}file_id'])!,
      thumbId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}thumb_id']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      mime: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mime'])!,
      sizeBytes: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final int id;

  /// 'receipt', 'tax_form' (W-2/1099), 'prior_return', 'letter', 'other'.
  final String folder;
  final int year;

  /// Linked ledger entry (receipts); null = unmatched.
  final int? entryId;
  final String fileId;
  final String? thumbId;
  final String name;
  final String mime;
  final int sizeBytes;
  final DateTime createdAt;
  const Attachment({
    required this.id,
    required this.folder,
    required this.year,
    this.entryId,
    required this.fileId,
    this.thumbId,
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder'] = Variable<String>(folder);
    map['year'] = Variable<int>(year);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<int>(entryId);
    }
    map['file_id'] = Variable<String>(fileId);
    if (!nullToAbsent || thumbId != null) {
      map['thumb_id'] = Variable<String>(thumbId);
    }
    map['name'] = Variable<String>(name);
    map['mime'] = Variable<String>(mime);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      folder: Value(folder),
      year: Value(year),
      entryId: entryId == null && nullToAbsent ? const Value.absent() : Value(entryId),
      fileId: Value(fileId),
      thumbId: thumbId == null && nullToAbsent ? const Value.absent() : Value(thumbId),
      name: Value(name),
      mime: Value(mime),
      sizeBytes: Value(sizeBytes),
      createdAt: Value(createdAt),
    );
  }

  factory Attachment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<int>(json['id']),
      folder: serializer.fromJson<String>(json['folder']),
      year: serializer.fromJson<int>(json['year']),
      entryId: serializer.fromJson<int?>(json['entryId']),
      fileId: serializer.fromJson<String>(json['fileId']),
      thumbId: serializer.fromJson<String?>(json['thumbId']),
      name: serializer.fromJson<String>(json['name']),
      mime: serializer.fromJson<String>(json['mime']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folder': serializer.toJson<String>(folder),
      'year': serializer.toJson<int>(year),
      'entryId': serializer.toJson<int?>(entryId),
      'fileId': serializer.toJson<String>(fileId),
      'thumbId': serializer.toJson<String?>(thumbId),
      'name': serializer.toJson<String>(name),
      'mime': serializer.toJson<String>(mime),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Attachment copyWith({
    int? id,
    String? folder,
    int? year,
    Value<int?> entryId = const Value.absent(),
    String? fileId,
    Value<String?> thumbId = const Value.absent(),
    String? name,
    String? mime,
    int? sizeBytes,
    DateTime? createdAt,
  }) => Attachment(
    id: id ?? this.id,
    folder: folder ?? this.folder,
    year: year ?? this.year,
    entryId: entryId.present ? entryId.value : this.entryId,
    fileId: fileId ?? this.fileId,
    thumbId: thumbId.present ? thumbId.value : this.thumbId,
    name: name ?? this.name,
    mime: mime ?? this.mime,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      folder: data.folder.present ? data.folder.value : this.folder,
      year: data.year.present ? data.year.value : this.year,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      thumbId: data.thumbId.present ? data.thumbId.value : this.thumbId,
      name: data.name.present ? data.name.value : this.name,
      mime: data.mime.present ? data.mime.value : this.mime,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('folder: $folder, ')
          ..write('year: $year, ')
          ..write('entryId: $entryId, ')
          ..write('fileId: $fileId, ')
          ..write('thumbId: $thumbId, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, folder, year, entryId, fileId, thumbId, name, mime, sizeBytes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.folder == this.folder &&
          other.year == this.year &&
          other.entryId == this.entryId &&
          other.fileId == this.fileId &&
          other.thumbId == this.thumbId &&
          other.name == this.name &&
          other.mime == this.mime &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<int> id;
  final Value<String> folder;
  final Value<int> year;
  final Value<int?> entryId;
  final Value<String> fileId;
  final Value<String?> thumbId;
  final Value<String> name;
  final Value<String> mime;
  final Value<int> sizeBytes;
  final Value<DateTime> createdAt;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.folder = const Value.absent(),
    this.year = const Value.absent(),
    this.entryId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.thumbId = const Value.absent(),
    this.name = const Value.absent(),
    this.mime = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    required String folder,
    required int year,
    this.entryId = const Value.absent(),
    required String fileId,
    this.thumbId = const Value.absent(),
    this.name = const Value.absent(),
    required String mime,
    required int sizeBytes,
    this.createdAt = const Value.absent(),
  }) : folder = Value(folder),
       year = Value(year),
       fileId = Value(fileId),
       mime = Value(mime),
       sizeBytes = Value(sizeBytes);
  static Insertable<Attachment> custom({
    Expression<int>? id,
    Expression<String>? folder,
    Expression<int>? year,
    Expression<int>? entryId,
    Expression<String>? fileId,
    Expression<String>? thumbId,
    Expression<String>? name,
    Expression<String>? mime,
    Expression<int>? sizeBytes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folder != null) 'folder': folder,
      if (year != null) 'year': year,
      if (entryId != null) 'entry_id': entryId,
      if (fileId != null) 'file_id': fileId,
      if (thumbId != null) 'thumb_id': thumbId,
      if (name != null) 'name': name,
      if (mime != null) 'mime': mime,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<String>? folder,
    Value<int>? year,
    Value<int?>? entryId,
    Value<String>? fileId,
    Value<String?>? thumbId,
    Value<String>? name,
    Value<String>? mime,
    Value<int>? sizeBytes,
    Value<DateTime>? createdAt,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      folder: folder ?? this.folder,
      year: year ?? this.year,
      entryId: entryId ?? this.entryId,
      fileId: fileId ?? this.fileId,
      thumbId: thumbId ?? this.thumbId,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folder.present) {
      map['folder'] = Variable<String>(folder.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (thumbId.present) {
      map['thumb_id'] = Variable<String>(thumbId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('folder: $folder, ')
          ..write('year: $year, ')
          ..write('entryId: $entryId, ')
          ..write('fileId: $fileId, ')
          ..write('thumbId: $thumbId, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $LedgerEntriesTable ledgerEntries = $LedgerEntriesTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [settings, ledgerEntries, attachments];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('ledger_entries', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('attachments', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, Setting>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, Setting>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$LedgerEntriesTableCreateCompanionBuilder = LedgerEntriesCompanion Function({
  Value<int> id,
  required bool isIncome,
  required String date,
  required int amountCents,
  Value<int> feeCents,
  Value<int> businessPct,
  required String category,
  Value<String> party,
  Value<String> platform,
  Value<String> notes,
  Value<DateTime> createdAt,
});
typedef $$LedgerEntriesTableUpdateCompanionBuilder = LedgerEntriesCompanion Function({
  Value<int> id,
  Value<bool> isIncome,
  Value<String> date,
  Value<int> amountCents,
  Value<int> feeCents,
  Value<int> businessPct,
  Value<String> category,
  Value<String> party,
  Value<String> platform,
  Value<String> notes,
  Value<DateTime> createdAt,
});

final class $$LedgerEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $LedgerEntriesTable, LedgerEntry> {
  $$LedgerEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>> _attachmentsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.attachments, aliasName: 'ledger_entries__id__attachments__entry_id');

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LedgerEntriesTableFilterComposer extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get feeCents =>
      $composableBuilder(column: $table.feeCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get businessPct =>
      $composableBuilder(column: $table.businessPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get party =>
      $composableBuilder(column: $table.party, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> attachmentsRefs(Expression<bool> Function($$AttachmentsTableFilterComposer f) f) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgerEntriesTableOrderingComposer extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get feeCents =>
      $composableBuilder(column: $table.feeCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get businessPct =>
      $composableBuilder(column: $table.businessPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get party =>
      $composableBuilder(column: $table.party, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LedgerEntriesTableAnnotationComposer extends Composer<_$AppDatabase, $LedgerEntriesTable> {
  $$LedgerEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<int> get feeCents =>
      $composableBuilder(column: $table.feeCents, builder: (column) => column);

  GeneratedColumn<int> get businessPct =>
      $composableBuilder(column: $table.businessPct, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get party => $composableBuilder(column: $table.party, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.entryId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LedgerEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerEntriesTable,
          LedgerEntry,
          $$LedgerEntriesTableFilterComposer,
          $$LedgerEntriesTableOrderingComposer,
          $$LedgerEntriesTableAnnotationComposer,
          $$LedgerEntriesTableCreateCompanionBuilder,
          $$LedgerEntriesTableUpdateCompanionBuilder,
          (LedgerEntry, $$LedgerEntriesTableReferences),
          LedgerEntry,
          PrefetchHooks Function({bool attachmentsRefs})
        > {
  $$LedgerEntriesTableTableManager(_$AppDatabase db, $LedgerEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LedgerEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LedgerEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LedgerEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isIncome = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<int> feeCents = const Value.absent(),
                Value<int> businessPct = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> party = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LedgerEntriesCompanion(
                id: id,
                isIncome: isIncome,
                date: date,
                amountCents: amountCents,
                feeCents: feeCents,
                businessPct: businessPct,
                category: category,
                party: party,
                platform: platform,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required bool isIncome,
                required String date,
                required int amountCents,
                Value<int> feeCents = const Value.absent(),
                Value<int> businessPct = const Value.absent(),
                required String category,
                Value<String> party = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => LedgerEntriesCompanion.insert(
                id: id,
                isIncome: isIncome,
                date: date,
                amountCents: amountCents,
                feeCents: feeCents,
                businessPct: businessPct,
                category: category,
                party: party,
                platform: platform,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LedgerEntriesTable, LedgerEntry>(table),
                  $$LedgerEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({attachmentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (attachmentsRefs) db.attachments],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (attachmentsRefs)
                    await $_getPrefetchedDataByColumns<
                      LedgerEntry,
                      $LedgerEntriesTable,
                      Attachment,
                      $AttachmentsTable
                    >(
                      currentTable: table,
                      referencedTable: $$LedgerEntriesTableReferences._attachmentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LedgerEntriesTableReferences(db, table, p0).attachmentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'entry_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LedgerEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerEntriesTable,
      LedgerEntry,
      $$LedgerEntriesTableFilterComposer,
      $$LedgerEntriesTableOrderingComposer,
      $$LedgerEntriesTableAnnotationComposer,
      $$LedgerEntriesTableCreateCompanionBuilder,
      $$LedgerEntriesTableUpdateCompanionBuilder,
      (LedgerEntry, $$LedgerEntriesTableReferences),
      LedgerEntry,
      PrefetchHooks Function({bool attachmentsRefs})
    >;
typedef $$AttachmentsTableCreateCompanionBuilder = AttachmentsCompanion Function({
  Value<int> id,
  required String folder,
  required int year,
  Value<int?> entryId,
  required String fileId,
  Value<String?> thumbId,
  Value<String> name,
  required String mime,
  required int sizeBytes,
  Value<DateTime> createdAt,
});
typedef $$AttachmentsTableUpdateCompanionBuilder = AttachmentsCompanion Function({
  Value<int> id,
  Value<String> folder,
  Value<int> year,
  Value<int?> entryId,
  Value<String> fileId,
  Value<String?> thumbId,
  Value<String> name,
  Value<String> mime,
  Value<int> sizeBytes,
  Value<DateTime> createdAt,
});

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LedgerEntriesTable _entryIdTable(_$AppDatabase db) =>
      db.ledgerEntries.createAlias('attachments__entry_id__ledger_entries__id');

  $$LedgerEntriesTableProcessedTableManager? get entryId {
    final $_column = $_itemColumn<int>('entry_id');
    if ($_column == null) return null;
    final manager = $$LedgerEntriesTableTableManager(
      $_db,
      $_db.ledgerEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$AttachmentsTableFilterComposer extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbId =>
      $composableBuilder(column: $table.thumbId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$LedgerEntriesTableFilterComposer get entryId {
    final $$LedgerEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.ledgerEntries,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$LedgerEntriesTableFilterComposer(
            $db: $db,
            $table: $db.ledgerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbId =>
      $composableBuilder(column: $table.thumbId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$LedgerEntriesTableOrderingComposer get entryId {
    final $$LedgerEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.ledgerEntries,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$LedgerEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.ledgerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<int> get year => $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get thumbId =>
      $composableBuilder(column: $table.thumbId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$LedgerEntriesTableAnnotationComposer get entryId {
    final $$LedgerEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.ledgerEntries,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$LedgerEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.ledgerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool entryId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> folder = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<int?> entryId = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<String?> thumbId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mime = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                folder: folder,
                year: year,
                entryId: entryId,
                fileId: fileId,
                thumbId: thumbId,
                name: name,
                mime: mime,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String folder,
                required int year,
                Value<int?> entryId = const Value.absent(),
                required String fileId,
                Value<String?> thumbId = const Value.absent(),
                Value<String> name = const Value.absent(),
                required String mime,
                required int sizeBytes,
                Value<DateTime> createdAt = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                folder: folder,
                year: year,
                entryId: entryId,
                fileId: fileId,
                thumbId: thumbId,
                name: name,
                mime: mime,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (entryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.entryId,
                        referencedTable: $$AttachmentsTableReferences._entryIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences._entryIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool entryId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings => $$SettingsTableTableManager(_db, _db.settings);
  $$LedgerEntriesTableTableManager get ledgerEntries =>
      $$LedgerEntriesTableTableManager(_db, _db.ledgerEntries);
  $$AttachmentsTableTableManager get attachments => $$AttachmentsTableTableManager(_db, _db.attachments);
}
