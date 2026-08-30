/// デッキの読み書き（M2 の目的そのもの / `docs/UI設計メモ.md` §2-4）.
///
/// ★★ M1 が通したのは「読み」だけだった ★★
/// M2 で確認するのは**書きが層を通ること**であり、確認できたと言える条件は
/// 「保存 → 開き直す → 残っている」の 1 つだけである。
///
/// ★実 DB を使う。ここをフェイクにすると、確かめたい往復そのものが消える。
/// 本番と同じ `openAppDatabase()`（`NativeDatabase.createInBackground` /
/// 決定 D45）で開く。テストだけ別経路にすると、D45 が本経路で成立することが
/// テストからは検証されない状態になる。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/repository_exception.dart';
import 'package:path/path.dart' as p;

/// ★固定時刻。`Clock` から供給されていることを確かめるために使う
/// （`DateTime.now()` を踏んでいたらこの値と一致しない / 設計メモ §9-1）。
final _t0 = DateTime.utc(2026, 8, 24, 12, 0, 0);

/// 最小のカタログ。★`DeckValidator` の材料であって DB とは無関係
/// （決定 D55: 検証は DB へ行かない）。
MasterCatalog _catalog() => MasterCatalog(
      cards: const {
        // ★★ cost / score は「規則順 ≠ printingId 昇順」になるように選んである ★★
        //   M-1 のほうが printingId は小さいが cost は**小さい**ので、
        //   規則順（cost 降順 / 決定 D99）では **M-2 が先**に来る。
        //   値をそろえると、比較器が何もしなくてもテストが通ってしまう。
        'M-1': Card(
            cardNumber: 'M-1', name: 'メンバー1', cardType: CardType.member, cost: 2),
        'M-2': Card(
            cardNumber: 'M-2', name: 'メンバー2', cardType: CardType.member, cost: 9),
        'L-1': Card(
            cardNumber: 'L-1', name: 'ライブ1', cardType: CardType.live, score: 5),
        'E-1':
            Card(cardNumber: 'E-1', name: 'エネルギー1', cardType: CardType.energy),
      },
      printings: const {
        'M-1-N': Printing(
          printingId: 'M-1-N',
          cardNumber: 'M-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        'L-1-N': Printing(
          printingId: 'L-1-N',
          cardNumber: 'L-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        'M-2-N': Printing(
          printingId: 'M-2-N',
          cardNumber: 'M-2',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
        'E-1-N': Printing(
          printingId: 'E-1-N',
          cardNumber: 'E-1',
          expansion: 'bp1',
          rarity: 'N',
          isParallel: false,
        ),
      },
      config: RuleConfig.standard,
      rows: const [],
      dataVersion: 7,
    );

void main() {
  late Directory tmp;
  late File dbFile;
  late LovecaDatabase db;
  final opened = <LovecaDatabase>[];

  Future<LovecaDatabase> open() async {
    final handle = await openAppDatabase(dbFile);
    opened.add(handle);
    return handle;
  }

  DeckRepository repositoryOn(
    LovecaDatabase handle, {
    DateTime? now,
    String deckId = 'fixed-deck-id',
  }) =>
      DeckRepository(
        handle,
        catalog: _catalog(),
        clock: () => now ?? _t0,
        newDeckId: () => deckId,
      );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_deck_repo_test');
    dbFile = File(p.join(tmp.path, 'loveca.db'));
    opened.clear();
    db = await open();
  });

  tearDown(() async {
    for (final handle in opened) {
      // すでに閉じているものがあるので握る（後始末であって検査ではない）。
      try {
        await handle.close();
      } on Object catch (_) {}
    }
    // ★Windows は開いたままだと消せない。閉じてから消す。
    tmp.deleteSync(recursive: true);
  });

  group('★★ 保存 → 開き直す → 残っている（M2 の目的）★★', () {
    test('デッキの中身が 1 バイトも欠けずに戻る', () async {
      final created = await repositoryOn(db).create(name: 'はじめてのデッキ');

      // 中身を入れて保存する。★entries は printingId 単位（決定 D11）。
      final withEntries = Deck(
        deckId: created.deckId,
        name: created.name,
        entries: const [
          DeckEntry(printingId: 'M-1-N', count: 4),
          DeckEntry(printingId: 'L-1-N', count: 2),
        ],
        memo: 'メモ',
        tags: const ['青', 'テスト'],
        coverPrintingId: 'M-1-N',
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
        revision: created.revision,
        masterDataVersion: created.masterDataVersion,
      );
      await repositoryOn(db).save(
        withEntries,
        DeckDraft(
          name: '改名後',
          memo: '書き換えたメモ',
          // ★entries は必須。名前だけ変えたつもりで中身を消す経路を作らない。
          entries: withEntries.entries,
          // ★メタもドラフトが持つ（M6 / 決定 D70）。渡さなければ消える。
          tags: withEntries.tags,
          coverPrintingId: withEntries.coverPrintingId,
        ),
        ops: const [],
      );

      // ★★ ここで本当に閉じる。プロセス内のキャッシュではなく DB を見る ★★
      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      expect(restored, isNotNull);
      expect(restored!.deckId, created.deckId);
      expect(restored.name, '改名後');
      expect(restored.memo, '書き換えたメモ');
      expect(restored.coverPrintingId, 'M-1-N');
      expect(restored.tags, ['青', 'テスト']);
      expect(restored.entries, hasLength(2));
      expect(
        {for (final e in restored.entries) e.printingId: e.count},
        {'M-1-N': 4, 'L-1-N': 2},
      );
      expect(restored.createdAt, _t0);
      expect(restored.updatedAt, _t0);
      expect(restored.revision, 1);
      // ★決定 D35: 作成時のカードマスタ版が残る（決定 D35 の未知カード検出に使う）。
      expect(restored.masterDataVersion, 7);
      expect(restored.isDeleted, isFalse);
    });

    test('一覧にも出る', () async {
      await repositoryOn(db, deckId: 'a').create(name: 'A');
      await repositoryOn(db, deckId: 'b').create(name: 'B');

      await db.close();
      final reopened = await open();

      final all = await repositoryOn(reopened).all();
      expect(all.map((d) => d.name).toSet(), {'A', 'B'});
    });
  });

  group('★ revision は保存回数で増える（編集操作の回数ではない）', () {
    test('ドラフトを何度変えても、保存 1 回で +1 しか増えない', () async {
      final deck = await repositoryOn(db).create(name: '初期名');
      expect(deck.revision, 0);

      // ★編集はドラフトの上だけで起きる（設計メモ §9-1）。
      //   Deck.copyWith を呼ばないので revision は動かない。
      var draft = DeckDraft.of(deck);
      draft = draft.copyWith(name: 'あ');
      draft = draft.copyWith(name: 'あい');
      draft = draft.copyWith(name: 'あいう');
      draft = draft.copyWith(memo: 'めも');

      final saved = await repositoryOn(db).save(deck, draft, ops: const []);

      // ★4 回編集して 1 回保存 → +1。
      //   跳ねると Phase 4 の同期で「大量に更新された」ように見える。
      expect(saved.revision, 1);
      expect(saved.name, 'あいう');

      final again =
          await repositoryOn(db)
              .save(saved, draft.copyWith(name: 'ん'), ops: const []);
      expect(again.revision, 2);

      // DB 側も同じ。
      final restored = await repositoryOn(db).byId(deck.deckId);
      expect(restored!.revision, 2);
    });
  });

  group('★ updatedAt は Clock から来る（DateTime.now() を踏んでいない）', () {
    test('create の createdAt / updatedAt が固定時刻ちょうど', () async {
      final deck = await repositoryOn(db).create(name: 'X');

      expect(deck.createdAt, _t0);
      expect(deck.updatedAt, _t0);
    });

    test('save の updatedAt が渡した時刻ちょうど（DB 再読込でも一致）', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final later = _t0.add(const Duration(days: 3));

      final saved = await repositoryOn(db, now: later)
          .save(deck, DeckDraft.of(deck).copyWith(name: 'Y'), ops: const []);

      // ★★ Deck.copyWith の既定値（DateTime.now()）を踏んでいたら一致しない ★★
      expect(saved.updatedAt, later);
      expect(saved.createdAt, _t0, reason: 'createdAt は動かない');

      final restored = await repositoryOn(db).byId(deck.deckId);
      expect(restored!.updatedAt, later);
    });
  });

  group('★ 論理削除は一覧から消え、DB には残る（決定 D102）', () {
    test('all から外れ、byId では取れる', () async {
      final deck = await repositoryOn(db).create(name: '消すデッキ');
      await repositoryOn(db, deckId: 'other').create(name: '残すデッキ');

      final deletedAt = _t0.add(const Duration(hours: 5));
      await repositoryOn(db, now: deletedAt).softDelete(deck.deckId);

      expect(
        (await repositoryOn(db).all()).map((d) => d.name),
        ['残すデッキ'],
      );

      // ★★ 物理削除していないこと。削除が同期で伝播するために要る ★★
      final still = await repositoryOn(db).byId(deck.deckId);
      expect(still, isNotNull);
      expect(still!.isDeleted, isTrue);
      expect(still.deletedAt, deletedAt);
    });

    test('★再起動しても復活しない（開き直しても一覧に出ない）', () async {
      final deck = await repositoryOn(db).create(name: '消すデッキ');
      await repositoryOn(db).softDelete(deck.deckId);

      await db.close();
      final reopened = await open();

      expect(await repositoryOn(reopened).all(), isEmpty);
      expect(await repositoryOn(reopened).byId(deck.deckId), isNotNull);
    });

    test('★revision は上がらない（D-9 として記録済み。挙動をここで固定する）', () async {
      // DeckDao.softDelete は deletedAt / updatedAt だけを書き revision に触れない。
      // 決定 D101「更新のたびに +1」と食い違うが、直す先は loveca_db 側であり
      // Phase 4 で判断する（ルール整合性チェック_v1.06.md D-9）。
      // ★食い違いを黙って抱えないよう、現状の挙動をテストで見える形にしておく。
      final deck = await repositoryOn(db).create(name: 'X');
      await repositoryOn(db).softDelete(deck.deckId);

      expect((await repositoryOn(db).byId(deck.deckId))!.revision, 0);
    });
  });

  group('★★ 検証は DB へ行かない（決定 D55）★★', () {
    test('DB を閉じたあとでも validate が答える', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      // ★★ これが D55 の機械的な証明である ★★
      // DeckDao.validate 経由なら cardsByNumber() を引き直すのでここで落ちる。
      await db.close();

      final result = repository.validate(deck);
      expect(result.isValid, isFalse);
      expect(result.memberCount, 0);
      expect(result.liveCount, 0);
      expect(result.energyCount, 0);
      // 総合ルール 6.1.1.1 / 6.1.1.3 の「ちょうど」に足りていない 3 件。
      expect(result.issues, hasLength(3));
    });

    test('canAdd も DB へ行かない', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      await db.close();

      expect(repository.canAdd(deck, 'M-1-N'), isTrue);
      expect(repository.canAdd(deck, '存在しない刷り'), isFalse);
    });
  });

  group('★ リポジトリは例外を握らない（決定 D53）', () {
    test('読めないとき空リストではなく RepositoryException が飛ぶ', () async {
      final repository = repositoryOn(db);
      await db.close();

      // ★★ 「空」と「失敗」を同じ型で表さない ★★
      // 空リストを返すと利用者は「デッキが 1 つも無い」と誤解する。
      await expectLater(
        repository.all(),
        throwsA(
          isA<RepositoryException>().having((e) => e.op, 'op', 'deck.all'),
        ),
      );
    });

    test('書けないときも同様', () async {
      final repository = repositoryOn(db);
      await db.close();

      await expectLater(
        repository.create(name: 'X'),
        throwsA(
          isA<RepositoryException>().having((e) => e.op, 'op', 'deck.create'),
        ),
      );
    });
  });

  group('★★ ドラフトの検証も DB へ行かない（決定 D55 / M4）★★', () {
    test('DB を閉じたあとでも validateDraft が答える', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      final draft = repository.draftOf(deck).addCopy('M-1-N').addCopy('M-1-N');

      // ★★ D55 の機械的な証明。DeckDao.validate 経由ならここで落ちる ★★
      await db.close();

      final result = repository.validateDraft(deck, draft);
      expect(result.memberCount, 2);
      expect(result.liveCount, 0);
    });

    test('canAddToDraft も DB へ行かない', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      final draft = repository.draftOf(deck);
      await db.close();

      expect(repository.canAddToDraft(deck, draft, 'M-1-N'), isTrue);
      expect(repository.canAddToDraft(deck, draft, '存在しない刷り'), isFalse);
    });

    test('★★ validateDraft を何度呼んでも revision / updatedAt が動かない ★★',
        () async {
      // ★検証は編集のたびに走る。copyWith を通すとその回数だけ revision が跳ね、
      //   保存もしていないのに Phase 4 の同期で「大量に更新された」ように見える。
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      var draft = repository.draftOf(deck);
      for (var i = 0; i < 20; i++) {
        draft = draft.addCopy('M-1-N');
        repository.validateDraft(deck, draft);
      }

      expect(deck.revision, 0);
      expect(deck.updatedAt, _t0);
      // DB 側も動いていない（保存していないのだから当然だが、そこを固定する）。
      final stored = await repositoryOn(db).byId(deck.deckId);
      expect(stored!.revision, 0);
      expect(stored.entries, isEmpty);
    });

    test('★4 枚制限はメインデッキだけ（6.1.1.2）——エネルギーには効かない', () async {
      final deck = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      var main = repository.draftOf(deck);
      var energy = repository.draftOf(deck);
      for (var i = 0; i < 4; i++) {
        main = main.addCopy('M-1-N');
        energy = energy.addCopy('E-1-N');
      }

      // ★出る側と出ない側を対で見る。
      expect(repository.canAddToDraft(deck, main, 'M-1-N'), isFalse);
      expect(repository.canAddToDraft(deck, energy, 'E-1-N'), isTrue);

      // エネルギーは 12 枚（6.1.1.3）で止まる。
      for (var i = 0; i < 8; i++) {
        energy = energy.addCopy('E-1-N');
      }
      expect(repository.canAddToDraft(deck, energy, 'E-1-N'), isFalse);
    });
  });

  group('★★ カードの増減が層を通る（M4）★★', () {
    test('ドラフトに入れたカードが DB を開き直しても戻る', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft = repository
          .draftOf(created)
          .addCopy('M-1-N')
          .addCopy('M-1-N')
          .addCopy('L-1-N');
      await repository.save(created, draft, ops: const []);

      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      expect(
        {for (final e in restored!.entries) e.printingId: e.count},
        {'M-1-N': 2, 'L-1-N': 1},
      );
      expect(restored.revision, 1, reason: '保存 1 回で +1');
    });

    test('★同じ刷りを 2 行にしない（deck_entries の主キーが {deckId, printingId}）',
        () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft =
          repository.draftOf(created).addCopy('M-1-N').addCopy('M-1-N');

      // ★行は 1 つ・枚数が 2。行を増やすと保存時に主キー衝突で落ちる。
      expect(draft.entries, hasLength(1));
      expect(draft.entries.single.count, 2);

      await repository.save(created, draft, ops: const []);
      expect((await repository.byId(created.deckId))!.entries, hasLength(1));
    });
  });

  group('★★ 並び順は保存される（決定 D99 / D65 の ord）★★', () {
    // ★★ 2026-08-27: この group は向きが逆になった（決定 D99）★★
    //   `deck_entries` に `ord` が入り、`byId` / `all` が `ORDER BY ord` で読む。
    //   ★元のテスト群は D65 の事実（保存されない）を固定していたもので、
    //     **誤っていたのではなく前提が変わった**。
    //
    // ★★ このカタログでは 規則順 ≠ printingId 昇順 である ★★
    //   M-1 は cost 2 / M-2 は cost 9 なので、規則順では **M-2 が先**。
    //   （`_catalog()` の doc を参照。値をそろえると比較器が no-op でも通る）
    test('★前提: 規則順と printingId 昇順が食い違う', () {
      final repository = repositoryOn(db);
      final sorted = repository.sortedByRule(const [
        DeckEntry(printingId: 'M-1-N', count: 1),
        DeckEntry(printingId: 'M-2-N', count: 1),
      ]);
      expect(sorted.map((e) => e.printingId), ['M-2-N', 'M-1-N'],
          reason: '★ここが一致していると、以下のテストは比較器が何もしなくても通る');
    });

    test('★★ 並べ替えて保存すると、開き直しても並びが残る ★★', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      var draft = repository.draftOf(created).addCopy('M-1-N').addCopy('M-2-N');
      draft = draft.moveEntry('M-1-N', 'M-2-N', after: true);
      // ★★ 保存する並びが規則順とも printingId 昇順とも違うこと ★★
      expect(draft.entries.map((e) => e.printingId), ['M-2-N', 'M-1-N']);

      await repository.save(created, draft, ops: const []);
      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      expect(restored!.entries.map((e) => e.printingId), ['M-2-N', 'M-1-N']);
    });

    test('★ 一覧（all）から来た Deck も同じ並び（D-11 の経路差）', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft = repository
          .draftOf(created)
          .addCopy('E-1-N')
          .addCopy('M-1-N')
          .addCopy('L-1-N');
      // ★★ 区分順ですらない並びで保存する ★★
      //   `all` に ORDER BY が無かった時代は、ここが取得経路で違っていた。
      expect(draft.entries.map((e) => e.printingId),
          ['E-1-N', 'M-1-N', 'L-1-N']);
      await repository.save(created, draft, ops: const []);
      await db.close();

      final reopened = await open();
      final repo2 = repositoryOn(reopened);
      final viaAll =
          (await repo2.all()).firstWhere((d) => d.deckId == created.deckId);
      final viaById = await repo2.byId(created.deckId);

      expect(viaAll.entries.map((e) => e.printingId),
          ['E-1-N', 'M-1-N', 'L-1-N']);
      expect(viaById!.entries.map((e) => e.printingId),
          ['E-1-N', 'M-1-N', 'L-1-N']);
    });

    test('★ 開いた直後は DB の並びをそのまま使う（正規化しない）', () async {
      // ★★ `normalizedEntries` を撤去した根拠（決定 D99）★★
      //   経路差は `DeckDao` 側で解消したので、画面で並べ直す理由が無い。
      //   並べ直すと、**利用者が保存した手動順が開くたびに消える。**
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      final saved = await repository.save(
        created,
        repository
            .draftOf(created)
            .addCopy('E-1-N')
            .addCopy('M-1-N'), // ★区分順でもない
        ops: const [],
      );

      expect(repository.draftOf(saved).entries.map((e) => e.printingId),
          ['E-1-N', 'M-1-N']);
    });

    test('★★ 並べ替えたら保存ボタンが光る（D65 の手当て 4 は前提が反転）★★', () async {
      // ★★ 保存されるようになったので、光らせないほうが誤りになった ★★
      //   D65 は「押せると『保存したのに戻る』という最悪の形になる」ので
      //   光らせなかった。いまは「並べ替えたのに保存できない」になる。
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final saved = await repository.save(
        created,
        repository.draftOf(created).addCopy('M-1-N').addCopy('M-2-N'),
        ops: const [],
      );

      final reordered = repository
          .draftOf(saved)
          .moveEntry(saved.entries.first.printingId,
              saved.entries.last.printingId, after: true);

      expect(reordered.entries.map((e) => e.printingId),
          isNot(equals(saved.entries.map((e) => e.printingId).toList())));
      expect(reordered.isDirtyAgainst(saved), isTrue);
    });

    test('★対: 並べ替えていなければ光らない（枚数も名前も同じ）', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      final saved = await repository.save(
        created,
        repository.draftOf(created).addCopy('M-1-N').addCopy('M-2-N'),
        ops: const [],
      );

      expect(repository.draftOf(saved).isDirtyAgainst(saved), isFalse);
    });

    test('★ 枚数だけ変えても光る（並びを見るようになっても壊れていない）', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);
      final saved = await repository.save(
        created,
        repository.draftOf(created).addCopy('M-1-N'),
        ops: const [],
      );

      final more = repository.draftOf(saved).addCopy('M-1-N');
      // ★並びは同じ（1 行のまま枚数が増えただけ）。
      expect(more.entries.map((e) => e.printingId),
          saved.entries.map((e) => e.printingId));
      expect(more.isDirtyAgainst(saved), isTrue);
    });

    group('★★ 規則順に戻す（決定 D99）★★', () {
      test('区分順 → メンバー cost 降順 / ライブ score 降順 → 未知は末尾', () async {
        final repository = repositoryOn(db);
        final sorted = repository.sortedByRule(const [
          DeckEntry(printingId: '知らない刷り', count: 1),
          DeckEntry(printingId: 'E-1-N', count: 1),
          DeckEntry(printingId: 'L-1-N', count: 1),
          DeckEntry(printingId: 'M-1-N', count: 1),
          DeckEntry(printingId: 'M-2-N', count: 1),
        ]);

        expect(
          sorted.map((e) => e.printingId),
          // ★M-2 は cost 9 / M-1 は cost 2。**printingId 昇順ではない。**
          ['M-2-N', 'M-1-N', 'L-1-N', 'E-1-N', '知らない刷り'],
        );
      });

      test('★ 未知の刷りも消えない（決定 D35）', () async {
        final repository = repositoryOn(db);
        final sorted = repository.sortedByRule(const [
          DeckEntry(printingId: '知らない刷り', count: 3),
          DeckEntry(printingId: 'M-1-N', count: 1),
        ]);
        expect(sorted, hasLength(2));
        expect(sorted.last.printingId, '知らない刷り');
        expect(sorted.last.count, 3);
      });
    });

  });

  group('★★ save が明示コンストラクタである代償の受け（決定 D70）★★', () {
    // ★★ copyWith は書かなかったフィールドを自動で引き継ぐが、
    //    コンストラクタは書き忘れると既定値になる。
    //    上の「1 バイトも欠けずに戻る」は**フィールドを手で列挙している**ので、
    //    Deck にフィールドが増えても落ちない。それでは受けにならない。★★
    test('★Deck のフィールドが増えたら落ちる（toJson のキーを凍結する）', () {
      final deck = Deck(
        deckId: 'x',
        name: 'n',
        createdAt: _t0,
        updatedAt: _t0,
      );

      expect(
        deck.toJson().keys.toSet(),
        {
          'deckId',
          'name',
          'entries',
          'memo',
          'tags',
          'coverPrintingId',
          'createdAt',
          'updatedAt',
          'deletedAt',
          'revision',
          'lastDeviceId',
          'masterDataVersion',
        },
        reason: '★DeckRepository.save は明示コンストラクタなので、'
            'Deck にフィールドが増えたら save にも足すこと（決定 D70）。'
            '★このテストは Deck.toJson 自体の更新漏れまでは捉えられない——'
            'そちらは loveca-core の JSON 往復テストが受けになる。',
      );
    });

    test('★★ 保存 → 開き直すと toJson が丸ごと一致する（手で列挙しない）★★',
        () async {
      final created = await repositoryOn(db).create(name: '元の名前');
      final base = Deck(
        deckId: created.deckId,
        name: created.name,
        entries: const [DeckEntry(printingId: 'M-1-N', count: 2)],
        memo: 'めも',
        tags: const ['a', 'b'],
        coverPrintingId: 'M-1-N',
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
        revision: created.revision,
        lastDeviceId: created.lastDeviceId,
        masterDataVersion: created.masterDataVersion,
      );

      final saved =
          await repositoryOn(db).save(base, DeckDraft.of(base), ops: const []);

      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      // ★1 フィールドでも書き漏らせばここで落ちる。列挙していないので腐らない。
      expect(restored!.toJson(), saved.toJson());
    });

    test('★カバーを外して保存すると null になる（copyWith では書けなかった）',
        () async {
      final created = await repositoryOn(db).create(name: 'カバーつき');
      final withCover = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(coverPrintingId: 'M-1-N'),
        ops: const [],
      );
      expect(withCover.coverPrintingId, 'M-1-N', reason: '前提');

      final cleared = await repositoryOn(db).save(
        withCover,
        DeckDraft.of(withCover).copyWith(clearCover: true),
        ops: const [],
      );

      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      expect(cleared.coverPrintingId, isNull);
      expect(restored!.coverPrintingId, isNull, reason: 'DB からも消えている');
    });

    test('★clearCover を渡さなければ残る（上の対）', () async {
      final created = await repositoryOn(db).create(name: 'カバーつき');
      final withCover = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(coverPrintingId: 'M-1-N'),
        ops: const [],
      );

      final renamed = await repositoryOn(db).save(
        withCover,
        DeckDraft.of(withCover).copyWith(name: '別の名前'),
        ops: const [],
      );

      expect(renamed.coverPrintingId, 'M-1-N',
          reason: '「外せる」だけを見ると、常に外す実装でも通ってしまう');
    });

    test('★タグは往復し、空リストで消せる', () async {
      final created = await repositoryOn(db).create(name: 'タグ');
      final tagged = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(tags: const ['青', '青赤']),
        ops: const [],
      );
      expect(tagged.tags, ['青', '青赤']);

      final cleared = await repositoryOn(db).save(
        tagged,
        DeckDraft.of(tagged).copyWith(tags: const []),
        ops: const [],
      );

      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);
      expect(cleared.tags, isEmpty);
      expect(restored!.tags, isEmpty);
    });

    test('★メタを変えても revision は保存 1 回につき +1 のまま', () async {
      final created = await repositoryOn(db).create(name: 'r');
      expect(created.revision, 0);

      final a = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(memo: 'm', tags: const ['t']),
        ops: const [],
      );
      expect(a.revision, 1);

      final b = await repositoryOn(db).save(
        a,
        DeckDraft.of(a).copyWith(coverPrintingId: 'M-1-N'),
        ops: const [],
      );
      expect(b.revision, 2);
      expect(b.createdAt, created.createdAt, reason: 'createdAt は動かない');
    });

    test('★メタの編集はドラフトの上で起きるので保存前は dirty になる', () async {
      final created = await repositoryOn(db).create(name: 'd');
      final draft = DeckDraft.of(created);

      expect(draft.isDirtyAgainst(created), isFalse, reason: '前提');
      expect(draft.copyWith(tags: const ['x']).isDirtyAgainst(created), isTrue);
      expect(
        draft.copyWith(coverPrintingId: 'M-1-N').isDirtyAgainst(created),
        isTrue,
      );
    });
  });

  group('★★ 複製（決定 D71 / M6）★★', () {
    test('★★ 刷りの違いが保たれる（共有形式では潰れる）★★', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      final source = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(
          entries: const [
            DeckEntry(printingId: 'M-1-N', count: 2),
            DeckEntry(printingId: 'M-1-P', count: 1),
          ],
        ),
        ops: const [],
      );

      final copy = await repositoryOn(db, deckId: 'dup')
          .duplicate(source, name: '元 のコピー');

      // ★同じ cardNumber の別の刷りが別々のまま残ること。
      //   共有形式（Map<cardNumber, 枚数>）ではここが 1 行に潰れる。
      expect(
        {for (final e in copy.entries) e.printingId: e.count},
        {'M-1-N': 2, 'M-1-P': 1},
      );
    });

    test('★deckId は新しく、revision は 0、時刻は Clock から', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      final source = await repositoryOn(db)
          .save(created, DeckDraft.of(created), ops: const []);
      expect(source.revision, 1, reason: '前提: 元は 1 回保存してある');

      final copy = await repositoryOn(db, deckId: 'dup')
          .duplicate(source, name: 'コピー');

      expect(copy.deckId, 'dup');
      expect(copy.deckId, isNot(source.deckId));
      expect(copy.revision, 0, reason: '新しく作ったデッキ。create と揃える');
      expect(copy.createdAt, _t0);
      expect(copy.updatedAt, _t0);
      expect(copy.deletedAt, isNull);
    });

    test('★★ masterDataVersion（決定 D35）は元の値を引き継ぐ ★★', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      expect(created.masterDataVersion, 7, reason: '前提: 作成時の版');

      final copy = await repositoryOn(db, deckId: 'dup')
          .duplicate(created, name: 'コピー');

      // ★現在版を打つと、元デッキが持つ未知の刷りが
      //   「今の版で作ったのに未知」という説明不能な状態になる。
      expect(copy.masterDataVersion, 7);
    });

    test('★★ 未知の刷りもそのまま写す（決定 D35）★★', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      final source = await repositoryOn(db).save(
        created,
        DeckDraft.of(created).copyWith(
          entries: const [
            DeckEntry(printingId: 'M-1-N', count: 1),
            // ★カタログに無い刷り。落とすと、元を消したときに消える。
            DeckEntry(printingId: 'UNKNOWN-1', count: 3),
          ],
        ),
        ops: const [],
      );

      final copy = await repositoryOn(db, deckId: 'dup')
          .duplicate(source, name: 'コピー');

      expect(
        copy.entries.map((e) => e.printingId),
        containsAll(<String>['M-1-N', 'UNKNOWN-1']),
      );
    });

    test('メタも写る', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      final source = await repositoryOn(db).save(
        created,
        DeckDraft.of(created)
            .copyWith(memo: 'めも', tags: const ['青'], coverPrintingId: 'M-1-N'),
        ops: const [],
      );

      final copy = await repositoryOn(db, deckId: 'dup')
          .duplicate(source, name: 'コピー');

      expect(copy.memo, 'めも');
      expect(copy.tags, ['青']);
      expect(copy.coverPrintingId, 'M-1-N');
    });

    test('複製は DB に残り、開き直しても両方ある', () async {
      final created = await repositoryOn(db, deckId: 'src').create(name: '元');
      await repositoryOn(db, deckId: 'dup')
          .duplicate(created, name: '元 のコピー');

      await db.close();
      final reopened = await open();
      final all = await repositoryOn(reopened).all();

      expect(all.map((d) => d.name), containsAll(<String>['元', '元 のコピー']));
    });
  });
}
