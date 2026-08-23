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
        'M-1': Card(cardNumber: 'M-1', name: 'メンバー1', cardType: CardType.member),
        'L-1': Card(cardNumber: 'L-1', name: 'ライブ1', cardType: CardType.live),
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
        const DeckDraft(name: '改名後', memo: '書き換えたメモ'),
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
      // ★P5: 作成時のカードマスタ版が残る（決定 D35 の未知カード検出に使う）。
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

      final saved = await repositoryOn(db).save(deck, draft);

      // ★4 回編集して 1 回保存 → +1。
      //   跳ねると Phase 4 の同期で「大量に更新された」ように見える。
      expect(saved.revision, 1);
      expect(saved.name, 'あいう');

      final again =
          await repositoryOn(db).save(saved, draft.copyWith(name: 'ん'));
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
          .save(deck, const DeckDraft(name: 'Y', memo: ''));

      // ★★ Deck.copyWith の既定値（DateTime.now()）を踏んでいたら一致しない ★★
      expect(saved.updatedAt, later);
      expect(saved.createdAt, _t0, reason: 'createdAt は動かない');

      final restored = await repositoryOn(db).byId(deck.deckId);
      expect(restored!.updatedAt, later);
    });
  });

  group('★ 論理削除は一覧から消え、DB には残る（P3）', () {
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
      // P2「更新のたびに +1」と食い違うが、直す先は loveca_db 側であり
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
}
