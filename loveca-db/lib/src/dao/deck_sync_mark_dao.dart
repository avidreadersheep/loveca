/// 前回同期時点の器の読み書き —— ★★§32-6 の **23** の一部（決定 **D114-1** / **D140-1**）.
///
/// ★★ ここは「器への記録点」だけである。★送信も判定も解決も無い ★★
/// ★**判定は `loveca_core` の `judgeDeckConflict`**（**D111-2**）、
/// ★**解決は同じく `resolveDeckConflict`**（**D138-1**）、
/// ★**送るのは★★まだ 1 行も無い★★**（★§32-6 の **23** の残り / ★口の細目が未決 / **D139-4**）。
///
/// ★★ 呼ぶ側が★今日 1 人も居ない ★★
/// ★**これは「空の器」ではない**（★器は **D114-1** が commit 22 で建てた）——
/// ★★**器を★引く経路である。★引く人がまだ居ない。**★★
/// → ★**「同期が動くようになった」と読まないこと。**
///
/// ---
///
/// ## ★★ 目印の値の意味を決めた（**D140-1**）—— ★★§24-8 が未決にしていた分 ★★
///
/// ★**§24-8 は「★目印の値の意味（「最後に送った」か「次に送る」か）は★★決めていない。★器の形に効かない★★」
/// と書いた**（★実読）。★★**器の形には効かないが、★★引く経路には効く★★**★★ ——
/// ★**`id > 目印` か `id >= 目印` かが★ここで決まる。**
///
/// | # | 候補 | ★書く時点で値が確定しているか | ★一度も送っていない状態 |
/// |---|---|---|---|
/// | ★★**印-1**★★ | ★★**最後に送った操作の id**★★（★読みは `id > mark`） | ★★**確定している**★★（★送った最大の id） | ★**0**（★どの id よりも小さい） |
/// | ★**印-2** | ★**次に送る操作の id**（★読みは `id >= mark`） | ★★**確定していない**★★ —— ★**次の id は `AUTOINCREMENT` が決める**。→ ★★実際に書けるのは「最後 ＋ 1」である★★ | ★**1**（★★「最初の id は 1 である」という前提が要る★★） |
///
/// ★★**印-1 を採る**★★ —— ★**2 軸とも 印-1 の側で決まる。**
/// ★★**「印-2 が劣る」とは書かない**★★（**D110** / **D111** / **D138** / **D139** の作法）——
/// ★**印-2 は★同じ情報を 1 だけずらして持つ形であり、★到達する。**
/// ★**差し替え点は★下の [baselineFor] の比較 1 か所と、★[latestLogMark] の返す値である。**
///
/// ## ★★ 索引を足していない —— ★★測った（★規約に当てた）★★
///
/// ★**`tables.dart` の規約は「★索引は★★引く経路と一緒に足す★★」である**（★§24-8 が引いている）。
/// → ★**この commit が★その「引く経路」である。**★**当てた。**
///
/// ★★**測った**★★（2026-09-02 / ★この機械 / ★`deck_edit_ops` に 1 デッキあたり 200 件 × 50 デッキ ＝ ★★10,000 件★★）——
///
/// | 何 | ★100 回の平均 |
/// |---|---|
/// | ★[baselineFor]（★索引なし） | ★★**167.1 µs**★★ |
/// | ★[latestLogMark]（★索引なし） | ★**245.7 µs** |
/// | ★★[baselineFor]（★`(deck_id, id)` の索引を足した） | ★★**168.4 µs**★★ |
///
/// → ★★**足さない。★★索引を足しても速くならなかった★★**（★差は 1.3 µs で、★★遅くなった側である★★）。
/// ★★**書く前に「0.05 ms」と書いた。★★偽だった★★**★★（★型は **D-15 (j)** —— ★**測って直した**）。
/// ★★**「速い」とも「索引が要らない」とも書かない**★★ —— ★**測ったのは★★この件数・この機械だけである★★**
/// （**D-28** / **§7-11**）。★**件数が桁で増えたら測り直すこと。**
/// ★**足すなら★`schemaVersion` が 1 段上がり、★移行と巻き戻しが要る**（★別の論点）。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../schema/database.dart';

/// 前回同期時点の器（`deck_sync_marks` / **D114-1**）を読み書きする。
class DeckSyncMarkDao {
  const DeckSyncMarkDao(this.db);

  final LovecaDatabase db;

