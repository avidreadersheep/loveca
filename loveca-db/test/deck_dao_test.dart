/// デッキの保存・区分・検証の検証.
library;

import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// テストは時刻を固定する。`loveca_core` は `DateTime.now()` を持ち込まない方針。
final _t0 = DateTime.utc(2026, 8, 23, 12);

void main() {
  late LovecaDatabase db;
  late CardDao cards;
  late DeckDao decks;

  setUp(() async {
    db = LovecaDatabase(openInMemoryExecutor());
    cards = CardDao(db);
    decks = DeckDao(db);
    for (final expansion in fixtureExpansions) {
      await cards.replaceExpansion(loadCardSet(expansion));
    }
  });
  tearDown(() => db.close());

  /// 種別ごとの cardNumber を（刷りを 1 つ選んで）返す。
  Future<Map<CardType, List<({String cardNumber, String printingId})>>>
      byType() async {
    final all = await cards.cardsByNumber();
    final printings = await cards.printingsById();
    final out = {
      for (final t in CardType.values)
        t: <({String cardNumber, String printingId})>[],
    };
    for (final number in all.keys.toList()..sort()) {
      final p = printings.values
          .where((p) => p.cardNumber == number && !p.isParallel)
          .toList()
        ..sort((a, b) => a.printingId.compareTo(b.printingId));
      if (p.isEmpty) continue;
      out[all[number]!.cardType]!
          .add((cardNumber: number, printingId: p.first.printingId));
    }
    return out;
  }

  Deck deckOf(List<DeckEntry> entries, {String id = 'deck-1'}) => Deck(
        deckId: id,
        name: 'テストデッキ',
        entries: entries,
        createdAt: _t0,
        updatedAt: _t0,
      );

  group('保存と取得', () {
    test('デッキが値として往復する', () async {
      final deck = Deck(
        deckId: 'a3f1c2d4-0000-4000-8000-000000000001',
        name: 'μ\'s 型',
        entries: const [
          DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4),
          DeckEntry(printingId: 'PL!HS-bp1-012-PR', count: 2),
        ],
        memo: 'メモ',
        tags: const ['大会用', '調整中'],
        coverPrintingId: 'PL!HS-bp1-012-N',
        createdAt: _t0,
        updatedAt: _t0.add(const Duration(hours: 1)),
        revision: 7,
        lastDeviceId: 'pc-1',
        masterDataVersion: 2,
      );
      await decks.save(deck, ops: const []);

      final restored = (await decks.byId(deck.deckId))!;
      expect(restored.name, deck.name);
      expect(restored.memo, deck.memo);
      expect(restored.tags, deck.tags);
      expect(restored.coverPrintingId, deck.coverPrintingId);
      expect(restored.createdAt, deck.createdAt);
      expect(restored.updatedAt, deck.updatedAt);
      expect(restored.revision, 7);
      expect(restored.lastDeviceId, 'pc-1');
      expect(restored.masterDataVersion, 2);
      expect(restored.totalCount, 6);
      expect(
        restored.entries.map((e) => (e.printingId, e.count)).toSet(),
        deck.entries.map((e) => (e.printingId, e.count)).toSet(),
      );
    });

    test('保存し直すと中身が入れ替わる', () async {
      await decks.save(
        deckOf(const [
          DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4),
        ]),
        ops: const [],
      );
      await decks.save(
        deckOf(const [
          DeckEntry(printingId: 'PL!HS-bp1-012-PR', count: 1),
        ]),
        ops: const [],
      );
      final restored = (await decks.byId('deck-1'))!;
      expect(restored.entries, hasLength(1));
      expect(restored.entries.single.printingId, 'PL!HS-bp1-012-PR');
    });

    // ★決定 D102: 物理削除すると削除が同期で伝播しない。
    test('論理削除は一覧から外れるが行は残る', () async {
      await decks.save(deckOf(const []), ops: const []);
      await decks.softDelete('deck-1', _t0.add(const Duration(days: 1)));

      expect(await decks.all(), isEmpty);
      final withDeleted = await decks.all(includeDeleted: true);
      expect(withDeleted, hasLength(1));
      expect(withDeleted.single.isDeleted, isTrue);
      expect(withDeleted.single.deletedAt, isNotNull);
    });
  });

  // =========================================================================
  // ★★ 削除の記録点（決定 D110-3 ＝ 穴 (c) の C-iv）★★
  // =========================================================================

  group('★★ 削除は編集ログに 1 件残る（決定 D110-3 / 穴 (c)）★★', () {
    // ★読み出しの API は作らない（`docs/同期設計メモ.md` §17-9-7 のコミット 3 は
    //   「書くだけ」）。**検査のためだけ**にここで表を直に引く。
    Future<List<DeckEditOpRow>> logRows() => (db.select(db.deckEditOps)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();

    /// 中身のある 1 本。★空にしないのは、下の「対」で [DeckDao.backfillOrd]
    /// （＝**移行の経路**）を実際に走らせるためである —— 空だと `rows.isEmpty` で
    /// 即 return し、**通していないのに通したことになる**。
    Deck one({String id = 'deck-1'}) => deckOf(
          const [DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4)],
          id: id,
        );

    test('★ 削除が 1 件残る（deck_id / kind / at の 3 つが揃う）', () async {
      await decks.save(one(), ops: const []);
      final at = _t0.add(const Duration(days: 1));

      await decks.softDelete('deck-1', at);

      final rows = await logRows();
      expect(rows, hasLength(1));
      expect(rows.single.deckId, 'deck-1');
      // ★キーは Dart の識別子ではない（決定 D110-1 がわざと違えた 1 件）。
      expect(rows.single.kind, DeckEditOpKind.deleteDeck.key);
      expect(rows.single.kind, 'softDelete');
      // ★時刻は呼び出し側から渡った値がそのまま入る（`DateTime.now()` ではない）。
      expect(rows.single.at.toUtc(), at);
    });

    test('★★ 対: 削除以外は 1 件も残さない ★★', () async {
      // ★★ 「削除が残る」だけを見ると、**何でも記録する実装**でも通る ★★
      //   このコミットが足した記録点は `softDelete` の 1 つだけである。
      //   ★書き込みの経路を 1 つずつ通し、★読み出しも一緒に通す。
      final deck = one();
      await decks.save(deck, ops: const []); // 新規保存
      await decks.save(one(id: 'deck-2'), ops: const []); // もう 1 本
      await decks.save(deck, ops: const []); // 上書き保存
      await decks.backfillOrd(); // ★移行の経路（決定 D65 / D99）
      await decks.byId('deck-1');
      await decks.all(includeDeleted: true);
      await decks.sections(deck);
      await decks.validate(deck);
      await decks.canAdd(deck, 'PL!HS-bp1-012-PR');

      expect(await logRows(), isEmpty);
    });

    test('★ 1 回の削除 = 1 件（2 本消せば deck_id ごとに 1 件ずつ）', () async {
      await decks.save(one(), ops: const []);
      await decks.save(one(id: 'deck-2'), ops: const []);

      await decks.softDelete('deck-1', _t0);
      await decks.softDelete('deck-2', _t0.add(const Duration(minutes: 1)));

      final rows = await logRows();
      expect(rows.map((r) => r.deckId), ['deck-1', 'deck-2']);
      expect(rows.map((r) => r.kind).toSet(), {DeckEditOpKind.deleteDeck.key});
    });

    test('★ 当たる行が無ければ記録しない（起きていない削除を残さない）', () async {
      await decks.save(one(), ops: const []);

      // ★存在しない deckId。UPDATE は 0 行だが**例外は出ない**（既存の挙動を変えない）。
      await decks.softDelete('deck-none', _t0);
      expect(await logRows(), isEmpty);

      // ★対: 在るデッキなら同じ呼び出しで 1 件残る
      //   —— 「そもそも書けていないから空」ではないことを見る（**D-10**）。
      await decks.softDelete('deck-1', _t0);
      expect(await logRows(), hasLength(1));
    });

    // -----------------------------------------------------------------------
    // ★★ 同時性（決定 D110-3 の後半 —— DAO の中で閉じる）★★
    // -----------------------------------------------------------------------

    /// 指定した表への書き込みを必ず失敗させる。
    ///
    /// ★後始末は要らない —— `setUp` が毎回インメモリの DB を開き直すので、
    /// トリガは DB ごと消える。
    Future<void> failWritesTo(String table, String event) => db.customStatement(
          'CREATE TRIGGER fail_$table BEFORE $event ON $table '
          "BEGIN SELECT RAISE(ABORT, '★仕込んだ失敗'); END",
        );

    test('★★ 同時性: UPDATE が失敗したらログも残らない ★★', () async {
      await decks.save(one(), ops: const []);
      await failWritesTo('decks', 'UPDATE');

      await expectLater(decks.softDelete('deck-1', _t0), throwsA(anything));

      expect(await logRows(), isEmpty);
      expect((await decks.byId('deck-1'))!.isDeleted, isFalse);
    });

    test('★★ 対: ログの INSERT が失敗したら削除も残らない ★★', () async {
      // ★★ ここが「包んだ」ことの証拠である ★★
      //   `db.transaction` で包まなければ UPDATE だけが commit され、
      //   **「行は消えたのにログが無い」**——まさに穴 (c) と同じ状態が作れる。
      //   ★上の 1 件だけでは足りない: 包まなくても「UPDATE が失敗すれば
      //     INSERT まで進まない」ので、あちらは**素通しでも通る**。
      await decks.save(one(), ops: const []);
      await failWritesTo('deck_edit_ops', 'INSERT');

      await expectLater(decks.softDelete('deck-1', _t0), throwsA(anything));

      expect(await logRows(), isEmpty);
      expect((await decks.byId('deck-1'))!.isDeleted, isFalse);
      expect(await decks.all(), hasLength(1), reason: '★一覧からも消えていないこと');
    });

    // -----------------------------------------------------------------------
    // ★ D102 との関係（`docs/同期設計メモ.md` §15-7-7 (1)）
    // -----------------------------------------------------------------------

    test('★★ D102 の行と D110 のログが、同じ 1 回の削除で両方揃う ★★', () async {
      // ★★ このテストが固定できる範囲を先に書く ★★
      //   §15-7-7 (1) の衝突は「**D102** が物理削除を禁じてまで確保した削除の伝播が、
      //   検出層（＝ログ / **D110-1**）の側で失われる」ことである。
      //   ★★**「衝突が消えた」こと自体はここでは固定できない**★★ ——
      //     検出層を**読む**コードがまだ 1 行も無い（同期の送受信は
      //     §17-9-7 の 6 コミットのどれにも入っていない）。
      //   → ★**固定できるのは「衝突が消えるための前提」までである** ——
      //     すなわち **1 回の削除が 2 か所に同時に残ること**。
      await decks.save(one(), ops: const []);

      await decks.softDelete('deck-1', _t0);

      // (a) **D102**: 行は物理削除されない。
      final still = await decks.byId('deck-1');
      expect(still, isNotNull);
      expect(still!.isDeleted, isTrue);

      // (b) **D110-1**: 検出層が見る側にも、同じ削除が在る。
      final rows = await logRows();
      expect(rows, hasLength(1));
      expect(rows.single.deckId, still.deckId);
      expect(rows.single.kind, DeckEditOpKind.deleteDeck.key);
    });
  });

  group('★★ save が操作列を受け取る（署名だけ / §17-9-7 の commit 4）★★', () {
    // ★★ この群が何を固定していて、何を固定していないか ★★
    //   固定している —— ★**空の列を渡してもログが 1 件も増えないこと。**
    //   ★★固定していない —— **「渡した列が無視されていないこと」**★★。
    //   このコミットは [DeckDao.save] の**中身を 1 行も書いていない**ので、
    //   `ops` は**証明可能に未読**であり、★**観測できる差が 1 つも無い。**
    //   → ★★**この群は commit 4 では判別力を持たない**★★ ——
    //     `ops` を丸ごと捨てる実装でも、★1 件も落ちずに通る（★実測した）。
    //     ★**判別力が付くのは commit 5（9 操作を貯めて渡す）からである**（**D-27**）。
    //   ★**推測で埋めない。**「無視されていない」と読める文をここに書かない。
    Future<int> logCount() async =>
        (await db.select(db.deckEditOps).get()).length;

    Deck one({String id = 'deck-1'}) => deckOf(
          const [DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4)],
          id: id,
        );

    test('★ 空の列を渡してもログは 1 件も増えない', () async {
      await decks.save(one(), ops: const []);
      await decks.save(one(), ops: const []); // ★上書き保存も同じ
      await decks.save(one(id: 'deck-2'), ops: const []);

      expect(await logCount(), 0);
    });

    test('★★ 対: 0 件が「見えていない」のではないこと（**D-10**）★★', () async {
      // ★★ 上の 0 件だけでは、**表を読めていない**場合と区別がつかない ★★
      //   ★同じ `logCount()` で 1 件を数えられることを見る。
      await decks.save(one(), ops: const []);
      expect(await logCount(), 0);

      await decks.softDelete('deck-1', _t0);
      expect(await logCount(), 1);
    });

    test('★ 保存の中身は 1 つも変わっていない（★挙動の差が無いことの受け）', () async {
      // ★★ commit 4 の契約そのもの ★★
      //   §17-9-7 は「4 の時点では挙動が 1 つも変わらないので、
      //   落ちるテストが在れば署名変更そのものの誤りである」と書いている。
      final deck = deckOf(const [
        DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4),
        DeckEntry(printingId: 'PL!HS-bp1-012-PR', count: 1),
      ]);
      await decks.save(deck, ops: const []);

      final restored = (await decks.byId('deck-1'))!;
      // ★並びも枚数も `revision` も、署名を変える前と同じである（決定 D65 / D99）。
      expect(restored.entries.map((e) => e.printingId),
          ['PL!HS-bp1-012-N', 'PL!HS-bp1-012-PR']);
      expect(restored.entries.map((e) => e.count), [4, 1]);
      expect(restored.revision, deck.revision);
      expect(restored.updatedAt, deck.updatedAt);
    });
  });

  group('★区分は cardType から導出する (決定 D41)', () {
    test('メンバー / ライブ / エネルギーに分かれる', () async {
      final t = await byType();
      final deck = deckOf([
        DeckEntry(printingId: t[CardType.member]!.first.printingId, count: 4),
        DeckEntry(printingId: t[CardType.live]!.first.printingId, count: 2),
        DeckEntry(printingId: t[CardType.energy]!.first.printingId, count: 12),
      ]);

      final sections = await decks.sections(deck);
      expect(sections.memberCount, 4);
      expect(sections.liveCount, 2);
      expect(sections.energyCount, 12);
      // メインデッキ = メンバー + ライブ（6.1.1.1）
      expect(sections.main, hasLength(2));
      expect(sections.hasUnknownCards, isFalse);
    });

    // ★決定 D35: 黙って削除しない。
    test('マスタに無い printingId は unknown に集まり、行も消えない', () async {
      final deck = deckOf(const [
        DeckEntry(printingId: 'NOT-A-REAL-PRINTING', count: 3),
      ]);
      await decks.save(deck, ops: const []);

      final sections = await decks.sections((await decks.byId('deck-1'))!);
      expect(sections.hasUnknownCards, isTrue);
      expect(sections.unknownCount, 3);
      expect(sections.members, isEmpty);

      // 保存された行が消えていないこと。
      expect((await decks.byId('deck-1'))!.entries, hasLength(1));
    });

    test('カードマスタを消してもデッキの行は残る', () async {
      final t = await byType();
      final printingId = t[CardType.member]!.first.printingId;
      await decks.save(
        deckOf([DeckEntry(printingId: printingId, count: 4)]),
        ops: const [],
      );

      for (final expansion in fixtureExpansions) {
        await cards.deleteExpansion(expansion);
      }
      await cards.deleteOrphanCards();

      // ★deck_entries を printings への外部キーにしていないので消えない。
      final restored = (await decks.byId('deck-1'))!;
      expect(restored.entries, hasLength(1));
      final sections = await decks.sections(restored);
      expect(sections.hasUnknownCards, isTrue);
    });
  });

  group('★4 枚制限はメインデッキのみ (6.1.1.2 / 6.1.1.3)', () {
    test('エネルギーは同一 cardNumber を 12 枚入れられる', () async {
      final t = await byType();
      final energy = t[CardType.energy]!.first;
      final members = t[CardType.member]!.take(12).toList();
      final lives = t[CardType.live]!.take(6).toList();

      final deck = deckOf([
        for (final m in members) DeckEntry(printingId: m.printingId, count: 4),
        for (final l in lives) DeckEntry(printingId: l.printingId, count: 2),
        DeckEntry(printingId: energy.printingId, count: 12),
      ]);

      final result = await decks.validate(deck);
      expect(result.memberCount, 48);
      expect(result.liveCount, 12);
      expect(result.energyCount, 12);
      // ★エネルギー 12 枚で tooManyCopies が出ないこと。
      expect(
        result.issues.where((i) => i.code == DeckIssueCode.tooManyCopies),
        isEmpty,
      );
      expect(result.isValid, isTrue);
    });

    test('メンバーの同一 cardNumber 5 枚は違反になる', () async {
      final t = await byType();
      final member = t[CardType.member]!.first;
      final deck = deckOf([DeckEntry(printingId: member.printingId, count: 5)]);

      final result = await decks.validate(deck);
      final tooMany = result.issues
          .where((i) => i.code == DeckIssueCode.tooManyCopies)
          .toList();
      expect(tooMany, hasLength(1));
      expect(tooMany.single.cardNumber, member.cardNumber);
      expect(tooMany.single.actual, 5);
    });

    // ★異なる刷り（パラレル違い）でも cardNumber が同じなら合算される。
    test('パラレル違いも合算して 4 枚制限にかかる', () async {
      final printings = await cards.printingsById();
      final variants = printings.values
          .where((p) => p.cardNumber == multiPrintingWithParallel)
          .toList()
        ..sort((a, b) => a.printingId.compareTo(b.printingId));
      expect(variants.length, greaterThanOrEqualTo(2));

      final legal = deckOf([
        DeckEntry(printingId: variants[0].printingId, count: 2),
        DeckEntry(printingId: variants[1].printingId, count: 2),
      ]);
      expect(
        (await decks.validate(legal))
            .issues
            .where((i) => i.code == DeckIssueCode.tooManyCopies),
        isEmpty,
      );

      final illegal = deckOf([
        DeckEntry(printingId: variants[0].printingId, count: 3),
        DeckEntry(printingId: variants[1].printingId, count: 2),
      ]);
      final issues = (await decks.validate(illegal))
          .issues
          .where((i) => i.code == DeckIssueCode.tooManyCopies)
          .toList();
      expect(issues, hasLength(1));
      expect(issues.single.actual, 5);
    });

    test('canAdd がエネルギーとメインで違う判定になる', () async {
      final t = await byType();
      final member = t[CardType.member]!.first;
      final energy = t[CardType.energy]!.first;

      final memberFull =
          deckOf([DeckEntry(printingId: member.printingId, count: 4)]);
      expect(await decks.canAdd(memberFull, member.printingId), isFalse);

      final energyFour =
          deckOf([DeckEntry(printingId: energy.printingId, count: 4)]);
      // ★エネルギーに 4 枚制限は無い。12 枚上限にだけかかる。
      expect(await decks.canAdd(energyFour, energy.printingId), isTrue);

      final energyFull =
          deckOf([DeckEntry(printingId: energy.printingId, count: 12)]);
      expect(await decks.canAdd(energyFull, energy.printingId), isFalse);
    });
  });

  group('構築条件', () {
    test('配信された ruleConfig を使う', () async {
      await db.into(db.ruleConfigs).insertOnConflictUpdate(
            RuleConfigsCompanion.insert(
              id: const Value(singletonRowId),
              mainDeckSize: 60,
              memberCount: 48,
              liveCount: 12,
              energyDeckSize: 12,
              maxCopiesPerCardNumber: 4,
              initialHandSize: 6,
              initialEnergyOnField: 3,
              liveSlotMax: 3,
              winCondition: 3,
              stageAreaCount: 3,
            ),
          );
      final config = await decks.ruleConfig();
      expect(config.memberCount, 48);
      expect(config.maxCopiesPerCardNumber, 4);
    });

    test('未取得なら標準値になる', () async {
      expect(
        (await decks.ruleConfig()).memberCount,
        RuleConfig.standard.memberCount,
      );
    });
  });
}
