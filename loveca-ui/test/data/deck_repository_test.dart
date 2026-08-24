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
        'M-2': Card(cardNumber: 'M-2', name: 'メンバー2', cardType: CardType.member),
        'L-1': Card(cardNumber: 'L-1', name: 'ライブ1', cardType: CardType.live),
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
        ),
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
          .save(deck, DeckDraft.of(deck).copyWith(name: 'Y'));

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
      await repository.save(created, draft);

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

      await repository.save(created, draft);
      expect((await repository.byId(created.deckId))!.entries, hasLength(1));
    });
  });

  group('★★ 並び順は保存されない（決定 D65）★★', () {
    // ★deck_entries に順序列が無く、DeckDao.byId は ORDER BY printing_id。
    //   直せる場所は loveca_db 側なので、M4 は**そうなることを固定して見せる**。
    test('並べ替えて保存しても、開き直すとカード番号順に戻る', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      var draft = repository.draftOf(created).addCopy('M-1-N').addCopy('M-2-N');
      expect(
        draft.entries.map((e) => e.printingId),
        ['M-1-N', 'M-2-N'],
        reason: '開いた直後は正規化された並び',
      );

      draft = draft.moveEntry('M-2-N', 'M-1-N', after: false);
      expect(draft.entries.map((e) => e.printingId), ['M-2-N', 'M-1-N']);
      expect(repository.isReordered(draft), isTrue);

      await repository.save(created, draft);
      await db.close();
      final reopened = await open();
      final restored = await repositoryOn(reopened).byId(created.deckId);

      // ★★ ここが決定 D65 の中身。画面はこれを先に予告している ★★
      expect(restored!.entries.map((e) => e.printingId), ['M-1-N', 'M-2-N']);
    });

    test('★★ 区分をまたいで足しただけでは縮退にしない（実機で誤検知した）★★', () async {
      // ★★ 画面は区分ごとに分けて出す ★★
      //   平坦なリストで比べると、エネルギーの次にメンバーを足した瞬間に
      //   「並べ替えました」と出る。**利用者は並べ替えていない。**
      //   M4 の実機確認で実際に出た誤検知。比べるのは各区分の中の並びである。
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft = repository
          .draftOf(created)
          .addCopy('E-1-N') // 先にエネルギー
          .addCopy('M-1-N'); // あとからメンバー（平坦には E, M の順）

      expect(repository.isReordered(draft), isFalse);
    });

    test('★同じ区分の中で順が崩れていれば縮退になる（出る側）', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft = repository
          .draftOf(created)
          .addCopy('M-2-N')
          .addCopy('M-1-N'); // メンバーの中で降順になった

      expect(repository.isReordered(draft), isTrue);
    });

    test('★並べ替えていなければ isReordered は false（出ない側）', () async {
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final draft =
          repository.draftOf(created).addCopy('M-1-N').addCopy('L-1-N');

      expect(repository.isReordered(draft), isFalse);
    });

    test('★区分順に正規化する（メンバー → ライブ → エネルギー → 未知）', () async {
      final repository = repositoryOn(db);

      final normalized = repository.normalizedEntries(const [
        DeckEntry(printingId: '知らない刷り', count: 1),
        DeckEntry(printingId: 'E-1-N', count: 1),
        DeckEntry(printingId: 'L-1-N', count: 1),
        DeckEntry(printingId: 'M-2-N', count: 1),
        DeckEntry(printingId: 'M-1-N', count: 1),
      ]);

      expect(
        normalized.map((e) => e.printingId),
        ['M-1-N', 'M-2-N', 'L-1-N', 'E-1-N', '知らない刷り'],
      );
    });

    test('★並べ替えただけなら保存ボタンを光らせない', () async {
      // ★★ 光らせると「保存したのに戻る」という最悪の形になる ★★
      //   並べ替えたこと自体は縮退として別に見せる。
      final created = await repositoryOn(db).create(name: 'X');
      final repository = repositoryOn(db);

      final saved = await repository.save(
        created,
        repository.draftOf(created).addCopy('M-1-N').addCopy('M-2-N'),
      );

      final reordered =
          repository.draftOf(saved).moveEntry('M-2-N', 'M-1-N', after: false);

      expect(reordered.isDirtyAgainst(saved), isFalse);
      // 枚数が変われば当然 true。
      expect(reordered.addCopy('M-1-N').isDirtyAgainst(saved), isTrue);
    });
  });
}
