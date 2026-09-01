/// ★★ 操作の列を渡す保存は、`lib` に数えるほどしか無い（決定 **D110-2** の A-i）★★
///
/// 穴 (a) は「`DeckEditStore` の 9 つの名前つき操作を通らずに `DeckRepository.save`
/// へ直行する経路」だった（`docs/同期設計メモ.md` §15-7-1 の 2）。
/// ★合流点の `DeckRepository.save(base, draft)` が採れるのは **(before, after) の対だけ**で、
/// ★**意図は採れない**（§15-7-2）。→ ★**意図を採る層を 1 つに揃える**のが **D110-2** である。
///
/// ★★ この検査が要る理由 —— 塞いだ形は「メソッドを消したこと」でしか残らない ★★
/// `DeckListStore.saveMeta` は撤去したが、**同じものはいつでも書き足せる。**
/// ★それは **A-ii**（記録点を 2 か所にする案）そのもので、**D110-2** が
/// 「次に入口が増えたとき同じ穴が開く」として採らなかった形である（§15-7-3）。
/// → ★**書き足したらここが落ちる。**
///
/// ★★ なぜ `.save(` ではなくこの字面を走査するか ★★
/// `.save(` は `AppSettingsStore.save(`（設定の保存）や `DeckEditStore.save()` を
/// 一緒に拾う。★**呼び出し元の変数名で絞ると、その変数名がそのまま検出範囲になる**
/// （新所見 **D-37** —— ★束 C の commit 4 の前に実際に踏んだ）。
/// → ★**引数の名前で走査する。**これは commit 4 が `required` にしたもの、
///   すなわち**この論点そのものの印**であって、偶然そこに在る識別子ではない。
///   ★`DeckDao.save` / `DeckRepository.save` は 2 つとも必須で受け取るので、
///   **この字面を書かずに保存を呼ぶことはできない。**
///
/// ★★ 「0 件であること」を完了条件にしない（**D-30** / **D-31**）★★
/// 走査は**コメントも読む**ので、禁止対象を説明する doc は必ず自分でヒットする。
/// → ★**許可リストとの完全一致で見張る**（先例は `test/docs/legacy_design_number_test.dart`）。
/// ★**この検査は 0 件を主張しない**ので、走査が壊れて何も拾わなくなれば落ちる
///   （**D-10**: 0 件は「無い」と「見えていない」の区別がつかない）。
///
/// ★★ 字面をこのファイルの外に持ち出さない ★★
/// 走査するのは `lib` だけである。★このファイル自身は範囲外なので、
/// 説明のために字面を書いても許可リストに自分を載せることにならない。
library;

import 'package:flutter_test/flutter_test.dart';

import '../support/source_scan.dart';

/// 操作の列を伴う保存の呼び出し。★`stops:` のような別の語を拾わないよう
/// 直前 1 文字を見る（`.` を除くのは `foo.ops:` のような形が Dart に無いため）。
final _opsArgument = RegExp(r'(^|[^.\w])ops:');

/// ★許されるヒット。**ファイル名 → 件数**。★理由の無い許可を作らない。
const _allowed = <String, int>{
  // ★`DeckDao.save` を呼ぶ 3 箇所（`create` / `save` / `duplicate`）。
  //   ★`create` / `duplicate` が空の列を渡すことは**穴ではない** ——
  //   どちらも新規デッキ（`revision` 0）で、比べる相手が存在しない（§15-2）。
  // ★★ 2026-09-02: ★3 → 4（★受信の口を足した / **D144**）★★
  //   ★**`saveReceived` が★4 つ目である**（★§32-6 の **24**）。
  //   ★★**意図は★呼び出し側が採る**★★ —— ★解決が起きたなら `resolveConflict` を 1 件、
  //     ★相手側だけが変わっていたなら★★1 件も渡さない★★（**D119-1** / `deck_sync.dart`）。
  //   ★★**空の列を渡して通しているのではない**★★ —— ★★渡す列を★決めているのが `applyRemoteDeck` である★★。
  'deck_repository.dart': 4,
  // ★★ 意図を採る唯一の層（**D110-2**）★★
  'deck_edit_store.dart': 1,
  // ★★ 受信の意図を採る層（★§32-6 の **24** / **D144**）★★
  //   ★**手元の編集ではない**ので `DeckEditStore` を通らない。
  //   ★**`remoteOnly` なら 1 件も残さない**（★残すと★★次の同期が「まだ送っていない」と読む★★）。
  'deck_sync.dart': 1,
};

void main() {
  test('★★ 陽性対照: 走査が「渡している側」を拾う ★★', () {
    // ★これが当たらないなら、下の一致は何も証明しない。
    expect(_opsArgument.hasMatch('await DeckDao(_db).save(next, ops: ops);'),
        isTrue);
    expect(
      _opsArgument
          .hasMatch('_repository.save(deck, draft, ops: const []);'),
      isTrue,
    );
  });

  test('★★ 対: 似た語を拾わない（★`stops:` は別物）★★', () {
    // ★語を広げると許可リストが育ち、検査の意味が薄れる
    //   （`reduce_call_site_test.dart` が同じ理由を書いている）。
    expect(_opsArgument.hasMatch('_StopReasonLine(stops: operation.stops),'),
        isFalse);
    expect(_opsArgument.hasMatch('BoardStepLog(steps: run.steps),'), isFalse);
  });

  test('★★ `lib` の実測は許可リストと完全一致する ★★', () {
    // ★★ 落ちたときにすること ★★
    //   増えた側 —— その呼び出しが**意図を持っているか**を人が見る。
    //     持っているなら `DeckEditStore` の 9 操作の側へ登らせる（A-i と同じ形）。
    //     ★空の列を渡して通すのは、**穴 (a) を作り直すことである**。
    //   減った側 —— 許可リストからその行を消す。★件数だけ直して理由を残さない、をしない。
    expect(scanDart('lib', _opsArgument), _allowed);
  });

  test('★★ `DeckListStore` は 1 件も持たない（穴 (a) がそこに在った）★★', () {
    // ★上の完全一致に含まれているが、**何を見張っているのかを名前で残す。**
    //   ★総数だけだと、2 件目がどこにできても「増えた」としか分からない
    //   （`reduce_call_site_test.dart` が同じ理由で 2 つに割っている）。
    final hits = scanDart('lib', _opsArgument);

    expect(hits, isNotEmpty, reason: '★走査が何も拾っていない（**D-10**）');
    expect(hits.containsKey('deck_list_store.dart'), isFalse,
        reason: '★メタを書く口を R2 の一覧 store へ戻すと A-ii になる（**D110-2**）');
  });
}