  /// [deckId] の基準を、★★判定に渡す形に畳んで返す★★（**D111-2** の `DeckSyncBaseline`）。
  ///
  /// ★★ 行が無ければ `null` ＝ まだ一度も同期していない（決定 **D114-3**）★★
  /// ★**「何をするか」はここで答えない**（★初回同期の設計 ＝ ★門 カ）。
  ///
  /// ★★ 目印そのものを返さない。★有無に畳む ★★
  /// ★**判定が見るのは「その位置より後ろに操作が在るか」の★★答えだけ★★である**
  /// （`deck_conflict.dart` の `DeckSyncBaseline` の doc）。
  /// → ★**目印の値の意味（**D140-1**）を★★呼ぶ側へ漏らさない。**★★
  Future<DeckSyncBaseline?> baselineFor(String deckId) async {
    final row = await (db.select(db.deckSyncMarks)
          ..where((m) => m.deckId.equals(deckId)))
        .getSingleOrNull();
    if (row == null) return null;

    // ★★ 印-1 —— 目印は「最後に送った操作の id」である（**D140-1**）★★
    //   ★**差し替え点はこの比較 1 か所である**（★印-2 なら `isBiggerOrEqualValue`）。
    final unsent = await (db.select(db.deckEditOps)
          ..where((o) =>
              o.deckId.equals(deckId) & o.id.isBiggerThanValue(row.logMark))
          ..limit(1))
        .getSingleOrNull();

    return (
      hasOpsSinceMark: unsent != null,
      contentHash: row.baselineHash,
    );
  }

  /// [deckId] のログの★★最後の id★★（★★目印に書くべき値★★ / **D140-1**）。
  ///
  /// ★★ ログが 1 件も無ければ 0 である ★★
  /// ★**0 はどの id よりも小さい**（`AUTOINCREMENT` は 1 から採る）ので、
  /// ★★**「まだ 1 件も送っていない」と「全部送った」が★同じ形で書ける**★★。
  /// ★**`create` / `duplicate` はログを 1 件も残さない**（★`deck_conflict.dart` の事実 16）ので、
  /// ★**この場合が★実際に起こる。**
  Future<int> latestLogMark(String deckId) async {
    final row = await (db.select(db.deckEditOps)
          ..where((o) => o.deckId.equals(deckId))
          ..orderBy([(o) => OrderingTerm.desc(o.id)])
          ..limit(1))
        .getSingleOrNull();
    return row?.id ?? 0;
  }

  /// 同期が通った時点の目印と基準ハッシュを★★同じ行に★★書く（**D114-1** / **D114-4** の 1）。
  ///
  /// ★★ 2 つを別々に書ける口を作らない ★★
  /// ★**「片方だけ在る状態を作れない」ことが★この表を選んだ根拠の 1 つである**（**D114-4** の 1）。
  /// → ★**引数も 2 つとも必須にする。**★規約ではなく形で守る。
  ///
  /// ★★ `decks` を 1 度も触らない（**D114-4** の 3）★★
  /// ★**この口は `deck_sync_marks` の 1 行しか書かない**（★`updatedAt` も `revision` も動かない）。
  Future<void> record({
    required String deckId,
    required int logMark,
    required String baselineHash,
  }) =>
      db.into(db.deckSyncMarks).insertOnConflictUpdate(
            DeckSyncMarksCompanion.insert(
              deckId: deckId,
              logMark: logMark,
              baselineHash: baselineHash,
            ),
          );

  /// 器の行を消して「★まだ一度も同期していない」に戻す（**D119-5** ＝ 失-1 / **D121-7** ＝ 落-1）。
  ///
  /// ★★ 新しい状態を 1 つも作らない ★★
  /// ★**D114-3** が★行の不在に意味を与えているので、★★戻す先が既に在る★★
  /// （**D119-5** —— ★「機構を丸ごと持っている」）。
  ///
  /// ★★ ログには触れない ★★
  /// ★**N-16**（★ログをいつ捨てるか）は★別の問いである。★**ここは器の 1 行だけを消す。**
  Future<void> forget(String deckId) =>
      (db.delete(db.deckSyncMarks)..where((m) => m.deckId.equals(deckId)))
          .go();

  /// 器の行を★★全部★★消す（★§32-6 の **27** / 決定 **D145-2** の受け）。
  ///
  /// ## ★★ なぜデッキ 1 つずつではないのか ★★
  ///
  /// ★**引き金は「★★この端末が★名簿から外れていた★★」である**（**D145-2** ＝ 引-1）。
  /// ★**外れているあいだに★★どのデッキが動いたかは★端末には分からない★★。**
  /// → ★**デッキを選べない。★★全部を「まだ一度も同期していない」に戻す★★。**
  ///
  /// ## ★★ ログには触れない（[forget] と同じ）★★
  ///
  /// ★**未送信の編集を★★失わせない★★** —— ★**捨てる規則は **N-16** / **Q-10** であり、
  ///   ★★この口の論点ではない★★。**
  ///
  /// ## ★★ `decks` にも触れない ★★
  ///
  /// ★**器の行だけを消す**（★`updatedAt` も `revision` も動かない / **D114-4** の 3）。
  Future<void> forgetAll() => db.delete(db.deckSyncMarks).go();
}
