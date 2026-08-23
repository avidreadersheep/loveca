/// カードマスタの読み書き.
///
/// `loveca_core` の `Card` / `Printing` と DB の行を相互変換する。
/// ★エンティティ側の定義には手を入れない★
/// このパッケージは `loveca_core` の型をそのまま運ぶ器に徹する。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../schema/database.dart';
import '../schema/enums.dart';
import '../search/card_search_dao.dart';
import '../search/fold.dart';

class CardDao {
  const CardDao(this.db);

  final LovecaDatabase db;

  // -------------------------------------------------------------------------
  // 書き込み
  // -------------------------------------------------------------------------

  /// 商品ファイル 1 件分を置き換える。
  ///
  /// ★検索索引の更新も同じトランザクションで行う★
  /// 別トランザクションにすると、途中で失敗したときに本体と索引がずれる。
  ///
  /// ★`printings` は expansion 単位で削除してから入れ直す★
  /// 配信ファイル `cards/{EXPANSION}.json` の `printings` はその商品の刷りが全てなので、
  /// 削除→挿入で「配信側から消えた刷り」も正しく反映される。
  ///
  /// ★`cards` は削除しない。upsert する★
  /// 実データでは **102 の cardNumber が複数の商品ファイルに現れる**
  /// （BP01 の通常刷りとプロモの再録など）。`cards` の行は特定の商品の所有物ではない。
  /// expansion 単位で消すと、他の商品から参照されている行を巻き添えで消してしまう。
  /// 内容は全ファイルで完全一致することを実測で確認済みなので upsert で矛盾しない。
  Future<void> replaceExpansion(CardSet set) async {
    await db.transaction(() async {
      await _writeExpansion(set);
      await CardSearchDao(db).reindex(set.cards);
    });
  }

  Future<void> _writeExpansion(CardSet set) async {
    final cardNumbers = set.cards.map((c) => c.cardNumber).toList();

    await db.batch((batch) {
      // この商品の刷りを入れ替える。
      batch.deleteWhere(db.printings, (p) => p.expansion.equals(set.expansion));

      // このファイルが持つカードの子行を作り直す。
      batch.deleteWhere(db.cardNames, (t) => t.cardNumber.isIn(cardNumbers));
      batch.deleteWhere(db.cardKeywords, (t) => t.cardNumber.isIn(cardNumbers));
      batch.deleteWhere(db.cardHearts, (t) => t.cardNumber.isIn(cardNumbers));
      batch.deleteWhere(
        db.cardBladeHeartEffects,
        (t) => t.cardNumber.isIn(cardNumbers),
      );

      batch.insertAllOnConflictUpdate(
        db.cards,
        set.cards.map(_toCardRow).toList(),
      );
      batch.insertAllOnConflictUpdate(
        db.printings,
        set.printings.map(_toPrintingRow).toList(),
      );

      for (final card in set.cards) {
        batch.insertAll(db.cardNames, _nameRows(card));
        batch.insertAll(db.cardKeywords, _keywordRows(card));
        batch.insertAll(db.cardHearts, _heartRows(card));
        batch.insertAll(db.cardBladeHeartEffects, _effectRows(card));
      }
    });
  }

  /// 配信側から消えた商品を取り除く。
  ///
  /// `cards` は他の商品から参照されうるので消さない
  /// （どこからも参照されなくなった行は [deleteOrphanCards] で掃除する）。
  Future<void> deleteExpansion(String expansion) async {
    await (db.delete(db.printings)
          ..where((p) => p.expansion.equals(expansion)))
        .go();
  }

  /// 刷りが 1 件も残っていないカードを消す。検索索引からも同時に落とす。
  Future<int> deleteOrphanCards() => db.transaction(() async {
        final rows = await db
            .customSelect('SELECT card_number FROM cards WHERE card_number '
                'NOT IN (SELECT card_number FROM printings)')
            .get();
        final numbers = rows.map((r) => r.read<String>('card_number')).toList();
        if (numbers.isEmpty) return 0;

        await CardSearchDao(db).removeFromIndex(numbers);
        return (db.delete(db.cards)..where((c) => c.cardNumber.isIn(numbers)))
            .go();
      });

  // -------------------------------------------------------------------------
  // 読み出し
  // -------------------------------------------------------------------------

