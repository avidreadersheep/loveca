/// 9 つの編集操作が、保存のときに編集ログへ残ること（決定 **D110-1** / **D110-2**）.
///
/// ★★ なぜ実 DB を使うか ★★
/// `FakeDeckRepository` は `saveCalls` を数えるだけで**ログの行を持たない**。
/// 数えるだけでは「store が repository を呼んだ」までしか言えず、
/// ★**記録点から DB の行までが繋がっていること**を 1 文字も検証できない。
/// → `deck_delete_log_test.dart`（**D110-3**）が採ったのと同じ形で、
///   本番と同じ `openAppDatabase()`（決定 D45）を開いて**表を直接見る**。
///
/// ★★ 1 操作 = 1 テストである。★まとめない ★★
/// 9 つを 1 件のテストにまとめると、**1 つ記録し忘れてもそのテストが 1 件落ちるだけ**で、
/// ★**どれが落ちたのか分からない。**
/// → ★**9 件に割る。**
///
/// ★★ 実測（2026-08-30 / ★9 通りとも仕込んで走らせ、戻した）★★
/// **9 通りとも、下の群のうち★その操作に対応する 1 件が落ちた。★群の中で落ちたのはその 1 件だけである。**
///
/// ★★ ただし「その 1 件**だけ**が落ちる」ではない ★★
/// 群の**外**では、その操作を通す**合成のテスト**も一緒に落ちる
/// （★「保存していなければ増えない」「保存 1 回 = ログ N 件」など。★複数操作を通しているので当然）。
/// ★実測の落ちた件数は **1〜6 件**で、`replaceEntries` / `applyMeta` / `removeEntry` だけが
/// ちょうど 1 件だった（★合成のテストがそれらを通していないため）。
/// ★**内訳は `CLAUDE.md` §3 に在る。★ここに数を書かない**（**D-15**）。
///
/// ★★ この doc は 1 度誤っていた ★★
/// 測る**前**に「1 つ外したらその 1 件だけが落ちる（★実測で確かめてある）」と書いていた。
/// ★**測ったら偽だった**（型は **D-15 (j)** —— ★検証していない完了報告）。
/// → ★**「群の中では 1 件」と「群の外でも落ちる」を分けて書き直した。**
///
/// ★★ 読み出しの API は作っていない ★★
/// §17-9-7 のコミット 5 までに `DeckDao` へログを引く口は無い（★同期の送受信はその先）。
/// ★**検査のためだけ**にここで表を直に引く（`lib` からは 1 行も引いていない）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/state/deck_edit_store.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';
import 'package:path/path.dart' as p;

import '../support/fake_deck_repository.dart' show fakeCatalog;

/// ★固定時刻。`at` が [Clock] から供給されていることを見るために使う。
final _t0 = DateTime.utc(2026, 8, 30, 9);

