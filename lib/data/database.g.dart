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
    return Setting(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
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
  static Insertable<Setting> custom({Expression<String>? key, Expression<String>? value, Expression<int>? rowid}) {
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
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<bool> paid = GeneratedColumn<bool>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("paid" IN (0, 1))'),
    defaultValue: const Constant(true),
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
    paid,
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
      context.handle(_amountCentsMeta, amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('fee_cents')) {
      context.handle(_feeCentsMeta, feeCents.isAcceptableOrUnknown(data['fee_cents']!, _feeCentsMeta));
    }
    if (data.containsKey('business_pct')) {
      context.handle(_businessPctMeta, businessPct.isAcceptableOrUnknown(data['business_pct']!, _businessPctMeta));
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
    if (data.containsKey('paid')) {
      context.handle(_paidMeta, paid.isAcceptableOrUnknown(data['paid']!, _paidMeta));
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
      amountCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      feeCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}fee_cents'])!,
      businessPct: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}business_pct'])!,
      category: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      party: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}party'])!,
      platform: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}platform'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      paid: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}paid'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
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

  /// Income only: false = invoiced, not paid yet (excluded from totals: cash basis). SPEC §2.13.
  final bool paid;
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
    required this.paid,
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
    map['paid'] = Variable<bool>(paid);
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
      paid: Value(paid),
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
      paid: serializer.fromJson<bool>(json['paid']),
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
      'paid': serializer.toJson<bool>(paid),
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
    bool? paid,
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
    paid: paid ?? this.paid,
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
      paid: data.paid.present ? data.paid.value : this.paid,
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
          ..write('paid: $paid, ')
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
    paid,
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
          other.paid == this.paid &&
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
  final Value<bool> paid;
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
    this.paid = const Value.absent(),
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
    this.paid = const Value.absent(),
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
    Expression<bool>? paid,
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
      if (paid != null) 'paid': paid,
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
    Value<bool>? paid,
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
      paid: paid ?? this.paid,
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
    if (paid.present) {
      map['paid'] = Variable<bool>(paid.value);
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
          ..write('paid: $paid, ')
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
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES ledger_entries (id) ON DELETE SET NULL'),
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
  List<GeneratedColumn> get $columns => [id, folder, year, entryId, fileId, thumbId, name, mime, sizeBytes, createdAt];
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
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
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
  int get hashCode => Object.hash(id, folder, year, entryId, fileId, thumbId, name, mime, sizeBytes, createdAt);
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

class $TaxPaymentsTable extends TaxPayments with TableInfo<$TaxPaymentsTable, TaxPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaxPaymentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _taxYearMeta = const VerificationMeta('taxYear');
  @override
  late final GeneratedColumn<int> taxYear = GeneratedColumn<int>(
    'tax_year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quarterMeta = const VerificationMeta('quarter');
  @override
  late final GeneratedColumn<String> quarter = GeneratedColumn<String>(
    'quarter',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
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
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
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
  @override
  List<GeneratedColumn> get $columns => [id, taxYear, quarter, date, amountCents, method, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tax_payments';
  @override
  VerificationContext validateIntegrity(Insertable<TaxPayment> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tax_year')) {
      context.handle(_taxYearMeta, taxYear.isAcceptableOrUnknown(data['tax_year']!, _taxYearMeta));
    } else if (isInserting) {
      context.missing(_taxYearMeta);
    }
    if (data.containsKey('quarter')) {
      context.handle(_quarterMeta, quarter.isAcceptableOrUnknown(data['quarter']!, _quarterMeta));
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(_amountCentsMeta, amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta, method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaxPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaxPayment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      taxYear: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tax_year'])!,
      quarter: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}quarter'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      amountCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      method: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      notes: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
    );
  }

  @override
  $TaxPaymentsTable createAlias(String alias) {
    return $TaxPaymentsTable(attachedDatabase, alias);
  }
}

class TaxPayment extends DataClass implements Insertable<TaxPayment> {
  final int id;
  final int taxYear;
  final String quarter;
  final String date;
  final int amountCents;
  final String method;
  final String notes;
  const TaxPayment({
    required this.id,
    required this.taxYear,
    required this.quarter,
    required this.date,
    required this.amountCents,
    required this.method,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tax_year'] = Variable<int>(taxYear);
    map['quarter'] = Variable<String>(quarter);
    map['date'] = Variable<String>(date);
    map['amount_cents'] = Variable<int>(amountCents);
    map['method'] = Variable<String>(method);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  TaxPaymentsCompanion toCompanion(bool nullToAbsent) {
    return TaxPaymentsCompanion(
      id: Value(id),
      taxYear: Value(taxYear),
      quarter: Value(quarter),
      date: Value(date),
      amountCents: Value(amountCents),
      method: Value(method),
      notes: Value(notes),
    );
  }

  factory TaxPayment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaxPayment(
      id: serializer.fromJson<int>(json['id']),
      taxYear: serializer.fromJson<int>(json['taxYear']),
      quarter: serializer.fromJson<String>(json['quarter']),
      date: serializer.fromJson<String>(json['date']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      method: serializer.fromJson<String>(json['method']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taxYear': serializer.toJson<int>(taxYear),
      'quarter': serializer.toJson<String>(quarter),
      'date': serializer.toJson<String>(date),
      'amountCents': serializer.toJson<int>(amountCents),
      'method': serializer.toJson<String>(method),
      'notes': serializer.toJson<String>(notes),
    };
  }

  TaxPayment copyWith({
    int? id,
    int? taxYear,
    String? quarter,
    String? date,
    int? amountCents,
    String? method,
    String? notes,
  }) => TaxPayment(
    id: id ?? this.id,
    taxYear: taxYear ?? this.taxYear,
    quarter: quarter ?? this.quarter,
    date: date ?? this.date,
    amountCents: amountCents ?? this.amountCents,
    method: method ?? this.method,
    notes: notes ?? this.notes,
  );
  TaxPayment copyWithCompanion(TaxPaymentsCompanion data) {
    return TaxPayment(
      id: data.id.present ? data.id.value : this.id,
      taxYear: data.taxYear.present ? data.taxYear.value : this.taxYear,
      quarter: data.quarter.present ? data.quarter.value : this.quarter,
      date: data.date.present ? data.date.value : this.date,
      amountCents: data.amountCents.present ? data.amountCents.value : this.amountCents,
      method: data.method.present ? data.method.value : this.method,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaxPayment(')
          ..write('id: $id, ')
          ..write('taxYear: $taxYear, ')
          ..write('quarter: $quarter, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('method: $method, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taxYear, quarter, date, amountCents, method, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaxPayment &&
          other.id == this.id &&
          other.taxYear == this.taxYear &&
          other.quarter == this.quarter &&
          other.date == this.date &&
          other.amountCents == this.amountCents &&
          other.method == this.method &&
          other.notes == this.notes);
}

class TaxPaymentsCompanion extends UpdateCompanion<TaxPayment> {
  final Value<int> id;
  final Value<int> taxYear;
  final Value<String> quarter;
  final Value<String> date;
  final Value<int> amountCents;
  final Value<String> method;
  final Value<String> notes;
  const TaxPaymentsCompanion({
    this.id = const Value.absent(),
    this.taxYear = const Value.absent(),
    this.quarter = const Value.absent(),
    this.date = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.method = const Value.absent(),
    this.notes = const Value.absent(),
  });
  TaxPaymentsCompanion.insert({
    this.id = const Value.absent(),
    required int taxYear,
    this.quarter = const Value.absent(),
    required String date,
    required int amountCents,
    this.method = const Value.absent(),
    this.notes = const Value.absent(),
  }) : taxYear = Value(taxYear),
       date = Value(date),
       amountCents = Value(amountCents);
  static Insertable<TaxPayment> custom({
    Expression<int>? id,
    Expression<int>? taxYear,
    Expression<String>? quarter,
    Expression<String>? date,
    Expression<int>? amountCents,
    Expression<String>? method,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taxYear != null) 'tax_year': taxYear,
      if (quarter != null) 'quarter': quarter,
      if (date != null) 'date': date,
      if (amountCents != null) 'amount_cents': amountCents,
      if (method != null) 'method': method,
      if (notes != null) 'notes': notes,
    });
  }

  TaxPaymentsCompanion copyWith({
    Value<int>? id,
    Value<int>? taxYear,
    Value<String>? quarter,
    Value<String>? date,
    Value<int>? amountCents,
    Value<String>? method,
    Value<String>? notes,
  }) {
    return TaxPaymentsCompanion(
      id: id ?? this.id,
      taxYear: taxYear ?? this.taxYear,
      quarter: quarter ?? this.quarter,
      date: date ?? this.date,
      amountCents: amountCents ?? this.amountCents,
      method: method ?? this.method,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taxYear.present) {
      map['tax_year'] = Variable<int>(taxYear.value);
    }
    if (quarter.present) {
      map['quarter'] = Variable<String>(quarter.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaxPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('taxYear: $taxYear, ')
          ..write('quarter: $quarter, ')
          ..write('date: $date, ')
          ..write('amountCents: $amountCents, ')
          ..write('method: $method, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $TripsTable extends Trips with TableInfo<$TripsTable, Trip> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TripsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _milesTenthsMeta = const VerificationMeta('milesTenths');
  @override
  late final GeneratedColumn<int> milesTenths = GeneratedColumn<int>(
    'miles_tenths',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purposeMeta = const VerificationMeta('purpose');
  @override
  late final GeneratedColumn<String> purpose = GeneratedColumn<String>(
    'purpose',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, milesTenths, purpose, route];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trips';
  @override
  VerificationContext validateIntegrity(Insertable<Trip> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('miles_tenths')) {
      context.handle(_milesTenthsMeta, milesTenths.isAcceptableOrUnknown(data['miles_tenths']!, _milesTenthsMeta));
    } else if (isInserting) {
      context.missing(_milesTenthsMeta);
    }
    if (data.containsKey('purpose')) {
      context.handle(_purposeMeta, purpose.isAcceptableOrUnknown(data['purpose']!, _purposeMeta));
    }
    if (data.containsKey('route')) {
      context.handle(_routeMeta, route.isAcceptableOrUnknown(data['route']!, _routeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Trip map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Trip(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      milesTenths: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}miles_tenths'])!,
      purpose: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}purpose'])!,
      route: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}route'])!,
    );
  }

  @override
  $TripsTable createAlias(String alias) {
    return $TripsTable(attachedDatabase, alias);
  }
}

class Trip extends DataClass implements Insertable<Trip> {
  final int id;
  final String date;
  final int milesTenths;
  final String purpose;
  final String route;
  const Trip({
    required this.id,
    required this.date,
    required this.milesTenths,
    required this.purpose,
    required this.route,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<String>(date);
    map['miles_tenths'] = Variable<int>(milesTenths);
    map['purpose'] = Variable<String>(purpose);
    map['route'] = Variable<String>(route);
    return map;
  }

  TripsCompanion toCompanion(bool nullToAbsent) {
    return TripsCompanion(
      id: Value(id),
      date: Value(date),
      milesTenths: Value(milesTenths),
      purpose: Value(purpose),
      route: Value(route),
    );
  }

  factory Trip.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Trip(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      milesTenths: serializer.fromJson<int>(json['milesTenths']),
      purpose: serializer.fromJson<String>(json['purpose']),
      route: serializer.fromJson<String>(json['route']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<String>(date),
      'milesTenths': serializer.toJson<int>(milesTenths),
      'purpose': serializer.toJson<String>(purpose),
      'route': serializer.toJson<String>(route),
    };
  }

  Trip copyWith({int? id, String? date, int? milesTenths, String? purpose, String? route}) => Trip(
    id: id ?? this.id,
    date: date ?? this.date,
    milesTenths: milesTenths ?? this.milesTenths,
    purpose: purpose ?? this.purpose,
    route: route ?? this.route,
  );
  Trip copyWithCompanion(TripsCompanion data) {
    return Trip(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      milesTenths: data.milesTenths.present ? data.milesTenths.value : this.milesTenths,
      purpose: data.purpose.present ? data.purpose.value : this.purpose,
      route: data.route.present ? data.route.value : this.route,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Trip(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('milesTenths: $milesTenths, ')
          ..write('purpose: $purpose, ')
          ..write('route: $route')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, milesTenths, purpose, route);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Trip &&
          other.id == this.id &&
          other.date == this.date &&
          other.milesTenths == this.milesTenths &&
          other.purpose == this.purpose &&
          other.route == this.route);
}

class TripsCompanion extends UpdateCompanion<Trip> {
  final Value<int> id;
  final Value<String> date;
  final Value<int> milesTenths;
  final Value<String> purpose;
  final Value<String> route;
  const TripsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.milesTenths = const Value.absent(),
    this.purpose = const Value.absent(),
    this.route = const Value.absent(),
  });
  TripsCompanion.insert({
    this.id = const Value.absent(),
    required String date,
    required int milesTenths,
    this.purpose = const Value.absent(),
    this.route = const Value.absent(),
  }) : date = Value(date),
       milesTenths = Value(milesTenths);
  static Insertable<Trip> custom({
    Expression<int>? id,
    Expression<String>? date,
    Expression<int>? milesTenths,
    Expression<String>? purpose,
    Expression<String>? route,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (milesTenths != null) 'miles_tenths': milesTenths,
      if (purpose != null) 'purpose': purpose,
      if (route != null) 'route': route,
    });
  }

  TripsCompanion copyWith({
    Value<int>? id,
    Value<String>? date,
    Value<int>? milesTenths,
    Value<String>? purpose,
    Value<String>? route,
  }) {
    return TripsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      milesTenths: milesTenths ?? this.milesTenths,
      purpose: purpose ?? this.purpose,
      route: route ?? this.route,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (milesTenths.present) {
      map['miles_tenths'] = Variable<int>(milesTenths.value);
    }
    if (purpose.present) {
      map['purpose'] = Variable<String>(purpose.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TripsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('milesTenths: $milesTenths, ')
          ..write('purpose: $purpose, ')
          ..write('route: $route')
          ..write(')'))
        .toString();
  }
}

class $Forms1099Table extends Forms1099 with TableInfo<$Forms1099Table, Form1099> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $Forms1099Table(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payerMeta = const VerificationMeta('payer');
  @override
  late final GeneratedColumn<String> payer = GeneratedColumn<String>(
    'payer',
    aliasedName,
    false,
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
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta('attachmentId');
  @override
  late final GeneratedColumn<int> attachmentId = GeneratedColumn<int>(
    'attachment_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES attachments (id) ON DELETE SET NULL'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, year, kind, payer, amountCents, attachmentId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'forms1099';
  @override
  VerificationContext validateIntegrity(Insertable<Form1099> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('year')) {
      context.handle(_yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    } else if (isInserting) {
      context.missing(_yearMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('payer')) {
      context.handle(_payerMeta, payer.isAcceptableOrUnknown(data['payer']!, _payerMeta));
    } else if (isInserting) {
      context.missing(_payerMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(_amountCentsMeta, amountCents.isAcceptableOrUnknown(data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('attachment_id')) {
      context.handle(_attachmentIdMeta, attachmentId.isAcceptableOrUnknown(data['attachment_id']!, _attachmentIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Form1099 map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Form1099(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      year: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}year'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      payer: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}payer'])!,
      amountCents: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      attachmentId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}attachment_id']),
    );
  }

  @override
  $Forms1099Table createAlias(String alias) {
    return $Forms1099Table(attachedDatabase, alias);
  }
}

class Form1099 extends DataClass implements Insertable<Form1099> {
  final int id;
  final int year;
  final String kind;
  final String payer;
  final int amountCents;
  final int? attachmentId;
  const Form1099({
    required this.id,
    required this.year,
    required this.kind,
    required this.payer,
    required this.amountCents,
    this.attachmentId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['year'] = Variable<int>(year);
    map['kind'] = Variable<String>(kind);
    map['payer'] = Variable<String>(payer);
    map['amount_cents'] = Variable<int>(amountCents);
    if (!nullToAbsent || attachmentId != null) {
      map['attachment_id'] = Variable<int>(attachmentId);
    }
    return map;
  }

  Forms1099Companion toCompanion(bool nullToAbsent) {
    return Forms1099Companion(
      id: Value(id),
      year: Value(year),
      kind: Value(kind),
      payer: Value(payer),
      amountCents: Value(amountCents),
      attachmentId: attachmentId == null && nullToAbsent ? const Value.absent() : Value(attachmentId),
    );
  }

  factory Form1099.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Form1099(
      id: serializer.fromJson<int>(json['id']),
      year: serializer.fromJson<int>(json['year']),
      kind: serializer.fromJson<String>(json['kind']),
      payer: serializer.fromJson<String>(json['payer']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      attachmentId: serializer.fromJson<int?>(json['attachmentId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'year': serializer.toJson<int>(year),
      'kind': serializer.toJson<String>(kind),
      'payer': serializer.toJson<String>(payer),
      'amountCents': serializer.toJson<int>(amountCents),
      'attachmentId': serializer.toJson<int?>(attachmentId),
    };
  }

  Form1099 copyWith({
    int? id,
    int? year,
    String? kind,
    String? payer,
    int? amountCents,
    Value<int?> attachmentId = const Value.absent(),
  }) => Form1099(
    id: id ?? this.id,
    year: year ?? this.year,
    kind: kind ?? this.kind,
    payer: payer ?? this.payer,
    amountCents: amountCents ?? this.amountCents,
    attachmentId: attachmentId.present ? attachmentId.value : this.attachmentId,
  );
  Form1099 copyWithCompanion(Forms1099Companion data) {
    return Form1099(
      id: data.id.present ? data.id.value : this.id,
      year: data.year.present ? data.year.value : this.year,
      kind: data.kind.present ? data.kind.value : this.kind,
      payer: data.payer.present ? data.payer.value : this.payer,
      amountCents: data.amountCents.present ? data.amountCents.value : this.amountCents,
      attachmentId: data.attachmentId.present ? data.attachmentId.value : this.attachmentId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Form1099(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('kind: $kind, ')
          ..write('payer: $payer, ')
          ..write('amountCents: $amountCents, ')
          ..write('attachmentId: $attachmentId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, year, kind, payer, amountCents, attachmentId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Form1099 &&
          other.id == this.id &&
          other.year == this.year &&
          other.kind == this.kind &&
          other.payer == this.payer &&
          other.amountCents == this.amountCents &&
          other.attachmentId == this.attachmentId);
}

class Forms1099Companion extends UpdateCompanion<Form1099> {
  final Value<int> id;
  final Value<int> year;
  final Value<String> kind;
  final Value<String> payer;
  final Value<int> amountCents;
  final Value<int?> attachmentId;
  const Forms1099Companion({
    this.id = const Value.absent(),
    this.year = const Value.absent(),
    this.kind = const Value.absent(),
    this.payer = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.attachmentId = const Value.absent(),
  });
  Forms1099Companion.insert({
    this.id = const Value.absent(),
    required int year,
    required String kind,
    required String payer,
    required int amountCents,
    this.attachmentId = const Value.absent(),
  }) : year = Value(year),
       kind = Value(kind),
       payer = Value(payer),
       amountCents = Value(amountCents);
  static Insertable<Form1099> custom({
    Expression<int>? id,
    Expression<int>? year,
    Expression<String>? kind,
    Expression<String>? payer,
    Expression<int>? amountCents,
    Expression<int>? attachmentId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (year != null) 'year': year,
      if (kind != null) 'kind': kind,
      if (payer != null) 'payer': payer,
      if (amountCents != null) 'amount_cents': amountCents,
      if (attachmentId != null) 'attachment_id': attachmentId,
    });
  }

  Forms1099Companion copyWith({
    Value<int>? id,
    Value<int>? year,
    Value<String>? kind,
    Value<String>? payer,
    Value<int>? amountCents,
    Value<int?>? attachmentId,
  }) {
    return Forms1099Companion(
      id: id ?? this.id,
      year: year ?? this.year,
      kind: kind ?? this.kind,
      payer: payer ?? this.payer,
      amountCents: amountCents ?? this.amountCents,
      attachmentId: attachmentId ?? this.attachmentId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (payer.present) {
      map['payer'] = Variable<String>(payer.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (attachmentId.present) {
      map['attachment_id'] = Variable<int>(attachmentId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('Forms1099Companion(')
          ..write('id: $id, ')
          ..write('year: $year, ')
          ..write('kind: $kind, ')
          ..write('payer: $payer, ')
          ..write('amountCents: $amountCents, ')
          ..write('attachmentId: $attachmentId')
          ..write(')'))
        .toString();
  }
}

class $CategoryRulesTable extends CategoryRules with TableInfo<$CategoryRulesTable, CategoryRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryRulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _containsMeta = const VerificationMeta('contains');
  @override
  late final GeneratedColumn<String> contains = GeneratedColumn<String>(
    'contains',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _businessPctMeta = const VerificationMeta('businessPct');
  @override
  late final GeneratedColumn<int> businessPct = GeneratedColumn<int>(
    'business_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _learnedMeta = const VerificationMeta('learned');
  @override
  late final GeneratedColumn<bool> learned = GeneratedColumn<bool>(
    'learned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("learned" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, isIncome, contains, category, businessPct, learned];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'category_rules';
  @override
  VerificationContext validateIntegrity(Insertable<CategoryRule> instance, {bool isInserting = false}) {
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
    if (data.containsKey('contains')) {
      context.handle(_containsMeta, contains.isAcceptableOrUnknown(data['contains']!, _containsMeta));
    } else if (isInserting) {
      context.missing(_containsMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta, category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('business_pct')) {
      context.handle(_businessPctMeta, businessPct.isAcceptableOrUnknown(data['business_pct']!, _businessPctMeta));
    }
    if (data.containsKey('learned')) {
      context.handle(_learnedMeta, learned.isAcceptableOrUnknown(data['learned']!, _learnedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRule(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      isIncome: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_income'])!,
      contains: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}contains'])!,
      category: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      businessPct: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}business_pct']),
      learned: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}learned'])!,
    );
  }

  @override
  $CategoryRulesTable createAlias(String alias) {
    return $CategoryRulesTable(attachedDatabase, alias);
  }
}

class CategoryRule extends DataClass implements Insertable<CategoryRule> {
  final int id;
  final bool isIncome;
  final String contains;
  final String category;
  final int? businessPct;
  final bool learned;
  const CategoryRule({
    required this.id,
    required this.isIncome,
    required this.contains,
    required this.category,
    this.businessPct,
    required this.learned,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['is_income'] = Variable<bool>(isIncome);
    map['contains'] = Variable<String>(contains);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || businessPct != null) {
      map['business_pct'] = Variable<int>(businessPct);
    }
    map['learned'] = Variable<bool>(learned);
    return map;
  }

  CategoryRulesCompanion toCompanion(bool nullToAbsent) {
    return CategoryRulesCompanion(
      id: Value(id),
      isIncome: Value(isIncome),
      contains: Value(contains),
      category: Value(category),
      businessPct: businessPct == null && nullToAbsent ? const Value.absent() : Value(businessPct),
      learned: Value(learned),
    );
  }

  factory CategoryRule.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRule(
      id: serializer.fromJson<int>(json['id']),
      isIncome: serializer.fromJson<bool>(json['isIncome']),
      contains: serializer.fromJson<String>(json['contains']),
      category: serializer.fromJson<String>(json['category']),
      businessPct: serializer.fromJson<int?>(json['businessPct']),
      learned: serializer.fromJson<bool>(json['learned']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isIncome': serializer.toJson<bool>(isIncome),
      'contains': serializer.toJson<String>(contains),
      'category': serializer.toJson<String>(category),
      'businessPct': serializer.toJson<int?>(businessPct),
      'learned': serializer.toJson<bool>(learned),
    };
  }

  CategoryRule copyWith({
    int? id,
    bool? isIncome,
    String? contains,
    String? category,
    Value<int?> businessPct = const Value.absent(),
    bool? learned,
  }) => CategoryRule(
    id: id ?? this.id,
    isIncome: isIncome ?? this.isIncome,
    contains: contains ?? this.contains,
    category: category ?? this.category,
    businessPct: businessPct.present ? businessPct.value : this.businessPct,
    learned: learned ?? this.learned,
  );
  CategoryRule copyWithCompanion(CategoryRulesCompanion data) {
    return CategoryRule(
      id: data.id.present ? data.id.value : this.id,
      isIncome: data.isIncome.present ? data.isIncome.value : this.isIncome,
      contains: data.contains.present ? data.contains.value : this.contains,
      category: data.category.present ? data.category.value : this.category,
      businessPct: data.businessPct.present ? data.businessPct.value : this.businessPct,
      learned: data.learned.present ? data.learned.value : this.learned,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRule(')
          ..write('id: $id, ')
          ..write('isIncome: $isIncome, ')
          ..write('contains: $contains, ')
          ..write('category: $category, ')
          ..write('businessPct: $businessPct, ')
          ..write('learned: $learned')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, isIncome, contains, category, businessPct, learned);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRule &&
          other.id == this.id &&
          other.isIncome == this.isIncome &&
          other.contains == this.contains &&
          other.category == this.category &&
          other.businessPct == this.businessPct &&
          other.learned == this.learned);
}

class CategoryRulesCompanion extends UpdateCompanion<CategoryRule> {
  final Value<int> id;
  final Value<bool> isIncome;
  final Value<String> contains;
  final Value<String> category;
  final Value<int?> businessPct;
  final Value<bool> learned;
  const CategoryRulesCompanion({
    this.id = const Value.absent(),
    this.isIncome = const Value.absent(),
    this.contains = const Value.absent(),
    this.category = const Value.absent(),
    this.businessPct = const Value.absent(),
    this.learned = const Value.absent(),
  });
  CategoryRulesCompanion.insert({
    this.id = const Value.absent(),
    required bool isIncome,
    required String contains,
    required String category,
    this.businessPct = const Value.absent(),
    this.learned = const Value.absent(),
  }) : isIncome = Value(isIncome),
       contains = Value(contains),
       category = Value(category);
  static Insertable<CategoryRule> custom({
    Expression<int>? id,
    Expression<bool>? isIncome,
    Expression<String>? contains,
    Expression<String>? category,
    Expression<int>? businessPct,
    Expression<bool>? learned,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isIncome != null) 'is_income': isIncome,
      if (contains != null) 'contains': contains,
      if (category != null) 'category': category,
      if (businessPct != null) 'business_pct': businessPct,
      if (learned != null) 'learned': learned,
    });
  }

  CategoryRulesCompanion copyWith({
    Value<int>? id,
    Value<bool>? isIncome,
    Value<String>? contains,
    Value<String>? category,
    Value<int?>? businessPct,
    Value<bool>? learned,
  }) {
    return CategoryRulesCompanion(
      id: id ?? this.id,
      isIncome: isIncome ?? this.isIncome,
      contains: contains ?? this.contains,
      category: category ?? this.category,
      businessPct: businessPct ?? this.businessPct,
      learned: learned ?? this.learned,
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
    if (contains.present) {
      map['contains'] = Variable<String>(contains.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (businessPct.present) {
      map['business_pct'] = Variable<int>(businessPct.value);
    }
    if (learned.present) {
      map['learned'] = Variable<bool>(learned.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRulesCompanion(')
          ..write('id: $id, ')
          ..write('isIncome: $isIncome, ')
          ..write('contains: $contains, ')
          ..write('category: $category, ')
          ..write('businessPct: $businessPct, ')
          ..write('learned: $learned')
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
  late final $TaxPaymentsTable taxPayments = $TaxPaymentsTable(this);
  late final $TripsTable trips = $TripsTable(this);
  late final $Forms1099Table forms1099 = $Forms1099Table(this);
  late final $CategoryRulesTable categoryRules = $CategoryRulesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    ledgerEntries,
    attachments,
    taxPayments,
    trips,
    forms1099,
    categoryRules,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('ledger_entries', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('attachments', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName('attachments', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('forms1099', kind: UpdateKind.update)],
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
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

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
  Value<bool> paid,
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
  Value<bool> paid,
  Value<DateTime> createdAt,
});

final class $$LedgerEntriesTableReferences extends BaseReferences<_$AppDatabase, $LedgerEntriesTable, LedgerEntry> {
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
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

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

  ColumnFilters<bool> get paid => $composableBuilder(column: $table.paid, builder: (column) => ColumnFilters(column));

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
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

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

  ColumnOrderings<bool> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<bool> get isIncome => $composableBuilder(column: $table.isIncome, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<int> get feeCents => $composableBuilder(column: $table.feeCents, builder: (column) => column);

  GeneratedColumn<int> get businessPct => $composableBuilder(column: $table.businessPct, builder: (column) => column);

  GeneratedColumn<String> get category => $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get party => $composableBuilder(column: $table.party, builder: (column) => column);

  GeneratedColumn<String> get platform => $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get paid => $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> attachmentsRefs<T extends Object>(Expression<T> Function($$AttachmentsTableAnnotationComposer a) f) {
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
                Value<bool> paid = const Value.absent(),
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
                paid: paid,
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
                Value<bool> paid = const Value.absent(),
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
                paid: paid,
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
                    await $_getPrefetchedDataByColumns<LedgerEntry, $LedgerEntriesTable, Attachment, $AttachmentsTable>(
                      currentTable: table,
                      referencedTable: $$LedgerEntriesTableReferences._attachmentsRefsTable(db),
                      managerFromTypedResult: (p0) => $$LedgerEntriesTableReferences(db, table, p0).attachmentsRefs,
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

final class $$AttachmentsTableReferences extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LedgerEntriesTable _entryIdTable(_$AppDatabase db) =>
      db.ledgerEntries.createAlias('attachments__entry_id__ledger_entries__id');

  $$LedgerEntriesTableProcessedTableManager? get entryId {
    final $_column = $_itemColumn<int>('entry_id');
    if ($_column == null) return null;
    final manager = $$LedgerEntriesTableTableManager($_db, $_db.ledgerEntries).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$Forms1099Table, List<Form1099>> _forms1099RefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.forms1099, aliasName: 'attachments__id__forms1099__attachment_id');

  $$Forms1099TableProcessedTableManager get forms1099Refs {
    final manager = $$Forms1099TableTableManager(
      $_db,
      $_db.forms1099,
    ).filter((f) => f.attachmentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_forms1099RefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
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
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folder =>
      $composableBuilder(column: $table.folder, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbId =>
      $composableBuilder(column: $table.thumbId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => ColumnFilters(column));

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

  Expression<bool> forms1099Refs(Expression<bool> Function($$Forms1099TableFilterComposer f) f) {
    final $$Forms1099TableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.forms1099,
      getReferencedColumn: (t) => t.attachmentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$Forms1099TableFilterComposer(
            $db: $db,
            $table: $db.forms1099,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get folder => $composableBuilder(column: $table.folder, builder: (column) => column);

  GeneratedColumn<int> get year => $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get fileId => $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get thumbId => $composableBuilder(column: $table.thumbId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes => $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

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

  Expression<T> forms1099Refs<T extends Object>(Expression<T> Function($$Forms1099TableAnnotationComposer a) f) {
    final $$Forms1099TableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.forms1099,
      getReferencedColumn: (t) => t.attachmentId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$Forms1099TableAnnotationComposer(
            $db: $db,
            $table: $db.forms1099,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
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
          PrefetchHooks Function({bool entryId, bool forms1099Refs})
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
                (e) => (e.readTable<$AttachmentsTable, Attachment>(table), $$AttachmentsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false, forms1099Refs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (forms1099Refs) db.forms1099],
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
                return [
                  if (forms1099Refs)
                    await $_getPrefetchedDataByColumns<Attachment, $AttachmentsTable, Form1099, $Forms1099Table>(
                      currentTable: table,
                      referencedTable: $$AttachmentsTableReferences._forms1099RefsTable(db),
                      managerFromTypedResult: (p0) => $$AttachmentsTableReferences(db, table, p0).forms1099Refs,
                      currentColumn: 'id',
                      referencedColumn: 'attachment_id',
                      typedResults: items,
                    ),
                ];
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
      PrefetchHooks Function({bool entryId, bool forms1099Refs})
    >;
typedef $$TaxPaymentsTableCreateCompanionBuilder = TaxPaymentsCompanion Function({
  Value<int> id,
  required int taxYear,
  Value<String> quarter,
  required String date,
  required int amountCents,
  Value<String> method,
  Value<String> notes,
});
typedef $$TaxPaymentsTableUpdateCompanionBuilder = TaxPaymentsCompanion Function({
  Value<int> id,
  Value<int> taxYear,
  Value<String> quarter,
  Value<String> date,
  Value<int> amountCents,
  Value<String> method,
  Value<String> notes,
});

class $$TaxPaymentsTableFilterComposer extends Composer<_$AppDatabase, $TaxPaymentsTable> {
  $$TaxPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get taxYear =>
      $composableBuilder(column: $table.taxYear, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quarter =>
      $composableBuilder(column: $table.quarter, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$TaxPaymentsTableOrderingComposer extends Composer<_$AppDatabase, $TaxPaymentsTable> {
  $$TaxPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get taxYear =>
      $composableBuilder(column: $table.taxYear, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quarter =>
      $composableBuilder(column: $table.quarter, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$TaxPaymentsTableAnnotationComposer extends Composer<_$AppDatabase, $TaxPaymentsTable> {
  $$TaxPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get taxYear => $composableBuilder(column: $table.taxYear, builder: (column) => column);

  GeneratedColumn<String> get quarter => $composableBuilder(column: $table.quarter, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<String> get method => $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get notes => $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$TaxPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaxPaymentsTable,
          TaxPayment,
          $$TaxPaymentsTableFilterComposer,
          $$TaxPaymentsTableOrderingComposer,
          $$TaxPaymentsTableAnnotationComposer,
          $$TaxPaymentsTableCreateCompanionBuilder,
          $$TaxPaymentsTableUpdateCompanionBuilder,
          (TaxPayment, BaseReferences<_$AppDatabase, $TaxPaymentsTable, TaxPayment>),
          TaxPayment,
          PrefetchHooks Function()
        > {
  $$TaxPaymentsTableTableManager(_$AppDatabase db, $TaxPaymentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TaxPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TaxPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TaxPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> taxYear = const Value.absent(),
                Value<String> quarter = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String> notes = const Value.absent(),
              }) => TaxPaymentsCompanion(
                id: id,
                taxYear: taxYear,
                quarter: quarter,
                date: date,
                amountCents: amountCents,
                method: method,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int taxYear,
                Value<String> quarter = const Value.absent(),
                required String date,
                required int amountCents,
                Value<String> method = const Value.absent(),
                Value<String> notes = const Value.absent(),
              }) => TaxPaymentsCompanion.insert(
                id: id,
                taxYear: taxYear,
                quarter: quarter,
                date: date,
                amountCents: amountCents,
                method: method,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaxPaymentsTable, TaxPayment>(table),
                  BaseReferences<_$AppDatabase, $TaxPaymentsTable, TaxPayment>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TaxPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaxPaymentsTable,
      TaxPayment,
      $$TaxPaymentsTableFilterComposer,
      $$TaxPaymentsTableOrderingComposer,
      $$TaxPaymentsTableAnnotationComposer,
      $$TaxPaymentsTableCreateCompanionBuilder,
      $$TaxPaymentsTableUpdateCompanionBuilder,
      (TaxPayment, BaseReferences<_$AppDatabase, $TaxPaymentsTable, TaxPayment>),
      TaxPayment,
      PrefetchHooks Function()
    >;
typedef $$TripsTableCreateCompanionBuilder = TripsCompanion Function({
  Value<int> id,
  required String date,
  required int milesTenths,
  Value<String> purpose,
  Value<String> route,
});
typedef $$TripsTableUpdateCompanionBuilder = TripsCompanion Function({
  Value<int> id,
  Value<String> date,
  Value<int> milesTenths,
  Value<String> purpose,
  Value<String> route,
});

class $$TripsTableFilterComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get milesTenths =>
      $composableBuilder(column: $table.milesTenths, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => ColumnFilters(column));
}

class $$TripsTableOrderingComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get milesTenths =>
      $composableBuilder(column: $table.milesTenths, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get purpose =>
      $composableBuilder(column: $table.purpose, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => ColumnOrderings(column));
}

class $$TripsTableAnnotationComposer extends Composer<_$AppDatabase, $TripsTable> {
  $$TripsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date => $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get milesTenths => $composableBuilder(column: $table.milesTenths, builder: (column) => column);

  GeneratedColumn<String> get purpose => $composableBuilder(column: $table.purpose, builder: (column) => column);

  GeneratedColumn<String> get route => $composableBuilder(column: $table.route, builder: (column) => column);
}

class $$TripsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TripsTable,
          Trip,
          $$TripsTableFilterComposer,
          $$TripsTableOrderingComposer,
          $$TripsTableAnnotationComposer,
          $$TripsTableCreateCompanionBuilder,
          $$TripsTableUpdateCompanionBuilder,
          (Trip, BaseReferences<_$AppDatabase, $TripsTable, Trip>),
          Trip,
          PrefetchHooks Function()
        > {
  $$TripsTableTableManager(_$AppDatabase db, $TripsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$TripsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$TripsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$TripsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<int> milesTenths = const Value.absent(),
            Value<String> purpose = const Value.absent(),
            Value<String> route = const Value.absent(),
          }) => TripsCompanion(id: id, date: date, milesTenths: milesTenths, purpose: purpose, route: route),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String date,
            required int milesTenths,
            Value<String> purpose = const Value.absent(),
            Value<String> route = const Value.absent(),
          }) => TripsCompanion.insert(id: id, date: date, milesTenths: milesTenths, purpose: purpose, route: route),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TripsTable, Trip>(table),
                  BaseReferences<_$AppDatabase, $TripsTable, Trip>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TripsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TripsTable,
      Trip,
      $$TripsTableFilterComposer,
      $$TripsTableOrderingComposer,
      $$TripsTableAnnotationComposer,
      $$TripsTableCreateCompanionBuilder,
      $$TripsTableUpdateCompanionBuilder,
      (Trip, BaseReferences<_$AppDatabase, $TripsTable, Trip>),
      Trip,
      PrefetchHooks Function()
    >;
typedef $$Forms1099TableCreateCompanionBuilder = Forms1099Companion Function({
  Value<int> id,
  required int year,
  required String kind,
  required String payer,
  required int amountCents,
  Value<int?> attachmentId,
});
typedef $$Forms1099TableUpdateCompanionBuilder = Forms1099Companion Function({
  Value<int> id,
  Value<int> year,
  Value<String> kind,
  Value<String> payer,
  Value<int> amountCents,
  Value<int?> attachmentId,
});

final class $$Forms1099TableReferences extends BaseReferences<_$AppDatabase, $Forms1099Table, Form1099> {
  $$Forms1099TableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AttachmentsTable _attachmentIdTable(_$AppDatabase db) =>
      db.attachments.createAlias('forms1099__attachment_id__attachments__id');

  $$AttachmentsTableProcessedTableManager? get attachmentId {
    final $_column = $_itemColumn<int>('attachment_id');
    if ($_column == null) return null;
    final manager = $$AttachmentsTableTableManager($_db, $_db.attachments).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_attachmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$Forms1099TableFilterComposer extends Composer<_$AppDatabase, $Forms1099Table> {
  $$Forms1099TableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payer =>
      $composableBuilder(column: $table.payer, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnFilters(column));

  $$AttachmentsTableFilterComposer get attachmentId {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Forms1099TableOrderingComposer extends Composer<_$AppDatabase, $Forms1099Table> {
  $$Forms1099TableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payer =>
      $composableBuilder(column: $table.payer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents =>
      $composableBuilder(column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  $$AttachmentsTableOrderingComposer get attachmentId {
    final $$AttachmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttachmentsTableOrderingComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Forms1099TableAnnotationComposer extends Composer<_$AppDatabase, $Forms1099Table> {
  $$Forms1099TableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get year => $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payer => $composableBuilder(column: $table.payer, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(column: $table.amountCents, builder: (column) => column);

  $$AttachmentsTableAnnotationComposer get attachmentId {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.attachmentId,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$Forms1099TableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $Forms1099Table,
          Form1099,
          $$Forms1099TableFilterComposer,
          $$Forms1099TableOrderingComposer,
          $$Forms1099TableAnnotationComposer,
          $$Forms1099TableCreateCompanionBuilder,
          $$Forms1099TableUpdateCompanionBuilder,
          (Form1099, $$Forms1099TableReferences),
          Form1099,
          PrefetchHooks Function({bool attachmentId})
        > {
  $$Forms1099TableTableManager(_$AppDatabase db, $Forms1099Table table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$Forms1099TableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$Forms1099TableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$Forms1099TableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> year = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> payer = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<int?> attachmentId = const Value.absent(),
              }) => Forms1099Companion(
                id: id,
                year: year,
                kind: kind,
                payer: payer,
                amountCents: amountCents,
                attachmentId: attachmentId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int year,
                required String kind,
                required String payer,
                required int amountCents,
                Value<int?> attachmentId = const Value.absent(),
              }) => Forms1099Companion.insert(
                id: id,
                year: year,
                kind: kind,
                payer: payer,
                amountCents: amountCents,
                attachmentId: attachmentId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$Forms1099Table, Form1099>(table), $$Forms1099TableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({attachmentId = false}) {
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
                    if (attachmentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.attachmentId,
                        referencedTable: $$Forms1099TableReferences._attachmentIdTable(db),
                        referencedColumn: $$Forms1099TableReferences._attachmentIdTable(db).id,
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

typedef $$Forms1099TableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $Forms1099Table,
      Form1099,
      $$Forms1099TableFilterComposer,
      $$Forms1099TableOrderingComposer,
      $$Forms1099TableAnnotationComposer,
      $$Forms1099TableCreateCompanionBuilder,
      $$Forms1099TableUpdateCompanionBuilder,
      (Form1099, $$Forms1099TableReferences),
      Form1099,
      PrefetchHooks Function({bool attachmentId})
    >;
typedef $$CategoryRulesTableCreateCompanionBuilder = CategoryRulesCompanion Function({
  Value<int> id,
  required bool isIncome,
  required String contains,
  required String category,
  Value<int?> businessPct,
  Value<bool> learned,
});
typedef $$CategoryRulesTableUpdateCompanionBuilder = CategoryRulesCompanion Function({
  Value<int> id,
  Value<bool> isIncome,
  Value<String> contains,
  Value<String> category,
  Value<int?> businessPct,
  Value<bool> learned,
});

class $$CategoryRulesTableFilterComposer extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contains =>
      $composableBuilder(column: $table.contains, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get businessPct =>
      $composableBuilder(column: $table.businessPct, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get learned =>
      $composableBuilder(column: $table.learned, builder: (column) => ColumnFilters(column));
}

class $$CategoryRulesTableOrderingComposer extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isIncome =>
      $composableBuilder(column: $table.isIncome, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contains =>
      $composableBuilder(column: $table.contains, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get businessPct =>
      $composableBuilder(column: $table.businessPct, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get learned =>
      $composableBuilder(column: $table.learned, builder: (column) => ColumnOrderings(column));
}

class $$CategoryRulesTableAnnotationComposer extends Composer<_$AppDatabase, $CategoryRulesTable> {
  $$CategoryRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isIncome => $composableBuilder(column: $table.isIncome, builder: (column) => column);

  GeneratedColumn<String> get contains => $composableBuilder(column: $table.contains, builder: (column) => column);

  GeneratedColumn<String> get category => $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get businessPct => $composableBuilder(column: $table.businessPct, builder: (column) => column);

  GeneratedColumn<bool> get learned => $composableBuilder(column: $table.learned, builder: (column) => column);
}

class $$CategoryRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryRulesTable,
          CategoryRule,
          $$CategoryRulesTableFilterComposer,
          $$CategoryRulesTableOrderingComposer,
          $$CategoryRulesTableAnnotationComposer,
          $$CategoryRulesTableCreateCompanionBuilder,
          $$CategoryRulesTableUpdateCompanionBuilder,
          (CategoryRule, BaseReferences<_$AppDatabase, $CategoryRulesTable, CategoryRule>),
          CategoryRule,
          PrefetchHooks Function()
        > {
  $$CategoryRulesTableTableManager(_$AppDatabase db, $CategoryRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CategoryRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CategoryRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CategoryRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isIncome = const Value.absent(),
                Value<String> contains = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int?> businessPct = const Value.absent(),
                Value<bool> learned = const Value.absent(),
              }) => CategoryRulesCompanion(
                id: id,
                isIncome: isIncome,
                contains: contains,
                category: category,
                businessPct: businessPct,
                learned: learned,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required bool isIncome,
                required String contains,
                required String category,
                Value<int?> businessPct = const Value.absent(),
                Value<bool> learned = const Value.absent(),
              }) => CategoryRulesCompanion.insert(
                id: id,
                isIncome: isIncome,
                contains: contains,
                category: category,
                businessPct: businessPct,
                learned: learned,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoryRulesTable, CategoryRule>(table),
                  BaseReferences<_$AppDatabase, $CategoryRulesTable, CategoryRule>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoryRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryRulesTable,
      CategoryRule,
      $$CategoryRulesTableFilterComposer,
      $$CategoryRulesTableOrderingComposer,
      $$CategoryRulesTableAnnotationComposer,
      $$CategoryRulesTableCreateCompanionBuilder,
      $$CategoryRulesTableUpdateCompanionBuilder,
      (CategoryRule, BaseReferences<_$AppDatabase, $CategoryRulesTable, CategoryRule>),
      CategoryRule,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings => $$SettingsTableTableManager(_db, _db.settings);
  $$LedgerEntriesTableTableManager get ledgerEntries => $$LedgerEntriesTableTableManager(_db, _db.ledgerEntries);
  $$AttachmentsTableTableManager get attachments => $$AttachmentsTableTableManager(_db, _db.attachments);
  $$TaxPaymentsTableTableManager get taxPayments => $$TaxPaymentsTableTableManager(_db, _db.taxPayments);
  $$TripsTableTableManager get trips => $$TripsTableTableManager(_db, _db.trips);
  $$Forms1099TableTableManager get forms1099 => $$Forms1099TableTableManager(_db, _db.forms1099);
  $$CategoryRulesTableTableManager get categoryRules => $$CategoryRulesTableTableManager(_db, _db.categoryRules);
}