  /// cardNumber -> Card。`DeckValidator` に渡す形。
  Future<Map<String, Card>> cardsByNumber() async {
    final rows = await db.select(db.cards).get();
    if (rows.isEmpty) return const {};

    final names = <String, List<CardNameRow>>{};
    for (final r in await db.select(db.cardNames).get()) {
      (names[r.cardNumber] ??= []).add(r);
    }
    final keywords = <String, List<CardKeywordRow>>{};
    for (final r in await db.select(db.cardKeywords).get()) {
      (keywords[r.cardNumber] ??= []).add(r);
    }
    final hearts = <String, List<CardHeartRow>>{};
    for (final r in await db.select(db.cardHearts).get()) {
      (hearts[r.cardNumber] ??= []).add(r);
    }
    final effects = <String, List<CardBladeHeartEffectRow>>{};
    for (final r in await db.select(db.cardBladeHeartEffects).get()) {
      (effects[r.cardNumber] ??= []).add(r);
    }

    return {
      for (final row in rows)
        row.cardNumber: _assemble(
          row,
          names[row.cardNumber] ?? const [],
          keywords[row.cardNumber] ?? const [],
          hearts[row.cardNumber] ?? const [],
          effects[row.cardNumber] ?? const [],
        ),
    };
  }

  Future<Card?> cardByNumber(String cardNumber) async {
    final row = await (db.select(db.cards)
          ..where((c) => c.cardNumber.equals(cardNumber)))
        .getSingleOrNull();
    if (row == null) return null;

    return _assemble(
      row,
      await (db.select(db.cardNames)
            ..where((t) => t.cardNumber.equals(cardNumber)))
          .get(),
      await (db.select(db.cardKeywords)
            ..where((t) => t.cardNumber.equals(cardNumber)))
          .get(),
      await (db.select(db.cardHearts)
            ..where((t) => t.cardNumber.equals(cardNumber)))
          .get(),
      await (db.select(db.cardBladeHeartEffects)
            ..where((t) => t.cardNumber.equals(cardNumber)))
          .get(),
    );
  }

  /// printingId -> Printing。`DeckValidator` に渡す形。
  Future<Map<String, Printing>> printingsById() async {
    final rows = await db.select(db.printings).get();
    return {for (final r in rows) r.printingId: _toPrinting(r)};
  }

  /// ある cardNumber の刷りを全部返す。
  ///
  /// ★非パラレル刷りが複数返りうる★
  /// パラレル表示 OFF は `isParallel == false` の刷りを「すべて」表示する
  /// （CLAUDE.md §5-(4)）。実データで 19 の cardNumber が該当する。
  Future<List<Printing>> printingsOfCard(String cardNumber) async {
    final rows = await (db.select(db.printings)
          ..where((p) => p.cardNumber.equals(cardNumber))
          ..orderBy([(p) => OrderingTerm(expression: p.printingId)]))
        .get();
    return rows.map(_toPrinting).toList();
  }

