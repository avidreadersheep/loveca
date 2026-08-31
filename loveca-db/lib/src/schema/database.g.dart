// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardType, String> cardType =
      GeneratedColumn<String>(
        'card_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardType>($CardsTable.$convertercardType);
  static const VerificationMeta _effectTextMeta = const VerificationMeta(
    'effectText',
  );
  @override
  late final GeneratedColumn<String> effectText = GeneratedColumn<String>(
    'effect_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<int> cost = GeneratedColumn<int>(
    'cost',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bladeCountMeta = const VerificationMeta(
    'bladeCount',
  );
  @override
  late final GeneratedColumn<int> bladeCount = GeneratedColumn<int>(
    'blade_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heartTotalMeta = const VerificationMeta(
    'heartTotal',
  );
  @override
  late final GeneratedColumn<int> heartTotal = GeneratedColumn<int>(
    'heart_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _requiredHeartTotalMeta =
      const VerificationMeta('requiredHeartTotal');
  @override
  late final GeneratedColumn<int> requiredHeartTotal = GeneratedColumn<int>(
    'required_heart_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statsMeta = const VerificationMeta('stats');
  @override
  late final GeneratedColumn<int> stats = GeneratedColumn<int>(
    'stats',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _searchBlobMeta = const VerificationMeta(
    'searchBlob',
  );
  @override
  late final GeneratedColumn<String> searchBlob = GeneratedColumn<String>(
    'search_blob',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    cardNumber,
    name,
    cardType,
    effectText,
    cost,
    bladeCount,
    score,
    heartTotal,
    requiredHeartTotal,
    stats,
    isDeleted,
    searchBlob,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('effect_text')) {
      context.handle(
        _effectTextMeta,
        effectText.isAcceptableOrUnknown(data['effect_text']!, _effectTextMeta),
      );
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    }
    if (data.containsKey('blade_count')) {
      context.handle(
        _bladeCountMeta,
        bladeCount.isAcceptableOrUnknown(data['blade_count']!, _bladeCountMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('heart_total')) {
      context.handle(
        _heartTotalMeta,
        heartTotal.isAcceptableOrUnknown(data['heart_total']!, _heartTotalMeta),
      );
    }
    if (data.containsKey('required_heart_total')) {
      context.handle(
        _requiredHeartTotalMeta,
        requiredHeartTotal.isAcceptableOrUnknown(
          data['required_heart_total']!,
          _requiredHeartTotalMeta,
        ),
      );
    }
    if (data.containsKey('stats')) {
      context.handle(
        _statsMeta,
        stats.isAcceptableOrUnknown(data['stats']!, _statsMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('search_blob')) {
      context.handle(
        _searchBlobMeta,
        searchBlob.isAcceptableOrUnknown(data['search_blob']!, _searchBlobMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardNumber};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cardType: $CardsTable.$convertercardType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}card_type'],
        )!,
      ),
      effectText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effect_text'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost'],
      ),
      bladeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}blade_count'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      ),
      heartTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}heart_total'],
      )!,
      requiredHeartTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}required_heart_total'],
      )!,
      stats: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stats'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      searchBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}search_blob'],
      )!,
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardType, String, String> $convertercardType =
      const EnumNameConverter<CardType>(CardType.values);
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final String cardNumber;
  final String name;
  final CardType cardType;
  final String effectText;

  /// メンバーのみ（2.6）。
  final int? cost;

  /// メンバーのみ（2.8）。★8.3.10 の集計対象は「アクティブ状態のメンバー」のみ。
  final int? bladeCount;

  /// ライブのみ（2.10）。
  final int? score;
  final int heartTotal;
  final int requiredHeartTotal;

  /// 決定 D14: ブレード数 + ハート数。検索・ソート用の派生値。
  final int? stats;

  /// 公式から消えても既存デッキを壊さないため保持する。
  final bool isDeleted;

  /// ★2 文字以下の検索語のための折りたたみ済み連結テキスト★
  /// trigram は 3 文字未満だと**エラーにならず静かに 0 件**を返すため、
  /// 短い語はこの列への `LIKE` に切り替える。
  /// 中身は `fold()` を通した cardNumber + name + effect + groups + units。
  final String searchBlob;
  const CardRow({
    required this.cardNumber,
    required this.name,
    required this.cardType,
    required this.effectText,
    this.cost,
    this.bladeCount,
    this.score,
    required this.heartTotal,
    required this.requiredHeartTotal,
    this.stats,
    required this.isDeleted,
    required this.searchBlob,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_number'] = Variable<String>(cardNumber);
    map['name'] = Variable<String>(name);
    {
      map['card_type'] = Variable<String>(
        $CardsTable.$convertercardType.toSql(cardType),
      );
    }
    map['effect_text'] = Variable<String>(effectText);
    if (!nullToAbsent || cost != null) {
      map['cost'] = Variable<int>(cost);
    }
    if (!nullToAbsent || bladeCount != null) {
      map['blade_count'] = Variable<int>(bladeCount);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<int>(score);
    }
    map['heart_total'] = Variable<int>(heartTotal);
    map['required_heart_total'] = Variable<int>(requiredHeartTotal);
    if (!nullToAbsent || stats != null) {
      map['stats'] = Variable<int>(stats);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['search_blob'] = Variable<String>(searchBlob);
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      cardNumber: Value(cardNumber),
      name: Value(name),
      cardType: Value(cardType),
      effectText: Value(effectText),
      cost: cost == null && nullToAbsent ? const Value.absent() : Value(cost),
      bladeCount: bladeCount == null && nullToAbsent
          ? const Value.absent()
          : Value(bladeCount),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      heartTotal: Value(heartTotal),
      requiredHeartTotal: Value(requiredHeartTotal),
      stats: stats == null && nullToAbsent
          ? const Value.absent()
          : Value(stats),
      isDeleted: Value(isDeleted),
      searchBlob: Value(searchBlob),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      name: serializer.fromJson<String>(json['name']),
      cardType: $CardsTable.$convertercardType.fromJson(
        serializer.fromJson<String>(json['cardType']),
      ),
      effectText: serializer.fromJson<String>(json['effectText']),
      cost: serializer.fromJson<int?>(json['cost']),
      bladeCount: serializer.fromJson<int?>(json['bladeCount']),
      score: serializer.fromJson<int?>(json['score']),
      heartTotal: serializer.fromJson<int>(json['heartTotal']),
      requiredHeartTotal: serializer.fromJson<int>(json['requiredHeartTotal']),
      stats: serializer.fromJson<int?>(json['stats']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      searchBlob: serializer.fromJson<String>(json['searchBlob']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardNumber': serializer.toJson<String>(cardNumber),
      'name': serializer.toJson<String>(name),
      'cardType': serializer.toJson<String>(
        $CardsTable.$convertercardType.toJson(cardType),
      ),
      'effectText': serializer.toJson<String>(effectText),
      'cost': serializer.toJson<int?>(cost),
      'bladeCount': serializer.toJson<int?>(bladeCount),
      'score': serializer.toJson<int?>(score),
      'heartTotal': serializer.toJson<int>(heartTotal),
      'requiredHeartTotal': serializer.toJson<int>(requiredHeartTotal),
      'stats': serializer.toJson<int?>(stats),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'searchBlob': serializer.toJson<String>(searchBlob),
    };
  }

  CardRow copyWith({
    String? cardNumber,
    String? name,
    CardType? cardType,
    String? effectText,
    Value<int?> cost = const Value.absent(),
    Value<int?> bladeCount = const Value.absent(),
    Value<int?> score = const Value.absent(),
    int? heartTotal,
    int? requiredHeartTotal,
    Value<int?> stats = const Value.absent(),
    bool? isDeleted,
    String? searchBlob,
  }) => CardRow(
    cardNumber: cardNumber ?? this.cardNumber,
    name: name ?? this.name,
    cardType: cardType ?? this.cardType,
    effectText: effectText ?? this.effectText,
    cost: cost.present ? cost.value : this.cost,
    bladeCount: bladeCount.present ? bladeCount.value : this.bladeCount,
    score: score.present ? score.value : this.score,
    heartTotal: heartTotal ?? this.heartTotal,
    requiredHeartTotal: requiredHeartTotal ?? this.requiredHeartTotal,
    stats: stats.present ? stats.value : this.stats,
    isDeleted: isDeleted ?? this.isDeleted,
    searchBlob: searchBlob ?? this.searchBlob,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      name: data.name.present ? data.name.value : this.name,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      effectText: data.effectText.present
          ? data.effectText.value
          : this.effectText,
      cost: data.cost.present ? data.cost.value : this.cost,
      bladeCount: data.bladeCount.present
          ? data.bladeCount.value
          : this.bladeCount,
      score: data.score.present ? data.score.value : this.score,
      heartTotal: data.heartTotal.present
          ? data.heartTotal.value
          : this.heartTotal,
      requiredHeartTotal: data.requiredHeartTotal.present
          ? data.requiredHeartTotal.value
          : this.requiredHeartTotal,
      stats: data.stats.present ? data.stats.value : this.stats,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      searchBlob: data.searchBlob.present
          ? data.searchBlob.value
          : this.searchBlob,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('cardNumber: $cardNumber, ')
          ..write('name: $name, ')
          ..write('cardType: $cardType, ')
          ..write('effectText: $effectText, ')
          ..write('cost: $cost, ')
          ..write('bladeCount: $bladeCount, ')
          ..write('score: $score, ')
          ..write('heartTotal: $heartTotal, ')
          ..write('requiredHeartTotal: $requiredHeartTotal, ')
          ..write('stats: $stats, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('searchBlob: $searchBlob')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    cardNumber,
    name,
    cardType,
    effectText,
    cost,
    bladeCount,
    score,
    heartTotal,
    requiredHeartTotal,
    stats,
    isDeleted,
    searchBlob,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.cardNumber == this.cardNumber &&
          other.name == this.name &&
          other.cardType == this.cardType &&
          other.effectText == this.effectText &&
          other.cost == this.cost &&
          other.bladeCount == this.bladeCount &&
          other.score == this.score &&
          other.heartTotal == this.heartTotal &&
          other.requiredHeartTotal == this.requiredHeartTotal &&
          other.stats == this.stats &&
          other.isDeleted == this.isDeleted &&
          other.searchBlob == this.searchBlob);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<String> cardNumber;
  final Value<String> name;
  final Value<CardType> cardType;
  final Value<String> effectText;
  final Value<int?> cost;
  final Value<int?> bladeCount;
  final Value<int?> score;
  final Value<int> heartTotal;
  final Value<int> requiredHeartTotal;
  final Value<int?> stats;
  final Value<bool> isDeleted;
  final Value<String> searchBlob;
  final Value<int> rowid;
  const CardsCompanion({
    this.cardNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.cardType = const Value.absent(),
    this.effectText = const Value.absent(),
    this.cost = const Value.absent(),
    this.bladeCount = const Value.absent(),
    this.score = const Value.absent(),
    this.heartTotal = const Value.absent(),
    this.requiredHeartTotal = const Value.absent(),
    this.stats = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.searchBlob = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCompanion.insert({
    required String cardNumber,
    required String name,
    required CardType cardType,
    this.effectText = const Value.absent(),
    this.cost = const Value.absent(),
    this.bladeCount = const Value.absent(),
    this.score = const Value.absent(),
    this.heartTotal = const Value.absent(),
    this.requiredHeartTotal = const Value.absent(),
    this.stats = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.searchBlob = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cardNumber = Value(cardNumber),
       name = Value(name),
       cardType = Value(cardType);
  static Insertable<CardRow> custom({
    Expression<String>? cardNumber,
    Expression<String>? name,
    Expression<String>? cardType,
    Expression<String>? effectText,
    Expression<int>? cost,
    Expression<int>? bladeCount,
    Expression<int>? score,
    Expression<int>? heartTotal,
    Expression<int>? requiredHeartTotal,
    Expression<int>? stats,
    Expression<bool>? isDeleted,
    Expression<String>? searchBlob,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardNumber != null) 'card_number': cardNumber,
      if (name != null) 'name': name,
      if (cardType != null) 'card_type': cardType,
      if (effectText != null) 'effect_text': effectText,
      if (cost != null) 'cost': cost,
      if (bladeCount != null) 'blade_count': bladeCount,
      if (score != null) 'score': score,
      if (heartTotal != null) 'heart_total': heartTotal,
      if (requiredHeartTotal != null)
        'required_heart_total': requiredHeartTotal,
      if (stats != null) 'stats': stats,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (searchBlob != null) 'search_blob': searchBlob,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCompanion copyWith({
    Value<String>? cardNumber,
    Value<String>? name,
    Value<CardType>? cardType,
    Value<String>? effectText,
    Value<int?>? cost,
    Value<int?>? bladeCount,
    Value<int?>? score,
    Value<int>? heartTotal,
    Value<int>? requiredHeartTotal,
    Value<int?>? stats,
    Value<bool>? isDeleted,
    Value<String>? searchBlob,
    Value<int>? rowid,
  }) {
    return CardsCompanion(
      cardNumber: cardNumber ?? this.cardNumber,
      name: name ?? this.name,
      cardType: cardType ?? this.cardType,
      effectText: effectText ?? this.effectText,
      cost: cost ?? this.cost,
      bladeCount: bladeCount ?? this.bladeCount,
      score: score ?? this.score,
      heartTotal: heartTotal ?? this.heartTotal,
      requiredHeartTotal: requiredHeartTotal ?? this.requiredHeartTotal,
      stats: stats ?? this.stats,
      isDeleted: isDeleted ?? this.isDeleted,
      searchBlob: searchBlob ?? this.searchBlob,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(
        $CardsTable.$convertercardType.toSql(cardType.value),
      );
    }
    if (effectText.present) {
      map['effect_text'] = Variable<String>(effectText.value);
    }
    if (cost.present) {
      map['cost'] = Variable<int>(cost.value);
    }
    if (bladeCount.present) {
      map['blade_count'] = Variable<int>(bladeCount.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (heartTotal.present) {
      map['heart_total'] = Variable<int>(heartTotal.value);
    }
    if (requiredHeartTotal.present) {
      map['required_heart_total'] = Variable<int>(requiredHeartTotal.value);
    }
    if (stats.present) {
      map['stats'] = Variable<int>(stats.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (searchBlob.present) {
      map['search_blob'] = Variable<String>(searchBlob.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('cardNumber: $cardNumber, ')
          ..write('name: $name, ')
          ..write('cardType: $cardType, ')
          ..write('effectText: $effectText, ')
          ..write('cost: $cost, ')
          ..write('bladeCount: $bladeCount, ')
          ..write('score: $score, ')
          ..write('heartTotal: $heartTotal, ')
          ..write('requiredHeartTotal: $requiredHeartTotal, ')
          ..write('stats: $stats, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('searchBlob: $searchBlob, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardNamesTable extends CardNames
    with TableInfo<$CardNamesTable, CardNameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardNamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (card_number) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardNameKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CardNameKind>($CardNamesTable.$converterkind);
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  List<GeneratedColumn> get $columns => [cardNumber, kind, ord, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_names';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardNameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardNumber, kind, ord};
  @override
  CardNameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardNameRow(
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      kind: $CardNamesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $CardNamesTable createAlias(String alias) {
    return $CardNamesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardNameKind, String, String> $converterkind =
      const EnumNameConverter<CardNameKind>(CardNameKind.values);
}

class CardNameRow extends DataClass implements Insertable<CardNameRow> {
  final String cardNumber;
  final CardNameKind kind;

  /// リスト内の位置。`Card` の 3 リストへ順序どおり復元するために要る。
  final int ord;
  final String value;
  const CardNameRow({
    required this.cardNumber,
    required this.kind,
    required this.ord,
    required this.value,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_number'] = Variable<String>(cardNumber);
    {
      map['kind'] = Variable<String>(
        $CardNamesTable.$converterkind.toSql(kind),
      );
    }
    map['ord'] = Variable<int>(ord);
    map['value'] = Variable<String>(value);
    return map;
  }

  CardNamesCompanion toCompanion(bool nullToAbsent) {
    return CardNamesCompanion(
      cardNumber: Value(cardNumber),
      kind: Value(kind),
      ord: Value(ord),
      value: Value(value),
    );
  }

  factory CardNameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardNameRow(
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      kind: $CardNamesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      ord: serializer.fromJson<int>(json['ord']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardNumber': serializer.toJson<String>(cardNumber),
      'kind': serializer.toJson<String>(
        $CardNamesTable.$converterkind.toJson(kind),
      ),
      'ord': serializer.toJson<int>(ord),
      'value': serializer.toJson<String>(value),
    };
  }

  CardNameRow copyWith({
    String? cardNumber,
    CardNameKind? kind,
    int? ord,
    String? value,
  }) => CardNameRow(
    cardNumber: cardNumber ?? this.cardNumber,
    kind: kind ?? this.kind,
    ord: ord ?? this.ord,
    value: value ?? this.value,
  );
  CardNameRow copyWithCompanion(CardNamesCompanion data) {
    return CardNameRow(
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      kind: data.kind.present ? data.kind.value : this.kind,
      ord: data.ord.present ? data.ord.value : this.ord,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardNameRow(')
          ..write('cardNumber: $cardNumber, ')
          ..write('kind: $kind, ')
          ..write('ord: $ord, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardNumber, kind, ord, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardNameRow &&
          other.cardNumber == this.cardNumber &&
          other.kind == this.kind &&
          other.ord == this.ord &&
          other.value == this.value);
}

class CardNamesCompanion extends UpdateCompanion<CardNameRow> {
  final Value<String> cardNumber;
  final Value<CardNameKind> kind;
  final Value<int> ord;
  final Value<String> value;
  final Value<int> rowid;
  const CardNamesCompanion({
    this.cardNumber = const Value.absent(),
    this.kind = const Value.absent(),
    this.ord = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardNamesCompanion.insert({
    required String cardNumber,
    required CardNameKind kind,
    required int ord,
    required String value,
    this.rowid = const Value.absent(),
  }) : cardNumber = Value(cardNumber),
       kind = Value(kind),
       ord = Value(ord),
       value = Value(value);
  static Insertable<CardNameRow> custom({
    Expression<String>? cardNumber,
    Expression<String>? kind,
    Expression<int>? ord,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardNumber != null) 'card_number': cardNumber,
      if (kind != null) 'kind': kind,
      if (ord != null) 'ord': ord,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardNamesCompanion copyWith({
    Value<String>? cardNumber,
    Value<CardNameKind>? kind,
    Value<int>? ord,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return CardNamesCompanion(
      cardNumber: cardNumber ?? this.cardNumber,
      kind: kind ?? this.kind,
      ord: ord ?? this.ord,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CardNamesTable.$converterkind.toSql(kind.value),
      );
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
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
    return (StringBuffer('CardNamesCompanion(')
          ..write('cardNumber: $cardNumber, ')
          ..write('kind: $kind, ')
          ..write('ord: $ord, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardKeywordsTable extends CardKeywords
    with TableInfo<$CardKeywordsTable, CardKeywordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardKeywordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (card_number) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keywordMeta = const VerificationMeta(
    'keyword',
  );
  @override
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
    'keyword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardNumber, ord, keyword];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_keywords';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardKeywordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('keyword')) {
      context.handle(
        _keywordMeta,
        keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta),
      );
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardNumber, ord};
  @override
  CardKeywordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardKeywordRow(
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      keyword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keyword'],
      )!,
    );
  }

  @override
  $CardKeywordsTable createAlias(String alias) {
    return $CardKeywordsTable(attachedDatabase, alias);
  }
}

class CardKeywordRow extends DataClass implements Insertable<CardKeywordRow> {
  final String cardNumber;
  final int ord;
  final String keyword;
  const CardKeywordRow({
    required this.cardNumber,
    required this.ord,
    required this.keyword,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_number'] = Variable<String>(cardNumber);
    map['ord'] = Variable<int>(ord);
    map['keyword'] = Variable<String>(keyword);
    return map;
  }

  CardKeywordsCompanion toCompanion(bool nullToAbsent) {
    return CardKeywordsCompanion(
      cardNumber: Value(cardNumber),
      ord: Value(ord),
      keyword: Value(keyword),
    );
  }

  factory CardKeywordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardKeywordRow(
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      ord: serializer.fromJson<int>(json['ord']),
      keyword: serializer.fromJson<String>(json['keyword']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardNumber': serializer.toJson<String>(cardNumber),
      'ord': serializer.toJson<int>(ord),
      'keyword': serializer.toJson<String>(keyword),
    };
  }

  CardKeywordRow copyWith({String? cardNumber, int? ord, String? keyword}) =>
      CardKeywordRow(
        cardNumber: cardNumber ?? this.cardNumber,
        ord: ord ?? this.ord,
        keyword: keyword ?? this.keyword,
      );
  CardKeywordRow copyWithCompanion(CardKeywordsCompanion data) {
    return CardKeywordRow(
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      ord: data.ord.present ? data.ord.value : this.ord,
      keyword: data.keyword.present ? data.keyword.value : this.keyword,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardKeywordRow(')
          ..write('cardNumber: $cardNumber, ')
          ..write('ord: $ord, ')
          ..write('keyword: $keyword')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardNumber, ord, keyword);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardKeywordRow &&
          other.cardNumber == this.cardNumber &&
          other.ord == this.ord &&
          other.keyword == this.keyword);
}

class CardKeywordsCompanion extends UpdateCompanion<CardKeywordRow> {
  final Value<String> cardNumber;
  final Value<int> ord;
  final Value<String> keyword;
  final Value<int> rowid;
  const CardKeywordsCompanion({
    this.cardNumber = const Value.absent(),
    this.ord = const Value.absent(),
    this.keyword = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardKeywordsCompanion.insert({
    required String cardNumber,
    required int ord,
    required String keyword,
    this.rowid = const Value.absent(),
  }) : cardNumber = Value(cardNumber),
       ord = Value(ord),
       keyword = Value(keyword);
  static Insertable<CardKeywordRow> custom({
    Expression<String>? cardNumber,
    Expression<int>? ord,
    Expression<String>? keyword,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardNumber != null) 'card_number': cardNumber,
      if (ord != null) 'ord': ord,
      if (keyword != null) 'keyword': keyword,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardKeywordsCompanion copyWith({
    Value<String>? cardNumber,
    Value<int>? ord,
    Value<String>? keyword,
    Value<int>? rowid,
  }) {
    return CardKeywordsCompanion(
      cardNumber: cardNumber ?? this.cardNumber,
      ord: ord ?? this.ord,
      keyword: keyword ?? this.keyword,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardKeywordsCompanion(')
          ..write('cardNumber: $cardNumber, ')
          ..write('ord: $ord, ')
          ..write('keyword: $keyword, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardHeartsTable extends CardHearts
    with TableInfo<$CardHeartsTable, CardHeartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardHeartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (card_number) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<HeartKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<HeartKind>($CardHeartsTable.$converterkind);
  @override
  late final GeneratedColumnWithTypeConverter<HeartColor, String> color =
      GeneratedColumn<String>(
        'color',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<HeartColor>($CardHeartsTable.$convertercolor);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardNumber, kind, color, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_hearts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardHeartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardNumber, kind, color};
  @override
  CardHeartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardHeartRow(
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      kind: $CardHeartsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      color: $CardHeartsTable.$convertercolor.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}color'],
        )!,
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $CardHeartsTable createAlias(String alias) {
    return $CardHeartsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<HeartKind, String, String> $converterkind =
      const EnumNameConverter<HeartKind>(HeartKind.values);
  static JsonTypeConverter2<HeartColor, String, String> $convertercolor =
      const EnumNameConverter<HeartColor>(HeartColor.values);
}

class CardHeartRow extends DataClass implements Insertable<CardHeartRow> {
  final String cardNumber;
  final HeartKind kind;
  final HeartColor color;
  final int count;
  const CardHeartRow({
    required this.cardNumber,
    required this.kind,
    required this.color,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_number'] = Variable<String>(cardNumber);
    {
      map['kind'] = Variable<String>(
        $CardHeartsTable.$converterkind.toSql(kind),
      );
    }
    {
      map['color'] = Variable<String>(
        $CardHeartsTable.$convertercolor.toSql(color),
      );
    }
    map['count'] = Variable<int>(count);
    return map;
  }

  CardHeartsCompanion toCompanion(bool nullToAbsent) {
    return CardHeartsCompanion(
      cardNumber: Value(cardNumber),
      kind: Value(kind),
      color: Value(color),
      count: Value(count),
    );
  }

  factory CardHeartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardHeartRow(
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      kind: $CardHeartsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      color: $CardHeartsTable.$convertercolor.fromJson(
        serializer.fromJson<String>(json['color']),
      ),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardNumber': serializer.toJson<String>(cardNumber),
      'kind': serializer.toJson<String>(
        $CardHeartsTable.$converterkind.toJson(kind),
      ),
      'color': serializer.toJson<String>(
        $CardHeartsTable.$convertercolor.toJson(color),
      ),
      'count': serializer.toJson<int>(count),
    };
  }

  CardHeartRow copyWith({
    String? cardNumber,
    HeartKind? kind,
    HeartColor? color,
    int? count,
  }) => CardHeartRow(
    cardNumber: cardNumber ?? this.cardNumber,
    kind: kind ?? this.kind,
    color: color ?? this.color,
    count: count ?? this.count,
  );
  CardHeartRow copyWithCompanion(CardHeartsCompanion data) {
    return CardHeartRow(
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      kind: data.kind.present ? data.kind.value : this.kind,
      color: data.color.present ? data.color.value : this.color,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardHeartRow(')
          ..write('cardNumber: $cardNumber, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardNumber, kind, color, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardHeartRow &&
          other.cardNumber == this.cardNumber &&
          other.kind == this.kind &&
          other.color == this.color &&
          other.count == this.count);
}

class CardHeartsCompanion extends UpdateCompanion<CardHeartRow> {
  final Value<String> cardNumber;
  final Value<HeartKind> kind;
  final Value<HeartColor> color;
  final Value<int> count;
  final Value<int> rowid;
  const CardHeartsCompanion({
    this.cardNumber = const Value.absent(),
    this.kind = const Value.absent(),
    this.color = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardHeartsCompanion.insert({
    required String cardNumber,
    required HeartKind kind,
    required HeartColor color,
    required int count,
    this.rowid = const Value.absent(),
  }) : cardNumber = Value(cardNumber),
       kind = Value(kind),
       color = Value(color),
       count = Value(count);
  static Insertable<CardHeartRow> custom({
    Expression<String>? cardNumber,
    Expression<String>? kind,
    Expression<String>? color,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardNumber != null) 'card_number': cardNumber,
      if (kind != null) 'kind': kind,
      if (color != null) 'color': color,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardHeartsCompanion copyWith({
    Value<String>? cardNumber,
    Value<HeartKind>? kind,
    Value<HeartColor>? color,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return CardHeartsCompanion(
      cardNumber: cardNumber ?? this.cardNumber,
      kind: kind ?? this.kind,
      color: color ?? this.color,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $CardHeartsTable.$converterkind.toSql(kind.value),
      );
    }
    if (color.present) {
      map['color'] = Variable<String>(
        $CardHeartsTable.$convertercolor.toSql(color.value),
      );
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardHeartsCompanion(')
          ..write('cardNumber: $cardNumber, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CardBladeHeartEffectsTable extends CardBladeHeartEffects
    with TableInfo<$CardBladeHeartEffectsTable, CardBladeHeartEffectRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardBladeHeartEffectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (card_number) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<BladeHeartEffect, String> effect =
      GeneratedColumn<String>(
        'effect',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<BladeHeartEffect>(
        $CardBladeHeartEffectsTable.$convertereffect,
      );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cardNumber, effect, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_blade_heart_effects';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardBladeHeartEffectRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cardNumber, effect};
  @override
  CardBladeHeartEffectRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardBladeHeartEffectRow(
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      effect: $CardBladeHeartEffectsTable.$convertereffect.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}effect'],
        )!,
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $CardBladeHeartEffectsTable createAlias(String alias) {
    return $CardBladeHeartEffectsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BladeHeartEffect, String, String> $convertereffect =
      const EnumNameConverter<BladeHeartEffect>(BladeHeartEffect.values);
}

class CardBladeHeartEffectRow extends DataClass
    implements Insertable<CardBladeHeartEffectRow> {
  final String cardNumber;
  final BladeHeartEffect effect;
  final int count;
  const CardBladeHeartEffectRow({
    required this.cardNumber,
    required this.effect,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['card_number'] = Variable<String>(cardNumber);
    {
      map['effect'] = Variable<String>(
        $CardBladeHeartEffectsTable.$convertereffect.toSql(effect),
      );
    }
    map['count'] = Variable<int>(count);
    return map;
  }

  CardBladeHeartEffectsCompanion toCompanion(bool nullToAbsent) {
    return CardBladeHeartEffectsCompanion(
      cardNumber: Value(cardNumber),
      effect: Value(effect),
      count: Value(count),
    );
  }

  factory CardBladeHeartEffectRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardBladeHeartEffectRow(
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      effect: $CardBladeHeartEffectsTable.$convertereffect.fromJson(
        serializer.fromJson<String>(json['effect']),
      ),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cardNumber': serializer.toJson<String>(cardNumber),
      'effect': serializer.toJson<String>(
        $CardBladeHeartEffectsTable.$convertereffect.toJson(effect),
      ),
      'count': serializer.toJson<int>(count),
    };
  }

  CardBladeHeartEffectRow copyWith({
    String? cardNumber,
    BladeHeartEffect? effect,
    int? count,
  }) => CardBladeHeartEffectRow(
    cardNumber: cardNumber ?? this.cardNumber,
    effect: effect ?? this.effect,
    count: count ?? this.count,
  );
  CardBladeHeartEffectRow copyWithCompanion(
    CardBladeHeartEffectsCompanion data,
  ) {
    return CardBladeHeartEffectRow(
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      effect: data.effect.present ? data.effect.value : this.effect,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardBladeHeartEffectRow(')
          ..write('cardNumber: $cardNumber, ')
          ..write('effect: $effect, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cardNumber, effect, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardBladeHeartEffectRow &&
          other.cardNumber == this.cardNumber &&
          other.effect == this.effect &&
          other.count == this.count);
}

class CardBladeHeartEffectsCompanion
    extends UpdateCompanion<CardBladeHeartEffectRow> {
  final Value<String> cardNumber;
  final Value<BladeHeartEffect> effect;
  final Value<int> count;
  final Value<int> rowid;
  const CardBladeHeartEffectsCompanion({
    this.cardNumber = const Value.absent(),
    this.effect = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardBladeHeartEffectsCompanion.insert({
    required String cardNumber,
    required BladeHeartEffect effect,
    required int count,
    this.rowid = const Value.absent(),
  }) : cardNumber = Value(cardNumber),
       effect = Value(effect),
       count = Value(count);
  static Insertable<CardBladeHeartEffectRow> custom({
    Expression<String>? cardNumber,
    Expression<String>? effect,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cardNumber != null) 'card_number': cardNumber,
      if (effect != null) 'effect': effect,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardBladeHeartEffectsCompanion copyWith({
    Value<String>? cardNumber,
    Value<BladeHeartEffect>? effect,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return CardBladeHeartEffectsCompanion(
      cardNumber: cardNumber ?? this.cardNumber,
      effect: effect ?? this.effect,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (effect.present) {
      map['effect'] = Variable<String>(
        $CardBladeHeartEffectsTable.$convertereffect.toSql(effect.value),
      );
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardBladeHeartEffectsCompanion(')
          ..write('cardNumber: $cardNumber, ')
          ..write('effect: $effect, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrintingsTable extends Printings
    with TableInfo<$PrintingsTable, PrintingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrintingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _printingIdMeta = const VerificationMeta(
    'printingId',
  );
  @override
  late final GeneratedColumn<String> printingId = GeneratedColumn<String>(
    'printing_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cardNumberMeta = const VerificationMeta(
    'cardNumber',
  );
  @override
  late final GeneratedColumn<String> cardNumber = GeneratedColumn<String>(
    'card_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (card_number) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _expansionMeta = const VerificationMeta(
    'expansion',
  );
  @override
  late final GeneratedColumn<String> expansion = GeneratedColumn<String>(
    'expansion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isParallelMeta = const VerificationMeta(
    'isParallel',
  );
  @override
  late final GeneratedColumn<bool> isParallel = GeneratedColumn<bool>(
    'is_parallel',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_parallel" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _illustratorMeta = const VerificationMeta(
    'illustrator',
  );
  @override
  late final GeneratedColumn<String> illustrator = GeneratedColumn<String>(
    'illustrator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageHashMeta = const VerificationMeta(
    'imageHash',
  );
  @override
  late final GeneratedColumn<String> imageHash = GeneratedColumn<String>(
    'image_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    printingId,
    cardNumber,
    expansion,
    rarity,
    isParallel,
    illustrator,
    imageHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'printings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PrintingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('printing_id')) {
      context.handle(
        _printingIdMeta,
        printingId.isAcceptableOrUnknown(data['printing_id']!, _printingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_printingIdMeta);
    }
    if (data.containsKey('card_number')) {
      context.handle(
        _cardNumberMeta,
        cardNumber.isAcceptableOrUnknown(data['card_number']!, _cardNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_cardNumberMeta);
    }
    if (data.containsKey('expansion')) {
      context.handle(
        _expansionMeta,
        expansion.isAcceptableOrUnknown(data['expansion']!, _expansionMeta),
      );
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    }
    if (data.containsKey('is_parallel')) {
      context.handle(
        _isParallelMeta,
        isParallel.isAcceptableOrUnknown(data['is_parallel']!, _isParallelMeta),
      );
    }
    if (data.containsKey('illustrator')) {
      context.handle(
        _illustratorMeta,
        illustrator.isAcceptableOrUnknown(
          data['illustrator']!,
          _illustratorMeta,
        ),
      );
    }
    if (data.containsKey('image_hash')) {
      context.handle(
        _imageHashMeta,
        imageHash.isAcceptableOrUnknown(data['image_hash']!, _imageHashMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {printingId};
  @override
  PrintingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrintingRow(
      printingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printing_id'],
      )!,
      cardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number'],
      )!,
      expansion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expansion'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      )!,
      isParallel: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_parallel'],
      )!,
      illustrator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}illustrator'],
      )!,
      imageHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_hash'],
      )!,
    );
  }

  @override
  $PrintingsTable createAlias(String alias) {
    return $PrintingsTable(attachedDatabase, alias);
  }
}

class PrintingRow extends DataClass implements Insertable<PrintingRow> {
  final String printingId;
  final String cardNumber;
  final String expansion;
  final String rarity;

  /// ★「cardNumber ごとの代表 1 枚」ではない★
  /// パラレル表示 OFF = `isParallel == false` の刷りを**すべて**表示する。
  final bool isParallel;
  final String illustrator;

  /// 画像のコンテンツハッシュ。画像キャッシュの無効化キーに使う。
  /// ★公式サイトの `picture` パスから URL を組み立ててはいけない（CLAUDE.md §5-(3)）。
  final String imageHash;
  const PrintingRow({
    required this.printingId,
    required this.cardNumber,
    required this.expansion,
    required this.rarity,
    required this.isParallel,
    required this.illustrator,
    required this.imageHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['printing_id'] = Variable<String>(printingId);
    map['card_number'] = Variable<String>(cardNumber);
    map['expansion'] = Variable<String>(expansion);
    map['rarity'] = Variable<String>(rarity);
    map['is_parallel'] = Variable<bool>(isParallel);
    map['illustrator'] = Variable<String>(illustrator);
    map['image_hash'] = Variable<String>(imageHash);
    return map;
  }

  PrintingsCompanion toCompanion(bool nullToAbsent) {
    return PrintingsCompanion(
      printingId: Value(printingId),
      cardNumber: Value(cardNumber),
      expansion: Value(expansion),
      rarity: Value(rarity),
      isParallel: Value(isParallel),
      illustrator: Value(illustrator),
      imageHash: Value(imageHash),
    );
  }

  factory PrintingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrintingRow(
      printingId: serializer.fromJson<String>(json['printingId']),
      cardNumber: serializer.fromJson<String>(json['cardNumber']),
      expansion: serializer.fromJson<String>(json['expansion']),
      rarity: serializer.fromJson<String>(json['rarity']),
      isParallel: serializer.fromJson<bool>(json['isParallel']),
      illustrator: serializer.fromJson<String>(json['illustrator']),
      imageHash: serializer.fromJson<String>(json['imageHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'printingId': serializer.toJson<String>(printingId),
      'cardNumber': serializer.toJson<String>(cardNumber),
      'expansion': serializer.toJson<String>(expansion),
      'rarity': serializer.toJson<String>(rarity),
      'isParallel': serializer.toJson<bool>(isParallel),
      'illustrator': serializer.toJson<String>(illustrator),
      'imageHash': serializer.toJson<String>(imageHash),
    };
  }

  PrintingRow copyWith({
    String? printingId,
    String? cardNumber,
    String? expansion,
    String? rarity,
    bool? isParallel,
    String? illustrator,
    String? imageHash,
  }) => PrintingRow(
    printingId: printingId ?? this.printingId,
    cardNumber: cardNumber ?? this.cardNumber,
    expansion: expansion ?? this.expansion,
    rarity: rarity ?? this.rarity,
    isParallel: isParallel ?? this.isParallel,
    illustrator: illustrator ?? this.illustrator,
    imageHash: imageHash ?? this.imageHash,
  );
  PrintingRow copyWithCompanion(PrintingsCompanion data) {
    return PrintingRow(
      printingId: data.printingId.present
          ? data.printingId.value
          : this.printingId,
      cardNumber: data.cardNumber.present
          ? data.cardNumber.value
          : this.cardNumber,
      expansion: data.expansion.present ? data.expansion.value : this.expansion,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      isParallel: data.isParallel.present
          ? data.isParallel.value
          : this.isParallel,
      illustrator: data.illustrator.present
          ? data.illustrator.value
          : this.illustrator,
      imageHash: data.imageHash.present ? data.imageHash.value : this.imageHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrintingRow(')
          ..write('printingId: $printingId, ')
          ..write('cardNumber: $cardNumber, ')
          ..write('expansion: $expansion, ')
          ..write('rarity: $rarity, ')
          ..write('isParallel: $isParallel, ')
          ..write('illustrator: $illustrator, ')
          ..write('imageHash: $imageHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    printingId,
    cardNumber,
    expansion,
    rarity,
    isParallel,
    illustrator,
    imageHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrintingRow &&
          other.printingId == this.printingId &&
          other.cardNumber == this.cardNumber &&
          other.expansion == this.expansion &&
          other.rarity == this.rarity &&
          other.isParallel == this.isParallel &&
          other.illustrator == this.illustrator &&
          other.imageHash == this.imageHash);
}

class PrintingsCompanion extends UpdateCompanion<PrintingRow> {
  final Value<String> printingId;
  final Value<String> cardNumber;
  final Value<String> expansion;
  final Value<String> rarity;
  final Value<bool> isParallel;
  final Value<String> illustrator;
  final Value<String> imageHash;
  final Value<int> rowid;
  const PrintingsCompanion({
    this.printingId = const Value.absent(),
    this.cardNumber = const Value.absent(),
    this.expansion = const Value.absent(),
    this.rarity = const Value.absent(),
    this.isParallel = const Value.absent(),
    this.illustrator = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrintingsCompanion.insert({
    required String printingId,
    required String cardNumber,
    this.expansion = const Value.absent(),
    this.rarity = const Value.absent(),
    this.isParallel = const Value.absent(),
    this.illustrator = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : printingId = Value(printingId),
       cardNumber = Value(cardNumber);
  static Insertable<PrintingRow> custom({
    Expression<String>? printingId,
    Expression<String>? cardNumber,
    Expression<String>? expansion,
    Expression<String>? rarity,
    Expression<bool>? isParallel,
    Expression<String>? illustrator,
    Expression<String>? imageHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (printingId != null) 'printing_id': printingId,
      if (cardNumber != null) 'card_number': cardNumber,
      if (expansion != null) 'expansion': expansion,
      if (rarity != null) 'rarity': rarity,
      if (isParallel != null) 'is_parallel': isParallel,
      if (illustrator != null) 'illustrator': illustrator,
      if (imageHash != null) 'image_hash': imageHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrintingsCompanion copyWith({
    Value<String>? printingId,
    Value<String>? cardNumber,
    Value<String>? expansion,
    Value<String>? rarity,
    Value<bool>? isParallel,
    Value<String>? illustrator,
    Value<String>? imageHash,
    Value<int>? rowid,
  }) {
    return PrintingsCompanion(
      printingId: printingId ?? this.printingId,
      cardNumber: cardNumber ?? this.cardNumber,
      expansion: expansion ?? this.expansion,
      rarity: rarity ?? this.rarity,
      isParallel: isParallel ?? this.isParallel,
      illustrator: illustrator ?? this.illustrator,
      imageHash: imageHash ?? this.imageHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (printingId.present) {
      map['printing_id'] = Variable<String>(printingId.value);
    }
    if (cardNumber.present) {
      map['card_number'] = Variable<String>(cardNumber.value);
    }
    if (expansion.present) {
      map['expansion'] = Variable<String>(expansion.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (isParallel.present) {
      map['is_parallel'] = Variable<bool>(isParallel.value);
    }
    if (illustrator.present) {
      map['illustrator'] = Variable<String>(illustrator.value);
    }
    if (imageHash.present) {
      map['image_hash'] = Variable<String>(imageHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrintingsCompanion(')
          ..write('printingId: $printingId, ')
          ..write('cardNumber: $cardNumber, ')
          ..write('expansion: $expansion, ')
          ..write('rarity: $rarity, ')
          ..write('isParallel: $isParallel, ')
          ..write('illustrator: $illustrator, ')
          ..write('imageHash: $imageHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products
    with TableInfo<$ProductsTable, ProductRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _expansionIdMeta = const VerificationMeta(
    'expansionId',
  );
  @override
  late final GeneratedColumn<String> expansionId = GeneratedColumn<String>(
    'expansion_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<String> releaseDate = GeneratedColumn<String>(
    'release_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    expansionId,
    name,
    releaseDate,
    slug,
    url,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('expansion_id')) {
      context.handle(
        _expansionIdMeta,
        expansionId.isAcceptableOrUnknown(
          data['expansion_id']!,
          _expansionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_expansionIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {expansionId};
  @override
  ProductRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductRow(
      expansionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expansion_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}release_date'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class ProductRow extends DataClass implements Insertable<ProductRow> {
  final String expansionId;
  final String name;

  /// 公式表記は "2025.02.08" 形式。
  final String releaseDate;
  final String slug;
  final String url;
  const ProductRow({
    required this.expansionId,
    required this.name,
    required this.releaseDate,
    required this.slug,
    required this.url,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['expansion_id'] = Variable<String>(expansionId);
    map['name'] = Variable<String>(name);
    map['release_date'] = Variable<String>(releaseDate);
    map['slug'] = Variable<String>(slug);
    map['url'] = Variable<String>(url);
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      expansionId: Value(expansionId),
      name: Value(name),
      releaseDate: Value(releaseDate),
      slug: Value(slug),
      url: Value(url),
    );
  }

  factory ProductRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductRow(
      expansionId: serializer.fromJson<String>(json['expansionId']),
      name: serializer.fromJson<String>(json['name']),
      releaseDate: serializer.fromJson<String>(json['releaseDate']),
      slug: serializer.fromJson<String>(json['slug']),
      url: serializer.fromJson<String>(json['url']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'expansionId': serializer.toJson<String>(expansionId),
      'name': serializer.toJson<String>(name),
      'releaseDate': serializer.toJson<String>(releaseDate),
      'slug': serializer.toJson<String>(slug),
      'url': serializer.toJson<String>(url),
    };
  }

  ProductRow copyWith({
    String? expansionId,
    String? name,
    String? releaseDate,
    String? slug,
    String? url,
  }) => ProductRow(
    expansionId: expansionId ?? this.expansionId,
    name: name ?? this.name,
    releaseDate: releaseDate ?? this.releaseDate,
    slug: slug ?? this.slug,
    url: url ?? this.url,
  );
  ProductRow copyWithCompanion(ProductsCompanion data) {
    return ProductRow(
      expansionId: data.expansionId.present
          ? data.expansionId.value
          : this.expansionId,
      name: data.name.present ? data.name.value : this.name,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      slug: data.slug.present ? data.slug.value : this.slug,
      url: data.url.present ? data.url.value : this.url,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductRow(')
          ..write('expansionId: $expansionId, ')
          ..write('name: $name, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('slug: $slug, ')
          ..write('url: $url')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(expansionId, name, releaseDate, slug, url);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductRow &&
          other.expansionId == this.expansionId &&
          other.name == this.name &&
          other.releaseDate == this.releaseDate &&
          other.slug == this.slug &&
          other.url == this.url);
}

class ProductsCompanion extends UpdateCompanion<ProductRow> {
  final Value<String> expansionId;
  final Value<String> name;
  final Value<String> releaseDate;
  final Value<String> slug;
  final Value<String> url;
  final Value<int> rowid;
  const ProductsCompanion({
    this.expansionId = const Value.absent(),
    this.name = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.slug = const Value.absent(),
    this.url = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductsCompanion.insert({
    required String expansionId,
    this.name = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.slug = const Value.absent(),
    this.url = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : expansionId = Value(expansionId);
  static Insertable<ProductRow> custom({
    Expression<String>? expansionId,
    Expression<String>? name,
    Expression<String>? releaseDate,
    Expression<String>? slug,
    Expression<String>? url,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (expansionId != null) 'expansion_id': expansionId,
      if (name != null) 'name': name,
      if (releaseDate != null) 'release_date': releaseDate,
      if (slug != null) 'slug': slug,
      if (url != null) 'url': url,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductsCompanion copyWith({
    Value<String>? expansionId,
    Value<String>? name,
    Value<String>? releaseDate,
    Value<String>? slug,
    Value<String>? url,
    Value<int>? rowid,
  }) {
    return ProductsCompanion(
      expansionId: expansionId ?? this.expansionId,
      name: name ?? this.name,
      releaseDate: releaseDate ?? this.releaseDate,
      slug: slug ?? this.slug,
      url: url ?? this.url,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (expansionId.present) {
      map['expansion_id'] = Variable<String>(expansionId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<String>(releaseDate.value);
    }
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('expansionId: $expansionId, ')
          ..write('name: $name, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('slug: $slug, ')
          ..write('url: $url, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FaqsTable extends Faqs with TableInfo<$FaqsTable, FaqRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FaqsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _qaIdMeta = const VerificationMeta('qaId');
  @override
  late final GeneratedColumn<String> qaId = GeneratedColumn<String>(
    'qa_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _faqIdMeta = const VerificationMeta('faqId');
  @override
  late final GeneratedColumn<int> faqId = GeneratedColumn<int>(
    'faq_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _registTimeMeta = const VerificationMeta(
    'registTime',
  );
  @override
  late final GeneratedColumn<String> registTime = GeneratedColumn<String>(
    'regist_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updateTimeMeta = const VerificationMeta(
    'updateTime',
  );
  @override
  late final GeneratedColumn<String> updateTime = GeneratedColumn<String>(
    'update_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    qaId,
    faqId,
    question,
    answer,
    registTime,
    updateTime,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'faqs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FaqRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('qa_id')) {
      context.handle(
        _qaIdMeta,
        qaId.isAcceptableOrUnknown(data['qa_id']!, _qaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_qaIdMeta);
    }
    if (data.containsKey('faq_id')) {
      context.handle(
        _faqIdMeta,
        faqId.isAcceptableOrUnknown(data['faq_id']!, _faqIdMeta),
      );
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    }
    if (data.containsKey('regist_time')) {
      context.handle(
        _registTimeMeta,
        registTime.isAcceptableOrUnknown(data['regist_time']!, _registTimeMeta),
      );
    }
    if (data.containsKey('update_time')) {
      context.handle(
        _updateTimeMeta,
        updateTime.isAcceptableOrUnknown(data['update_time']!, _updateTimeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {qaId};
  @override
  FaqRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FaqRow(
      qaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qa_id'],
      )!,
      faqId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}faq_id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      registTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regist_time'],
      )!,
      updateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}update_time'],
      )!,
    );
  }

  @override
  $FaqsTable createAlias(String alias) {
    return $FaqsTable(attachedDatabase, alias);
  }
}

class FaqRow extends DataClass implements Insertable<FaqRow> {
  /// 公式の Q 番号。同一 Q&A が複数カードに紐づくため、これが重複排除のキー。
  final String qaId;
  final int faqId;
  final String question;
  final String answer;
  final String registTime;
  final String updateTime;
  const FaqRow({
    required this.qaId,
    required this.faqId,
    required this.question,
    required this.answer,
    required this.registTime,
    required this.updateTime,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['qa_id'] = Variable<String>(qaId);
    map['faq_id'] = Variable<int>(faqId);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['regist_time'] = Variable<String>(registTime);
    map['update_time'] = Variable<String>(updateTime);
    return map;
  }

  FaqsCompanion toCompanion(bool nullToAbsent) {
    return FaqsCompanion(
      qaId: Value(qaId),
      faqId: Value(faqId),
      question: Value(question),
      answer: Value(answer),
      registTime: Value(registTime),
      updateTime: Value(updateTime),
    );
  }

  factory FaqRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FaqRow(
      qaId: serializer.fromJson<String>(json['qaId']),
      faqId: serializer.fromJson<int>(json['faqId']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      registTime: serializer.fromJson<String>(json['registTime']),
      updateTime: serializer.fromJson<String>(json['updateTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'qaId': serializer.toJson<String>(qaId),
      'faqId': serializer.toJson<int>(faqId),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'registTime': serializer.toJson<String>(registTime),
      'updateTime': serializer.toJson<String>(updateTime),
    };
  }

  FaqRow copyWith({
    String? qaId,
    int? faqId,
    String? question,
    String? answer,
    String? registTime,
    String? updateTime,
  }) => FaqRow(
    qaId: qaId ?? this.qaId,
    faqId: faqId ?? this.faqId,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    registTime: registTime ?? this.registTime,
    updateTime: updateTime ?? this.updateTime,
  );
  FaqRow copyWithCompanion(FaqsCompanion data) {
    return FaqRow(
      qaId: data.qaId.present ? data.qaId.value : this.qaId,
      faqId: data.faqId.present ? data.faqId.value : this.faqId,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      registTime: data.registTime.present
          ? data.registTime.value
          : this.registTime,
      updateTime: data.updateTime.present
          ? data.updateTime.value
          : this.updateTime,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FaqRow(')
          ..write('qaId: $qaId, ')
          ..write('faqId: $faqId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('registTime: $registTime, ')
          ..write('updateTime: $updateTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(qaId, faqId, question, answer, registTime, updateTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FaqRow &&
          other.qaId == this.qaId &&
          other.faqId == this.faqId &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.registTime == this.registTime &&
          other.updateTime == this.updateTime);
}

class FaqsCompanion extends UpdateCompanion<FaqRow> {
  final Value<String> qaId;
  final Value<int> faqId;
  final Value<String> question;
  final Value<String> answer;
  final Value<String> registTime;
  final Value<String> updateTime;
  final Value<int> rowid;
  const FaqsCompanion({
    this.qaId = const Value.absent(),
    this.faqId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.registTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FaqsCompanion.insert({
    required String qaId,
    this.faqId = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.registTime = const Value.absent(),
    this.updateTime = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : qaId = Value(qaId);
  static Insertable<FaqRow> custom({
    Expression<String>? qaId,
    Expression<int>? faqId,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? registTime,
    Expression<String>? updateTime,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (qaId != null) 'qa_id': qaId,
      if (faqId != null) 'faq_id': faqId,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (registTime != null) 'regist_time': registTime,
      if (updateTime != null) 'update_time': updateTime,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FaqsCompanion copyWith({
    Value<String>? qaId,
    Value<int>? faqId,
    Value<String>? question,
    Value<String>? answer,
    Value<String>? registTime,
    Value<String>? updateTime,
    Value<int>? rowid,
  }) {
    return FaqsCompanion(
      qaId: qaId ?? this.qaId,
      faqId: faqId ?? this.faqId,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      registTime: registTime ?? this.registTime,
      updateTime: updateTime ?? this.updateTime,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (qaId.present) {
      map['qa_id'] = Variable<String>(qaId.value);
    }
    if (faqId.present) {
      map['faq_id'] = Variable<int>(faqId.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (registTime.present) {
      map['regist_time'] = Variable<String>(registTime.value);
    }
    if (updateTime.present) {
      map['update_time'] = Variable<String>(updateTime.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FaqsCompanion(')
          ..write('qaId: $qaId, ')
          ..write('faqId: $faqId, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('registTime: $registTime, ')
          ..write('updateTime: $updateTime, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FaqPrintingsTable extends FaqPrintings
    with TableInfo<$FaqPrintingsTable, FaqPrintingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FaqPrintingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _qaIdMeta = const VerificationMeta('qaId');
  @override
  late final GeneratedColumn<String> qaId = GeneratedColumn<String>(
    'qa_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES faqs (qa_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _printingIdMeta = const VerificationMeta(
    'printingId',
  );
  @override
  late final GeneratedColumn<String> printingId = GeneratedColumn<String>(
    'printing_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [qaId, printingId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'faq_printings';
  @override
  VerificationContext validateIntegrity(
    Insertable<FaqPrintingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('qa_id')) {
      context.handle(
        _qaIdMeta,
        qaId.isAcceptableOrUnknown(data['qa_id']!, _qaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_qaIdMeta);
    }
    if (data.containsKey('printing_id')) {
      context.handle(
        _printingIdMeta,
        printingId.isAcceptableOrUnknown(data['printing_id']!, _printingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_printingIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {qaId, printingId};
  @override
  FaqPrintingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FaqPrintingRow(
      qaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qa_id'],
      )!,
      printingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printing_id'],
      )!,
    );
  }

  @override
  $FaqPrintingsTable createAlias(String alias) {
    return $FaqPrintingsTable(attachedDatabase, alias);
  }
}

class FaqPrintingRow extends DataClass implements Insertable<FaqPrintingRow> {
  final String qaId;
  final String printingId;
  const FaqPrintingRow({required this.qaId, required this.printingId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['qa_id'] = Variable<String>(qaId);
    map['printing_id'] = Variable<String>(printingId);
    return map;
  }

  FaqPrintingsCompanion toCompanion(bool nullToAbsent) {
    return FaqPrintingsCompanion(
      qaId: Value(qaId),
      printingId: Value(printingId),
    );
  }

  factory FaqPrintingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FaqPrintingRow(
      qaId: serializer.fromJson<String>(json['qaId']),
      printingId: serializer.fromJson<String>(json['printingId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'qaId': serializer.toJson<String>(qaId),
      'printingId': serializer.toJson<String>(printingId),
    };
  }

  FaqPrintingRow copyWith({String? qaId, String? printingId}) => FaqPrintingRow(
    qaId: qaId ?? this.qaId,
    printingId: printingId ?? this.printingId,
  );
  FaqPrintingRow copyWithCompanion(FaqPrintingsCompanion data) {
    return FaqPrintingRow(
      qaId: data.qaId.present ? data.qaId.value : this.qaId,
      printingId: data.printingId.present
          ? data.printingId.value
          : this.printingId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FaqPrintingRow(')
          ..write('qaId: $qaId, ')
          ..write('printingId: $printingId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(qaId, printingId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FaqPrintingRow &&
          other.qaId == this.qaId &&
          other.printingId == this.printingId);
}

class FaqPrintingsCompanion extends UpdateCompanion<FaqPrintingRow> {
  final Value<String> qaId;
  final Value<String> printingId;
  final Value<int> rowid;
  const FaqPrintingsCompanion({
    this.qaId = const Value.absent(),
    this.printingId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FaqPrintingsCompanion.insert({
    required String qaId,
    required String printingId,
    this.rowid = const Value.absent(),
  }) : qaId = Value(qaId),
       printingId = Value(printingId);
  static Insertable<FaqPrintingRow> custom({
    Expression<String>? qaId,
    Expression<String>? printingId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (qaId != null) 'qa_id': qaId,
      if (printingId != null) 'printing_id': printingId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FaqPrintingsCompanion copyWith({
    Value<String>? qaId,
    Value<String>? printingId,
    Value<int>? rowid,
  }) {
    return FaqPrintingsCompanion(
      qaId: qaId ?? this.qaId,
      printingId: printingId ?? this.printingId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (qaId.present) {
      map['qa_id'] = Variable<String>(qaId.value);
    }
    if (printingId.present) {
      map['printing_id'] = Variable<String>(printingId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FaqPrintingsCompanion(')
          ..write('qaId: $qaId, ')
          ..write('printingId: $printingId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RuleConfigsTable extends RuleConfigs
    with TableInfo<$RuleConfigsTable, RuleConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RuleConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mainDeckSizeMeta = const VerificationMeta(
    'mainDeckSize',
  );
  @override
  late final GeneratedColumn<int> mainDeckSize = GeneratedColumn<int>(
    'main_deck_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberCountMeta = const VerificationMeta(
    'memberCount',
  );
  @override
  late final GeneratedColumn<int> memberCount = GeneratedColumn<int>(
    'member_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _liveCountMeta = const VerificationMeta(
    'liveCount',
  );
  @override
  late final GeneratedColumn<int> liveCount = GeneratedColumn<int>(
    'live_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _energyDeckSizeMeta = const VerificationMeta(
    'energyDeckSize',
  );
  @override
  late final GeneratedColumn<int> energyDeckSize = GeneratedColumn<int>(
    'energy_deck_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _maxCopiesPerCardNumberMeta =
      const VerificationMeta('maxCopiesPerCardNumber');
  @override
  late final GeneratedColumn<int> maxCopiesPerCardNumber = GeneratedColumn<int>(
    'max_copies_per_card_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _initialHandSizeMeta = const VerificationMeta(
    'initialHandSize',
  );
  @override
  late final GeneratedColumn<int> initialHandSize = GeneratedColumn<int>(
    'initial_hand_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _initialEnergyOnFieldMeta =
      const VerificationMeta('initialEnergyOnField');
  @override
  late final GeneratedColumn<int> initialEnergyOnField = GeneratedColumn<int>(
    'initial_energy_on_field',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _liveSlotMaxMeta = const VerificationMeta(
    'liveSlotMax',
  );
  @override
  late final GeneratedColumn<int> liveSlotMax = GeneratedColumn<int>(
    'live_slot_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _winConditionMeta = const VerificationMeta(
    'winCondition',
  );
  @override
  late final GeneratedColumn<int> winCondition = GeneratedColumn<int>(
    'win_condition',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stageAreaCountMeta = const VerificationMeta(
    'stageAreaCount',
  );
  @override
  late final GeneratedColumn<int> stageAreaCount = GeneratedColumn<int>(
    'stage_area_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mainDeckSize,
    memberCount,
    liveCount,
    energyDeckSize,
    maxCopiesPerCardNumber,
    initialHandSize,
    initialEnergyOnField,
    liveSlotMax,
    winCondition,
    stageAreaCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rule_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleConfigRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('main_deck_size')) {
      context.handle(
        _mainDeckSizeMeta,
        mainDeckSize.isAcceptableOrUnknown(
          data['main_deck_size']!,
          _mainDeckSizeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_mainDeckSizeMeta);
    }
    if (data.containsKey('member_count')) {
      context.handle(
        _memberCountMeta,
        memberCount.isAcceptableOrUnknown(
          data['member_count']!,
          _memberCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberCountMeta);
    }
    if (data.containsKey('live_count')) {
      context.handle(
        _liveCountMeta,
        liveCount.isAcceptableOrUnknown(data['live_count']!, _liveCountMeta),
      );
    } else if (isInserting) {
      context.missing(_liveCountMeta);
    }
    if (data.containsKey('energy_deck_size')) {
      context.handle(
        _energyDeckSizeMeta,
        energyDeckSize.isAcceptableOrUnknown(
          data['energy_deck_size']!,
          _energyDeckSizeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_energyDeckSizeMeta);
    }
    if (data.containsKey('max_copies_per_card_number')) {
      context.handle(
        _maxCopiesPerCardNumberMeta,
        maxCopiesPerCardNumber.isAcceptableOrUnknown(
          data['max_copies_per_card_number']!,
          _maxCopiesPerCardNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_maxCopiesPerCardNumberMeta);
    }
    if (data.containsKey('initial_hand_size')) {
      context.handle(
        _initialHandSizeMeta,
        initialHandSize.isAcceptableOrUnknown(
          data['initial_hand_size']!,
          _initialHandSizeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initialHandSizeMeta);
    }
    if (data.containsKey('initial_energy_on_field')) {
      context.handle(
        _initialEnergyOnFieldMeta,
        initialEnergyOnField.isAcceptableOrUnknown(
          data['initial_energy_on_field']!,
          _initialEnergyOnFieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initialEnergyOnFieldMeta);
    }
    if (data.containsKey('live_slot_max')) {
      context.handle(
        _liveSlotMaxMeta,
        liveSlotMax.isAcceptableOrUnknown(
          data['live_slot_max']!,
          _liveSlotMaxMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_liveSlotMaxMeta);
    }
    if (data.containsKey('win_condition')) {
      context.handle(
        _winConditionMeta,
        winCondition.isAcceptableOrUnknown(
          data['win_condition']!,
          _winConditionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_winConditionMeta);
    }
    if (data.containsKey('stage_area_count')) {
      context.handle(
        _stageAreaCountMeta,
        stageAreaCount.isAcceptableOrUnknown(
          data['stage_area_count']!,
          _stageAreaCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_stageAreaCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleConfigRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mainDeckSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}main_deck_size'],
      )!,
      memberCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_count'],
      )!,
      liveCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}live_count'],
      )!,
      energyDeckSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_deck_size'],
      )!,
      maxCopiesPerCardNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_copies_per_card_number'],
      )!,
      initialHandSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_hand_size'],
      )!,
      initialEnergyOnField: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_energy_on_field'],
      )!,
      liveSlotMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}live_slot_max'],
      )!,
      winCondition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}win_condition'],
      )!,
      stageAreaCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage_area_count'],
      )!,
    );
  }

  @override
  $RuleConfigsTable createAlias(String alias) {
    return $RuleConfigsTable(attachedDatabase, alias);
  }
}

class RuleConfigRow extends DataClass implements Insertable<RuleConfigRow> {
  final int id;
  final int mainDeckSize;
  final int memberCount;
  final int liveCount;
  final int energyDeckSize;
  final int maxCopiesPerCardNumber;
  final int initialHandSize;
  final int initialEnergyOnField;
  final int liveSlotMax;
  final int winCondition;
  final int stageAreaCount;
  const RuleConfigRow({
    required this.id,
    required this.mainDeckSize,
    required this.memberCount,
    required this.liveCount,
    required this.energyDeckSize,
    required this.maxCopiesPerCardNumber,
    required this.initialHandSize,
    required this.initialEnergyOnField,
    required this.liveSlotMax,
    required this.winCondition,
    required this.stageAreaCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['main_deck_size'] = Variable<int>(mainDeckSize);
    map['member_count'] = Variable<int>(memberCount);
    map['live_count'] = Variable<int>(liveCount);
    map['energy_deck_size'] = Variable<int>(energyDeckSize);
    map['max_copies_per_card_number'] = Variable<int>(maxCopiesPerCardNumber);
    map['initial_hand_size'] = Variable<int>(initialHandSize);
    map['initial_energy_on_field'] = Variable<int>(initialEnergyOnField);
    map['live_slot_max'] = Variable<int>(liveSlotMax);
    map['win_condition'] = Variable<int>(winCondition);
    map['stage_area_count'] = Variable<int>(stageAreaCount);
    return map;
  }

  RuleConfigsCompanion toCompanion(bool nullToAbsent) {
    return RuleConfigsCompanion(
      id: Value(id),
      mainDeckSize: Value(mainDeckSize),
      memberCount: Value(memberCount),
      liveCount: Value(liveCount),
      energyDeckSize: Value(energyDeckSize),
      maxCopiesPerCardNumber: Value(maxCopiesPerCardNumber),
      initialHandSize: Value(initialHandSize),
      initialEnergyOnField: Value(initialEnergyOnField),
      liveSlotMax: Value(liveSlotMax),
      winCondition: Value(winCondition),
      stageAreaCount: Value(stageAreaCount),
    );
  }

  factory RuleConfigRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleConfigRow(
      id: serializer.fromJson<int>(json['id']),
      mainDeckSize: serializer.fromJson<int>(json['mainDeckSize']),
      memberCount: serializer.fromJson<int>(json['memberCount']),
      liveCount: serializer.fromJson<int>(json['liveCount']),
      energyDeckSize: serializer.fromJson<int>(json['energyDeckSize']),
      maxCopiesPerCardNumber: serializer.fromJson<int>(
        json['maxCopiesPerCardNumber'],
      ),
      initialHandSize: serializer.fromJson<int>(json['initialHandSize']),
      initialEnergyOnField: serializer.fromJson<int>(
        json['initialEnergyOnField'],
      ),
      liveSlotMax: serializer.fromJson<int>(json['liveSlotMax']),
      winCondition: serializer.fromJson<int>(json['winCondition']),
      stageAreaCount: serializer.fromJson<int>(json['stageAreaCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mainDeckSize': serializer.toJson<int>(mainDeckSize),
      'memberCount': serializer.toJson<int>(memberCount),
      'liveCount': serializer.toJson<int>(liveCount),
      'energyDeckSize': serializer.toJson<int>(energyDeckSize),
      'maxCopiesPerCardNumber': serializer.toJson<int>(maxCopiesPerCardNumber),
      'initialHandSize': serializer.toJson<int>(initialHandSize),
      'initialEnergyOnField': serializer.toJson<int>(initialEnergyOnField),
      'liveSlotMax': serializer.toJson<int>(liveSlotMax),
      'winCondition': serializer.toJson<int>(winCondition),
      'stageAreaCount': serializer.toJson<int>(stageAreaCount),
    };
  }

  RuleConfigRow copyWith({
    int? id,
    int? mainDeckSize,
    int? memberCount,
    int? liveCount,
    int? energyDeckSize,
    int? maxCopiesPerCardNumber,
    int? initialHandSize,
    int? initialEnergyOnField,
    int? liveSlotMax,
    int? winCondition,
    int? stageAreaCount,
  }) => RuleConfigRow(
    id: id ?? this.id,
    mainDeckSize: mainDeckSize ?? this.mainDeckSize,
    memberCount: memberCount ?? this.memberCount,
    liveCount: liveCount ?? this.liveCount,
    energyDeckSize: energyDeckSize ?? this.energyDeckSize,
    maxCopiesPerCardNumber:
        maxCopiesPerCardNumber ?? this.maxCopiesPerCardNumber,
    initialHandSize: initialHandSize ?? this.initialHandSize,
    initialEnergyOnField: initialEnergyOnField ?? this.initialEnergyOnField,
    liveSlotMax: liveSlotMax ?? this.liveSlotMax,
    winCondition: winCondition ?? this.winCondition,
    stageAreaCount: stageAreaCount ?? this.stageAreaCount,
  );
  RuleConfigRow copyWithCompanion(RuleConfigsCompanion data) {
    return RuleConfigRow(
      id: data.id.present ? data.id.value : this.id,
      mainDeckSize: data.mainDeckSize.present
          ? data.mainDeckSize.value
          : this.mainDeckSize,
      memberCount: data.memberCount.present
          ? data.memberCount.value
          : this.memberCount,
      liveCount: data.liveCount.present ? data.liveCount.value : this.liveCount,
      energyDeckSize: data.energyDeckSize.present
          ? data.energyDeckSize.value
          : this.energyDeckSize,
      maxCopiesPerCardNumber: data.maxCopiesPerCardNumber.present
          ? data.maxCopiesPerCardNumber.value
          : this.maxCopiesPerCardNumber,
      initialHandSize: data.initialHandSize.present
          ? data.initialHandSize.value
          : this.initialHandSize,
      initialEnergyOnField: data.initialEnergyOnField.present
          ? data.initialEnergyOnField.value
          : this.initialEnergyOnField,
      liveSlotMax: data.liveSlotMax.present
          ? data.liveSlotMax.value
          : this.liveSlotMax,
      winCondition: data.winCondition.present
          ? data.winCondition.value
          : this.winCondition,
      stageAreaCount: data.stageAreaCount.present
          ? data.stageAreaCount.value
          : this.stageAreaCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleConfigRow(')
          ..write('id: $id, ')
          ..write('mainDeckSize: $mainDeckSize, ')
          ..write('memberCount: $memberCount, ')
          ..write('liveCount: $liveCount, ')
          ..write('energyDeckSize: $energyDeckSize, ')
          ..write('maxCopiesPerCardNumber: $maxCopiesPerCardNumber, ')
          ..write('initialHandSize: $initialHandSize, ')
          ..write('initialEnergyOnField: $initialEnergyOnField, ')
          ..write('liveSlotMax: $liveSlotMax, ')
          ..write('winCondition: $winCondition, ')
          ..write('stageAreaCount: $stageAreaCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mainDeckSize,
    memberCount,
    liveCount,
    energyDeckSize,
    maxCopiesPerCardNumber,
    initialHandSize,
    initialEnergyOnField,
    liveSlotMax,
    winCondition,
    stageAreaCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleConfigRow &&
          other.id == this.id &&
          other.mainDeckSize == this.mainDeckSize &&
          other.memberCount == this.memberCount &&
          other.liveCount == this.liveCount &&
          other.energyDeckSize == this.energyDeckSize &&
          other.maxCopiesPerCardNumber == this.maxCopiesPerCardNumber &&
          other.initialHandSize == this.initialHandSize &&
          other.initialEnergyOnField == this.initialEnergyOnField &&
          other.liveSlotMax == this.liveSlotMax &&
          other.winCondition == this.winCondition &&
          other.stageAreaCount == this.stageAreaCount);
}

class RuleConfigsCompanion extends UpdateCompanion<RuleConfigRow> {
  final Value<int> id;
  final Value<int> mainDeckSize;
  final Value<int> memberCount;
  final Value<int> liveCount;
  final Value<int> energyDeckSize;
  final Value<int> maxCopiesPerCardNumber;
  final Value<int> initialHandSize;
  final Value<int> initialEnergyOnField;
  final Value<int> liveSlotMax;
  final Value<int> winCondition;
  final Value<int> stageAreaCount;
  const RuleConfigsCompanion({
    this.id = const Value.absent(),
    this.mainDeckSize = const Value.absent(),
    this.memberCount = const Value.absent(),
    this.liveCount = const Value.absent(),
    this.energyDeckSize = const Value.absent(),
    this.maxCopiesPerCardNumber = const Value.absent(),
    this.initialHandSize = const Value.absent(),
    this.initialEnergyOnField = const Value.absent(),
    this.liveSlotMax = const Value.absent(),
    this.winCondition = const Value.absent(),
    this.stageAreaCount = const Value.absent(),
  });
  RuleConfigsCompanion.insert({
    this.id = const Value.absent(),
    required int mainDeckSize,
    required int memberCount,
    required int liveCount,
    required int energyDeckSize,
    required int maxCopiesPerCardNumber,
    required int initialHandSize,
    required int initialEnergyOnField,
    required int liveSlotMax,
    required int winCondition,
    required int stageAreaCount,
  }) : mainDeckSize = Value(mainDeckSize),
       memberCount = Value(memberCount),
       liveCount = Value(liveCount),
       energyDeckSize = Value(energyDeckSize),
       maxCopiesPerCardNumber = Value(maxCopiesPerCardNumber),
       initialHandSize = Value(initialHandSize),
       initialEnergyOnField = Value(initialEnergyOnField),
       liveSlotMax = Value(liveSlotMax),
       winCondition = Value(winCondition),
       stageAreaCount = Value(stageAreaCount);
  static Insertable<RuleConfigRow> custom({
    Expression<int>? id,
    Expression<int>? mainDeckSize,
    Expression<int>? memberCount,
    Expression<int>? liveCount,
    Expression<int>? energyDeckSize,
    Expression<int>? maxCopiesPerCardNumber,
    Expression<int>? initialHandSize,
    Expression<int>? initialEnergyOnField,
    Expression<int>? liveSlotMax,
    Expression<int>? winCondition,
    Expression<int>? stageAreaCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mainDeckSize != null) 'main_deck_size': mainDeckSize,
      if (memberCount != null) 'member_count': memberCount,
      if (liveCount != null) 'live_count': liveCount,
      if (energyDeckSize != null) 'energy_deck_size': energyDeckSize,
      if (maxCopiesPerCardNumber != null)
        'max_copies_per_card_number': maxCopiesPerCardNumber,
      if (initialHandSize != null) 'initial_hand_size': initialHandSize,
      if (initialEnergyOnField != null)
        'initial_energy_on_field': initialEnergyOnField,
      if (liveSlotMax != null) 'live_slot_max': liveSlotMax,
      if (winCondition != null) 'win_condition': winCondition,
      if (stageAreaCount != null) 'stage_area_count': stageAreaCount,
    });
  }

  RuleConfigsCompanion copyWith({
    Value<int>? id,
    Value<int>? mainDeckSize,
    Value<int>? memberCount,
    Value<int>? liveCount,
    Value<int>? energyDeckSize,
    Value<int>? maxCopiesPerCardNumber,
    Value<int>? initialHandSize,
    Value<int>? initialEnergyOnField,
    Value<int>? liveSlotMax,
    Value<int>? winCondition,
    Value<int>? stageAreaCount,
  }) {
    return RuleConfigsCompanion(
      id: id ?? this.id,
      mainDeckSize: mainDeckSize ?? this.mainDeckSize,
      memberCount: memberCount ?? this.memberCount,
      liveCount: liveCount ?? this.liveCount,
      energyDeckSize: energyDeckSize ?? this.energyDeckSize,
      maxCopiesPerCardNumber:
          maxCopiesPerCardNumber ?? this.maxCopiesPerCardNumber,
      initialHandSize: initialHandSize ?? this.initialHandSize,
      initialEnergyOnField: initialEnergyOnField ?? this.initialEnergyOnField,
      liveSlotMax: liveSlotMax ?? this.liveSlotMax,
      winCondition: winCondition ?? this.winCondition,
      stageAreaCount: stageAreaCount ?? this.stageAreaCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mainDeckSize.present) {
      map['main_deck_size'] = Variable<int>(mainDeckSize.value);
    }
    if (memberCount.present) {
      map['member_count'] = Variable<int>(memberCount.value);
    }
    if (liveCount.present) {
      map['live_count'] = Variable<int>(liveCount.value);
    }
    if (energyDeckSize.present) {
      map['energy_deck_size'] = Variable<int>(energyDeckSize.value);
    }
    if (maxCopiesPerCardNumber.present) {
      map['max_copies_per_card_number'] = Variable<int>(
        maxCopiesPerCardNumber.value,
      );
    }
    if (initialHandSize.present) {
      map['initial_hand_size'] = Variable<int>(initialHandSize.value);
    }
    if (initialEnergyOnField.present) {
      map['initial_energy_on_field'] = Variable<int>(
        initialEnergyOnField.value,
      );
    }
    if (liveSlotMax.present) {
      map['live_slot_max'] = Variable<int>(liveSlotMax.value);
    }
    if (winCondition.present) {
      map['win_condition'] = Variable<int>(winCondition.value);
    }
    if (stageAreaCount.present) {
      map['stage_area_count'] = Variable<int>(stageAreaCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RuleConfigsCompanion(')
          ..write('id: $id, ')
          ..write('mainDeckSize: $mainDeckSize, ')
          ..write('memberCount: $memberCount, ')
          ..write('liveCount: $liveCount, ')
          ..write('energyDeckSize: $energyDeckSize, ')
          ..write('maxCopiesPerCardNumber: $maxCopiesPerCardNumber, ')
          ..write('initialHandSize: $initialHandSize, ')
          ..write('initialEnergyOnField: $initialEnergyOnField, ')
          ..write('liveSlotMax: $liveSlotMax, ')
          ..write('winCondition: $winCondition, ')
          ..write('stageAreaCount: $stageAreaCount')
          ..write(')'))
        .toString();
  }
}

class $DecksTable extends Decks with TableInfo<$DecksTable, DeckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memoMeta = const VerificationMeta('memo');
  @override
  late final GeneratedColumn<String> memo = GeneratedColumn<String>(
    'memo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _coverPrintingIdMeta = const VerificationMeta(
    'coverPrintingId',
  );
  @override
  late final GeneratedColumn<String> coverPrintingId = GeneratedColumn<String>(
    'cover_printing_id',
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
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastDeviceIdMeta = const VerificationMeta(
    'lastDeviceId',
  );
  @override
  late final GeneratedColumn<String> lastDeviceId = GeneratedColumn<String>(
    'last_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _masterDataVersionMeta = const VerificationMeta(
    'masterDataVersion',
  );
  @override
  late final GeneratedColumn<int> masterDataVersion = GeneratedColumn<int>(
    'master_data_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deckId,
    name,
    memo,
    coverPrintingId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastDeviceId,
    masterDataVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('memo')) {
      context.handle(
        _memoMeta,
        memo.isAcceptableOrUnknown(data['memo']!, _memoMeta),
      );
    }
    if (data.containsKey('cover_printing_id')) {
      context.handle(
        _coverPrintingIdMeta,
        coverPrintingId.isAcceptableOrUnknown(
          data['cover_printing_id']!,
          _coverPrintingIdMeta,
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
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('last_device_id')) {
      context.handle(
        _lastDeviceIdMeta,
        lastDeviceId.isAcceptableOrUnknown(
          data['last_device_id']!,
          _lastDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('master_data_version')) {
      context.handle(
        _masterDataVersionMeta,
        masterDataVersion.isAcceptableOrUnknown(
          data['master_data_version']!,
          _masterDataVersionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deckId};
  @override
  DeckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckRow(
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      memo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}memo'],
      )!,
      coverPrintingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_printing_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      lastDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_device_id'],
      )!,
      masterDataVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}master_data_version'],
      )!,
    );
  }

  @override
  $DecksTable createAlias(String alias) {
    return $DecksTable(attachedDatabase, alias);
  }
}

class DeckRow extends DataClass implements Insertable<DeckRow> {
  /// ★UUID v4。連番にすると端末間で衝突する（決定 D100）。
  final String deckId;
  final String name;
  final String memo;
  final String? coverPrintingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// ★論理削除（決定 D102）。物理削除すると削除が同期で伝播しない。
  final DateTime? deletedAt;

  /// ★更新のたびに +1（決定 D101）。同期の差分検出に使う。
  final int revision;
  final String lastDeviceId;

  /// ★作成時のカードマスタ版（決定 D35）。未知カード検出に使う（決定 D35）。
  final int masterDataVersion;
  const DeckRow({
    required this.deckId,
    required this.name,
    required this.memo,
    this.coverPrintingId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.lastDeviceId,
    required this.masterDataVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deck_id'] = Variable<String>(deckId);
    map['name'] = Variable<String>(name);
    map['memo'] = Variable<String>(memo);
    if (!nullToAbsent || coverPrintingId != null) {
      map['cover_printing_id'] = Variable<String>(coverPrintingId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['last_device_id'] = Variable<String>(lastDeviceId);
    map['master_data_version'] = Variable<int>(masterDataVersion);
    return map;
  }

  DecksCompanion toCompanion(bool nullToAbsent) {
    return DecksCompanion(
      deckId: Value(deckId),
      name: Value(name),
      memo: Value(memo),
      coverPrintingId: coverPrintingId == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPrintingId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      lastDeviceId: Value(lastDeviceId),
      masterDataVersion: Value(masterDataVersion),
    );
  }

  factory DeckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckRow(
      deckId: serializer.fromJson<String>(json['deckId']),
      name: serializer.fromJson<String>(json['name']),
      memo: serializer.fromJson<String>(json['memo']),
      coverPrintingId: serializer.fromJson<String?>(json['coverPrintingId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      lastDeviceId: serializer.fromJson<String>(json['lastDeviceId']),
      masterDataVersion: serializer.fromJson<int>(json['masterDataVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deckId': serializer.toJson<String>(deckId),
      'name': serializer.toJson<String>(name),
      'memo': serializer.toJson<String>(memo),
      'coverPrintingId': serializer.toJson<String?>(coverPrintingId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'lastDeviceId': serializer.toJson<String>(lastDeviceId),
      'masterDataVersion': serializer.toJson<int>(masterDataVersion),
    };
  }

  DeckRow copyWith({
    String? deckId,
    String? name,
    String? memo,
    Value<String?> coverPrintingId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? lastDeviceId,
    int? masterDataVersion,
  }) => DeckRow(
    deckId: deckId ?? this.deckId,
    name: name ?? this.name,
    memo: memo ?? this.memo,
    coverPrintingId: coverPrintingId.present
        ? coverPrintingId.value
        : this.coverPrintingId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    masterDataVersion: masterDataVersion ?? this.masterDataVersion,
  );
  DeckRow copyWithCompanion(DecksCompanion data) {
    return DeckRow(
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      name: data.name.present ? data.name.value : this.name,
      memo: data.memo.present ? data.memo.value : this.memo,
      coverPrintingId: data.coverPrintingId.present
          ? data.coverPrintingId.value
          : this.coverPrintingId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      lastDeviceId: data.lastDeviceId.present
          ? data.lastDeviceId.value
          : this.lastDeviceId,
      masterDataVersion: data.masterDataVersion.present
          ? data.masterDataVersion.value
          : this.masterDataVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckRow(')
          ..write('deckId: $deckId, ')
          ..write('name: $name, ')
          ..write('memo: $memo, ')
          ..write('coverPrintingId: $coverPrintingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastDeviceId: $lastDeviceId, ')
          ..write('masterDataVersion: $masterDataVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deckId,
    name,
    memo,
    coverPrintingId,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    lastDeviceId,
    masterDataVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckRow &&
          other.deckId == this.deckId &&
          other.name == this.name &&
          other.memo == this.memo &&
          other.coverPrintingId == this.coverPrintingId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.lastDeviceId == this.lastDeviceId &&
          other.masterDataVersion == this.masterDataVersion);
}

class DecksCompanion extends UpdateCompanion<DeckRow> {
  final Value<String> deckId;
  final Value<String> name;
  final Value<String> memo;
  final Value<String?> coverPrintingId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> lastDeviceId;
  final Value<int> masterDataVersion;
  final Value<int> rowid;
  const DecksCompanion({
    this.deckId = const Value.absent(),
    this.name = const Value.absent(),
    this.memo = const Value.absent(),
    this.coverPrintingId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.masterDataVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DecksCompanion.insert({
    required String deckId,
    required String name,
    this.memo = const Value.absent(),
    this.coverPrintingId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.lastDeviceId = const Value.absent(),
    this.masterDataVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deckId = Value(deckId),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeckRow> custom({
    Expression<String>? deckId,
    Expression<String>? name,
    Expression<String>? memo,
    Expression<String>? coverPrintingId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? lastDeviceId,
    Expression<int>? masterDataVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deckId != null) 'deck_id': deckId,
      if (name != null) 'name': name,
      if (memo != null) 'memo': memo,
      if (coverPrintingId != null) 'cover_printing_id': coverPrintingId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (lastDeviceId != null) 'last_device_id': lastDeviceId,
      if (masterDataVersion != null) 'master_data_version': masterDataVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DecksCompanion copyWith({
    Value<String>? deckId,
    Value<String>? name,
    Value<String>? memo,
    Value<String?>? coverPrintingId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? lastDeviceId,
    Value<int>? masterDataVersion,
    Value<int>? rowid,
  }) {
    return DecksCompanion(
      deckId: deckId ?? this.deckId,
      name: name ?? this.name,
      memo: memo ?? this.memo,
      coverPrintingId: coverPrintingId ?? this.coverPrintingId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      masterDataVersion: masterDataVersion ?? this.masterDataVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (memo.present) {
      map['memo'] = Variable<String>(memo.value);
    }
    if (coverPrintingId.present) {
      map['cover_printing_id'] = Variable<String>(coverPrintingId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (lastDeviceId.present) {
      map['last_device_id'] = Variable<String>(lastDeviceId.value);
    }
    if (masterDataVersion.present) {
      map['master_data_version'] = Variable<int>(masterDataVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecksCompanion(')
          ..write('deckId: $deckId, ')
          ..write('name: $name, ')
          ..write('memo: $memo, ')
          ..write('coverPrintingId: $coverPrintingId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('lastDeviceId: $lastDeviceId, ')
          ..write('masterDataVersion: $masterDataVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckTagsTable extends DeckTags
    with TableInfo<$DeckTagsTable, DeckTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (deck_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deckId, ord, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deckId, ord};
  @override
  DeckTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckTagRow(
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $DeckTagsTable createAlias(String alias) {
    return $DeckTagsTable(attachedDatabase, alias);
  }
}

class DeckTagRow extends DataClass implements Insertable<DeckTagRow> {
  final String deckId;
  final int ord;
  final String tag;
  const DeckTagRow({
    required this.deckId,
    required this.ord,
    required this.tag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deck_id'] = Variable<String>(deckId);
    map['ord'] = Variable<int>(ord);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  DeckTagsCompanion toCompanion(bool nullToAbsent) {
    return DeckTagsCompanion(
      deckId: Value(deckId),
      ord: Value(ord),
      tag: Value(tag),
    );
  }

  factory DeckTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckTagRow(
      deckId: serializer.fromJson<String>(json['deckId']),
      ord: serializer.fromJson<int>(json['ord']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deckId': serializer.toJson<String>(deckId),
      'ord': serializer.toJson<int>(ord),
      'tag': serializer.toJson<String>(tag),
    };
  }

  DeckTagRow copyWith({String? deckId, int? ord, String? tag}) => DeckTagRow(
    deckId: deckId ?? this.deckId,
    ord: ord ?? this.ord,
    tag: tag ?? this.tag,
  );
  DeckTagRow copyWithCompanion(DeckTagsCompanion data) {
    return DeckTagRow(
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      ord: data.ord.present ? data.ord.value : this.ord,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckTagRow(')
          ..write('deckId: $deckId, ')
          ..write('ord: $ord, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deckId, ord, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckTagRow &&
          other.deckId == this.deckId &&
          other.ord == this.ord &&
          other.tag == this.tag);
}

class DeckTagsCompanion extends UpdateCompanion<DeckTagRow> {
  final Value<String> deckId;
  final Value<int> ord;
  final Value<String> tag;
  final Value<int> rowid;
  const DeckTagsCompanion({
    this.deckId = const Value.absent(),
    this.ord = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckTagsCompanion.insert({
    required String deckId,
    required int ord,
    required String tag,
    this.rowid = const Value.absent(),
  }) : deckId = Value(deckId),
       ord = Value(ord),
       tag = Value(tag);
  static Insertable<DeckTagRow> custom({
    Expression<String>? deckId,
    Expression<int>? ord,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deckId != null) 'deck_id': deckId,
      if (ord != null) 'ord': ord,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckTagsCompanion copyWith({
    Value<String>? deckId,
    Value<int>? ord,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return DeckTagsCompanion(
      deckId: deckId ?? this.deckId,
      ord: ord ?? this.ord,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckTagsCompanion(')
          ..write('deckId: $deckId, ')
          ..write('ord: $ord, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckEntriesTable extends DeckEntries
    with TableInfo<$DeckEntriesTable, DeckEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES decks (deck_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _printingIdMeta = const VerificationMeta(
    'printingId',
  );
  @override
  late final GeneratedColumn<String> printingId = GeneratedColumn<String>(
    'printing_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [deckId, printingId, count, ord];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('printing_id')) {
      context.handle(
        _printingIdMeta,
        printingId.isAcceptableOrUnknown(data['printing_id']!, _printingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_printingIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
        _ordMeta,
        ord.isAcceptableOrUnknown(data['ord']!, _ordMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deckId, printingId};
  @override
  DeckEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckEntryRow(
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      printingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}printing_id'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      ord: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ord'],
      )!,
    );
  }

  @override
  $DeckEntriesTable createAlias(String alias) {
    return $DeckEntriesTable(attachedDatabase, alias);
  }
}

class DeckEntryRow extends DataClass implements Insertable<DeckEntryRow> {
  final String deckId;
  final String printingId;
  final int count;

  /// デッキの中の並び順（決定 D65 / **D99**）。0 始まりの添字。
  ///
  /// ★★ 主キーに入れない ★★
  /// 「同じ刷りは 1 行」の不変条件は `{deckId, printingId}` が守っている。
  /// `ord` を鍵に入れると、同じ刷りが違う `ord` で 2 行入れられるようになる。
  ///
  /// ★★ 既定値 0 は移行のためである ★★
  /// `schemaVersion` 2 → 3 の `ALTER TABLE ... ADD COLUMN` が NOT NULL 列に
  /// 既定値を要求する。**書き込み時は [DeckDao.save] が必ず添字を明示する**ので、
  /// 既定値が実際に使われるのは移行の一瞬だけである
  /// （直後に backfill が上書きする / `database.dart` の `from < 3` の枝）。
  final int ord;
  const DeckEntryRow({
    required this.deckId,
    required this.printingId,
    required this.count,
    required this.ord,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deck_id'] = Variable<String>(deckId);
    map['printing_id'] = Variable<String>(printingId);
    map['count'] = Variable<int>(count);
    map['ord'] = Variable<int>(ord);
    return map;
  }

  DeckEntriesCompanion toCompanion(bool nullToAbsent) {
    return DeckEntriesCompanion(
      deckId: Value(deckId),
      printingId: Value(printingId),
      count: Value(count),
      ord: Value(ord),
    );
  }

  factory DeckEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckEntryRow(
      deckId: serializer.fromJson<String>(json['deckId']),
      printingId: serializer.fromJson<String>(json['printingId']),
      count: serializer.fromJson<int>(json['count']),
      ord: serializer.fromJson<int>(json['ord']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deckId': serializer.toJson<String>(deckId),
      'printingId': serializer.toJson<String>(printingId),
      'count': serializer.toJson<int>(count),
      'ord': serializer.toJson<int>(ord),
    };
  }

  DeckEntryRow copyWith({
    String? deckId,
    String? printingId,
    int? count,
    int? ord,
  }) => DeckEntryRow(
    deckId: deckId ?? this.deckId,
    printingId: printingId ?? this.printingId,
    count: count ?? this.count,
    ord: ord ?? this.ord,
  );
  DeckEntryRow copyWithCompanion(DeckEntriesCompanion data) {
    return DeckEntryRow(
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      printingId: data.printingId.present
          ? data.printingId.value
          : this.printingId,
      count: data.count.present ? data.count.value : this.count,
      ord: data.ord.present ? data.ord.value : this.ord,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckEntryRow(')
          ..write('deckId: $deckId, ')
          ..write('printingId: $printingId, ')
          ..write('count: $count, ')
          ..write('ord: $ord')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deckId, printingId, count, ord);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckEntryRow &&
          other.deckId == this.deckId &&
          other.printingId == this.printingId &&
          other.count == this.count &&
          other.ord == this.ord);
}

class DeckEntriesCompanion extends UpdateCompanion<DeckEntryRow> {
  final Value<String> deckId;
  final Value<String> printingId;
  final Value<int> count;
  final Value<int> ord;
  final Value<int> rowid;
  const DeckEntriesCompanion({
    this.deckId = const Value.absent(),
    this.printingId = const Value.absent(),
    this.count = const Value.absent(),
    this.ord = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckEntriesCompanion.insert({
    required String deckId,
    required String printingId,
    required int count,
    this.ord = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deckId = Value(deckId),
       printingId = Value(printingId),
       count = Value(count);
  static Insertable<DeckEntryRow> custom({
    Expression<String>? deckId,
    Expression<String>? printingId,
    Expression<int>? count,
    Expression<int>? ord,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deckId != null) 'deck_id': deckId,
      if (printingId != null) 'printing_id': printingId,
      if (count != null) 'count': count,
      if (ord != null) 'ord': ord,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckEntriesCompanion copyWith({
    Value<String>? deckId,
    Value<String>? printingId,
    Value<int>? count,
    Value<int>? ord,
    Value<int>? rowid,
  }) {
    return DeckEntriesCompanion(
      deckId: deckId ?? this.deckId,
      printingId: printingId ?? this.printingId,
      count: count ?? this.count,
      ord: ord ?? this.ord,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (printingId.present) {
      map['printing_id'] = Variable<String>(printingId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckEntriesCompanion(')
          ..write('deckId: $deckId, ')
          ..write('printingId: $printingId, ')
          ..write('count: $count, ')
          ..write('ord: $ord, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeckEditOpsTable extends DeckEditOps
    with TableInfo<$DeckEditOpsTable, DeckEditOpRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckEditOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, deckId, kind, at];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_edit_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckEditOpRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeckEditOpRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckEditOpRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
    );
  }

  @override
  $DeckEditOpsTable createAlias(String alias) {
    return $DeckEditOpsTable(attachedDatabase, alias);
  }
}

class DeckEditOpRow extends DataClass implements Insertable<DeckEditOpRow> {
  /// §17-9-1 の 1 が言う「順序」と、同 2 が言う「主キー」を **1 本の単調増加**が兼ねる。
  ///
  /// ★★ 既存の慣習（複合キー）を採らなかった ★★
  /// §17-9-1 の 2 は「既存の慣習は複合キー（`{deckId, ord}` など）。
  /// 単調増加の 1 本にするかは**未決**」と書いている。→ ★**単調増加を採る。**
  ///
  /// | | |
  /// |---|---|
  /// | `{deckId, ord}` | ★**デッキをまたぐ順序が消える。**挿入のたびに `MAX(ord)` を引く |
  /// | ★**単調増加 1 本** | ★**両方引ける** —— 全体順は `ORDER BY id`、デッキ内は `WHERE deck_id = ? ORDER BY id` |
  ///
  /// ★**選ぶ余地を狭めないほうを採った。**§17-9-5 は「前回同期時点の目印を
  /// **ログの位置**で持つか別のスカラで持つか」を**未決**にしており、
  /// 複合キーにすると「ログの位置」という選択肢が先に消える。
  ///
  /// ★★ `AUTOINCREMENT` である（rowid の再利用が起きない）★★
  /// drift の `autoIncrement()` は `INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT` を吐く
  /// （`drift_dev/lib/src/writer/utils/column_constraints.dart:31`。★実読）。
  /// 素の `INTEGER PRIMARY KEY` は削除後に **rowid を使い回す**ので、
  /// **N-16** が古い行を捨てた瞬間に「目印より後ろ」の判定が壊れる。
  final int id;

  /// どのデッキへの操作か。★10 種すべてがデッキ 1 つに対する操作である。
  final String deckId;

  /// 操作の種類。★**`DeckEditOpKind.key` の字面**を入れる。
  ///
  /// ★★ `textEnum<DeckEditOpKind>()` を使ってはならない ★★
  /// drift の `EnumNameConverter` は **`value.name`（Dart の識別子）**を保存する
  /// （`drift/lib/src/runtime/types/converters.dart:283`。★実読）。
  /// `DeckEditOpKind.deleteDeck` の識別子は `deleteDeck` だが、
  /// ★**キーは `softDelete`（記録点のメソッド名）である** —— **D110-1** が
  /// 「リネームで送信済みのログが意味を失わないように」わざと違えた 1 件である。
  /// → ★`textEnum` にすると**その決定が黙って裏返る。**素の [text] にして
  ///   `DeckEditOpKind.key` を明示で入れる
  ///   （★`test/migration_test.dart` の「kind は key の字面を持つ」が対で見張る）。
  ///
  /// ★★ 未知のキーの扱いはここで決めない ★★
  /// `DeckEditOpKind.tryFromKey` は `null` を返すだけで、例外を投げるかは
  /// **N-12**（版のずれ）と **A-4**（**D-1** の厳格性）の下流である
  /// （`loveca-core/lib/src/sync/deck_edit_op.dart` の library doc の 3）。
  /// → ★**列は字面をそのまま持つ。読み出す層が決める。**
  final String kind;

  /// ★呼び出し側から渡された時刻。`DateTime.now()` を層の内側で呼ばない。
  /// （`master_files.imported_at` / `DeckDao.softDelete` の `at` と同じ扱い）
  final DateTime at;
  const DeckEditOpRow({
    required this.id,
    required this.deckId,
    required this.kind,
    required this.at,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['deck_id'] = Variable<String>(deckId);
    map['kind'] = Variable<String>(kind);
    map['at'] = Variable<DateTime>(at);
    return map;
  }

  DeckEditOpsCompanion toCompanion(bool nullToAbsent) {
    return DeckEditOpsCompanion(
      id: Value(id),
      deckId: Value(deckId),
      kind: Value(kind),
      at: Value(at),
    );
  }

  factory DeckEditOpRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckEditOpRow(
      id: serializer.fromJson<int>(json['id']),
      deckId: serializer.fromJson<String>(json['deckId']),
      kind: serializer.fromJson<String>(json['kind']),
      at: serializer.fromJson<DateTime>(json['at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deckId': serializer.toJson<String>(deckId),
      'kind': serializer.toJson<String>(kind),
      'at': serializer.toJson<DateTime>(at),
    };
  }

  DeckEditOpRow copyWith({
    int? id,
    String? deckId,
    String? kind,
    DateTime? at,
  }) => DeckEditOpRow(
    id: id ?? this.id,
    deckId: deckId ?? this.deckId,
    kind: kind ?? this.kind,
    at: at ?? this.at,
  );
  DeckEditOpRow copyWithCompanion(DeckEditOpsCompanion data) {
    return DeckEditOpRow(
      id: data.id.present ? data.id.value : this.id,
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      kind: data.kind.present ? data.kind.value : this.kind,
      at: data.at.present ? data.at.value : this.at,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckEditOpRow(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('kind: $kind, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, deckId, kind, at);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckEditOpRow &&
          other.id == this.id &&
          other.deckId == this.deckId &&
          other.kind == this.kind &&
          other.at == this.at);
}

class DeckEditOpsCompanion extends UpdateCompanion<DeckEditOpRow> {
  final Value<int> id;
  final Value<String> deckId;
  final Value<String> kind;
  final Value<DateTime> at;
  const DeckEditOpsCompanion({
    this.id = const Value.absent(),
    this.deckId = const Value.absent(),
    this.kind = const Value.absent(),
    this.at = const Value.absent(),
  });
  DeckEditOpsCompanion.insert({
    this.id = const Value.absent(),
    required String deckId,
    required String kind,
    required DateTime at,
  }) : deckId = Value(deckId),
       kind = Value(kind),
       at = Value(at);
  static Insertable<DeckEditOpRow> custom({
    Expression<int>? id,
    Expression<String>? deckId,
    Expression<String>? kind,
    Expression<DateTime>? at,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deckId != null) 'deck_id': deckId,
      if (kind != null) 'kind': kind,
      if (at != null) 'at': at,
    });
  }

  DeckEditOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? deckId,
    Value<String>? kind,
    Value<DateTime>? at,
  }) {
    return DeckEditOpsCompanion(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      kind: kind ?? this.kind,
      at: at ?? this.at,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckEditOpsCompanion(')
          ..write('id: $id, ')
          ..write('deckId: $deckId, ')
          ..write('kind: $kind, ')
          ..write('at: $at')
          ..write(')'))
        .toString();
  }
}

class $DeckSyncMarksTable extends DeckSyncMarks
    with TableInfo<$DeckSyncMarksTable, DeckSyncMarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeckSyncMarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deckIdMeta = const VerificationMeta('deckId');
  @override
  late final GeneratedColumn<String> deckId = GeneratedColumn<String>(
    'deck_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _logMarkMeta = const VerificationMeta(
    'logMark',
  );
  @override
  late final GeneratedColumn<int> logMark = GeneratedColumn<int>(
    'log_mark',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baselineHashMeta = const VerificationMeta(
    'baselineHash',
  );
  @override
  late final GeneratedColumn<String> baselineHash = GeneratedColumn<String>(
    'baseline_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deckId, logMark, baselineHash];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deck_sync_marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeckSyncMarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deck_id')) {
      context.handle(
        _deckIdMeta,
        deckId.isAcceptableOrUnknown(data['deck_id']!, _deckIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deckIdMeta);
    }
    if (data.containsKey('log_mark')) {
      context.handle(
        _logMarkMeta,
        logMark.isAcceptableOrUnknown(data['log_mark']!, _logMarkMeta),
      );
    } else if (isInserting) {
      context.missing(_logMarkMeta);
    }
    if (data.containsKey('baseline_hash')) {
      context.handle(
        _baselineHashMeta,
        baselineHash.isAcceptableOrUnknown(
          data['baseline_hash']!,
          _baselineHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baselineHashMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deckId};
  @override
  DeckSyncMarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeckSyncMarkRow(
      deckId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deck_id'],
      )!,
      logMark: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}log_mark'],
      )!,
      baselineHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}baseline_hash'],
      )!,
    );
  }

  @override
  $DeckSyncMarksTable createAlias(String alias) {
    return $DeckSyncMarksTable(attachedDatabase, alias);
  }
}

class DeckSyncMarkRow extends DataClass implements Insertable<DeckSyncMarkRow> {
  /// どのデッキの目印か。★**行が無いこと**が「まだ一度も同期していない」を表す（**D114-3**）。
  ///
  /// ★★ 行の不在は「消えた」とも読める ★★
  /// ★だから意味づけを別に決めてある（**D114-3**）。★**先例は `master_files` の行の不在**
  /// （★無ければ再取得対象に残る）。★**同じ層の同じ形をなぞる。**
  final String deckId;

  /// 前回同期時点の**目印** ＝ `deck_edit_ops.id` の値（決定 **D114-2**）。
  ///
  /// ★★ 意味（「最後に送った」か「次に送る」か）はここで決めない ★★
  /// **§24-8** が未決にしている。★**列名でも言わない。**
  /// ★判定に要るのは「この位置より後ろに操作が在るか」の**答え**だけで、
  /// ★そこは `loveca_core` の `DeckSyncBaseline` が有無に畳んで受ける。
  ///
  /// ★★ `deck_edit_ops` への外部キーにしない ★★
  /// ★**N-16**（ログをいつ捨てるか）が古い行を捨てたとき、★目印だけは残らねばならない。
  /// ★外部キーにすると**捨てた瞬間に目印が消えるか、捨てられなくなる**。
  /// ★`AUTOINCREMENT` なので**番号は使い回されず**、★行が消えても比較は成り立つ
  /// （`DeckEditOps.id` の doc / **D114-2**）。→ ★**目印は N-16 に従属しない。**
  final int logMark;

  /// 前回同期時点の**内容ハッシュ**（決定 **D115-1** —— ★列は 1 本）。
  ///
  /// ★`loveca_core` の `deckContentHash` が作る字面をそのまま入れる（`"sha256:..."`）。
  /// ★★ 5 個に分けることは **(f-1)** を開き直すことである ★★（**D112** の **N-18** 追記）。
  ///
  /// ★★ ここに `NULL` を許さない ★★
  /// **D114-4** の 1 —— ★**目印と基準ハッシュが片方だけ在る状態を作れない**ことが
  /// この表を選んだ根拠の 1 つである。★空文字も入れないこと（★書く経路がまだ無い）。
  final String baselineHash;
  const DeckSyncMarkRow({
    required this.deckId,
    required this.logMark,
    required this.baselineHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['deck_id'] = Variable<String>(deckId);
    map['log_mark'] = Variable<int>(logMark);
    map['baseline_hash'] = Variable<String>(baselineHash);
    return map;
  }

  DeckSyncMarksCompanion toCompanion(bool nullToAbsent) {
    return DeckSyncMarksCompanion(
      deckId: Value(deckId),
      logMark: Value(logMark),
      baselineHash: Value(baselineHash),
    );
  }

  factory DeckSyncMarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeckSyncMarkRow(
      deckId: serializer.fromJson<String>(json['deckId']),
      logMark: serializer.fromJson<int>(json['logMark']),
      baselineHash: serializer.fromJson<String>(json['baselineHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deckId': serializer.toJson<String>(deckId),
      'logMark': serializer.toJson<int>(logMark),
      'baselineHash': serializer.toJson<String>(baselineHash),
    };
  }

  DeckSyncMarkRow copyWith({
    String? deckId,
    int? logMark,
    String? baselineHash,
  }) => DeckSyncMarkRow(
    deckId: deckId ?? this.deckId,
    logMark: logMark ?? this.logMark,
    baselineHash: baselineHash ?? this.baselineHash,
  );
  DeckSyncMarkRow copyWithCompanion(DeckSyncMarksCompanion data) {
    return DeckSyncMarkRow(
      deckId: data.deckId.present ? data.deckId.value : this.deckId,
      logMark: data.logMark.present ? data.logMark.value : this.logMark,
      baselineHash: data.baselineHash.present
          ? data.baselineHash.value
          : this.baselineHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeckSyncMarkRow(')
          ..write('deckId: $deckId, ')
          ..write('logMark: $logMark, ')
          ..write('baselineHash: $baselineHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deckId, logMark, baselineHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeckSyncMarkRow &&
          other.deckId == this.deckId &&
          other.logMark == this.logMark &&
          other.baselineHash == this.baselineHash);
}

class DeckSyncMarksCompanion extends UpdateCompanion<DeckSyncMarkRow> {
  final Value<String> deckId;
  final Value<int> logMark;
  final Value<String> baselineHash;
  final Value<int> rowid;
  const DeckSyncMarksCompanion({
    this.deckId = const Value.absent(),
    this.logMark = const Value.absent(),
    this.baselineHash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeckSyncMarksCompanion.insert({
    required String deckId,
    required int logMark,
    required String baselineHash,
    this.rowid = const Value.absent(),
  }) : deckId = Value(deckId),
       logMark = Value(logMark),
       baselineHash = Value(baselineHash);
  static Insertable<DeckSyncMarkRow> custom({
    Expression<String>? deckId,
    Expression<int>? logMark,
    Expression<String>? baselineHash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deckId != null) 'deck_id': deckId,
      if (logMark != null) 'log_mark': logMark,
      if (baselineHash != null) 'baseline_hash': baselineHash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeckSyncMarksCompanion copyWith({
    Value<String>? deckId,
    Value<int>? logMark,
    Value<String>? baselineHash,
    Value<int>? rowid,
  }) {
    return DeckSyncMarksCompanion(
      deckId: deckId ?? this.deckId,
      logMark: logMark ?? this.logMark,
      baselineHash: baselineHash ?? this.baselineHash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deckId.present) {
      map['deck_id'] = Variable<String>(deckId.value);
    }
    if (logMark.present) {
      map['log_mark'] = Variable<int>(logMark.value);
    }
    if (baselineHash.present) {
      map['baseline_hash'] = Variable<String>(baselineHash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeckSyncMarksCompanion(')
          ..write('deckId: $deckId, ')
          ..write('logMark: $logMark, ')
          ..write('baselineHash: $baselineHash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MasterStatesTable extends MasterStates
    with TableInfo<$MasterStatesTable, MasterStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasterStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dataVersionMeta = const VerificationMeta(
    'dataVersion',
  );
  @override
  late final GeneratedColumn<int> dataVersion = GeneratedColumn<int>(
    'data_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minAppVersionMeta = const VerificationMeta(
    'minAppVersion',
  );
  @override
  late final GeneratedColumn<String> minAppVersion = GeneratedColumn<String>(
    'min_app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('0.0.0'),
  );
  static const VerificationMeta _manifestHashMeta = const VerificationMeta(
    'manifestHash',
  );
  @override
  late final GeneratedColumn<String> manifestHash = GeneratedColumn<String>(
    'manifest_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dataVersion,
    minAppVersion,
    manifestHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'master_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasterStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('data_version')) {
      context.handle(
        _dataVersionMeta,
        dataVersion.isAcceptableOrUnknown(
          data['data_version']!,
          _dataVersionMeta,
        ),
      );
    }
    if (data.containsKey('min_app_version')) {
      context.handle(
        _minAppVersionMeta,
        minAppVersion.isAcceptableOrUnknown(
          data['min_app_version']!,
          _minAppVersionMeta,
        ),
      );
    }
    if (data.containsKey('manifest_hash')) {
      context.handle(
        _manifestHashMeta,
        manifestHash.isAcceptableOrUnknown(
          data['manifest_hash']!,
          _manifestHashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MasterStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasterStateRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dataVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}data_version'],
      )!,
      minAppVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}min_app_version'],
      )!,
      manifestHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_hash'],
      )!,
    );
  }

  @override
  $MasterStatesTable createAlias(String alias) {
    return $MasterStatesTable(attachedDatabase, alias);
  }
}

class MasterStateRow extends DataClass implements Insertable<MasterStateRow> {
  final int id;
  final int dataVersion;
  final String minAppVersion;
  final String manifestHash;
  const MasterStateRow({
    required this.id,
    required this.dataVersion,
    required this.minAppVersion,
    required this.manifestHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['data_version'] = Variable<int>(dataVersion);
    map['min_app_version'] = Variable<String>(minAppVersion);
    map['manifest_hash'] = Variable<String>(manifestHash);
    return map;
  }

  MasterStatesCompanion toCompanion(bool nullToAbsent) {
    return MasterStatesCompanion(
      id: Value(id),
      dataVersion: Value(dataVersion),
      minAppVersion: Value(minAppVersion),
      manifestHash: Value(manifestHash),
    );
  }

  factory MasterStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasterStateRow(
      id: serializer.fromJson<int>(json['id']),
      dataVersion: serializer.fromJson<int>(json['dataVersion']),
      minAppVersion: serializer.fromJson<String>(json['minAppVersion']),
      manifestHash: serializer.fromJson<String>(json['manifestHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dataVersion': serializer.toJson<int>(dataVersion),
      'minAppVersion': serializer.toJson<String>(minAppVersion),
      'manifestHash': serializer.toJson<String>(manifestHash),
    };
  }

  MasterStateRow copyWith({
    int? id,
    int? dataVersion,
    String? minAppVersion,
    String? manifestHash,
  }) => MasterStateRow(
    id: id ?? this.id,
    dataVersion: dataVersion ?? this.dataVersion,
    minAppVersion: minAppVersion ?? this.minAppVersion,
    manifestHash: manifestHash ?? this.manifestHash,
  );
  MasterStateRow copyWithCompanion(MasterStatesCompanion data) {
    return MasterStateRow(
      id: data.id.present ? data.id.value : this.id,
      dataVersion: data.dataVersion.present
          ? data.dataVersion.value
          : this.dataVersion,
      minAppVersion: data.minAppVersion.present
          ? data.minAppVersion.value
          : this.minAppVersion,
      manifestHash: data.manifestHash.present
          ? data.manifestHash.value
          : this.manifestHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasterStateRow(')
          ..write('id: $id, ')
          ..write('dataVersion: $dataVersion, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('manifestHash: $manifestHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dataVersion, minAppVersion, manifestHash);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasterStateRow &&
          other.id == this.id &&
          other.dataVersion == this.dataVersion &&
          other.minAppVersion == this.minAppVersion &&
          other.manifestHash == this.manifestHash);
}

class MasterStatesCompanion extends UpdateCompanion<MasterStateRow> {
  final Value<int> id;
  final Value<int> dataVersion;
  final Value<String> minAppVersion;
  final Value<String> manifestHash;
  const MasterStatesCompanion({
    this.id = const Value.absent(),
    this.dataVersion = const Value.absent(),
    this.minAppVersion = const Value.absent(),
    this.manifestHash = const Value.absent(),
  });
  MasterStatesCompanion.insert({
    this.id = const Value.absent(),
    this.dataVersion = const Value.absent(),
    this.minAppVersion = const Value.absent(),
    this.manifestHash = const Value.absent(),
  });
  static Insertable<MasterStateRow> custom({
    Expression<int>? id,
    Expression<int>? dataVersion,
    Expression<String>? minAppVersion,
    Expression<String>? manifestHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dataVersion != null) 'data_version': dataVersion,
      if (minAppVersion != null) 'min_app_version': minAppVersion,
      if (manifestHash != null) 'manifest_hash': manifestHash,
    });
  }

  MasterStatesCompanion copyWith({
    Value<int>? id,
    Value<int>? dataVersion,
    Value<String>? minAppVersion,
    Value<String>? manifestHash,
  }) {
    return MasterStatesCompanion(
      id: id ?? this.id,
      dataVersion: dataVersion ?? this.dataVersion,
      minAppVersion: minAppVersion ?? this.minAppVersion,
      manifestHash: manifestHash ?? this.manifestHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dataVersion.present) {
      map['data_version'] = Variable<int>(dataVersion.value);
    }
    if (minAppVersion.present) {
      map['min_app_version'] = Variable<String>(minAppVersion.value);
    }
    if (manifestHash.present) {
      map['manifest_hash'] = Variable<String>(manifestHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasterStatesCompanion(')
          ..write('id: $id, ')
          ..write('dataVersion: $dataVersion, ')
          ..write('minAppVersion: $minAppVersion, ')
          ..write('manifestHash: $manifestHash')
          ..write(')'))
        .toString();
  }
}

class $MasterFilesTable extends MasterFiles
    with TableInfo<$MasterFilesTable, MasterFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MasterFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cardCountMeta = const VerificationMeta(
    'cardCount',
  );
  @override
  late final GeneratedColumn<int> cardCount = GeneratedColumn<int>(
    'card_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    hash,
    bytes,
    cardCount,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'master_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<MasterFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    }
    if (data.containsKey('card_count')) {
      context.handle(
        _cardCountMeta,
        cardCount.isAcceptableOrUnknown(data['card_count']!, _cardCountMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  MasterFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MasterFileRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      cardCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_count'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $MasterFilesTable createAlias(String alias) {
    return $MasterFilesTable(attachedDatabase, alias);
  }
}

class MasterFileRow extends DataClass implements Insertable<MasterFileRow> {
  final String path;

  /// "sha256:..." 形式。
  final String hash;
  final int bytes;
  final int cardCount;

  /// ★呼び出し側から渡された時刻。`DateTime.now()` を層の内側で呼ばない。
  final DateTime importedAt;
  const MasterFileRow({
    required this.path,
    required this.hash,
    required this.bytes,
    required this.cardCount,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['hash'] = Variable<String>(hash);
    map['bytes'] = Variable<int>(bytes);
    map['card_count'] = Variable<int>(cardCount);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  MasterFilesCompanion toCompanion(bool nullToAbsent) {
    return MasterFilesCompanion(
      path: Value(path),
      hash: Value(hash),
      bytes: Value(bytes),
      cardCount: Value(cardCount),
      importedAt: Value(importedAt),
    );
  }

  factory MasterFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MasterFileRow(
      path: serializer.fromJson<String>(json['path']),
      hash: serializer.fromJson<String>(json['hash']),
      bytes: serializer.fromJson<int>(json['bytes']),
      cardCount: serializer.fromJson<int>(json['cardCount']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'hash': serializer.toJson<String>(hash),
      'bytes': serializer.toJson<int>(bytes),
      'cardCount': serializer.toJson<int>(cardCount),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  MasterFileRow copyWith({
    String? path,
    String? hash,
    int? bytes,
    int? cardCount,
    DateTime? importedAt,
  }) => MasterFileRow(
    path: path ?? this.path,
    hash: hash ?? this.hash,
    bytes: bytes ?? this.bytes,
    cardCount: cardCount ?? this.cardCount,
    importedAt: importedAt ?? this.importedAt,
  );
  MasterFileRow copyWithCompanion(MasterFilesCompanion data) {
    return MasterFileRow(
      path: data.path.present ? data.path.value : this.path,
      hash: data.hash.present ? data.hash.value : this.hash,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      cardCount: data.cardCount.present ? data.cardCount.value : this.cardCount,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MasterFileRow(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('bytes: $bytes, ')
          ..write('cardCount: $cardCount, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, hash, bytes, cardCount, importedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MasterFileRow &&
          other.path == this.path &&
          other.hash == this.hash &&
          other.bytes == this.bytes &&
          other.cardCount == this.cardCount &&
          other.importedAt == this.importedAt);
}

class MasterFilesCompanion extends UpdateCompanion<MasterFileRow> {
  final Value<String> path;
  final Value<String> hash;
  final Value<int> bytes;
  final Value<int> cardCount;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const MasterFilesCompanion({
    this.path = const Value.absent(),
    this.hash = const Value.absent(),
    this.bytes = const Value.absent(),
    this.cardCount = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MasterFilesCompanion.insert({
    required String path,
    required String hash,
    this.bytes = const Value.absent(),
    this.cardCount = const Value.absent(),
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       hash = Value(hash),
       importedAt = Value(importedAt);
  static Insertable<MasterFileRow> custom({
    Expression<String>? path,
    Expression<String>? hash,
    Expression<int>? bytes,
    Expression<int>? cardCount,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (hash != null) 'hash': hash,
      if (bytes != null) 'bytes': bytes,
      if (cardCount != null) 'card_count': cardCount,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MasterFilesCompanion copyWith({
    Value<String>? path,
    Value<String>? hash,
    Value<int>? bytes,
    Value<int>? cardCount,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return MasterFilesCompanion(
      path: path ?? this.path,
      hash: hash ?? this.hash,
      bytes: bytes ?? this.bytes,
      cardCount: cardCount ?? this.cardCount,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (cardCount.present) {
      map['card_count'] = Variable<int>(cardCount.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MasterFilesCompanion(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('bytes: $bytes, ')
          ..write('cardCount: $cardCount, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportIssuesTable extends ImportIssues
    with TableInfo<$ImportIssuesTable, ImportIssueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportIssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImportIssueKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ImportIssueKind>($ImportIssuesTable.$converterkind);
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurrenceCountMeta = const VerificationMeta(
    'occurrenceCount',
  );
  @override
  late final GeneratedColumn<int> occurrenceCount = GeneratedColumn<int>(
    'occurrence_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeenAt = GeneratedColumn<DateTime>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeenAt = GeneratedColumn<DateTime>(
    'last_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    hash,
    kind,
    message,
    occurrenceCount,
    firstSeenAt,
    lastSeenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_issues';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportIssueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    if (data.containsKey('occurrence_count')) {
      context.handle(
        _occurrenceCountMeta,
        occurrenceCount.isAcceptableOrUnknown(
          data['occurrence_count']!,
          _occurrenceCountMeta,
        ),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSeenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path, hash};
  @override
  ImportIssueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportIssueRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      kind: $ImportIssuesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
      occurrenceCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrence_count'],
      )!,
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen_at'],
      )!,
    );
  }

  @override
  $ImportIssuesTable createAlias(String alias) {
    return $ImportIssuesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImportIssueKind, String, String> $converterkind =
      const EnumNameConverter<ImportIssueKind>(ImportIssueKind.values);
}

class ImportIssueRow extends DataClass implements Insertable<ImportIssueRow> {
  final String path;
  final String hash;
  final ImportIssueKind kind;
  final String message;
  final int occurrenceCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  const ImportIssueRow({
    required this.path,
    required this.hash,
    required this.kind,
    required this.message,
    required this.occurrenceCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['hash'] = Variable<String>(hash);
    {
      map['kind'] = Variable<String>(
        $ImportIssuesTable.$converterkind.toSql(kind),
      );
    }
    map['message'] = Variable<String>(message);
    map['occurrence_count'] = Variable<int>(occurrenceCount);
    map['first_seen_at'] = Variable<DateTime>(firstSeenAt);
    map['last_seen_at'] = Variable<DateTime>(lastSeenAt);
    return map;
  }

  ImportIssuesCompanion toCompanion(bool nullToAbsent) {
    return ImportIssuesCompanion(
      path: Value(path),
      hash: Value(hash),
      kind: Value(kind),
      message: Value(message),
      occurrenceCount: Value(occurrenceCount),
      firstSeenAt: Value(firstSeenAt),
      lastSeenAt: Value(lastSeenAt),
    );
  }

  factory ImportIssueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportIssueRow(
      path: serializer.fromJson<String>(json['path']),
      hash: serializer.fromJson<String>(json['hash']),
      kind: $ImportIssuesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      message: serializer.fromJson<String>(json['message']),
      occurrenceCount: serializer.fromJson<int>(json['occurrenceCount']),
      firstSeenAt: serializer.fromJson<DateTime>(json['firstSeenAt']),
      lastSeenAt: serializer.fromJson<DateTime>(json['lastSeenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'hash': serializer.toJson<String>(hash),
      'kind': serializer.toJson<String>(
        $ImportIssuesTable.$converterkind.toJson(kind),
      ),
      'message': serializer.toJson<String>(message),
      'occurrenceCount': serializer.toJson<int>(occurrenceCount),
      'firstSeenAt': serializer.toJson<DateTime>(firstSeenAt),
      'lastSeenAt': serializer.toJson<DateTime>(lastSeenAt),
    };
  }

  ImportIssueRow copyWith({
    String? path,
    String? hash,
    ImportIssueKind? kind,
    String? message,
    int? occurrenceCount,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
  }) => ImportIssueRow(
    path: path ?? this.path,
    hash: hash ?? this.hash,
    kind: kind ?? this.kind,
    message: message ?? this.message,
    occurrenceCount: occurrenceCount ?? this.occurrenceCount,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );
  ImportIssueRow copyWithCompanion(ImportIssuesCompanion data) {
    return ImportIssueRow(
      path: data.path.present ? data.path.value : this.path,
      hash: data.hash.present ? data.hash.value : this.hash,
      kind: data.kind.present ? data.kind.value : this.kind,
      message: data.message.present ? data.message.value : this.message,
      occurrenceCount: data.occurrenceCount.present
          ? data.occurrenceCount.value
          : this.occurrenceCount,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportIssueRow(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('kind: $kind, ')
          ..write('message: $message, ')
          ..write('occurrenceCount: $occurrenceCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    hash,
    kind,
    message,
    occurrenceCount,
    firstSeenAt,
    lastSeenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportIssueRow &&
          other.path == this.path &&
          other.hash == this.hash &&
          other.kind == this.kind &&
          other.message == this.message &&
          other.occurrenceCount == this.occurrenceCount &&
          other.firstSeenAt == this.firstSeenAt &&
          other.lastSeenAt == this.lastSeenAt);
}

class ImportIssuesCompanion extends UpdateCompanion<ImportIssueRow> {
  final Value<String> path;
  final Value<String> hash;
  final Value<ImportIssueKind> kind;
  final Value<String> message;
  final Value<int> occurrenceCount;
  final Value<DateTime> firstSeenAt;
  final Value<DateTime> lastSeenAt;
  final Value<int> rowid;
  const ImportIssuesCompanion({
    this.path = const Value.absent(),
    this.hash = const Value.absent(),
    this.kind = const Value.absent(),
    this.message = const Value.absent(),
    this.occurrenceCount = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportIssuesCompanion.insert({
    required String path,
    required String hash,
    required ImportIssueKind kind,
    required String message,
    this.occurrenceCount = const Value.absent(),
    required DateTime firstSeenAt,
    required DateTime lastSeenAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       hash = Value(hash),
       kind = Value(kind),
       message = Value(message),
       firstSeenAt = Value(firstSeenAt),
       lastSeenAt = Value(lastSeenAt);
  static Insertable<ImportIssueRow> custom({
    Expression<String>? path,
    Expression<String>? hash,
    Expression<String>? kind,
    Expression<String>? message,
    Expression<int>? occurrenceCount,
    Expression<DateTime>? firstSeenAt,
    Expression<DateTime>? lastSeenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (hash != null) 'hash': hash,
      if (kind != null) 'kind': kind,
      if (message != null) 'message': message,
      if (occurrenceCount != null) 'occurrence_count': occurrenceCount,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportIssuesCompanion copyWith({
    Value<String>? path,
    Value<String>? hash,
    Value<ImportIssueKind>? kind,
    Value<String>? message,
    Value<int>? occurrenceCount,
    Value<DateTime>? firstSeenAt,
    Value<DateTime>? lastSeenAt,
    Value<int>? rowid,
  }) {
    return ImportIssuesCompanion(
      path: path ?? this.path,
      hash: hash ?? this.hash,
      kind: kind ?? this.kind,
      message: message ?? this.message,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ImportIssuesTable.$converterkind.toSql(kind.value),
      );
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (occurrenceCount.present) {
      map['occurrence_count'] = Variable<int>(occurrenceCount.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<DateTime>(firstSeenAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<DateTime>(lastSeenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportIssuesCompanion(')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('kind: $kind, ')
          ..write('message: $message, ')
          ..write('occurrenceCount: $occurrenceCount, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LovecaDatabase extends GeneratedDatabase {
  _$LovecaDatabase(QueryExecutor e) : super(e);
  $LovecaDatabaseManager get managers => $LovecaDatabaseManager(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CardNamesTable cardNames = $CardNamesTable(this);
  late final $CardKeywordsTable cardKeywords = $CardKeywordsTable(this);
  late final $CardHeartsTable cardHearts = $CardHeartsTable(this);
  late final $CardBladeHeartEffectsTable cardBladeHeartEffects =
      $CardBladeHeartEffectsTable(this);
  late final $PrintingsTable printings = $PrintingsTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $FaqsTable faqs = $FaqsTable(this);
  late final $FaqPrintingsTable faqPrintings = $FaqPrintingsTable(this);
  late final $RuleConfigsTable ruleConfigs = $RuleConfigsTable(this);
  late final $DecksTable decks = $DecksTable(this);
  late final $DeckTagsTable deckTags = $DeckTagsTable(this);
  late final $DeckEntriesTable deckEntries = $DeckEntriesTable(this);
  late final $DeckEditOpsTable deckEditOps = $DeckEditOpsTable(this);
  late final $DeckSyncMarksTable deckSyncMarks = $DeckSyncMarksTable(this);
  late final $MasterStatesTable masterStates = $MasterStatesTable(this);
  late final $MasterFilesTable masterFiles = $MasterFilesTable(this);
  late final $ImportIssuesTable importIssues = $ImportIssuesTable(this);
  late final Index idxCardNamesLookup = Index(
    'idx_card_names_lookup',
    'CREATE INDEX idx_card_names_lookup ON card_names (kind, value)',
  );
  late final Index idxCardKeywordsKeyword = Index(
    'idx_card_keywords_keyword',
    'CREATE INDEX idx_card_keywords_keyword ON card_keywords (keyword)',
  );
  late final Index idxCardHeartsKindColor = Index(
    'idx_card_hearts_kind_color',
    'CREATE INDEX idx_card_hearts_kind_color ON card_hearts (kind, color)',
  );
  late final Index idxPrintingsCardNumber = Index(
    'idx_printings_card_number',
    'CREATE INDEX idx_printings_card_number ON printings (card_number)',
  );
  late final Index idxPrintingsExpansion = Index(
    'idx_printings_expansion',
    'CREATE INDEX idx_printings_expansion ON printings (expansion)',
  );
  late final Index idxPrintingsIsParallel = Index(
    'idx_printings_is_parallel',
    'CREATE INDEX idx_printings_is_parallel ON printings (is_parallel)',
  );
  late final Index idxFaqPrintingsPrinting = Index(
    'idx_faq_printings_printing',
    'CREATE INDEX idx_faq_printings_printing ON faq_printings (printing_id)',
  );
  late final Index idxDeckEntriesPrinting = Index(
    'idx_deck_entries_printing',
    'CREATE INDEX idx_deck_entries_printing ON deck_entries (printing_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cards,
    cardNames,
    cardKeywords,
    cardHearts,
    cardBladeHeartEffects,
    printings,
    products,
    faqs,
    faqPrintings,
    ruleConfigs,
    decks,
    deckTags,
    deckEntries,
    deckEditOps,
    deckSyncMarks,
    masterStates,
    masterFiles,
    importIssues,
    idxCardNamesLookup,
    idxCardKeywordsKeyword,
    idxCardHeartsKindColor,
    idxPrintingsCardNumber,
    idxPrintingsExpansion,
    idxPrintingsIsParallel,
    idxFaqPrintingsPrinting,
    idxDeckEntriesPrinting,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_names', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_keywords', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_hearts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('card_blade_heart_effects', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('printings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'faqs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('faq_printings', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'decks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('deck_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'decks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('deck_entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      required String cardNumber,
      required String name,
      required CardType cardType,
      Value<String> effectText,
      Value<int?> cost,
      Value<int?> bladeCount,
      Value<int?> score,
      Value<int> heartTotal,
      Value<int> requiredHeartTotal,
      Value<int?> stats,
      Value<bool> isDeleted,
      Value<String> searchBlob,
      Value<int> rowid,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<String> cardNumber,
      Value<String> name,
      Value<CardType> cardType,
      Value<String> effectText,
      Value<int?> cost,
      Value<int?> bladeCount,
      Value<int?> score,
      Value<int> heartTotal,
      Value<int> requiredHeartTotal,
      Value<int?> stats,
      Value<bool> isDeleted,
      Value<String> searchBlob,
      Value<int> rowid,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$LovecaDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CardNamesTable, List<CardNameRow>>
  _cardNamesRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.cardNames,
    aliasName: 'cards__card_number__card_names__card_number',
  );

  $$CardNamesTableProcessedTableManager get cardNamesRefs {
    final manager = $$CardNamesTableTableManager($_db, $_db.cardNames).filter(
      (f) => f.cardNumber.cardNumber.sqlEquals(
        $_itemColumn<String>('card_number')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_cardNamesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardKeywordsTable, List<CardKeywordRow>>
  _cardKeywordsRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.cardKeywords,
    aliasName: 'cards__card_number__card_keywords__card_number',
  );

  $$CardKeywordsTableProcessedTableManager get cardKeywordsRefs {
    final manager = $$CardKeywordsTableTableManager($_db, $_db.cardKeywords)
        .filter(
          (f) => f.cardNumber.cardNumber.sqlEquals(
            $_itemColumn<String>('card_number')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(_cardKeywordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardHeartsTable, List<CardHeartRow>>
  _cardHeartsRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.cardHearts,
    aliasName: 'cards__card_number__card_hearts__card_number',
  );

  $$CardHeartsTableProcessedTableManager get cardHeartsRefs {
    final manager = $$CardHeartsTableTableManager($_db, $_db.cardHearts).filter(
      (f) => f.cardNumber.cardNumber.sqlEquals(
        $_itemColumn<String>('card_number')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_cardHeartsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $CardBladeHeartEffectsTable,
    List<CardBladeHeartEffectRow>
  >
  _cardBladeHeartEffectsRefsTable(_$LovecaDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.cardBladeHeartEffects,
        aliasName: 'cards__card_number__card_blade_heart_effects__card_number',
      );

  $$CardBladeHeartEffectsTableProcessedTableManager
  get cardBladeHeartEffectsRefs {
    final manager =
        $$CardBladeHeartEffectsTableTableManager(
          $_db,
          $_db.cardBladeHeartEffects,
        ).filter(
          (f) => f.cardNumber.cardNumber.sqlEquals(
            $_itemColumn<String>('card_number')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _cardBladeHeartEffectsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PrintingsTable, List<PrintingRow>>
  _printingsRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.printings,
    aliasName: 'cards__card_number__printings__card_number',
  );

  $$PrintingsTableProcessedTableManager get printingsRefs {
    final manager = $$PrintingsTableTableManager($_db, $_db.printings).filter(
      (f) => f.cardNumber.cardNumber.sqlEquals(
        $_itemColumn<String>('card_number')!,
      ),
    );

    final cache = $_typedResult.readTableOrNull(_printingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer
    extends Composer<_$LovecaDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CardType, CardType, String> get cardType =>
      $composableBuilder(
        column: $table.cardType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get effectText => $composableBuilder(
    column: $table.effectText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bladeCount => $composableBuilder(
    column: $table.bladeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heartTotal => $composableBuilder(
    column: $table.heartTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get requiredHeartTotal => $composableBuilder(
    column: $table.requiredHeartTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get searchBlob => $composableBuilder(
    column: $table.searchBlob,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> cardNamesRefs(
    Expression<bool> Function($$CardNamesTableFilterComposer f) f,
  ) {
    final $$CardNamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardNames,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardNamesTableFilterComposer(
            $db: $db,
            $table: $db.cardNames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardKeywordsRefs(
    Expression<bool> Function($$CardKeywordsTableFilterComposer f) f,
  ) {
    final $$CardKeywordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardKeywords,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardKeywordsTableFilterComposer(
            $db: $db,
            $table: $db.cardKeywords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardHeartsRefs(
    Expression<bool> Function($$CardHeartsTableFilterComposer f) f,
  ) {
    final $$CardHeartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardHearts,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardHeartsTableFilterComposer(
            $db: $db,
            $table: $db.cardHearts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardBladeHeartEffectsRefs(
    Expression<bool> Function($$CardBladeHeartEffectsTableFilterComposer f) f,
  ) {
    final $$CardBladeHeartEffectsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cardNumber,
          referencedTable: $db.cardBladeHeartEffects,
          getReferencedColumn: (t) => t.cardNumber,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CardBladeHeartEffectsTableFilterComposer(
                $db: $db,
                $table: $db.cardBladeHeartEffects,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> printingsRefs(
    Expression<bool> Function($$PrintingsTableFilterComposer f) f,
  ) {
    final $$PrintingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.printings,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrintingsTableFilterComposer(
            $db: $db,
            $table: $db.printings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardType => $composableBuilder(
    column: $table.cardType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effectText => $composableBuilder(
    column: $table.effectText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bladeCount => $composableBuilder(
    column: $table.bladeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heartTotal => $composableBuilder(
    column: $table.heartTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get requiredHeartTotal => $composableBuilder(
    column: $table.requiredHeartTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stats => $composableBuilder(
    column: $table.stats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get searchBlob => $composableBuilder(
    column: $table.searchBlob,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cardNumber => $composableBuilder(
    column: $table.cardNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardType, String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumn<String> get effectText => $composableBuilder(
    column: $table.effectText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<int> get bladeCount => $composableBuilder(
    column: $table.bladeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get heartTotal => $composableBuilder(
    column: $table.heartTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get requiredHeartTotal => $composableBuilder(
    column: $table.requiredHeartTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stats =>
      $composableBuilder(column: $table.stats, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get searchBlob => $composableBuilder(
    column: $table.searchBlob,
    builder: (column) => column,
  );

  Expression<T> cardNamesRefs<T extends Object>(
    Expression<T> Function($$CardNamesTableAnnotationComposer a) f,
  ) {
    final $$CardNamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardNames,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardNamesTableAnnotationComposer(
            $db: $db,
            $table: $db.cardNames,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardKeywordsRefs<T extends Object>(
    Expression<T> Function($$CardKeywordsTableAnnotationComposer a) f,
  ) {
    final $$CardKeywordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardKeywords,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardKeywordsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardKeywords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardHeartsRefs<T extends Object>(
    Expression<T> Function($$CardHeartsTableAnnotationComposer a) f,
  ) {
    final $$CardHeartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cardHearts,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardHeartsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardHearts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardBladeHeartEffectsRefs<T extends Object>(
    Expression<T> Function($$CardBladeHeartEffectsTableAnnotationComposer a) f,
  ) {
    final $$CardBladeHeartEffectsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.cardNumber,
          referencedTable: $db.cardBladeHeartEffects,
          getReferencedColumn: (t) => t.cardNumber,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CardBladeHeartEffectsTableAnnotationComposer(
                $db: $db,
                $table: $db.cardBladeHeartEffects,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> printingsRefs<T extends Object>(
    Expression<T> Function($$PrintingsTableAnnotationComposer a) f,
  ) {
    final $$PrintingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.printings,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PrintingsTableAnnotationComposer(
            $db: $db,
            $table: $db.printings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({
            bool cardNamesRefs,
            bool cardKeywordsRefs,
            bool cardHeartsRefs,
            bool cardBladeHeartEffectsRefs,
            bool printingsRefs,
          })
        > {
  $$CardsTableTableManager(_$LovecaDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardNumber = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<CardType> cardType = const Value.absent(),
                Value<String> effectText = const Value.absent(),
                Value<int?> cost = const Value.absent(),
                Value<int?> bladeCount = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<int> heartTotal = const Value.absent(),
                Value<int> requiredHeartTotal = const Value.absent(),
                Value<int?> stats = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> searchBlob = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion(
                cardNumber: cardNumber,
                name: name,
                cardType: cardType,
                effectText: effectText,
                cost: cost,
                bladeCount: bladeCount,
                score: score,
                heartTotal: heartTotal,
                requiredHeartTotal: requiredHeartTotal,
                stats: stats,
                isDeleted: isDeleted,
                searchBlob: searchBlob,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardNumber,
                required String name,
                required CardType cardType,
                Value<String> effectText = const Value.absent(),
                Value<int?> cost = const Value.absent(),
                Value<int?> bladeCount = const Value.absent(),
                Value<int?> score = const Value.absent(),
                Value<int> heartTotal = const Value.absent(),
                Value<int> requiredHeartTotal = const Value.absent(),
                Value<int?> stats = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> searchBlob = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCompanion.insert(
                cardNumber: cardNumber,
                name: name,
                cardType: cardType,
                effectText: effectText,
                cost: cost,
                bladeCount: bladeCount,
                score: score,
                heartTotal: heartTotal,
                requiredHeartTotal: requiredHeartTotal,
                stats: stats,
                isDeleted: isDeleted,
                searchBlob: searchBlob,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                cardNamesRefs = false,
                cardKeywordsRefs = false,
                cardHeartsRefs = false,
                cardBladeHeartEffectsRefs = false,
                printingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardNamesRefs) db.cardNames,
                    if (cardKeywordsRefs) db.cardKeywords,
                    if (cardHeartsRefs) db.cardHearts,
                    if (cardBladeHeartEffectsRefs) db.cardBladeHeartEffects,
                    if (printingsRefs) db.printings,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardNamesRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardNameRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardNamesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardNamesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardNumber == item.cardNumber,
                              ),
                          typedResults: items,
                        ),
                      if (cardKeywordsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardKeywordRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardKeywordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardKeywordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardNumber == item.cardNumber,
                              ),
                          typedResults: items,
                        ),
                      if (cardHeartsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardHeartRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardHeartsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardHeartsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardNumber == item.cardNumber,
                              ),
                          typedResults: items,
                        ),
                      if (cardBladeHeartEffectsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardBladeHeartEffectRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardBladeHeartEffectsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardBladeHeartEffectsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardNumber == item.cardNumber,
                              ),
                          typedResults: items,
                        ),
                      if (printingsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          PrintingRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._printingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).printingsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardNumber == item.cardNumber,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({
        bool cardNamesRefs,
        bool cardKeywordsRefs,
        bool cardHeartsRefs,
        bool cardBladeHeartEffectsRefs,
        bool printingsRefs,
      })
    >;
typedef $$CardNamesTableCreateCompanionBuilder =
    CardNamesCompanion Function({
      required String cardNumber,
      required CardNameKind kind,
      required int ord,
      required String value,
      Value<int> rowid,
    });
typedef $$CardNamesTableUpdateCompanionBuilder =
    CardNamesCompanion Function({
      Value<String> cardNumber,
      Value<CardNameKind> kind,
      Value<int> ord,
      Value<String> value,
      Value<int> rowid,
    });

final class $$CardNamesTableReferences
    extends BaseReferences<_$LovecaDatabase, $CardNamesTable, CardNameRow> {
  $$CardNamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardNumberTable(_$LovecaDatabase db) =>
      db.cards.createAlias('card_names__card_number__cards__card_number');

  $$CardsTableProcessedTableManager get cardNumber {
    final $_column = $_itemColumn<String>('card_number')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.cardNumber.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardNumberTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardNamesTableFilterComposer
    extends Composer<_$LovecaDatabase, $CardNamesTable> {
  $$CardNamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<CardNameKind, CardNameKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardNumber {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardNamesTableOrderingComposer
    extends Composer<_$LovecaDatabase, $CardNamesTable> {
  $$CardNamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardNumber {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardNamesTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $CardNamesTable> {
  $$CardNamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<CardNameKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardNumber {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardNamesTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $CardNamesTable,
          CardNameRow,
          $$CardNamesTableFilterComposer,
          $$CardNamesTableOrderingComposer,
          $$CardNamesTableAnnotationComposer,
          $$CardNamesTableCreateCompanionBuilder,
          $$CardNamesTableUpdateCompanionBuilder,
          (CardNameRow, $$CardNamesTableReferences),
          CardNameRow,
          PrefetchHooks Function({bool cardNumber})
        > {
  $$CardNamesTableTableManager(_$LovecaDatabase db, $CardNamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardNamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardNamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardNamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardNumber = const Value.absent(),
                Value<CardNameKind> kind = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardNamesCompanion(
                cardNumber: cardNumber,
                kind: kind,
                ord: ord,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardNumber,
                required CardNameKind kind,
                required int ord,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => CardNamesCompanion.insert(
                cardNumber: cardNumber,
                kind: kind,
                ord: ord,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardNamesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardNumber = false}) {
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
                    if (cardNumber) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardNumber,
                                referencedTable: $$CardNamesTableReferences
                                    ._cardNumberTable(db),
                                referencedColumn: $$CardNamesTableReferences
                                    ._cardNumberTable(db)
                                    .cardNumber,
                              )
                              as T;
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

typedef $$CardNamesTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $CardNamesTable,
      CardNameRow,
      $$CardNamesTableFilterComposer,
      $$CardNamesTableOrderingComposer,
      $$CardNamesTableAnnotationComposer,
      $$CardNamesTableCreateCompanionBuilder,
      $$CardNamesTableUpdateCompanionBuilder,
      (CardNameRow, $$CardNamesTableReferences),
      CardNameRow,
      PrefetchHooks Function({bool cardNumber})
    >;
typedef $$CardKeywordsTableCreateCompanionBuilder =
    CardKeywordsCompanion Function({
      required String cardNumber,
      required int ord,
      required String keyword,
      Value<int> rowid,
    });
typedef $$CardKeywordsTableUpdateCompanionBuilder =
    CardKeywordsCompanion Function({
      Value<String> cardNumber,
      Value<int> ord,
      Value<String> keyword,
      Value<int> rowid,
    });

final class $$CardKeywordsTableReferences
    extends
        BaseReferences<_$LovecaDatabase, $CardKeywordsTable, CardKeywordRow> {
  $$CardKeywordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardNumberTable(_$LovecaDatabase db) =>
      db.cards.createAlias('card_keywords__card_number__cards__card_number');

  $$CardsTableProcessedTableManager get cardNumber {
    final $_column = $_itemColumn<String>('card_number')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.cardNumber.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardNumberTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardKeywordsTableFilterComposer
    extends Composer<_$LovecaDatabase, $CardKeywordsTable> {
  $$CardKeywordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardNumber {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardKeywordsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $CardKeywordsTable> {
  $$CardKeywordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keyword => $composableBuilder(
    column: $table.keyword,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardNumber {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardKeywordsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $CardKeywordsTable> {
  $$CardKeywordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get keyword =>
      $composableBuilder(column: $table.keyword, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardNumber {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardKeywordsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $CardKeywordsTable,
          CardKeywordRow,
          $$CardKeywordsTableFilterComposer,
          $$CardKeywordsTableOrderingComposer,
          $$CardKeywordsTableAnnotationComposer,
          $$CardKeywordsTableCreateCompanionBuilder,
          $$CardKeywordsTableUpdateCompanionBuilder,
          (CardKeywordRow, $$CardKeywordsTableReferences),
          CardKeywordRow,
          PrefetchHooks Function({bool cardNumber})
        > {
  $$CardKeywordsTableTableManager(_$LovecaDatabase db, $CardKeywordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardKeywordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardKeywordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardKeywordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardNumber = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> keyword = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardKeywordsCompanion(
                cardNumber: cardNumber,
                ord: ord,
                keyword: keyword,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardNumber,
                required int ord,
                required String keyword,
                Value<int> rowid = const Value.absent(),
              }) => CardKeywordsCompanion.insert(
                cardNumber: cardNumber,
                ord: ord,
                keyword: keyword,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardKeywordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardNumber = false}) {
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
                    if (cardNumber) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardNumber,
                                referencedTable: $$CardKeywordsTableReferences
                                    ._cardNumberTable(db),
                                referencedColumn: $$CardKeywordsTableReferences
                                    ._cardNumberTable(db)
                                    .cardNumber,
                              )
                              as T;
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

typedef $$CardKeywordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $CardKeywordsTable,
      CardKeywordRow,
      $$CardKeywordsTableFilterComposer,
      $$CardKeywordsTableOrderingComposer,
      $$CardKeywordsTableAnnotationComposer,
      $$CardKeywordsTableCreateCompanionBuilder,
      $$CardKeywordsTableUpdateCompanionBuilder,
      (CardKeywordRow, $$CardKeywordsTableReferences),
      CardKeywordRow,
      PrefetchHooks Function({bool cardNumber})
    >;
typedef $$CardHeartsTableCreateCompanionBuilder =
    CardHeartsCompanion Function({
      required String cardNumber,
      required HeartKind kind,
      required HeartColor color,
      required int count,
      Value<int> rowid,
    });
typedef $$CardHeartsTableUpdateCompanionBuilder =
    CardHeartsCompanion Function({
      Value<String> cardNumber,
      Value<HeartKind> kind,
      Value<HeartColor> color,
      Value<int> count,
      Value<int> rowid,
    });

final class $$CardHeartsTableReferences
    extends BaseReferences<_$LovecaDatabase, $CardHeartsTable, CardHeartRow> {
  $$CardHeartsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardNumberTable(_$LovecaDatabase db) =>
      db.cards.createAlias('card_hearts__card_number__cards__card_number');

  $$CardsTableProcessedTableManager get cardNumber {
    final $_column = $_itemColumn<String>('card_number')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.cardNumber.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardNumberTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardHeartsTableFilterComposer
    extends Composer<_$LovecaDatabase, $CardHeartsTable> {
  $$CardHeartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<HeartKind, HeartKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<HeartColor, HeartColor, String> get color =>
      $composableBuilder(
        column: $table.color,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardNumber {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardHeartsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $CardHeartsTable> {
  $$CardHeartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardNumber {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardHeartsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $CardHeartsTable> {
  $$CardHeartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<HeartKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumnWithTypeConverter<HeartColor, String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardNumber {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardHeartsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $CardHeartsTable,
          CardHeartRow,
          $$CardHeartsTableFilterComposer,
          $$CardHeartsTableOrderingComposer,
          $$CardHeartsTableAnnotationComposer,
          $$CardHeartsTableCreateCompanionBuilder,
          $$CardHeartsTableUpdateCompanionBuilder,
          (CardHeartRow, $$CardHeartsTableReferences),
          CardHeartRow,
          PrefetchHooks Function({bool cardNumber})
        > {
  $$CardHeartsTableTableManager(_$LovecaDatabase db, $CardHeartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardHeartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardHeartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardHeartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cardNumber = const Value.absent(),
                Value<HeartKind> kind = const Value.absent(),
                Value<HeartColor> color = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardHeartsCompanion(
                cardNumber: cardNumber,
                kind: kind,
                color: color,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardNumber,
                required HeartKind kind,
                required HeartColor color,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => CardHeartsCompanion.insert(
                cardNumber: cardNumber,
                kind: kind,
                color: color,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardHeartsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardNumber = false}) {
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
                    if (cardNumber) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardNumber,
                                referencedTable: $$CardHeartsTableReferences
                                    ._cardNumberTable(db),
                                referencedColumn: $$CardHeartsTableReferences
                                    ._cardNumberTable(db)
                                    .cardNumber,
                              )
                              as T;
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

typedef $$CardHeartsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $CardHeartsTable,
      CardHeartRow,
      $$CardHeartsTableFilterComposer,
      $$CardHeartsTableOrderingComposer,
      $$CardHeartsTableAnnotationComposer,
      $$CardHeartsTableCreateCompanionBuilder,
      $$CardHeartsTableUpdateCompanionBuilder,
      (CardHeartRow, $$CardHeartsTableReferences),
      CardHeartRow,
      PrefetchHooks Function({bool cardNumber})
    >;
typedef $$CardBladeHeartEffectsTableCreateCompanionBuilder =
    CardBladeHeartEffectsCompanion Function({
      required String cardNumber,
      required BladeHeartEffect effect,
      required int count,
      Value<int> rowid,
    });
typedef $$CardBladeHeartEffectsTableUpdateCompanionBuilder =
    CardBladeHeartEffectsCompanion Function({
      Value<String> cardNumber,
      Value<BladeHeartEffect> effect,
      Value<int> count,
      Value<int> rowid,
    });

final class $$CardBladeHeartEffectsTableReferences
    extends
        BaseReferences<
          _$LovecaDatabase,
          $CardBladeHeartEffectsTable,
          CardBladeHeartEffectRow
        > {
  $$CardBladeHeartEffectsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CardsTable _cardNumberTable(_$LovecaDatabase db) => db.cards
      .createAlias('card_blade_heart_effects__card_number__cards__card_number');

  $$CardsTableProcessedTableManager get cardNumber {
    final $_column = $_itemColumn<String>('card_number')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.cardNumber.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardNumberTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CardBladeHeartEffectsTableFilterComposer
    extends Composer<_$LovecaDatabase, $CardBladeHeartEffectsTable> {
  $$CardBladeHeartEffectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<BladeHeartEffect, BladeHeartEffect, String>
  get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardNumber {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardBladeHeartEffectsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $CardBladeHeartEffectsTable> {
  $$CardBladeHeartEffectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get effect => $composableBuilder(
    column: $table.effect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardNumber {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardBladeHeartEffectsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $CardBladeHeartEffectsTable> {
  $$CardBladeHeartEffectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<BladeHeartEffect, String> get effect =>
      $composableBuilder(column: $table.effect, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardNumber {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardBladeHeartEffectsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $CardBladeHeartEffectsTable,
          CardBladeHeartEffectRow,
          $$CardBladeHeartEffectsTableFilterComposer,
          $$CardBladeHeartEffectsTableOrderingComposer,
          $$CardBladeHeartEffectsTableAnnotationComposer,
          $$CardBladeHeartEffectsTableCreateCompanionBuilder,
          $$CardBladeHeartEffectsTableUpdateCompanionBuilder,
          (CardBladeHeartEffectRow, $$CardBladeHeartEffectsTableReferences),
          CardBladeHeartEffectRow,
          PrefetchHooks Function({bool cardNumber})
        > {
  $$CardBladeHeartEffectsTableTableManager(
    _$LovecaDatabase db,
    $CardBladeHeartEffectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardBladeHeartEffectsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$CardBladeHeartEffectsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CardBladeHeartEffectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> cardNumber = const Value.absent(),
                Value<BladeHeartEffect> effect = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardBladeHeartEffectsCompanion(
                cardNumber: cardNumber,
                effect: effect,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cardNumber,
                required BladeHeartEffect effect,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => CardBladeHeartEffectsCompanion.insert(
                cardNumber: cardNumber,
                effect: effect,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardBladeHeartEffectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardNumber = false}) {
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
                    if (cardNumber) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardNumber,
                                referencedTable:
                                    $$CardBladeHeartEffectsTableReferences
                                        ._cardNumberTable(db),
                                referencedColumn:
                                    $$CardBladeHeartEffectsTableReferences
                                        ._cardNumberTable(db)
                                        .cardNumber,
                              )
                              as T;
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

typedef $$CardBladeHeartEffectsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $CardBladeHeartEffectsTable,
      CardBladeHeartEffectRow,
      $$CardBladeHeartEffectsTableFilterComposer,
      $$CardBladeHeartEffectsTableOrderingComposer,
      $$CardBladeHeartEffectsTableAnnotationComposer,
      $$CardBladeHeartEffectsTableCreateCompanionBuilder,
      $$CardBladeHeartEffectsTableUpdateCompanionBuilder,
      (CardBladeHeartEffectRow, $$CardBladeHeartEffectsTableReferences),
      CardBladeHeartEffectRow,
      PrefetchHooks Function({bool cardNumber})
    >;
typedef $$PrintingsTableCreateCompanionBuilder =
    PrintingsCompanion Function({
      required String printingId,
      required String cardNumber,
      Value<String> expansion,
      Value<String> rarity,
      Value<bool> isParallel,
      Value<String> illustrator,
      Value<String> imageHash,
      Value<int> rowid,
    });
typedef $$PrintingsTableUpdateCompanionBuilder =
    PrintingsCompanion Function({
      Value<String> printingId,
      Value<String> cardNumber,
      Value<String> expansion,
      Value<String> rarity,
      Value<bool> isParallel,
      Value<String> illustrator,
      Value<String> imageHash,
      Value<int> rowid,
    });

final class $$PrintingsTableReferences
    extends BaseReferences<_$LovecaDatabase, $PrintingsTable, PrintingRow> {
  $$PrintingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardNumberTable(_$LovecaDatabase db) =>
      db.cards.createAlias('printings__card_number__cards__card_number');

  $$CardsTableProcessedTableManager get cardNumber {
    final $_column = $_itemColumn<String>('card_number')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.cardNumber.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardNumberTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PrintingsTableFilterComposer
    extends Composer<_$LovecaDatabase, $PrintingsTable> {
  $$PrintingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get expansion => $composableBuilder(
    column: $table.expansion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isParallel => $composableBuilder(
    column: $table.isParallel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get illustrator => $composableBuilder(
    column: $table.illustrator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardNumber {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintingsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $PrintingsTable> {
  $$PrintingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get expansion => $composableBuilder(
    column: $table.expansion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isParallel => $composableBuilder(
    column: $table.isParallel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get illustrator => $composableBuilder(
    column: $table.illustrator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageHash => $composableBuilder(
    column: $table.imageHash,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardNumber {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintingsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $PrintingsTable> {
  $$PrintingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get expansion =>
      $composableBuilder(column: $table.expansion, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<bool> get isParallel => $composableBuilder(
    column: $table.isParallel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get illustrator => $composableBuilder(
    column: $table.illustrator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageHash =>
      $composableBuilder(column: $table.imageHash, builder: (column) => column);

  $$CardsTableAnnotationComposer get cardNumber {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardNumber,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.cardNumber,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PrintingsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $PrintingsTable,
          PrintingRow,
          $$PrintingsTableFilterComposer,
          $$PrintingsTableOrderingComposer,
          $$PrintingsTableAnnotationComposer,
          $$PrintingsTableCreateCompanionBuilder,
          $$PrintingsTableUpdateCompanionBuilder,
          (PrintingRow, $$PrintingsTableReferences),
          PrintingRow,
          PrefetchHooks Function({bool cardNumber})
        > {
  $$PrintingsTableTableManager(_$LovecaDatabase db, $PrintingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrintingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrintingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrintingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> printingId = const Value.absent(),
                Value<String> cardNumber = const Value.absent(),
                Value<String> expansion = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<bool> isParallel = const Value.absent(),
                Value<String> illustrator = const Value.absent(),
                Value<String> imageHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrintingsCompanion(
                printingId: printingId,
                cardNumber: cardNumber,
                expansion: expansion,
                rarity: rarity,
                isParallel: isParallel,
                illustrator: illustrator,
                imageHash: imageHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String printingId,
                required String cardNumber,
                Value<String> expansion = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<bool> isParallel = const Value.absent(),
                Value<String> illustrator = const Value.absent(),
                Value<String> imageHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrintingsCompanion.insert(
                printingId: printingId,
                cardNumber: cardNumber,
                expansion: expansion,
                rarity: rarity,
                isParallel: isParallel,
                illustrator: illustrator,
                imageHash: imageHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PrintingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardNumber = false}) {
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
                    if (cardNumber) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardNumber,
                                referencedTable: $$PrintingsTableReferences
                                    ._cardNumberTable(db),
                                referencedColumn: $$PrintingsTableReferences
                                    ._cardNumberTable(db)
                                    .cardNumber,
                              )
                              as T;
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

typedef $$PrintingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $PrintingsTable,
      PrintingRow,
      $$PrintingsTableFilterComposer,
      $$PrintingsTableOrderingComposer,
      $$PrintingsTableAnnotationComposer,
      $$PrintingsTableCreateCompanionBuilder,
      $$PrintingsTableUpdateCompanionBuilder,
      (PrintingRow, $$PrintingsTableReferences),
      PrintingRow,
      PrefetchHooks Function({bool cardNumber})
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      required String expansionId,
      Value<String> name,
      Value<String> releaseDate,
      Value<String> slug,
      Value<String> url,
      Value<int> rowid,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<String> expansionId,
      Value<String> name,
      Value<String> releaseDate,
      Value<String> slug,
      Value<String> url,
      Value<int> rowid,
    });

class $$ProductsTableFilterComposer
    extends Composer<_$LovecaDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get expansionId => $composableBuilder(
    column: $table.expansionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProductsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get expansionId => $composableBuilder(
    column: $table.expansionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get expansionId => $composableBuilder(
    column: $table.expansionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $ProductsTable,
          ProductRow,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (
            ProductRow,
            BaseReferences<_$LovecaDatabase, $ProductsTable, ProductRow>,
          ),
          ProductRow,
          PrefetchHooks Function()
        > {
  $$ProductsTableTableManager(_$LovecaDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> expansionId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> releaseDate = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion(
                expansionId: expansionId,
                name: name,
                releaseDate: releaseDate,
                slug: slug,
                url: url,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String expansionId,
                Value<String> name = const Value.absent(),
                Value<String> releaseDate = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductsCompanion.insert(
                expansionId: expansionId,
                name: name,
                releaseDate: releaseDate,
                slug: slug,
                url: url,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $ProductsTable,
      ProductRow,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (
        ProductRow,
        BaseReferences<_$LovecaDatabase, $ProductsTable, ProductRow>,
      ),
      ProductRow,
      PrefetchHooks Function()
    >;
typedef $$FaqsTableCreateCompanionBuilder =
    FaqsCompanion Function({
      required String qaId,
      Value<int> faqId,
      Value<String> question,
      Value<String> answer,
      Value<String> registTime,
      Value<String> updateTime,
      Value<int> rowid,
    });
typedef $$FaqsTableUpdateCompanionBuilder =
    FaqsCompanion Function({
      Value<String> qaId,
      Value<int> faqId,
      Value<String> question,
      Value<String> answer,
      Value<String> registTime,
      Value<String> updateTime,
      Value<int> rowid,
    });

final class $$FaqsTableReferences
    extends BaseReferences<_$LovecaDatabase, $FaqsTable, FaqRow> {
  $$FaqsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FaqPrintingsTable, List<FaqPrintingRow>>
  _faqPrintingsRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.faqPrintings,
    aliasName: 'faqs__qa_id__faq_printings__qa_id',
  );

  $$FaqPrintingsTableProcessedTableManager get faqPrintingsRefs {
    final manager = $$FaqPrintingsTableTableManager(
      $_db,
      $_db.faqPrintings,
    ).filter((f) => f.qaId.qaId.sqlEquals($_itemColumn<String>('qa_id')!));

    final cache = $_typedResult.readTableOrNull(_faqPrintingsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FaqsTableFilterComposer extends Composer<_$LovecaDatabase, $FaqsTable> {
  $$FaqsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get qaId => $composableBuilder(
    column: $table.qaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get faqId => $composableBuilder(
    column: $table.faqId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registTime => $composableBuilder(
    column: $table.registTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> faqPrintingsRefs(
    Expression<bool> Function($$FaqPrintingsTableFilterComposer f) f,
  ) {
    final $$FaqPrintingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.qaId,
      referencedTable: $db.faqPrintings,
      getReferencedColumn: (t) => t.qaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaqPrintingsTableFilterComposer(
            $db: $db,
            $table: $db.faqPrintings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FaqsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $FaqsTable> {
  $$FaqsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get qaId => $composableBuilder(
    column: $table.qaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get faqId => $composableBuilder(
    column: $table.faqId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registTime => $composableBuilder(
    column: $table.registTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FaqsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $FaqsTable> {
  $$FaqsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get qaId =>
      $composableBuilder(column: $table.qaId, builder: (column) => column);

  GeneratedColumn<int> get faqId =>
      $composableBuilder(column: $table.faqId, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get registTime => $composableBuilder(
    column: $table.registTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updateTime => $composableBuilder(
    column: $table.updateTime,
    builder: (column) => column,
  );

  Expression<T> faqPrintingsRefs<T extends Object>(
    Expression<T> Function($$FaqPrintingsTableAnnotationComposer a) f,
  ) {
    final $$FaqPrintingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.qaId,
      referencedTable: $db.faqPrintings,
      getReferencedColumn: (t) => t.qaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaqPrintingsTableAnnotationComposer(
            $db: $db,
            $table: $db.faqPrintings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FaqsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $FaqsTable,
          FaqRow,
          $$FaqsTableFilterComposer,
          $$FaqsTableOrderingComposer,
          $$FaqsTableAnnotationComposer,
          $$FaqsTableCreateCompanionBuilder,
          $$FaqsTableUpdateCompanionBuilder,
          (FaqRow, $$FaqsTableReferences),
          FaqRow,
          PrefetchHooks Function({bool faqPrintingsRefs})
        > {
  $$FaqsTableTableManager(_$LovecaDatabase db, $FaqsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FaqsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FaqsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FaqsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> qaId = const Value.absent(),
                Value<int> faqId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> registTime = const Value.absent(),
                Value<String> updateTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FaqsCompanion(
                qaId: qaId,
                faqId: faqId,
                question: question,
                answer: answer,
                registTime: registTime,
                updateTime: updateTime,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String qaId,
                Value<int> faqId = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> registTime = const Value.absent(),
                Value<String> updateTime = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FaqsCompanion.insert(
                qaId: qaId,
                faqId: faqId,
                question: question,
                answer: answer,
                registTime: registTime,
                updateTime: updateTime,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FaqsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({faqPrintingsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (faqPrintingsRefs) db.faqPrintings],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (faqPrintingsRefs)
                    await $_getPrefetchedData<
                      FaqRow,
                      $FaqsTable,
                      FaqPrintingRow
                    >(
                      currentTable: table,
                      referencedTable: $$FaqsTableReferences
                          ._faqPrintingsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FaqsTableReferences(db, table, p0).faqPrintingsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.qaId == item.qaId),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FaqsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $FaqsTable,
      FaqRow,
      $$FaqsTableFilterComposer,
      $$FaqsTableOrderingComposer,
      $$FaqsTableAnnotationComposer,
      $$FaqsTableCreateCompanionBuilder,
      $$FaqsTableUpdateCompanionBuilder,
      (FaqRow, $$FaqsTableReferences),
      FaqRow,
      PrefetchHooks Function({bool faqPrintingsRefs})
    >;
typedef $$FaqPrintingsTableCreateCompanionBuilder =
    FaqPrintingsCompanion Function({
      required String qaId,
      required String printingId,
      Value<int> rowid,
    });
typedef $$FaqPrintingsTableUpdateCompanionBuilder =
    FaqPrintingsCompanion Function({
      Value<String> qaId,
      Value<String> printingId,
      Value<int> rowid,
    });

final class $$FaqPrintingsTableReferences
    extends
        BaseReferences<_$LovecaDatabase, $FaqPrintingsTable, FaqPrintingRow> {
  $$FaqPrintingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FaqsTable _qaIdTable(_$LovecaDatabase db) =>
      db.faqs.createAlias('faq_printings__qa_id__faqs__qa_id');

  $$FaqsTableProcessedTableManager get qaId {
    final $_column = $_itemColumn<String>('qa_id')!;

    final manager = $$FaqsTableTableManager(
      $_db,
      $_db.faqs,
    ).filter((f) => f.qaId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_qaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FaqPrintingsTableFilterComposer
    extends Composer<_$LovecaDatabase, $FaqPrintingsTable> {
  $$FaqPrintingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnFilters(column),
  );

  $$FaqsTableFilterComposer get qaId {
    final $$FaqsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.qaId,
      referencedTable: $db.faqs,
      getReferencedColumn: (t) => t.qaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaqsTableFilterComposer(
            $db: $db,
            $table: $db.faqs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaqPrintingsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $FaqPrintingsTable> {
  $$FaqPrintingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnOrderings(column),
  );

  $$FaqsTableOrderingComposer get qaId {
    final $$FaqsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.qaId,
      referencedTable: $db.faqs,
      getReferencedColumn: (t) => t.qaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaqsTableOrderingComposer(
            $db: $db,
            $table: $db.faqs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaqPrintingsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $FaqPrintingsTable> {
  $$FaqPrintingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => column,
  );

  $$FaqsTableAnnotationComposer get qaId {
    final $$FaqsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.qaId,
      referencedTable: $db.faqs,
      getReferencedColumn: (t) => t.qaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FaqsTableAnnotationComposer(
            $db: $db,
            $table: $db.faqs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FaqPrintingsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $FaqPrintingsTable,
          FaqPrintingRow,
          $$FaqPrintingsTableFilterComposer,
          $$FaqPrintingsTableOrderingComposer,
          $$FaqPrintingsTableAnnotationComposer,
          $$FaqPrintingsTableCreateCompanionBuilder,
          $$FaqPrintingsTableUpdateCompanionBuilder,
          (FaqPrintingRow, $$FaqPrintingsTableReferences),
          FaqPrintingRow,
          PrefetchHooks Function({bool qaId})
        > {
  $$FaqPrintingsTableTableManager(_$LovecaDatabase db, $FaqPrintingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FaqPrintingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FaqPrintingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FaqPrintingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> qaId = const Value.absent(),
                Value<String> printingId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FaqPrintingsCompanion(
                qaId: qaId,
                printingId: printingId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String qaId,
                required String printingId,
                Value<int> rowid = const Value.absent(),
              }) => FaqPrintingsCompanion.insert(
                qaId: qaId,
                printingId: printingId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FaqPrintingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({qaId = false}) {
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
                    if (qaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.qaId,
                                referencedTable: $$FaqPrintingsTableReferences
                                    ._qaIdTable(db),
                                referencedColumn: $$FaqPrintingsTableReferences
                                    ._qaIdTable(db)
                                    .qaId,
                              )
                              as T;
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

typedef $$FaqPrintingsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $FaqPrintingsTable,
      FaqPrintingRow,
      $$FaqPrintingsTableFilterComposer,
      $$FaqPrintingsTableOrderingComposer,
      $$FaqPrintingsTableAnnotationComposer,
      $$FaqPrintingsTableCreateCompanionBuilder,
      $$FaqPrintingsTableUpdateCompanionBuilder,
      (FaqPrintingRow, $$FaqPrintingsTableReferences),
      FaqPrintingRow,
      PrefetchHooks Function({bool qaId})
    >;
typedef $$RuleConfigsTableCreateCompanionBuilder =
    RuleConfigsCompanion Function({
      Value<int> id,
      required int mainDeckSize,
      required int memberCount,
      required int liveCount,
      required int energyDeckSize,
      required int maxCopiesPerCardNumber,
      required int initialHandSize,
      required int initialEnergyOnField,
      required int liveSlotMax,
      required int winCondition,
      required int stageAreaCount,
    });
typedef $$RuleConfigsTableUpdateCompanionBuilder =
    RuleConfigsCompanion Function({
      Value<int> id,
      Value<int> mainDeckSize,
      Value<int> memberCount,
      Value<int> liveCount,
      Value<int> energyDeckSize,
      Value<int> maxCopiesPerCardNumber,
      Value<int> initialHandSize,
      Value<int> initialEnergyOnField,
      Value<int> liveSlotMax,
      Value<int> winCondition,
      Value<int> stageAreaCount,
    });

class $$RuleConfigsTableFilterComposer
    extends Composer<_$LovecaDatabase, $RuleConfigsTable> {
  $$RuleConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mainDeckSize => $composableBuilder(
    column: $table.mainDeckSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liveCount => $composableBuilder(
    column: $table.liveCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyDeckSize => $composableBuilder(
    column: $table.energyDeckSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxCopiesPerCardNumber => $composableBuilder(
    column: $table.maxCopiesPerCardNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialHandSize => $composableBuilder(
    column: $table.initialHandSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialEnergyOnField => $composableBuilder(
    column: $table.initialEnergyOnField,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get liveSlotMax => $composableBuilder(
    column: $table.liveSlotMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get winCondition => $composableBuilder(
    column: $table.winCondition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stageAreaCount => $composableBuilder(
    column: $table.stageAreaCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RuleConfigsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $RuleConfigsTable> {
  $$RuleConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mainDeckSize => $composableBuilder(
    column: $table.mainDeckSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liveCount => $composableBuilder(
    column: $table.liveCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyDeckSize => $composableBuilder(
    column: $table.energyDeckSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxCopiesPerCardNumber => $composableBuilder(
    column: $table.maxCopiesPerCardNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialHandSize => $composableBuilder(
    column: $table.initialHandSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialEnergyOnField => $composableBuilder(
    column: $table.initialEnergyOnField,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get liveSlotMax => $composableBuilder(
    column: $table.liveSlotMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get winCondition => $composableBuilder(
    column: $table.winCondition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stageAreaCount => $composableBuilder(
    column: $table.stageAreaCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RuleConfigsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $RuleConfigsTable> {
  $$RuleConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mainDeckSize => $composableBuilder(
    column: $table.mainDeckSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get memberCount => $composableBuilder(
    column: $table.memberCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get liveCount =>
      $composableBuilder(column: $table.liveCount, builder: (column) => column);

  GeneratedColumn<int> get energyDeckSize => $composableBuilder(
    column: $table.energyDeckSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxCopiesPerCardNumber => $composableBuilder(
    column: $table.maxCopiesPerCardNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialHandSize => $composableBuilder(
    column: $table.initialHandSize,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialEnergyOnField => $composableBuilder(
    column: $table.initialEnergyOnField,
    builder: (column) => column,
  );

  GeneratedColumn<int> get liveSlotMax => $composableBuilder(
    column: $table.liveSlotMax,
    builder: (column) => column,
  );

  GeneratedColumn<int> get winCondition => $composableBuilder(
    column: $table.winCondition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stageAreaCount => $composableBuilder(
    column: $table.stageAreaCount,
    builder: (column) => column,
  );
}

class $$RuleConfigsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $RuleConfigsTable,
          RuleConfigRow,
          $$RuleConfigsTableFilterComposer,
          $$RuleConfigsTableOrderingComposer,
          $$RuleConfigsTableAnnotationComposer,
          $$RuleConfigsTableCreateCompanionBuilder,
          $$RuleConfigsTableUpdateCompanionBuilder,
          (
            RuleConfigRow,
            BaseReferences<_$LovecaDatabase, $RuleConfigsTable, RuleConfigRow>,
          ),
          RuleConfigRow,
          PrefetchHooks Function()
        > {
  $$RuleConfigsTableTableManager(_$LovecaDatabase db, $RuleConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RuleConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RuleConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RuleConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mainDeckSize = const Value.absent(),
                Value<int> memberCount = const Value.absent(),
                Value<int> liveCount = const Value.absent(),
                Value<int> energyDeckSize = const Value.absent(),
                Value<int> maxCopiesPerCardNumber = const Value.absent(),
                Value<int> initialHandSize = const Value.absent(),
                Value<int> initialEnergyOnField = const Value.absent(),
                Value<int> liveSlotMax = const Value.absent(),
                Value<int> winCondition = const Value.absent(),
                Value<int> stageAreaCount = const Value.absent(),
              }) => RuleConfigsCompanion(
                id: id,
                mainDeckSize: mainDeckSize,
                memberCount: memberCount,
                liveCount: liveCount,
                energyDeckSize: energyDeckSize,
                maxCopiesPerCardNumber: maxCopiesPerCardNumber,
                initialHandSize: initialHandSize,
                initialEnergyOnField: initialEnergyOnField,
                liveSlotMax: liveSlotMax,
                winCondition: winCondition,
                stageAreaCount: stageAreaCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mainDeckSize,
                required int memberCount,
                required int liveCount,
                required int energyDeckSize,
                required int maxCopiesPerCardNumber,
                required int initialHandSize,
                required int initialEnergyOnField,
                required int liveSlotMax,
                required int winCondition,
                required int stageAreaCount,
              }) => RuleConfigsCompanion.insert(
                id: id,
                mainDeckSize: mainDeckSize,
                memberCount: memberCount,
                liveCount: liveCount,
                energyDeckSize: energyDeckSize,
                maxCopiesPerCardNumber: maxCopiesPerCardNumber,
                initialHandSize: initialHandSize,
                initialEnergyOnField: initialEnergyOnField,
                liveSlotMax: liveSlotMax,
                winCondition: winCondition,
                stageAreaCount: stageAreaCount,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RuleConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $RuleConfigsTable,
      RuleConfigRow,
      $$RuleConfigsTableFilterComposer,
      $$RuleConfigsTableOrderingComposer,
      $$RuleConfigsTableAnnotationComposer,
      $$RuleConfigsTableCreateCompanionBuilder,
      $$RuleConfigsTableUpdateCompanionBuilder,
      (
        RuleConfigRow,
        BaseReferences<_$LovecaDatabase, $RuleConfigsTable, RuleConfigRow>,
      ),
      RuleConfigRow,
      PrefetchHooks Function()
    >;
typedef $$DecksTableCreateCompanionBuilder =
    DecksCompanion Function({
      required String deckId,
      required String name,
      Value<String> memo,
      Value<String?> coverPrintingId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> lastDeviceId,
      Value<int> masterDataVersion,
      Value<int> rowid,
    });
typedef $$DecksTableUpdateCompanionBuilder =
    DecksCompanion Function({
      Value<String> deckId,
      Value<String> name,
      Value<String> memo,
      Value<String?> coverPrintingId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> lastDeviceId,
      Value<int> masterDataVersion,
      Value<int> rowid,
    });

final class $$DecksTableReferences
    extends BaseReferences<_$LovecaDatabase, $DecksTable, DeckRow> {
  $$DecksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DeckTagsTable, List<DeckTagRow>>
  _deckTagsRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.deckTags,
    aliasName: 'decks__deck_id__deck_tags__deck_id',
  );

  $$DeckTagsTableProcessedTableManager get deckTagsRefs {
    final manager = $$DeckTagsTableTableManager($_db, $_db.deckTags).filter(
      (f) => f.deckId.deckId.sqlEquals($_itemColumn<String>('deck_id')!),
    );

    final cache = $_typedResult.readTableOrNull(_deckTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DeckEntriesTable, List<DeckEntryRow>>
  _deckEntriesRefsTable(_$LovecaDatabase db) => MultiTypedResultKey.fromTable(
    db.deckEntries,
    aliasName: 'decks__deck_id__deck_entries__deck_id',
  );

  $$DeckEntriesTableProcessedTableManager get deckEntriesRefs {
    final manager = $$DeckEntriesTableTableManager($_db, $_db.deckEntries)
        .filter(
          (f) => f.deckId.deckId.sqlEquals($_itemColumn<String>('deck_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_deckEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DecksTableFilterComposer
    extends Composer<_$LovecaDatabase, $DecksTable> {
  $$DecksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPrintingId => $composableBuilder(
    column: $table.coverPrintingId,
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

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get masterDataVersion => $composableBuilder(
    column: $table.masterDataVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> deckTagsRefs(
    Expression<bool> Function($$DeckTagsTableFilterComposer f) f,
  ) {
    final $$DeckTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.deckTags,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckTagsTableFilterComposer(
            $db: $db,
            $table: $db.deckTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> deckEntriesRefs(
    Expression<bool> Function($$DeckEntriesTableFilterComposer f) f,
  ) {
    final $$DeckEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.deckEntries,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckEntriesTableFilterComposer(
            $db: $db,
            $table: $db.deckEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableOrderingComposer
    extends Composer<_$LovecaDatabase, $DecksTable> {
  $$DecksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get memo => $composableBuilder(
    column: $table.memo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPrintingId => $composableBuilder(
    column: $table.coverPrintingId,
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

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get masterDataVersion => $composableBuilder(
    column: $table.masterDataVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecksTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $DecksTable> {
  $$DecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get memo =>
      $composableBuilder(column: $table.memo, builder: (column) => column);

  GeneratedColumn<String> get coverPrintingId => $composableBuilder(
    column: $table.coverPrintingId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get lastDeviceId => $composableBuilder(
    column: $table.lastDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get masterDataVersion => $composableBuilder(
    column: $table.masterDataVersion,
    builder: (column) => column,
  );

  Expression<T> deckTagsRefs<T extends Object>(
    Expression<T> Function($$DeckTagsTableAnnotationComposer a) f,
  ) {
    final $$DeckTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.deckTags,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.deckTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> deckEntriesRefs<T extends Object>(
    Expression<T> Function($$DeckEntriesTableAnnotationComposer a) f,
  ) {
    final $$DeckEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.deckEntries,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DeckEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.deckEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DecksTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $DecksTable,
          DeckRow,
          $$DecksTableFilterComposer,
          $$DecksTableOrderingComposer,
          $$DecksTableAnnotationComposer,
          $$DecksTableCreateCompanionBuilder,
          $$DecksTableUpdateCompanionBuilder,
          (DeckRow, $$DecksTableReferences),
          DeckRow,
          PrefetchHooks Function({bool deckTagsRefs, bool deckEntriesRefs})
        > {
  $$DecksTableTableManager(_$LovecaDatabase db, $DecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deckId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> memo = const Value.absent(),
                Value<String?> coverPrintingId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastDeviceId = const Value.absent(),
                Value<int> masterDataVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion(
                deckId: deckId,
                name: name,
                memo: memo,
                coverPrintingId: coverPrintingId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastDeviceId: lastDeviceId,
                masterDataVersion: masterDataVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deckId,
                required String name,
                Value<String> memo = const Value.absent(),
                Value<String?> coverPrintingId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> lastDeviceId = const Value.absent(),
                Value<int> masterDataVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DecksCompanion.insert(
                deckId: deckId,
                name: name,
                memo: memo,
                coverPrintingId: coverPrintingId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                lastDeviceId: lastDeviceId,
                masterDataVersion: masterDataVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DecksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({deckTagsRefs = false, deckEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (deckTagsRefs) db.deckTags,
                    if (deckEntriesRefs) db.deckEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (deckTagsRefs)
                        await $_getPrefetchedData<
                          DeckRow,
                          $DecksTable,
                          DeckTagRow
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._deckTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).deckTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deckId == item.deckId,
                              ),
                          typedResults: items,
                        ),
                      if (deckEntriesRefs)
                        await $_getPrefetchedData<
                          DeckRow,
                          $DecksTable,
                          DeckEntryRow
                        >(
                          currentTable: table,
                          referencedTable: $$DecksTableReferences
                              ._deckEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DecksTableReferences(
                                db,
                                table,
                                p0,
                              ).deckEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.deckId == item.deckId,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DecksTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $DecksTable,
      DeckRow,
      $$DecksTableFilterComposer,
      $$DecksTableOrderingComposer,
      $$DecksTableAnnotationComposer,
      $$DecksTableCreateCompanionBuilder,
      $$DecksTableUpdateCompanionBuilder,
      (DeckRow, $$DecksTableReferences),
      DeckRow,
      PrefetchHooks Function({bool deckTagsRefs, bool deckEntriesRefs})
    >;
typedef $$DeckTagsTableCreateCompanionBuilder =
    DeckTagsCompanion Function({
      required String deckId,
      required int ord,
      required String tag,
      Value<int> rowid,
    });
typedef $$DeckTagsTableUpdateCompanionBuilder =
    DeckTagsCompanion Function({
      Value<String> deckId,
      Value<int> ord,
      Value<String> tag,
      Value<int> rowid,
    });

final class $$DeckTagsTableReferences
    extends BaseReferences<_$LovecaDatabase, $DeckTagsTable, DeckTagRow> {
  $$DeckTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DecksTable _deckIdTable(_$LovecaDatabase db) =>
      db.decks.createAlias('deck_tags__deck_id__decks__deck_id');

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.deckId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckTagsTableFilterComposer
    extends Composer<_$LovecaDatabase, $DeckTagsTable> {
  $$DeckTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckTagsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $DeckTagsTable> {
  $$DeckTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckTagsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $DeckTagsTable> {
  $$DeckTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckTagsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $DeckTagsTable,
          DeckTagRow,
          $$DeckTagsTableFilterComposer,
          $$DeckTagsTableOrderingComposer,
          $$DeckTagsTableAnnotationComposer,
          $$DeckTagsTableCreateCompanionBuilder,
          $$DeckTagsTableUpdateCompanionBuilder,
          (DeckTagRow, $$DeckTagsTableReferences),
          DeckTagRow,
          PrefetchHooks Function({bool deckId})
        > {
  $$DeckTagsTableTableManager(_$LovecaDatabase db, $DeckTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deckId = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckTagsCompanion(
                deckId: deckId,
                ord: ord,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deckId,
                required int ord,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => DeckTagsCompanion.insert(
                deckId: deckId,
                ord: ord,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
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
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$DeckTagsTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$DeckTagsTableReferences
                                    ._deckIdTable(db)
                                    .deckId,
                              )
                              as T;
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

typedef $$DeckTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $DeckTagsTable,
      DeckTagRow,
      $$DeckTagsTableFilterComposer,
      $$DeckTagsTableOrderingComposer,
      $$DeckTagsTableAnnotationComposer,
      $$DeckTagsTableCreateCompanionBuilder,
      $$DeckTagsTableUpdateCompanionBuilder,
      (DeckTagRow, $$DeckTagsTableReferences),
      DeckTagRow,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$DeckEntriesTableCreateCompanionBuilder =
    DeckEntriesCompanion Function({
      required String deckId,
      required String printingId,
      required int count,
      Value<int> ord,
      Value<int> rowid,
    });
typedef $$DeckEntriesTableUpdateCompanionBuilder =
    DeckEntriesCompanion Function({
      Value<String> deckId,
      Value<String> printingId,
      Value<int> count,
      Value<int> ord,
      Value<int> rowid,
    });

final class $$DeckEntriesTableReferences
    extends BaseReferences<_$LovecaDatabase, $DeckEntriesTable, DeckEntryRow> {
  $$DeckEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DecksTable _deckIdTable(_$LovecaDatabase db) =>
      db.decks.createAlias('deck_entries__deck_id__decks__deck_id');

  $$DecksTableProcessedTableManager get deckId {
    final $_column = $_itemColumn<String>('deck_id')!;

    final manager = $$DecksTableTableManager(
      $_db,
      $_db.decks,
    ).filter((f) => f.deckId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deckIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DeckEntriesTableFilterComposer
    extends Composer<_$LovecaDatabase, $DeckEntriesTable> {
  $$DeckEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnFilters(column),
  );

  $$DecksTableFilterComposer get deckId {
    final $$DecksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableFilterComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckEntriesTableOrderingComposer
    extends Composer<_$LovecaDatabase, $DeckEntriesTable> {
  $$DeckEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ord => $composableBuilder(
    column: $table.ord,
    builder: (column) => ColumnOrderings(column),
  );

  $$DecksTableOrderingComposer get deckId {
    final $$DecksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableOrderingComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckEntriesTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $DeckEntriesTable> {
  $$DeckEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get printingId => $composableBuilder(
    column: $table.printingId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  $$DecksTableAnnotationComposer get deckId {
    final $$DecksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deckId,
      referencedTable: $db.decks,
      getReferencedColumn: (t) => t.deckId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DecksTableAnnotationComposer(
            $db: $db,
            $table: $db.decks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DeckEntriesTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $DeckEntriesTable,
          DeckEntryRow,
          $$DeckEntriesTableFilterComposer,
          $$DeckEntriesTableOrderingComposer,
          $$DeckEntriesTableAnnotationComposer,
          $$DeckEntriesTableCreateCompanionBuilder,
          $$DeckEntriesTableUpdateCompanionBuilder,
          (DeckEntryRow, $$DeckEntriesTableReferences),
          DeckEntryRow,
          PrefetchHooks Function({bool deckId})
        > {
  $$DeckEntriesTableTableManager(_$LovecaDatabase db, $DeckEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deckId = const Value.absent(),
                Value<String> printingId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckEntriesCompanion(
                deckId: deckId,
                printingId: printingId,
                count: count,
                ord: ord,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deckId,
                required String printingId,
                required int count,
                Value<int> ord = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckEntriesCompanion.insert(
                deckId: deckId,
                printingId: printingId,
                count: count,
                ord: ord,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DeckEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deckId = false}) {
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
                    if (deckId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deckId,
                                referencedTable: $$DeckEntriesTableReferences
                                    ._deckIdTable(db),
                                referencedColumn: $$DeckEntriesTableReferences
                                    ._deckIdTable(db)
                                    .deckId,
                              )
                              as T;
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

typedef $$DeckEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $DeckEntriesTable,
      DeckEntryRow,
      $$DeckEntriesTableFilterComposer,
      $$DeckEntriesTableOrderingComposer,
      $$DeckEntriesTableAnnotationComposer,
      $$DeckEntriesTableCreateCompanionBuilder,
      $$DeckEntriesTableUpdateCompanionBuilder,
      (DeckEntryRow, $$DeckEntriesTableReferences),
      DeckEntryRow,
      PrefetchHooks Function({bool deckId})
    >;
typedef $$DeckEditOpsTableCreateCompanionBuilder =
    DeckEditOpsCompanion Function({
      Value<int> id,
      required String deckId,
      required String kind,
      required DateTime at,
    });
typedef $$DeckEditOpsTableUpdateCompanionBuilder =
    DeckEditOpsCompanion Function({
      Value<int> id,
      Value<String> deckId,
      Value<String> kind,
      Value<DateTime> at,
    });

class $$DeckEditOpsTableFilterComposer
    extends Composer<_$LovecaDatabase, $DeckEditOpsTable> {
  $$DeckEditOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeckEditOpsTableOrderingComposer
    extends Composer<_$LovecaDatabase, $DeckEditOpsTable> {
  $$DeckEditOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeckEditOpsTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $DeckEditOpsTable> {
  $$DeckEditOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);
}

class $$DeckEditOpsTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $DeckEditOpsTable,
          DeckEditOpRow,
          $$DeckEditOpsTableFilterComposer,
          $$DeckEditOpsTableOrderingComposer,
          $$DeckEditOpsTableAnnotationComposer,
          $$DeckEditOpsTableCreateCompanionBuilder,
          $$DeckEditOpsTableUpdateCompanionBuilder,
          (
            DeckEditOpRow,
            BaseReferences<_$LovecaDatabase, $DeckEditOpsTable, DeckEditOpRow>,
          ),
          DeckEditOpRow,
          PrefetchHooks Function()
        > {
  $$DeckEditOpsTableTableManager(_$LovecaDatabase db, $DeckEditOpsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckEditOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckEditOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckEditOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deckId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
              }) => DeckEditOpsCompanion(
                id: id,
                deckId: deckId,
                kind: kind,
                at: at,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deckId,
                required String kind,
                required DateTime at,
              }) => DeckEditOpsCompanion.insert(
                id: id,
                deckId: deckId,
                kind: kind,
                at: at,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeckEditOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $DeckEditOpsTable,
      DeckEditOpRow,
      $$DeckEditOpsTableFilterComposer,
      $$DeckEditOpsTableOrderingComposer,
      $$DeckEditOpsTableAnnotationComposer,
      $$DeckEditOpsTableCreateCompanionBuilder,
      $$DeckEditOpsTableUpdateCompanionBuilder,
      (
        DeckEditOpRow,
        BaseReferences<_$LovecaDatabase, $DeckEditOpsTable, DeckEditOpRow>,
      ),
      DeckEditOpRow,
      PrefetchHooks Function()
    >;
typedef $$DeckSyncMarksTableCreateCompanionBuilder =
    DeckSyncMarksCompanion Function({
      required String deckId,
      required int logMark,
      required String baselineHash,
      Value<int> rowid,
    });
typedef $$DeckSyncMarksTableUpdateCompanionBuilder =
    DeckSyncMarksCompanion Function({
      Value<String> deckId,
      Value<int> logMark,
      Value<String> baselineHash,
      Value<int> rowid,
    });

class $$DeckSyncMarksTableFilterComposer
    extends Composer<_$LovecaDatabase, $DeckSyncMarksTable> {
  $$DeckSyncMarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get logMark => $composableBuilder(
    column: $table.logMark,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baselineHash => $composableBuilder(
    column: $table.baselineHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeckSyncMarksTableOrderingComposer
    extends Composer<_$LovecaDatabase, $DeckSyncMarksTable> {
  $$DeckSyncMarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deckId => $composableBuilder(
    column: $table.deckId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get logMark => $composableBuilder(
    column: $table.logMark,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baselineHash => $composableBuilder(
    column: $table.baselineHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeckSyncMarksTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $DeckSyncMarksTable> {
  $$DeckSyncMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deckId =>
      $composableBuilder(column: $table.deckId, builder: (column) => column);

  GeneratedColumn<int> get logMark =>
      $composableBuilder(column: $table.logMark, builder: (column) => column);

  GeneratedColumn<String> get baselineHash => $composableBuilder(
    column: $table.baselineHash,
    builder: (column) => column,
  );
}

class $$DeckSyncMarksTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $DeckSyncMarksTable,
          DeckSyncMarkRow,
          $$DeckSyncMarksTableFilterComposer,
          $$DeckSyncMarksTableOrderingComposer,
          $$DeckSyncMarksTableAnnotationComposer,
          $$DeckSyncMarksTableCreateCompanionBuilder,
          $$DeckSyncMarksTableUpdateCompanionBuilder,
          (
            DeckSyncMarkRow,
            BaseReferences<
              _$LovecaDatabase,
              $DeckSyncMarksTable,
              DeckSyncMarkRow
            >,
          ),
          DeckSyncMarkRow,
          PrefetchHooks Function()
        > {
  $$DeckSyncMarksTableTableManager(
    _$LovecaDatabase db,
    $DeckSyncMarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeckSyncMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeckSyncMarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeckSyncMarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deckId = const Value.absent(),
                Value<int> logMark = const Value.absent(),
                Value<String> baselineHash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeckSyncMarksCompanion(
                deckId: deckId,
                logMark: logMark,
                baselineHash: baselineHash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deckId,
                required int logMark,
                required String baselineHash,
                Value<int> rowid = const Value.absent(),
              }) => DeckSyncMarksCompanion.insert(
                deckId: deckId,
                logMark: logMark,
                baselineHash: baselineHash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeckSyncMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $DeckSyncMarksTable,
      DeckSyncMarkRow,
      $$DeckSyncMarksTableFilterComposer,
      $$DeckSyncMarksTableOrderingComposer,
      $$DeckSyncMarksTableAnnotationComposer,
      $$DeckSyncMarksTableCreateCompanionBuilder,
      $$DeckSyncMarksTableUpdateCompanionBuilder,
      (
        DeckSyncMarkRow,
        BaseReferences<_$LovecaDatabase, $DeckSyncMarksTable, DeckSyncMarkRow>,
      ),
      DeckSyncMarkRow,
      PrefetchHooks Function()
    >;
typedef $$MasterStatesTableCreateCompanionBuilder =
    MasterStatesCompanion Function({
      Value<int> id,
      Value<int> dataVersion,
      Value<String> minAppVersion,
      Value<String> manifestHash,
    });
typedef $$MasterStatesTableUpdateCompanionBuilder =
    MasterStatesCompanion Function({
      Value<int> id,
      Value<int> dataVersion,
      Value<String> minAppVersion,
      Value<String> manifestHash,
    });

class $$MasterStatesTableFilterComposer
    extends Composer<_$LovecaDatabase, $MasterStatesTable> {
  $$MasterStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestHash => $composableBuilder(
    column: $table.manifestHash,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MasterStatesTableOrderingComposer
    extends Composer<_$LovecaDatabase, $MasterStatesTable> {
  $$MasterStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestHash => $composableBuilder(
    column: $table.manifestHash,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MasterStatesTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $MasterStatesTable> {
  $$MasterStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dataVersion => $composableBuilder(
    column: $table.dataVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get minAppVersion => $composableBuilder(
    column: $table.minAppVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestHash => $composableBuilder(
    column: $table.manifestHash,
    builder: (column) => column,
  );
}

class $$MasterStatesTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $MasterStatesTable,
          MasterStateRow,
          $$MasterStatesTableFilterComposer,
          $$MasterStatesTableOrderingComposer,
          $$MasterStatesTableAnnotationComposer,
          $$MasterStatesTableCreateCompanionBuilder,
          $$MasterStatesTableUpdateCompanionBuilder,
          (
            MasterStateRow,
            BaseReferences<
              _$LovecaDatabase,
              $MasterStatesTable,
              MasterStateRow
            >,
          ),
          MasterStateRow,
          PrefetchHooks Function()
        > {
  $$MasterStatesTableTableManager(_$LovecaDatabase db, $MasterStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasterStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MasterStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MasterStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dataVersion = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
                Value<String> manifestHash = const Value.absent(),
              }) => MasterStatesCompanion(
                id: id,
                dataVersion: dataVersion,
                minAppVersion: minAppVersion,
                manifestHash: manifestHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dataVersion = const Value.absent(),
                Value<String> minAppVersion = const Value.absent(),
                Value<String> manifestHash = const Value.absent(),
              }) => MasterStatesCompanion.insert(
                id: id,
                dataVersion: dataVersion,
                minAppVersion: minAppVersion,
                manifestHash: manifestHash,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MasterStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $MasterStatesTable,
      MasterStateRow,
      $$MasterStatesTableFilterComposer,
      $$MasterStatesTableOrderingComposer,
      $$MasterStatesTableAnnotationComposer,
      $$MasterStatesTableCreateCompanionBuilder,
      $$MasterStatesTableUpdateCompanionBuilder,
      (
        MasterStateRow,
        BaseReferences<_$LovecaDatabase, $MasterStatesTable, MasterStateRow>,
      ),
      MasterStateRow,
      PrefetchHooks Function()
    >;
typedef $$MasterFilesTableCreateCompanionBuilder =
    MasterFilesCompanion Function({
      required String path,
      required String hash,
      Value<int> bytes,
      Value<int> cardCount,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$MasterFilesTableUpdateCompanionBuilder =
    MasterFilesCompanion Function({
      Value<String> path,
      Value<String> hash,
      Value<int> bytes,
      Value<int> cardCount,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

class $$MasterFilesTableFilterComposer
    extends Composer<_$LovecaDatabase, $MasterFilesTable> {
  $$MasterFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MasterFilesTableOrderingComposer
    extends Composer<_$LovecaDatabase, $MasterFilesTable> {
  $$MasterFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cardCount => $composableBuilder(
    column: $table.cardCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MasterFilesTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $MasterFilesTable> {
  $$MasterFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<int> get cardCount =>
      $composableBuilder(column: $table.cardCount, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$MasterFilesTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $MasterFilesTable,
          MasterFileRow,
          $$MasterFilesTableFilterComposer,
          $$MasterFilesTableOrderingComposer,
          $$MasterFilesTableAnnotationComposer,
          $$MasterFilesTableCreateCompanionBuilder,
          $$MasterFilesTableUpdateCompanionBuilder,
          (
            MasterFileRow,
            BaseReferences<_$LovecaDatabase, $MasterFilesTable, MasterFileRow>,
          ),
          MasterFileRow,
          PrefetchHooks Function()
        > {
  $$MasterFilesTableTableManager(_$LovecaDatabase db, $MasterFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MasterFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MasterFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MasterFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<int> cardCount = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MasterFilesCompanion(
                path: path,
                hash: hash,
                bytes: bytes,
                cardCount: cardCount,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String hash,
                Value<int> bytes = const Value.absent(),
                Value<int> cardCount = const Value.absent(),
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => MasterFilesCompanion.insert(
                path: path,
                hash: hash,
                bytes: bytes,
                cardCount: cardCount,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MasterFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $MasterFilesTable,
      MasterFileRow,
      $$MasterFilesTableFilterComposer,
      $$MasterFilesTableOrderingComposer,
      $$MasterFilesTableAnnotationComposer,
      $$MasterFilesTableCreateCompanionBuilder,
      $$MasterFilesTableUpdateCompanionBuilder,
      (
        MasterFileRow,
        BaseReferences<_$LovecaDatabase, $MasterFilesTable, MasterFileRow>,
      ),
      MasterFileRow,
      PrefetchHooks Function()
    >;
typedef $$ImportIssuesTableCreateCompanionBuilder =
    ImportIssuesCompanion Function({
      required String path,
      required String hash,
      required ImportIssueKind kind,
      required String message,
      Value<int> occurrenceCount,
      required DateTime firstSeenAt,
      required DateTime lastSeenAt,
      Value<int> rowid,
    });
typedef $$ImportIssuesTableUpdateCompanionBuilder =
    ImportIssuesCompanion Function({
      Value<String> path,
      Value<String> hash,
      Value<ImportIssueKind> kind,
      Value<String> message,
      Value<int> occurrenceCount,
      Value<DateTime> firstSeenAt,
      Value<DateTime> lastSeenAt,
      Value<int> rowid,
    });

class $$ImportIssuesTableFilterComposer
    extends Composer<_$LovecaDatabase, $ImportIssuesTable> {
  $$ImportIssuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImportIssueKind, ImportIssueKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportIssuesTableOrderingComposer
    extends Composer<_$LovecaDatabase, $ImportIssuesTable> {
  $$ImportIssuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportIssuesTableAnnotationComposer
    extends Composer<_$LovecaDatabase, $ImportIssuesTable> {
  $$ImportIssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ImportIssueKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<int> get occurrenceCount => $composableBuilder(
    column: $table.occurrenceCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );
}

class $$ImportIssuesTableTableManager
    extends
        RootTableManager<
          _$LovecaDatabase,
          $ImportIssuesTable,
          ImportIssueRow,
          $$ImportIssuesTableFilterComposer,
          $$ImportIssuesTableOrderingComposer,
          $$ImportIssuesTableAnnotationComposer,
          $$ImportIssuesTableCreateCompanionBuilder,
          $$ImportIssuesTableUpdateCompanionBuilder,
          (
            ImportIssueRow,
            BaseReferences<
              _$LovecaDatabase,
              $ImportIssuesTable,
              ImportIssueRow
            >,
          ),
          ImportIssueRow,
          PrefetchHooks Function()
        > {
  $$ImportIssuesTableTableManager(_$LovecaDatabase db, $ImportIssuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportIssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportIssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportIssuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<ImportIssueKind> kind = const Value.absent(),
                Value<String> message = const Value.absent(),
                Value<int> occurrenceCount = const Value.absent(),
                Value<DateTime> firstSeenAt = const Value.absent(),
                Value<DateTime> lastSeenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportIssuesCompanion(
                path: path,
                hash: hash,
                kind: kind,
                message: message,
                occurrenceCount: occurrenceCount,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String hash,
                required ImportIssueKind kind,
                required String message,
                Value<int> occurrenceCount = const Value.absent(),
                required DateTime firstSeenAt,
                required DateTime lastSeenAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportIssuesCompanion.insert(
                path: path,
                hash: hash,
                kind: kind,
                message: message,
                occurrenceCount: occurrenceCount,
                firstSeenAt: firstSeenAt,
                lastSeenAt: lastSeenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportIssuesTableProcessedTableManager =
    ProcessedTableManager<
      _$LovecaDatabase,
      $ImportIssuesTable,
      ImportIssueRow,
      $$ImportIssuesTableFilterComposer,
      $$ImportIssuesTableOrderingComposer,
      $$ImportIssuesTableAnnotationComposer,
      $$ImportIssuesTableCreateCompanionBuilder,
      $$ImportIssuesTableUpdateCompanionBuilder,
      (
        ImportIssueRow,
        BaseReferences<_$LovecaDatabase, $ImportIssuesTable, ImportIssueRow>,
      ),
      ImportIssueRow,
      PrefetchHooks Function()
    >;

class $LovecaDatabaseManager {
  final _$LovecaDatabase _db;
  $LovecaDatabaseManager(this._db);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CardNamesTableTableManager get cardNames =>
      $$CardNamesTableTableManager(_db, _db.cardNames);
  $$CardKeywordsTableTableManager get cardKeywords =>
      $$CardKeywordsTableTableManager(_db, _db.cardKeywords);
  $$CardHeartsTableTableManager get cardHearts =>
      $$CardHeartsTableTableManager(_db, _db.cardHearts);
  $$CardBladeHeartEffectsTableTableManager get cardBladeHeartEffects =>
      $$CardBladeHeartEffectsTableTableManager(_db, _db.cardBladeHeartEffects);
  $$PrintingsTableTableManager get printings =>
      $$PrintingsTableTableManager(_db, _db.printings);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$FaqsTableTableManager get faqs => $$FaqsTableTableManager(_db, _db.faqs);
  $$FaqPrintingsTableTableManager get faqPrintings =>
      $$FaqPrintingsTableTableManager(_db, _db.faqPrintings);
  $$RuleConfigsTableTableManager get ruleConfigs =>
      $$RuleConfigsTableTableManager(_db, _db.ruleConfigs);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db, _db.decks);
  $$DeckTagsTableTableManager get deckTags =>
      $$DeckTagsTableTableManager(_db, _db.deckTags);
  $$DeckEntriesTableTableManager get deckEntries =>
      $$DeckEntriesTableTableManager(_db, _db.deckEntries);
  $$DeckEditOpsTableTableManager get deckEditOps =>
      $$DeckEditOpsTableTableManager(_db, _db.deckEditOps);
  $$DeckSyncMarksTableTableManager get deckSyncMarks =>
      $$DeckSyncMarksTableTableManager(_db, _db.deckSyncMarks);
  $$MasterStatesTableTableManager get masterStates =>
      $$MasterStatesTableTableManager(_db, _db.masterStates);
  $$MasterFilesTableTableManager get masterFiles =>
      $$MasterFilesTableTableManager(_db, _db.masterFiles);
  $$ImportIssuesTableTableManager get importIssues =>
      $$ImportIssuesTableTableManager(_db, _db.importIssues);
}
