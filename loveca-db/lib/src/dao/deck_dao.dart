/// デッキの読み書きと検証.
///
/// ★★ デッキ構築ルールをここに再実装しない ★★
/// 総合ルール 6.1 の判定は `loveca_core` の `DeckValidator` が唯一の実装である。
/// 決定 D28 の前提がこれで、別実装を作ると
/// 「スマホでは合法、PC では不正」という事故が起きる。
/// このクラスは DB から `cards` / `printings` / `RuleConfig` を集めて渡すだけ。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../schema/database.dart';
import '../schema/tables.dart';
import 'card_dao.dart';

/// ★DB 層は日時を UTC に正規化する★
///
/// drift は `DateTime` を unix 秒で保存し、**ローカル時刻**として読み戻す。
/// 瞬間としては同じだが `isUtc` が落ちるため、`Deck.toJson()` の
/// `toIso8601String()` が端末のタイムゾーンごとに別の文字列を吐く。
/// Phase 4 の同期は `updatedAt` を突き合わせるので、ここで揃えておかないと
/// 「同じデッキなのに端末ごとに違う値」が同期に流れ込む。
DateTime _utc(DateTime value) => value.toUtc();
DateTime? _utcOrNull(DateTime? value) => value?.toUtc();

/// デッキを総合ルール 6.1 の区分に分けたもの。
///
/// ★区分は `cards.card_type` から導出する。列には持たない（決定 D41）。
class DeckSections {
  const DeckSections({
    required this.members,
    required this.lives,
    required this.energies,
    required this.unknown,
  });

  /// 6.1.1.1: メインデッキのメンバーカード（48 枚ちょうど）。
  final List<DeckEntry> members;

  /// 6.1.1.1: メインデッキのライブカード（12 枚ちょうど）。
  final List<DeckEntry> lives;

  /// 6.1.1.3: エネルギーデッキ（12 枚ちょうど）。
  /// ★4 枚制限は適用されない。同じカードを 12 枚入れられる。
  final List<DeckEntry> energies;

  /// ★カードマスタに存在しない printingId（決定 D35）。
  /// **黙って削除しない。** 検出して読み取り専用で示すためにここへ集める。
  final List<DeckEntry> unknown;

  /// メインデッキ = メンバー + ライブ。4 枚制限が効くのはこちらだけ（6.1.1.2）。
  List<DeckEntry> get main => [...members, ...lives];

  int _sum(List<DeckEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.count);

  int get memberCount => _sum(members);
  int get liveCount => _sum(lives);
  int get energyCount => _sum(energies);
  int get unknownCount => _sum(unknown);

  bool get hasUnknownCards => unknown.isNotEmpty;
}

class DeckDao {
  const DeckDao(this.db);

  final LovecaDatabase db;

  // -------------------------------------------------------------------------
  // 書き込み
  // -------------------------------------------------------------------------

  Future<void> save(Deck deck) => db.transaction(() async {
        await db.into(db.decks).insertOnConflictUpdate(
              DecksCompanion.insert(
                deckId: deck.deckId,
                name: deck.name,
                memo: Value(deck.memo),
                coverPrintingId: Value(deck.coverPrintingId),
                createdAt: _utc(deck.createdAt),
                updatedAt: _utc(deck.updatedAt),
                deletedAt: Value(_utcOrNull(deck.deletedAt)),
                revision: Value(deck.revision),
                lastDeviceId: Value(deck.lastDeviceId),
                masterDataVersion: Value(deck.masterDataVersion),
              ),
            );

        await (db.delete(db.deckTags)
              ..where((t) => t.deckId.equals(deck.deckId)))
            .go();
        await (db.delete(db.deckEntries)
              ..where((t) => t.deckId.equals(deck.deckId)))
            .go();

        await db.batch((batch) {
          batch.insertAll(db.deckTags, [
            for (final (i, tag) in deck.tags.indexed)
              DeckTagsCompanion.insert(
                deckId: deck.deckId,
                ord: i,
                tag: tag,
              ),
          ]);
          // ★★ 並び順は `deck.entries` の添字である（決定 D65 / D99）★★
          //   save は毎回「全削除 → 全挿入」なので、増分の保守が要らない。
          batch.insertAll(db.deckEntries, [
            for (final (i, entry) in deck.entries.indexed)
              DeckEntriesCompanion.insert(
                deckId: deck.deckId,
                printingId: entry.printingId,
                count: entry.count,
                ord: Value(i),
              ),
          ]);
        });
      });