  Future<int> cardCount() async {
    final count = db.cards.cardNumber.count();
    final row = await (db.selectOnly(db.cards)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // -------------------------------------------------------------------------
  // 変換
  // -------------------------------------------------------------------------

  static Card _assemble(
    CardRow row,
    List<CardNameRow> names,
    List<CardKeywordRow> keywords,
    List<CardHeartRow> hearts,
    List<CardBladeHeartEffectRow> effects,
  ) {
    List<String> namesOf(CardNameKind kind) => (names
            .where((n) => n.kind == kind)
            .toList()
          ..sort((a, b) => a.ord.compareTo(b.ord)))
        .map((n) => n.value)
        .toList();

    Map<HeartColor, int> heartsOf(HeartKind kind) => {
          for (final h in hearts.where((h) => h.kind == kind))
            h.color: h.count,
        };

    return Card(
      cardNumber: row.cardNumber,
      name: row.name,
      cardType: row.cardType,
      characterNames: namesOf(CardNameKind.character),
      groupNames: namesOf(CardNameKind.group),
      unitNames: namesOf(CardNameKind.unit),
      effectText: row.effectText,
      keywords: (keywords.toList()..sort((a, b) => a.ord.compareTo(b.ord)))
          .map((k) => k.keyword)
          .toList(),
      cost: row.cost,
      bladeCount: row.bladeCount,
      score: row.score,
      hearts: heartsOf(HeartKind.hearts),
      requiredHearts: heartsOf(HeartKind.requiredHearts),
      // ★色だけ。DRAW / SCORE はここに来ない（別テーブル・別 enum 型）。
      bladeHearts: heartsOf(HeartKind.bladeHearts),
      bladeHeartEffects: {for (final e in effects) e.effect: e.count},
      heartTotal: row.heartTotal,
      requiredHeartTotal: row.requiredHeartTotal,
      stats: row.stats,
      isDeleted: row.isDeleted,
    );
  }

  static Printing _toPrinting(PrintingRow row) => Printing(
        printingId: row.printingId,
        cardNumber: row.cardNumber,
        expansion: row.expansion,
        rarity: row.rarity,
        isParallel: row.isParallel,
        illustrator: row.illustrator,
        imageHash: row.imageHash,
      );

  static CardsCompanion _toCardRow(Card card) => CardsCompanion.insert(
        cardNumber: card.cardNumber,
        name: card.name,
        cardType: card.cardType,
        effectText: Value(card.effectText),
        cost: Value(card.cost),
        bladeCount: Value(card.bladeCount),
        score: Value(card.score),
        heartTotal: Value(card.heartTotal),
        requiredHeartTotal: Value(card.requiredHeartTotal),
        stats: Value(card.stats),
        isDeleted: Value(card.isDeleted),
        searchBlob: Value(buildSearchBlob(card)),
      );

  static PrintingsCompanion _toPrintingRow(Printing p) =>
      PrintingsCompanion.insert(
        printingId: p.printingId,
        cardNumber: p.cardNumber,
        expansion: Value(p.expansion),
        rarity: Value(p.rarity),
        isParallel: Value(p.isParallel),
        illustrator: Value(p.illustrator),
        imageHash: Value(p.imageHash),
      );

  static List<CardNamesCompanion> _nameRows(Card card) => [
        for (final (i, v) in card.characterNames.indexed)
          CardNamesCompanion.insert(
            cardNumber: card.cardNumber,
            kind: CardNameKind.character,
            ord: i,
            value: v,
          ),
        for (final (i, v) in card.groupNames.indexed)
          CardNamesCompanion.insert(
            cardNumber: card.cardNumber,
            kind: CardNameKind.group,
            ord: i,
            value: v,
          ),
        for (final (i, v) in card.unitNames.indexed)
          CardNamesCompanion.insert(
            cardNumber: card.cardNumber,
            kind: CardNameKind.unit,
            ord: i,
            value: v,
          ),
      ];

  static List<CardKeywordsCompanion> _keywordRows(Card card) => [
        for (final (i, k) in card.keywords.indexed)
          CardKeywordsCompanion.insert(
            cardNumber: card.cardNumber,
            ord: i,
            keyword: k,
          ),
      ];

  /// ★色ハートだけをこのテーブルに入れる★
  /// `bladeHeartEffects` は別テーブル（[_effectRows]）へ行く。
  static List<CardHeartsCompanion> _heartRows(Card card) => [
        for (final entry in card.hearts.entries)
          CardHeartsCompanion.insert(
            cardNumber: card.cardNumber,
            kind: HeartKind.hearts,
            color: entry.key,
            count: entry.value,
          ),
        for (final entry in card.requiredHearts.entries)
          CardHeartsCompanion.insert(
            cardNumber: card.cardNumber,
            kind: HeartKind.requiredHearts,
            color: entry.key,
            count: entry.value,
          ),
        for (final entry in card.bladeHearts.entries)
          CardHeartsCompanion.insert(
            cardNumber: card.cardNumber,
            kind: HeartKind.bladeHearts,
            color: entry.key,
            count: entry.value,
          ),
      ];

  static List<CardBladeHeartEffectsCompanion> _effectRows(Card card) => [
        for (final entry in card.bladeHeartEffects.entries)
          CardBladeHeartEffectsCompanion.insert(
            cardNumber: card.cardNumber,
            effect: entry.key,
            count: entry.value,
          ),
      ];
}

/// 2 文字以下の検索語のための `LIKE` 対象テキスト。
///
/// trigram が引けない短い語はこの列を全走査する。
/// 実測で 1,708 行 / 約 1.6MB の走査が 2ms 未満。
String buildSearchBlob(Card card) => foldJoin([
      card.cardNumber,
      card.name,
      card.effectText,
      ...card.groupNames,
      ...card.unitNames,
    ]);
