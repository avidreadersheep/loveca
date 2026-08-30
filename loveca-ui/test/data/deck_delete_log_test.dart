/// 削除の 2 本の入口が、どちらも編集ログに 1 件残すこと（決定 **D110-3** / 穴 (c)）.
///
/// ★★ なぜこのファイルが要るか —— 入口が 2 本あり、片方が 0 件だった ★★
/// `docs/同期設計メモ.md` §15-7-6 の (4) が走査で記録している ——
/// **R2**（`DeckListStore.softDelete`）は `test/ui/deck_list_page_test.dart` が
/// 3 件見ているが、**R3**（`DeckEditStore.softDelete`）を見るテストは
/// `deck_edit_store_test.dart` にも `deck_edit_page_test.dart` にも **1 件も無かった**。
/// → §17-9-4 の 4「★**ログを足すなら、両方の入口から 1 件ずつ残ることを見ること**」。
///
/// ★★ 実 DB を使う。フェイクでは確かめたいものが消える ★★
/// `FakeDeckRepository` は `softDeleteCalls` を数えるだけで、**ログの行を持たない。**
/// 数えるだけだと「store が repository を呼んだ」までしか言えず、
/// **記録点が `DeckDao`（C-iv）に在ること**は 1 文字も検証できない。
/// → 本番と同じ `openAppDatabase()`（決定 D45）で開き、**表の行を直接見る。**
///   `test/data/deck_repository_test.dart` が実 DB を使うのと同じ格である。
///
/// ★★ 読み出しの API は作っていない ★★
/// §17-9-7 のコミット 3 は「書くだけ」なので、`DeckDao` にログを引く口は無い。
/// ★**検査のためだけ**にここで表を直に引く（`lib` からは 1 行も引いていない）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/deck_repository.dart';
import 'package:loveca_ui/src/state/deck_edit_store.dart';
import 'package:loveca_ui/src/state/deck_list_store.dart';
import 'package:path/path.dart' as p;

import '../support/fake_deck_repository.dart' show fakeCatalog;

/// ★固定時刻。`Clock` から供給されていることを見るために使う。
final _t0 = DateTime.utc(2026, 8, 30, 9);

void main() {
  late Directory tmp;
  late LovecaDatabase db;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_delete_log_test');
    db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
  });

  tearDown(() async {
    await db.close();
    // ★Windows は開いたままだと消せない。閉じてから消す。
    tmp.deleteSync(recursive: true);
  });

  DeckRepository repositoryFor(String deckId, {DateTime? now}) => DeckRepository(
        db,
        catalog: fakeCatalog(),
        clock: () => now ?? _t0,
        newDeckId: () => deckId,
      );

  /// 編集ログの全行（`deck_id` 昇順）。★検査専用。
  Future<List<DeckEditOpRow>> logRows() async {
    final rows = await db.select(db.deckEditOps).get();
    return rows..sort((a, b) => a.deckId.compareTo(b.deckId));
  }

  /// R2 の入口。一覧の「削除」から通る道（`deck_list_page.dart:175`）。
  Future<void> deleteFromR2(Deck deck) async {
    final store = DeckListStore(repositoryFor(deck.deckId));
    addTearDown(store.dispose);
    await store.softDelete(deck.deckId);
    expect(store.value.actionError, isNull, reason: '★削除そのものが失敗している');
  }

  /// R3 の入口。編集画面の「削除する」から通る道（`deck_edit_page.dart:160`）。
  Future<void> deleteFromR3(Deck deck) async {
    final store = DeckEditStore(repositoryFor(deck.deckId), deck);
    addTearDown(store.dispose);
    expect(await store.softDelete(), isTrue, reason: '★削除そのものが失敗している');
    expect(store.value.deleted, isTrue);
  }

  test('★前提: 開いた直後のログは空である（下の 3 件の土台）', () async {
    // ★★ 0 件は「無い」と「見えていない」の区別がつかない（**D-10**）★★
    //   下の 2 件が「入れれば増える」ことを見るので、この前提が対になる。
    expect(await logRows(), isEmpty);
  });

  test('★ R2 の入口（一覧）から消すとログに 1 件残る', () async {
    final deck = await repositoryFor('deck-r2').create(name: 'R2 から消す');

    await deleteFromR2(deck);

    final rows = await logRows();
    expect(rows, hasLength(1));
    expect(rows.single.deckId, 'deck-r2');
    expect(rows.single.kind, DeckEditOpKind.deleteDeck.key);
  });

  test('★★ R3 の入口（編集画面）から消してもログに 1 件残る ★★', () async {
    // ★★ この入口はこれまで 1 件も見られていなかった（§15-7-6 (4)）★★
    final deck = await repositoryFor('deck-r3').create(name: 'R3 から消す');

    await deleteFromR3(deck);

    final rows = await logRows();
    expect(rows, hasLength(1));
    expect(rows.single.deckId, 'deck-r3');
    expect(rows.single.kind, DeckEditOpKind.deleteDeck.key);
  });

  test('★★ 2 本の入口から 1 件ずつ残る（合わせて 2 件 / §17-9-4 の 4）★★', () async {
    final fromR2 = await repositoryFor('deck-r2').create(name: 'R2 から消す');
    final fromR3 = await repositoryFor('deck-r3').create(name: 'R3 から消す');

    await deleteFromR2(fromR2);
    await deleteFromR3(fromR3);

    final rows = await logRows();
    expect(rows.map((r) => r.deckId), ['deck-r2', 'deck-r3']);
    expect(rows.map((r) => r.kind).toSet(), {DeckEditOpKind.deleteDeck.key});

    // ★決定 D102: どちらの入口でも行そのものは残る。
    for (final deck in [fromR2, fromR3]) {
      expect((await repositoryFor(deck.deckId).byId(deck.deckId))!.isDeleted,
          isTrue);
    }
  });

  test('★★ 対: 削除以外は 1 件も残らない（この版の記録点は削除だけ）★★', () async {
    // ★★ 出る側だけ見ると「何でも記録する実装」でも通る ★★
    //   9 操作の記録点は §17-9-7 のコミット 5 であり、**この版にはまだ無い。**
    //   ★このテストはそこで**書き換わるはず**である。落ちたら合図であって不具合ではない。
    final repository = repositoryFor('deck-keep');
    final deck = await repository.create(name: '消さないデッキ');

    final store = DeckEditStore(repository, deck);
    addTearDown(store.dispose);
    store
      ..setName('名前を変えた')
      ..addCard('M-1-N');
    expect(await store.save(), isTrue);

    // ★R2 側の書き込みも通す（メタ編集 / 複製）。
    final list = DeckListStore(repository);
    addTearDown(list.dispose);
    await list.duplicate(store.value.saved, name: '複製');

    expect(await logRows(), isEmpty);
  });
}
