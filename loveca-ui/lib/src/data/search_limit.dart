/// 検索結果の上限（決定 D50 / D64）.
///
/// ★★ `LOVECA_SEARCH_LIMIT` は検証用の口であって本番の設定経路ではない ★★
/// `LOVECA_DIST_DIR`（決定 D60 段 1）は dist の場所を指す**本番の設定経路**だが、
/// これは違う。同じ「環境変数」という場所に並ぶので、位置づけを書かないと同格に見える。
///
/// なぜ要るか: 実データの最大ヒットは `ー` の **1,034 種**で、
/// 既定の 2000（決定 D50）では**打ち切りが絶対に起こらない**。
/// 上限を下げられないと、D50 が入れた `truncated` の表示を実データで確かめる手段が無い。
///
/// ★★ 不正値を黙って既定に戻さない ★★
/// 黙って戻すのは A-3（痕跡を残さずデータを落とす）と同じ型で、
/// 「下げたはずなのに打ち切られない」が原因不明のまま残る。
/// [SearchLimitSetting.rejectedValue] に実値を残し、起動時に警告する。
///
/// ★起動は止めない。**検証用の変数が本番起動を壊せる状態にしない。**
/// `app_settings.dart` の「設定ファイルが読めなければ既定に戻したうえで警告する」
/// （`docs/UI設計メモ.md` §4-6(5)）と同じ流儀に揃えてある。
library;

import 'package:loveca_db/loveca_db.dart';

/// ★検証用。本番の設定経路ではない（決定 D64）。
const String searchLimitEnvironmentKey = 'LOVECA_SEARCH_LIMIT';

/// 解決した上限と、その出所。
class SearchLimitSetting {
  const SearchLimitSetting({
    required this.limit,
    this.overriddenValue,
    this.rejectedValue,
  });

  /// 実際に使う上限。
  final int limit;

  /// ★上書きが効いているときの実値。効いていなければ null。
  /// 打ち切りの文面に出す（上書きに気づかないと「打ち切りが頻発するアプリ」と誤認する）。
  final String? overriddenValue;

  /// ★解釈できなかった実値。黙って捨てない。
  final String? rejectedValue;

  bool get isOverridden => overriddenValue != null;

  /// 既定（決定 D50 の 2000）。
  static const SearchLimitSetting standard =
      SearchLimitSetting(limit: CardSearchDao.defaultLimit);
}

/// 環境変数の生の値から上限を決める。
///
/// ★純関数にしてある。`dart:io` に触れるのは呼び出し側（`boot_steps.dart`）だけで、
/// 解釈の規則はここだけでテストできる。
///
/// | 入力 | 結果 |
/// |---|---|
/// | null / 空白のみ | 既定。**警告しない**（未設定と同じ扱い。`LOVECA_DIST_DIR` と揃える） |
/// | 1 以上の整数 | その値。`overriddenValue` に実値 |
/// | 0 / 負数 / 非数値 | 既定。`rejectedValue` に実値 → 起動時に警告 |
SearchLimitSetting resolveSearchLimit(String? raw) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return SearchLimitSetting.standard;

  final parsed = int.tryParse(trimmed);
  // ★0 と負数も弾く。LIMIT 0 は「常に 0 件」になり、検索が壊れているのと
  //   見分けがつかない状態を作る。
  if (parsed == null || parsed < 1) {
    return SearchLimitSetting(
      limit: CardSearchDao.defaultLimit,
      rejectedValue: trimmed,
    );
  }

  return SearchLimitSetting(limit: parsed, overriddenValue: trimmed);
}
