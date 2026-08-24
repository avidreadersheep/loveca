/// デッキ編集の縮退（`docs/UI設計メモ.md` §3-4(3)）.
///
/// ★★ 例外ではないが、結果が完全でない ★★
/// `Loadable` の `Failed` では表せず、成功に畳み込むと
/// **「できたが不完全」が「できた」と区別できなくなる。**
///
/// ★★ `SearchDegradation` と型を分けてある ★★
/// どちらも「結果が完全でない」通知だが、**寿命も出る場所も違う**
/// （検索語ごと / 編集セッションごと、検索結果ヘッダ / デッキペイン）。
/// 1 つの `sealed` にまとめると、検索側に 4 つ目を足したときここにも
/// 「ここでは起きない」枝が生え、**網羅性検査の意味が薄れる**（決定 D53）。
/// **描画だけ `ui/common/degradation_line.dart` で共有する**（振り分け規則も同ファイル）。
///
/// | 縮退 | 原因 | 利用者に伝えること |
/// |---|---|---|
/// | [DeckOrderNotPersisted] | `deck_entries` に順序列が無い（決定 D65） | 開き直すとカード番号順に戻る |
/// | [DeckUnknownPrintings] | マスタに無い刷りを持っている（決定 D35） | 消していない・触れないだけ |
library;

/// 並べ替えた並びは保存されない（決定 D65）.
///
/// ★★ 「保存されません」で止めない ★★
/// それだけだと**次に開いたとき何が起きるか**が伝わらない。
/// `deck_entries` の主キーは `{deckId, printingId}` で順序列が無く、
/// `DeckDao.byId` は `ORDER BY printing_id` で読み戻す。
/// したがって**戻る先はカード番号順**であり、そこまで言えば驚きにならない。
///
/// ★根治は `loveca_db` に `ord` 列を足すこと。方式は決定 D65 に書いてある。
final class DeckOrderNotPersisted extends DeckEditDegradation {
  const DeckOrderNotPersisted();
}

/// カードマスタに無い刷りを持っている（決定 D35）.
///
/// ★★ 黙って削除しない ★★
/// 消すとデッキが静かに壊れる。**残したまま、触れない行として見せる。**
/// 起きるのは「新しいデータで作ったデッキを古いデータで開いた」ときなど。
final class DeckUnknownPrintings extends DeckEditDegradation {
  const DeckUnknownPrintings(this.count);

  /// 刷りの件数（枚数ではない）。
  final int count;
}

sealed class DeckEditDegradation {
  const DeckEditDegradation();
}