void main() {
  late Directory tmp;
  late LovecaDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_edit_log_test');
    db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
  });

  tearDown(() async {
    await db.close();
    // ★Windows は開いたままだと消せない。閉じてから消す。
    tmp.deleteSync(recursive: true);
  });

  DeckRepository repositoryFor(String deckId) => DeckRepository(
        db,
        catalog: fakeCatalog(),
        clock: () => _t0,
        newDeckId: () => deckId,
      );

  /// 編集ログの全行。★`id`（AUTOINCREMENT）の昇順 ＝ 記録された順。
  ///
  /// ★drift の `OrderingTerm` は `loveca_db` から公開されていない（★決定 D55 の境界）。
  /// ★**検査専用なので Dart 側で並べる。**
  Future<List<DeckEditOpRow>> logRows() async {
    final rows = await db.select(db.deckEditOps).get();
    return rows..sort((a, b) => a.id.compareTo(b.id));
  }

  Future<List<String>> logKinds() async =>
      (await logRows()).map((r) => r.kind).toList();

  /// 中身のあるデッキを土台として作る。
  ///
  /// ★★ ここは記録点ではない ★★
  /// `DeckRepository.save` を**直に**呼び、★空の列を渡す。
  /// → ★**土台を作る作業がログに混ざらない**ので、下の各テストは
  ///   「その操作 1 件だけが在る」を言える。
  Future<(DeckRepository, Deck)> deckWith(
    List<String> printingIds, {
    String id = 'deck-1',
  }) async {
    final repository = repositoryFor(id);
    final created = await repository.create(name: 'デッキ');
    var draft = repository.draftOf(created);
    for (final printingId in printingIds) {
      draft = draft.addCopy(printingId);
    }
    final saved = await repository.save(created, draft, ops: const []);
    expect(await logRows(), isEmpty, reason: '★土台がログを汚している');
    return (repository, saved);
  }

  DeckEditStore storeOn(DeckRepository repository, Deck deck) {
    final store = DeckEditStore(repository, deck);
    addTearDown(store.dispose);
    return store;
  }

  /// 1 操作を通して保存し、記録された `kind` の列を返す。
  Future<List<String>> after(
    void Function(DeckEditStore store) edit, {
    List<String> entries = const [],
  }) async {
    final (repository, deck) = await deckWith(entries);
    final store = storeOn(repository, deck);
    edit(store);
    expect(store.value.canSave, isTrue,
        reason: '★保存できない状態では記録点まで届かない（テストの前提が崩れている）');
    expect(await store.save(), isTrue, reason: '★保存そのものが失敗している');
    return logKinds();
  }

  // ---------------------------------------------------------------------------
  // 前提
  // ---------------------------------------------------------------------------

  test('★前提: 開いた直後のログは空である（★下の 9 件の土台）', () async {
    // ★★ 0 件は「無い」と「見えていない」の区別がつかない（**D-10**）★★
    //   下の 9 件が「操作すれば増える」ことを見るので、この前提が対になる。
    await deckWith(const ['M-1-N']);
    expect(await logRows(), isEmpty);
  });

  // ---------------------------------------------------------------------------
  // ★★ 9 操作 —— 1 件ずつ（§17-9-2 / **D110-2**）★★
  // ---------------------------------------------------------------------------

  group('★★ 9 操作がそれぞれ 1 件残る ★★', () {
    test('1. setName', () async {
      expect(await after((s) => s.setName('別の名前')),
          [DeckEditOpKind.setName.key]);
    });

    test('2. setMemo', () async {
      expect(await after((s) => s.setMemo('メモを書いた')),
          [DeckEditOpKind.setMemo.key]);
    });

    test('3. replaceEntries（共有形式からの取り込み / 決定 D67）', () async {
      expect(
        await after((s) => s.replaceEntries(
              const [DeckEntry(printingId: 'M-1-N', count: 2)],
            )),
        [DeckEditOpKind.replaceEntries.key],
      );
    });

    test('4. applyMeta（P3 のメタ編集 / R3 側）', () async {
      final (repository, deck) = await deckWith(const []);
      final store = storeOn(repository, deck);
      store.applyMeta(
        repository.draftOf(deck).copyWith(name: 'メタ経由', tags: const ['青']),
      );
      expect(await store.save(), isTrue);

      expect(await logKinds(), [DeckEditOpKind.applyMeta.key]);
    });

    test('5. addCard', () async {
      expect(await after((s) => s.addCard('M-1-N')),
          [DeckEditOpKind.addCard.key]);
    });

    test('6. removeCopy', () async {
      expect(
        await after((s) => s.removeCopy('M-1-N'), entries: const ['M-1-N']),
        [DeckEditOpKind.removeCopy.key],
      );
    });

    test('7. removeEntry', () async {
      expect(
        await after((s) => s.removeEntry('M-1-N'), entries: const ['M-1-N']),
        [DeckEditOpKind.removeEntry.key],
      );
    });

    test('8. moveEntry（★`ord` に答えを持つ操作 / 決定 D99）', () async {
      expect(
        await after(
          (s) => s.moveEntry('M-1-N', 'M-2-N', DropEdge.trailing),
          entries: const ['M-1-N', 'M-2-N'],
        ),
        [DeckEditOpKind.moveEntry.key],
      );
    });

    test('9. sortByRule（★「規則順に戻した」という事実だけ）', () async {
      // ★★ 土台は規則順ではない ★★
      //   規則順（決定 D99）はメンバーの cost 降順なので、
      //   `M-2`（cost 9）が `M-1`（cost 2）より先に来る。
      //   ★投入順を規則順にすると、比較器が何もしなくても `isDirty` が立たず、
      //   **保存まで届かない**（テストが前提で落ちる）。
      final kinds = await after(
        (s) => s.sortByRule(),
        entries: const ['M-1-N', 'M-2-N'],
      );

      expect(kinds, [DeckEditOpKind.sortByRule.key]);
    });
  });

  test('★★ どの規則で並べたかは記録しない（★(f-3) の軸 B を倒さない）★★', () async {
    // ★★ 表に引数の列が無いことの実物 ★★
    //   `deck_edit_ops` は `id` / `deck_id` / `kind` / `at` の 4 つしか持たない。
    //   ★規則の名前で残して再生すると `deckOrderKeyOf` がカードマスタを引くので、
    //   ★受け取った端末の取り込み状態に結果が依存する（§13-5 / §17-9-2 の追記）。
    //   → ★**未決のまま残す。★ここで型に書き込まない。**
    final (repository, deck) = await deckWith(const ['M-1-N', 'M-2-N']);
    final store = storeOn(repository, deck);
    store.sortByRule();
    expect(await store.save(), isTrue);

    final row = (await logRows()).single;
    expect(row.kind, DeckEditOpKind.sortByRule.key);
    expect(row.deckId, 'deck-1');
    // ★時刻は [Clock] から来る（`DateTime.now()` ではない）。
    expect(row.at.toUtc(), _t0);
    // ★★ 引数を持てる列が無い —— 行の情報はこの 4 つで尽きている ★★
    //   ★`toJson` の鍵は Dart 側の名前である（列名は `deck_id`）。
    //   ★引数の列を足した人はここが落ちる。
    expect(row.toJson().keys.toSet(), {'id', 'deckId', 'kind', 'at'});
  });

  // ---------------------------------------------------------------------------
  // ★★ 対 ★★
  // ---------------------------------------------------------------------------

  test('★★ 対: 保存していなければ 1 件も増えない ★★', () async {
    // ★★ 「操作のたびに書く」ではなく「保存の時点で書く」（§17-9-2 の 3）★★
    //   ★これが崩れると、**保存前に閉じた編集が DB に残る** ——
    //   ドラフトの性質（保存しなければ元に戻せる）と正面から食い違う。
    final (repository, deck) = await deckWith(const ['M-1-N']);
    final store = storeOn(repository, deck);

    store
      ..setName('保存しない')
      ..setMemo('保存しない')
      ..addCard('M-2-N')
      ..removeCopy('M-1-N')
      ..sortByRule();

    expect(await logRows(), isEmpty);
    // ★対: 同じ store で保存すれば、貯めた 5 件がまとめて出る。
    //   —— 「そもそも書けていないから空」ではないことを見る（**D-10**）。
    expect(await store.save(), isTrue);
    expect(await logRows(), hasLength(5));
  });

  test('★★ 保存 1 回 = ログ N 件（★操作の順に並ぶ）★★', () async {
    // ★★ `revision` は +1 しか増えないが、操作の粒度は失わない ★★
    //   それが案 6（操作の履歴）を採った理由そのものである（§13-2）。
    final (repository, deck) = await deckWith(const ['M-1-N', 'M-2-N']);
    final store = storeOn(repository, deck);

    store
      ..setName('3 回さわった')
      ..moveEntry('M-1-N', 'M-2-N', DropEdge.trailing)
      ..setMemo('メモ');
    expect(await store.save(), isTrue);

    expect(await logKinds(), [
      DeckEditOpKind.setName.key,
      DeckEditOpKind.moveEntry.key,
      DeckEditOpKind.setMemo.key,
    ]);
    // ★保存は 1 回なので `revision` は +1 だけ（決定 D101）。
    expect(store.value.saved.revision, deck.revision + 1);
  });

  test('★★ 2 回保存しても 1 回目の分を二重に書かない ★★', () async {
    // ★★ 貯めた列を「保存が通ったら捨てる」ことの受け ★★
    final (repository, deck) = await deckWith(const []);
    final store = storeOn(repository, deck);

    store.setName('1 回目');
    expect(await store.save(), isTrue);
    expect(await logKinds(), [DeckEditOpKind.setName.key]);

    store.setMemo('2 回目');
    expect(await store.save(), isTrue);

    expect(await logKinds(),
        [DeckEditOpKind.setName.key, DeckEditOpKind.setMemo.key]);
  });

  test('★★ 保存が失敗したら列は捨てない（★やり直しで残る）★★', () async {
    // ★★ ここで捨てると穴 (c) と同じ形を自分で作る ★★
    //   失敗は `DeckDao.save` のトランザクションごと巻き戻るので、
    //   本体もログも残らない。★そこで捨てると、やり直した保存が
    //   **本体だけを書いてログを落とす。**
    final (repository, deck) = await deckWith(const []);
    final store = storeOn(repository, deck);
    store.setName('失敗させる');

    // ★ログの INSERT だけを失敗させる（`deck_dao_test.dart` と同じ手）。
    await db.customStatement(
      'CREATE TRIGGER fail_ops BEFORE INSERT ON deck_edit_ops '
      "BEGIN SELECT RAISE(ABORT, '★仕込んだ失敗'); END",
    );
    expect(await store.save(), isFalse);
    expect(store.value.actionError, isNotNull);
    // ★同時性: 本体も巻き戻っている（決定 D110-3 と同じ形）。
    expect((await repository.byId('deck-1'))!.name, 'デッキ');
    expect(await logRows(), isEmpty);

    await db.customStatement('DROP TRIGGER fail_ops');
    expect(await store.save(), isTrue);

    // ★★ 失敗した回の操作が、やり直しで書かれている ★★
    expect(await logKinds(), [DeckEditOpKind.setName.key]);
    expect((await repository.byId('deck-1'))!.name, '失敗させる');
  });

  test('★★ 対: 断られた addCard は記録しない ★★', () async {
    // ★★ 起きていない編集を履歴に残さない ★★
    //   `DeckDao.softDelete` の「当たる行が無ければ記録しない」と同じ形。
    final (repository, deck) = await deckWith(const []);
    final store = storeOn(repository, deck);

    // ★カードマスタに無い刷り（決定 D35）。
    expect(store.addCard('NOT-A-REAL-PRINTING'),
        AddCardRefusal.unknownPrinting);
    // ★4 枚制限（6.1.1.2）。★4 枚入れてから 5 枚目を断らせる。
    for (var i = 0; i < 4; i++) {
      expect(store.addCard('M-1-N'), isNull);
    }
    expect(store.addCard('M-1-P'), AddCardRefusal.tooManyCopies);

    expect(await store.save(), isTrue);
    // ★通った 4 回だけが残る（★断られた 2 回は残らない）。
    expect(await logKinds(), List.filled(4, DeckEditOpKind.addCard.key));
  });

  test('★★ 対: 記録点を通らない書き込みは 1 件も残さない ★★', () async {
    // ★★ 出る側だけ見ると「何でも記録する実装」でも通る ★★
    //   ★`create` / `duplicate` は 9 操作を通らないが**穴に数えない** ——
    //   どちらも新規デッキ（`revision` 0）で、比べる相手が存在しない（§15-2）。
    final repository = repositoryFor('deck-1');
    final created = await repository.create(name: '作っただけ');
    await repository.duplicate(created, name: '複製');
    // ★読み出しも通す。
    await repository.byId(created.deckId);
    await repository.all();

    expect(await logRows(), isEmpty);
  });

  test('★★ 穴 (a) は塞がった: R2 のメタ編集も記録が残る（**D110-2** の A-i）★★',
      () async {
    // ★★ ここは 2026-08-30 まで「まだ記録されない」を固定していた ★★
    //   `DeckListStore.saveMeta` が `DeckEditStore` を通らず
    //   `DeckRepository.save` へ直行していた（§15-7-1 の 2 / 穴 (a)）。
    //   ★元の doc が「コミット 6 でこのテストは落ちる。落ちたら合図であって
    //   不具合ではない」と**予告しており、そのとおりに落ちた。**
    //   → ★★**対を緩めていない。★見る対象を「ログが空であること」から
    //     「R2 が組む手順でログが 1 件残ること」へ移した。**★★
    //     （★`deck_delete_log_test.dart` がコミット 5 で採ったのと同じ処置）
    //
    // ★★ この test が見ていないもの（**D-27**）★★
    //   ★**画面がこの手順を組むこと**は 1 文字も見ていない。
    //   `DeckListStore.saveMeta` は**メソッドごと消えた**ので、この層に
    //   R2 固有の経路はもう存在しない。★見ているのは別の 2 つである ——
    //   (1) `test/data/deck_save_call_site_test.dart`（★経路が 1 本しか無いこと）
    //   (2) `test/ui/deck_meta_dialog_test.dart`（★`canSave` の門と失敗表示が R2 に出ること）
    final repository = repositoryFor('deck-1');
    final created = await repository.create(name: 'R2 から直す');
    // ★R2 は一覧から `Deck` を受け取る。★DB から読み戻したものを土台にする。
    final deck = (await repository.byId('deck-1'))!;
    expect(deck.revision, created.revision);
    expect(await logRows(), isEmpty, reason: '★土台がログを汚している');

    // ★★ `ui/deck/deck_list_page.dart` の `_editMeta` と同じ 3 手 ★★
    final store = storeOn(repository, deck);
    store.applyMeta(repository.draftOf(deck).copyWith(name: 'R2 で変えた'));
    expect(await store.save(), isTrue);

    // ★本体もログも動いている（★穴は「本体だけが動く」ことだった）。
    expect((await repository.byId('deck-1'))!.name, 'R2 で変えた');
    expect(await logKinds(), [DeckEditOpKind.applyMeta.key]);
  });
}
