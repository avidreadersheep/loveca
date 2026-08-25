/// 盤面セッションの縮退・注記（`docs/UI設計メモ.md` §3-4(3) / 盤面設計メモ §10-3）.
///
/// ★★ 4 つ目の系統である。既存の 3 つに畳まない ★★
///
/// | その縮退の寿命 | 系統 | 出る場所 |
/// |---|---|---|
/// | 検索語ごと | `SearchDegradation` | 検索結果ヘッダ |
/// | 編集セッションごと | `DeckEditDegradation` | デッキペイン |
/// | 起動時に決まり以降不変 | `BootNotice` | ★**全ルートの `NoticeBar`**（`BootGate` に一本化 / **決定 D89**） |
/// | ★**盤面セッションごと（新設）** | **[BoardNotice]** | 盤面の帯 |
///
/// ★`sealed` を文脈ごとに分ける理由は網羅性検査である（決定 D53）。
/// まとめると、他の文脈に枝を足したときここにも「盤面では起きない」枝が生え、
/// **網羅性検査の意味が薄れる。**描画だけ `ui/common/degradation_line.dart` を共有する。
///
/// ★内部語彙（instanceId / printingId / reduce）を出さない。
library;

import 'package:loveca_core/loveca_core.dart';

sealed class BoardNotice {
  const BoardNotice();
}


/// ★★ 整理（9.5.3 のチェックタイミング）で実行したルール処理（M-B3）★★
///
/// ★★ 盤面が勝手に動いたことを黙らない ★★
/// 10.4 / 10.5 は**アプリが自動で実行してよい**ルール処理だが、
/// プレイヤーから見ると「次へを押したら札が控え室へ移った」ように見える。
/// 何が起きたのかを条番号つきで出す。
final class RuleProcessApplied extends BoardNotice {
  const RuleProcessApplied({required this.stepRuleRef, required this.kinds});

  /// どのチェックタイミングでの整理か。★条番号で出す（ステップ ID は条番号そのもの）。
  final String stepRuleRef;

  /// 実行したもの。★重複しうる（同じ種別が複数枚に当たる）。
  final List<RuleProcessKind> kinds;
}

/// ★★ 自動実行せず警告に留めたルール処理（10.3 / 10.6）★★
///
/// 10.3 勝利処理 …… 決定 D10 により勝敗確定は手動。アプリが決めない
/// 10.6 不正解決領域処理 …… 「プレイ中 / 解決中」は効果の解決状態であり
///   観測できない（D-A）。自動で控え室へ送るとプレイヤーの作業を壊す
///
/// ★★ 条件が消えるまで出し続ける ★★
/// これは「起きた出来事」ではなく「いま満たされている条件」なので、
/// 次の操作 1 回で消えてはいけない（`state/game_store.dart` の `BoardTidyLog`）。
final class RuleProcessNotAutomatic extends BoardNotice {
  const RuleProcessNotAutomatic({
    required this.stepRuleRef,
    required this.kinds,
  });

  final String stepRuleRef;

  final List<RuleProcessWarningKind> kinds;
}

/// ★★ 手で押した整理（10.4 / 10.5）に当たるものが 1 つも無かった（M-B6 / 決定 D93-5）★★
///
/// ★★ 押したのに何も出ないと「壊れている」と読まれる ★★
/// このリポジトリで一貫している「黙って効かないボタンを作らない」の裏返しである。
/// ★**自動（チェックタイミング）の整理では出さない** —— そちらはほとんど毎回空なので、
/// 出すと帯が出っぱなしになって、本当に何か起きたときに気づけなくなる。
/// 撃ち分けは `state/game_store.dart` の `BoardTidyLog.manual`。
final class TidyFoundNothing extends BoardNotice {
  const TidyFoundNothing({required this.stepRuleRef});

  final String stepRuleRef;
}

/// 整理がカードマスタを引けず、種別を判定できなかった。
///
/// ★10.5.2 / 10.5.3 / 10.5.4 は種別で行き先が変わるので、引けないと動かせない。
/// ★黙って残さない（A-3「痕跡を残さずデータを落とす」と同じ失敗にしない）。
final class TidyExcluded extends BoardNotice {
  const TidyExcluded({
    required this.stepRuleRef,
    required this.count,
    required this.cardNumbers,
  });

