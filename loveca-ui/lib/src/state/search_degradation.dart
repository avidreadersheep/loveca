/// 検索結果の縮退（`docs/UI設計メモ.md` §3-4(3)）.
///
/// ★★ 例外ではないが結果が完全でない ★★
/// `Loadable` の `Failed` では表せず、`Ready` に畳み込むと
/// **「成功したが不完全」が「成功」と区別できなくなる。**
/// だから `Loadable` とは別枠で持ち、別枠で画面へ出す。
///
/// ★★ `sealed` にする理由は網羅性検査である（決定 D53 と同じ）★★
/// 4 つ目を足したとき、**拾い漏らした描画側の `switch` がコンパイルエラーになる。**
/// 縮退を「見せる」ことが M3 の主題なので、見せ忘れが静かに起きる形にしない。
///
/// ★★ 3 つを 1 行にまとめない ★★
/// どれも「結果が完全でない」通知だが、**原因も利用者の対処も違う。**
/// 区別がつかないと、どれも同じ「なんか出てる」になって無視される。
///
/// | 縮退 | 原因 | 利用者の対処 |
/// |---|---|---|
/// | [SearchTruncated] | 該当が多すぎて上限で切った（決定 D50） | 検索語を足す |
/// | [SearchLikeFallback] | 2 文字以下で trigram が使えない（決定 D40） | 3 文字以上にする |
/// | [SearchMissingCards] | 刷りが 1 件も無いカードに当たった（D-8） | カードデータを更新する |
library;

sealed class SearchDegradation {
  const SearchDegradation();
}

/// 上限に達して結果を切った（決定 D50）。
///
/// ★件数だけでなく**実効上限**も持つ。`LOVECA_SEARCH_LIMIT`（決定 D64）で
/// 上書きされていると既定 2000 と違う値になり、それを知らないと
/// 「打ち切りが頻発するアプリ」だと誤認する。
final class SearchTruncated extends SearchDegradation {
  const SearchTruncated({
    required this.shown,
    required this.limit,
    required this.limitOverridden,
  });

  /// 実際に表示できたカードの種数。
  final int shown;

  /// そのとき効いていた上限。
  final int limit;

  /// ★上限が `LOVECA_SEARCH_LIMIT` で上書きされているか（決定 D64）。
  final bool limitOverridden;
}

/// trigram が使えず部分一致で引いた（決定 D40）。
///
/// trigram は 3 文字未満だと**エラーにならず静かに 0 件**を返すため、
/// `loveca_db` 側が `LIKE` に切り替えている。**切り替わったことを利用者へ伝える。**
/// ★並び順も変わる（trigram は `rank` 順 / `LIKE` は cardNumber 順）。
final class SearchLikeFallback extends SearchDegradation {
  const SearchLikeFallback();
}

/// 検索には当たったが、いまのカードデータに刷りが 1 件も無いカードがあった。
///
/// ★★ D-8（`deleteOrphanCards` の本番呼び出し元が 0）の可視化である ★★
/// `CardDao.deleteExpansion` は `printings` だけを消して `cards` と `card_search` を
/// 残すため、**検索は「存在しない刷りの cardNumber」を返しうる。**
/// 一覧は `printings JOIN cards` なので出てこないが、検索は索引を直接引くので出てくる。
///
/// ここで黙って落とすと「検索に出るのにカードが開けない」が
/// **痕跡なしで「そもそも出ない」に化ける。**根治は決定 D63（`loveca_db` 側）。
final class SearchMissingCards extends SearchDegradation {
  const SearchMissingCards(this.count);

  /// 表示できなかったカードの種数。
  final int count;
}
