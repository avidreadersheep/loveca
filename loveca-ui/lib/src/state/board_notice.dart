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

import '../data/energy_fill.dart';

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

/// ★★ 整理がカードマスタを引けず、種別を判定できなかった（データの問題）★★
///
/// ★10.5.2 / 10.5.3 / 10.5.4 は種別で行き先が変わるので、引けないと動かせない。
/// ★★ その札は**元の置き場に残っている**（決定 D95 / D-22）★★
///   「動かせませんでした」だけだと消えたと読める。どこに在るかを必ず言う。
/// ★黙って残さない（A-3「痕跡を残さずデータを落とす」と同じ失敗にしない）。
///
/// ★★ [TidyNoRuleForCardType] と 1 行にまとめない ★★
///   こちらは**利用者が直せる**（カードデータを取り込み直す）。あちらは直せない。
///   原因も次の一手も違うものを 1 行にすると、直せる問題が埋もれる
///   （`docs/UI設計メモ.md` §3-4 で縮退の系統を分けたのと同じ理由）。
final class TidyUnknownCard extends BoardNotice {
  const TidyUnknownCard({
    required this.stepRuleRef,
    required this.count,
    required this.cardNumbers,
  });

  final String stepRuleRef;
  final int count;
  final List<String> cardNumbers;
}

/// ★★ 種別は分かるが、条文がその行き先を定めていない（条文の問題）★★
///
/// 10.5.3 はメンバーカード、10.5.4 はエネルギーカードしか定めておらず、
/// 4.5.5 も下に重ねられるカードをこの 2 種別に限る。
/// ★アプリはサンドボックス（D-A）なのでライブカードを下に置けるが、
///   **条文が定めていない移動を実装が決めない**（D-B / 決定 D95）。
///
/// ★★ 利用者にできることは無い ★★
///   取り込み直しても解消しない。だから [TidyUnknownCard] と文面を分ける。
///   次の一手は「手で動かす」だけである。
final class TidyNoRuleForCardType extends BoardNotice {
  const TidyNoRuleForCardType({
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
///
/// ★★ ここに入るのは「整理を待っている」札だけ（決定 D95）★★
///   整理しても動かない札は [OrphanCardsStuck] に分ける。
///   同じ 1 行にすると「整理で移ります」が**動かない札にも掛かって嘘になる**。
final class OrphanCardsPresent extends BoardNotice {
  const OrphanCardsPresent({
    required this.playerLabel,
    required this.areaLabels,
  });

  final String playerLabel;

  /// 4.5.2.1 が定める領域名称（「左サイドエリア」など）。
  final List<String> areaLabels;
}

/// ★★ 整理しても動かない孤児がある（決定 D95 / D-22）★★
///
/// ★★ 「整理を待っている」と見分けがつかないと、押すたびに同じ帯が出る ★★
///   [OrphanCardsPresent] は「次のチェックタイミングで移ります」と言う。
///   動かない札にそれを言うと、押しても消えない帯を出し続けることになり、
///   本当に何か起きたときに気づけなくなる（M3 の「なんか出てる」）。
///
/// ★これは**出来事ではなく状態**なので常設の帯に出す（盤面設計メモ §10-2）。
/// ★理由ごとに 1 件ずつ作る。1 行に混ぜない（[TidyUnknownCard] の doc を参照）。
final class OrphanCardsStuck extends BoardNotice {
  const OrphanCardsStuck({
    required this.playerLabel,
    required this.areaLabels,
    required this.reason,
  });

  final String playerLabel;
  final List<String> areaLabels;

  /// なぜ動かないか。★`loveca_core` の判定をそのまま運ぶ（言い換えない）。
  final UnmovableReason reason;
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

/// ★★ エネルギーデッキ 0 枚を開始時に補った（決定 D96 / D97）★★
///
/// ★★ 黙って足さない ★★
/// 保存されたデッキは 0 枚のままで、**盤面の中身だけが違う。**
/// 出さないと「入れていないカードが山に在る」ことに気づけない
/// （**D35**「黙って削除しない」の裏返し —— 黙って足しもしない）。
///
/// ★★ 再現情報でもある ★★
/// エネルギー 0 枚は乱数を 1 つも消費しないが、12 枚なら 6.2.1.7 で 3 回消費する。
/// 6.2.1 は手順ごとに両プレイヤーを回すので、**補完の有無で相手の抽出位置までずれる**
/// （**D-17** と同型）。★**seed だけでは盤面が決まらない**ので、何を足したかを残す。
final class EnergyDeckFilled extends BoardNotice {
  const EnergyDeckFilled({
    required this.playerLabel,
    required this.cardName,
    required this.cardNumber,
    required this.count,
  });

  /// 「自分」/「相手」。★playerId を出さない（内部語彙）。
  final String playerLabel;

  final String cardName;

  /// ★cardNumber は利用者に見える語である（カードに印刷され、共有形式でも使う）。
  /// ★**printingId は出さない**（内部語彙）。
  final String cardNumber;

  final int count;
}

/// ★★ 補完に使う設定が解決できなかった（決定 D97-5）★★
///
/// ★★ 黙って 0 枚で始めない ★★
/// 0 枚のまま開始すること自体は正当（**D81** / **D-A**）だが、
/// **利用者は補完されるつもりでいる。**何が起きなかったのかを出す。
///
/// ★★ 開始は止めない ★★
/// 止めると「(a) 保存時を却下した理由」を (b) で再現することになる
/// （補完の失敗がデッキを使えなくする）。**現状の挙動に戻るだけ**にする。
///
/// ★★ 理由を 1 行にまとめない ★★
/// cardNumber ごと無い / その刷りだけ無い / 種別が違う で**次の一手が違う。**
final class EnergyFillUnavailable extends BoardNotice {
  const EnergyFillUnavailable({required this.reason, required this.cardNumber});

  final EnergyFillSkip reason;

  /// 設定値から切り出した cardNumber。★**printingId は出さない**（内部語彙）。
  final String cardNumber;
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