  final String stepRuleRef;
  final int count;
  final List<String> cardNumbers;
}

/// ★★ 集計から落ちたカードがある（M-B3 / CLAUDE.md §6）★★
///
/// `LiveAggregator` は未知の cardNumber で例外を投げず、除外した事実を返り値に載せる
/// （`aggregation.dart`。実行時に落ちると対戦が続行不能になるため）。
/// ★**受け取ったまま捨てると A-3（数字なし表記を 59 種で無言に捨てていた）と同じになる。**
/// 表示している数値がその分だけ小さいことを出す。
final class AggregationExcluded extends BoardNotice {
  const AggregationExcluded({
    required this.scope,
    required this.ruleRef,
    required this.count,
    required this.cardNumbers,
  });

  /// 「自分」「相手」、または★**「解決領域（共有）」**（8.3.12 は所有者で絞らない）。
  final String scope;

  /// どの集計か。★条番号で出す（8.3.10 / 8.3.12 / 8.3.14 / 8.4.2）。
  final String ruleRef;

  final int count;

  /// ★件数だけにしない（何が引けていないか言えなくなる）。
  final List<String> cardNumbers;
}

/// 上にメンバーが居なくなったカードがある（4.5.5.4.1 / 4.5.5.4.2）。
///
/// ★★ エラーとして出さない ★★
/// 10.1.2 によりルール処理はチェックタイミングでのみ走るので、
/// これは**正規の中間状態**である（`member_area.dart`）。
final class OrphanCardsPresent extends BoardNotice {
  const OrphanCardsPresent({
    required this.playerLabel,
    required this.areaLabels,
  });

  final String playerLabel;

  /// 4.5.2.1 が定める領域名称（「左サイドエリア」など）。
  final List<String> areaLabels;
}

/// 1 つのメンバーエリアにメンバーが 2 人以上いる（10.4 待ち）。
///
/// ★★ これも正規の中間状態である ★★
/// 11.10.2 の入れ替えや 11.11.1 の再配置の途中では必ず通る。
final class DuplicateMembersPresent extends BoardNotice {
  const DuplicateMembersPresent({
    required this.playerLabel,
    required this.areaLabels,
  });

  final String playerLabel;
  final List<String> areaLabels;
}

/// デッキが 6.1 のデッキ構築条件を満たしていない。
///
/// ★★ それでも回せる。ただし黙って通さない ★★
/// アプリは「盤面・カード・山札・手札をデジタル上で操作するサンドボックス」
/// （CLAUDE.md §1 / D-A）なので、条件を満たさないデッキで回すこと自体は正当。
/// しかし**盤面から読み取れないと、あとで数が合わない理由が分からなくなる。**
///
/// ★開始ダイアログでも同じ内容を出して確認を取っている。ここは**盤面に残す**ぶん。
final class DeckNotValid extends BoardNotice {
  const DeckNotValid({required this.playerLabel, required this.issues});

  /// 「自分」/「相手」。★playerId を出さない（内部語彙）。
  final String playerLabel;

  /// `DeckValidator` が出した違反。★件数だけにしない（何が足りないか言えなくなる）。
  final List<DeckIssue> issues;
}

/// ★★ 巻き戻せる履歴が上限に達している（M-B5 / 決定 D78）★★
///
/// ★★ 黙って捨てられていることを黙らない ★★
/// `GameHistory` は上限（既定 512）を超えると**古いものから捨てる**。
/// `canUndo` は真のままなので、押しても戻れるうちは何も起きたように見えない。
/// **「これより前へは戻せない」ことに気づけるのは、到達した時点だけである。**
///
/// ★これは「押したときに分かる」ものではなく**いまそうなっている状態**なので、
/// ボタンの Tooltip ではなく盤面の帯に出す（盤面設計メモ §10-2 の 1 系統目）。
final class HistoryAtMaxDepth extends BoardNotice {
  const HistoryAtMaxDepth({required this.maxDepth});

  /// 保持している操作の件数の上限。★UI に 512 を直接書かないため値で渡す。
  final int maxDepth;
}