  /// ★論理削除（決定 D102）。物理削除すると削除が同期で伝播しない。
  ///
  /// [at] は呼び出し側から渡す。`DateTime.now()` を層の内側で呼ばない。
  Future<void> softDelete(String deckId, DateTime at) async {
    await (db.update(db.decks)..where((d) => d.deckId.equals(deckId))).write(
      DecksCompanion(
        deletedAt: Value(_utc(at)),
        updatedAt: Value(_utc(at)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // 読み出し
  // -------------------------------------------------------------------------

  Future<Deck?> byId(String deckId) async {
    final row = await (db.select(db.decks)
          ..where((d) => d.deckId.equals(deckId)))
        .getSingleOrNull();
    if (row == null) return null;
    return _assemble(
      row,
      await (db.select(db.deckTags)
            ..where((t) => t.deckId.equals(deckId))
            ..orderBy([(t) => OrderingTerm(expression: t.ord)]))
          .get(),
      // ★並びは保存されている（決定 D65 / D99）。printing_id 昇順ではない。
      await (db.select(db.deckEntries)
            ..where((t) => t.deckId.equals(deckId))
            ..orderBy([(t) => OrderingTerm(expression: t.ord)]))
          .get(),
    );
  }

  /// 一覧。★既定では論理削除済みを除く。
  Future<List<Deck>> all({bool includeDeleted = false}) async {
    final query = db.select(db.decks)
      ..orderBy([
        (d) => OrderingTerm(expression: d.updatedAt, mode: OrderingMode.desc),
      ]);
    if (!includeDeleted) query.where((d) => d.deletedAt.isNull());

    final rows = await query.get();
    if (rows.isEmpty) return const [];

    final ids = rows.map((r) => r.deckId).toList();
    final tags = <String, List<DeckTagRow>>{};
    for (final t
        in await (db.select(db.deckTags)..where((t) => t.deckId.isIn(ids)))
            .get()) {
      (tags[t.deckId] ??= []).add(t);
    }
    // ★★ `byId` と同じ並びで返す（決定 D65 / `ルール整合性チェック_v1.06.md` D-11）★★
    //   ここに ORDER BY が無かったため、**同じデッキでも取得経路で並びが違った。**
    //   deck_id ごとに束ねるので、並べ替えの単位は (deck_id, ord) である。
    final entries = <String, List<DeckEntryRow>>{};
    for (final e in await (db.select(db.deckEntries)
          ..where((t) => t.deckId.isIn(ids))
          ..orderBy([
            (t) => OrderingTerm(expression: t.deckId),
            (t) => OrderingTerm(expression: t.ord),
          ]))
        .get()) {
      (entries[e.deckId] ??= []).add(e);
    }

    return [
      for (final row in rows)
        _assemble(
          row,
          tags[row.deckId] ?? const [],
          entries[row.deckId] ?? const [],
        ),
    ];
  }

  // -------------------------------------------------------------------------
  // 移行（schemaVersion 2 -> 3）
  // -------------------------------------------------------------------------

  /// `ord` 列の backfill（決定 D65 / **D99**）.
  ///
  /// ★★ 基準は「移行の前後で見た目が変わらないこと」である ★★
  /// D65 はそのために `printing_id` 昇順を凍結すると書いていた。
  /// **D99 で基準は目的として維持し、凍結する値だけ規則順へ差し替えた。**
  /// 旧値のまま backfill すると、**既存デッキだけ永久に旧順で残り、
  /// 新規デッキだけコスト降順**になる——同じアプリの中で規則が 2 つになる。
  ///
  /// ★★ SQL ではなく Dart で書く（決定 D99）★★
  /// 規則順は区分と `cost` / `score` を見るので、SQL で書くと規則が
  /// 「Dart の比較器」と「移行の SQL」の**2 箇所**に載る。
  /// **UI と同じ比較器**（`loveca_core` の `sortedByDeckOrder`）を呼ぶ。
  ///
  /// ★★ マスタが空でも落ちない ★★
  /// `cards` / `printings` が空なら全件が「マスタに無い刷り」になり
  /// （決定 D35）、段 3 の `printingId` 昇順だけが効く。
  /// **これは移行前の並びと同じ**なので、その端末では見た目が変わらない。
  ///
  /// ★★ この経路は `revision` を上げない ★★
  /// `save` を通らないので意図どおりだが、端末間で並びがずれる経路が
  /// 1 本できる（`ルール整合性チェック_v1.06.md` **D-26**）。Phase 4 で見ること。
  Future<void> backfillOrd() async {
    final rows = await db.select(db.deckEntries).get();
    if (rows.isEmpty) return;

    final printings = await CardDao(db).printingsById();
    final cards = await CardDao(db).cardsByNumber();
    DeckOrderKey keyOf(String printingId) {
      final printing = printings[printingId];
      final card = printing == null ? null : cards[printing.cardNumber];
      if (card == null) return DeckOrderKey.unknown;
      return DeckOrderKey(
        cardType: card.cardType,
        cost: card.cost,
        score: card.score,
      );
    }

    final byDeck = <String, List<DeckEntryRow>>{};
    for (final row in rows) {
      (byDeck[row.deckId] ??= []).add(row);
    }

    await db.transaction(() async {
      for (final entry in byDeck.entries) {
        final sorted = sortedByDeckOrder(
          [
            for (final r in entry.value)
              DeckEntry(printingId: r.printingId, count: r.count),
          ],
          keyOf,
        );
        for (final (i, e) in sorted.indexed) {
          await (db.update(db.deckEntries)
                ..where((t) =>
                    t.deckId.equals(entry.key) &
                    t.printingId.equals(e.printingId)))
              .write(DeckEntriesCompanion(ord: Value(i)));
        }
      }
    });
  }

  // -------------------------------------------------------------------------
  // 区分と検証
  // -------------------------------------------------------------------------

  /// メインデッキとエネルギーデッキに分ける（決定 D41）。
  ///
  /// 区分は `cards.card_type` から導出する。DB に区分列を持たないので、
  /// `DeckValidator` の判定と食い違う経路が構造的に存在しない。
  Future<DeckSections> sections(Deck deck) async {
    final printings = await CardDao(db).printingsById();
    final cards = await CardDao(db).cardsByNumber();

    final members = <DeckEntry>[];
    final lives = <DeckEntry>[];
    final energies = <DeckEntry>[];
    final unknown = <DeckEntry>[];

    for (final entry in deck.entries) {
      final printing = printings[entry.printingId];
      final card = printing == null ? null : cards[printing.cardNumber];
      switch (card?.cardType) {
        case CardType.member:
          members.add(entry);
        case CardType.live:
          lives.add(entry);
        case CardType.energy:
          energies.add(entry);
        case null:
          // ★決定 D35: 黙って捨てない。呼び出し側に見せる。
          unknown.add(entry);
      }
    }

    return DeckSections(
      members: members,
      lives: lives,
      energies: energies,
      unknown: unknown,
    );
  }

  /// 総合ルール 6.1 の検証。
  ///
  /// ★判定そのものは `loveca_core` の `DeckValidator` が行う★
  /// ここは DB から材料を集めて渡すだけ。SQL 側に枚数制限を書かない。
  Future<DeckValidationResult> validate(Deck deck) async {
    final dao = CardDao(db);
    final validator = DeckValidator(
      cards: await dao.cardsByNumber(),
      printings: await dao.printingsById(),
      config: await ruleConfig(),
    );
    return validator.validate(deck);
  }

  /// 追加可能かの事前判定（UI で「+」を無効化するため）。
  Future<bool> canAdd(Deck deck, String printingId) async {
    final dao = CardDao(db);
    final validator = DeckValidator(
      cards: await dao.cardsByNumber(),
      printings: await dao.printingsById(),
      config: await ruleConfig(),
    );
    return validator.canAdd(deck, printingId);
  }

  /// 配信された構築条件。未取得なら `RuleConfig.standard`。
  ///
  /// ★定数にしない★
  /// 6.1.2 により構築条件を置換するカードが存在しうる。
  Future<RuleConfig> ruleConfig() async {
    final row = await (db.select(db.ruleConfigs)
          ..where((r) => r.id.equals(singletonRowId)))
        .getSingleOrNull();
    if (row == null) return RuleConfig.standard;
    return RuleConfig(
      mainDeckSize: row.mainDeckSize,
      memberCount: row.memberCount,
      liveCount: row.liveCount,
      energyDeckSize: row.energyDeckSize,
      maxCopiesPerCardNumber: row.maxCopiesPerCardNumber,
      initialHandSize: row.initialHandSize,
      initialEnergyOnField: row.initialEnergyOnField,
      liveSlotMax: row.liveSlotMax,
      winCondition: row.winCondition,
      stageAreaCount: row.stageAreaCount,
    );
  }

  static Deck _assemble(
    DeckRow row,
    List<DeckTagRow> tags,
    List<DeckEntryRow> entries,
  ) =>
      Deck(
        deckId: row.deckId,
        name: row.name,
        entries: [
          for (final e in entries)
            DeckEntry(printingId: e.printingId, count: e.count),
        ],
        memo: row.memo,
        tags: (tags.toList()..sort((a, b) => a.ord.compareTo(b.ord)))
            .map((t) => t.tag)
            .toList(),
        coverPrintingId: row.coverPrintingId,
        createdAt: _utc(row.createdAt),
        updatedAt: _utc(row.updatedAt),
        deletedAt: _utcOrNull(row.deletedAt),
        revision: row.revision,
        lastDeviceId: row.lastDeviceId,
        masterDataVersion: row.masterDataVersion,
      );
}
