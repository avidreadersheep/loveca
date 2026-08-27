/// 盤面の状態（決定 D53 / D75 / D77 / D79 / D81 / D86）.
///
/// ★★ [GameStore.dispatch] が `reduce` を呼ぶ唯一の場所である ★★
/// `state/store.dart` の doc が「Phase 3b では `GameStore.dispatch` が `reduce` を
/// 呼ぶ唯一の場所になり、Phase 6 で『サーバへ action を送って state を受け取る』に
/// 差し替える点もそこ 1 箇所になる」と定めている。**画面から `reduce` を呼ばない。**
///
/// ★★ M-B3 で `apply` から `reduceWithReport` + `record` に分けた（決定 D86）★★
/// 10.2.1 の割り込みリフレッシュ回数と整理の結果（10.3 / 10.6 の警告）を
/// **黙って落とさない**ためには [ReduceReport] が要るが、`GameSession.apply` は
/// `GameState` しか返さない。★これは盤面設計メモ §8-2 が M-B5 の
/// 合成コマンド向けに定めた形（`reduce` を回して `record` を 1 回だけ呼ぶ）と同じで、
/// **`loveca_core` の変更は要らない。**
///
/// ★★ 例外が出たら履歴に積まない ★★
/// `reduce` は呼び出し側のバグを [ArgumentError] で投げる（`reduce.dart` の `_takeOut`）。
/// 分ける前の `session.apply(a)` は「リデューサの戻り値を `record` に渡す」形であり、
/// Dart は引数を先に評価するので**投げた時点で `record` に到達しない**。
/// 分けたあとも順序は同じ —— リデューサを先に評価し、返ってきてから `record` する。
/// ★「同じはず」で済ませず `test/board/game_store_test.dart` が
/// 「投げても履歴が増えず盤面も変わらない」を固定している。
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない（決定 D55）★★
/// この Store は `Deck` と `MasterCatalog` を**値として受け取る**だけで、
/// リポジトリも DB も持たない。**盤面は保存も同期もしない**ので、
/// 盤面が DB へ行く用事がそもそも無い。
///
/// ★★ 視点（[BoardState.viewerId]）は `GameAction` ではない ★★
/// 盤面の向きは UI の状態であって、ゲームの状態ではない。
/// `reduce` を通さず [GameStore.setViewer] で変える。
///
/// ★★ seed は [GameState] にも [GameAction] にも持たせない（決定 D79）★★
/// `ReduceContext` にだけ置く。ここが `SeededRng` を 1 つ持ち、
/// 盤面セッションのあいだ**同じインスタンスを使い続ける**。
///
/// ★★ `redact` を掛けない（決定 D77 / D88 の訂正）★★
/// ★**ソロとローカル対戦で理由が違う。**ローカル対戦は 1 人が両プレイヤーを操作するので
/// 掛けると相手側を操作できなくなる。ソロは**隠す相手が居ない**。
/// **4.8 / 4.9 の秘匿は盤面 UI の責務**であり、この Store は隠さない。
/// 隠すのは `ui/board/hidden_pile.dart`（枚数しか受け取らない形）。
///
/// ★★ モードは [BoardState] ではなく [ReduceContext] へ渡す（決定 D88 / §14-3）★★
/// モードは条文の概念ではなく（1.1.1）、`GameState` に置くと **undo でモードが戻る**
/// という意味の無い操作が型の上で可能になる。★[BoardMode] はこの Store が
/// **セッションの設定として**持ち、`reduce` へは `ReduceContext.mode` で渡す。
library;

import 'package:loveca_core/loveca_core.dart';

import 'board_mode.dart';
import 'board_notice.dart';
import 'board_session.dart';
import 'counting_rng.dart';
import 'store.dart';

/// 1 つの `AdvanceStep` で起きたこと（M-B7 / 決定 D98-2）。
///
/// ★[GameState] を保持しない。値だけを写し取る。
class BoardStepLog {
  const BoardStepLog({
    required this.cursor,
    required this.taken,
    this.refreshCount = 0,
  });

  /// 実行した位置。★`AdvanceResult.executed` と同じ事実なので二重に持たない。
  final StepCursor cursor;

  /// たどった遷移。★8.3.6 の早期終了もこれで読める。
  final StepTransition taken;

  /// ★★ このステップの中で割り込んだリフレッシュの回数（10.2.1）★★
  /// ★**ステップ別に持つ**（盤面設計メモ §15-10）。1 押下で複数ステップ進むので、
  /// 合計だけだと「どのステップの途中で起きたか」が失われる。
  final int refreshCount;

  /// 条文が定める分岐（8.3.6 / 8.4.12）をたどったか。
  ///
  /// ★条番号を UI に書かないための入口。`StepDecision` は
  /// **分岐を持つステップだけ**が非 null である（`step.dart`）。
  bool get isBranch => cursor.step.decision != null;
}

/// ★★ 自動進行が止まった理由（M-B7 / 決定 D98-1）★★
///
/// ★★ 5 つを 1 つにまとめない ★★
/// 原因も「次に何をすればよいか」も違う ——
/// [playerAction] は**あなたが操作する**、[playerDeclaration] は**あなたが宣言する**、
/// [newWarning] は**手で処理する**、[refreshed] は**盤面の前提が変わった**、
/// [turnChanged] は**区切り**である。
/// ★M3 の縮退 3 種・決定 D95 の「動かせない理由」2 種と**同じ判断**である
/// （原因も対処も違うものを 1 行にまとめない）。
///
/// ★★ 格を分ける（決定 D92-3 / D73 と同じ作法）★★
/// 条文由来か実装判断かで [isFromRules] が分かれる。混ぜると、次に問われたときに
/// **存在しない条文を探すことになる。**
enum BoardStopReasonKind {
  /// 条文がプレイヤーの選択・判断・盤面操作を求めている（R-S1 / `StepId.requiresPlayerAction`）。
  playerAction,

  /// 条文が定める分岐で、プレイヤーの宣言が要る（8.4.12 / `StepDecision.playerDeclared`）。
  playerDeclaration,

  /// アプリが自動実行しないルール処理が**新しく**成立した（10.3 / 10.6）。
  newWarning,

  /// ★リフレッシュ（10.2.1）が割り込んだ。★**条文由来ではない**（決定 D92-3）。
  refreshed,

  /// ★ターン番号が変わった（8.4.14）。★**条文由来ではない**（決定 D92-3 / §15-6）。
  turnChanged;

  /// ★★ 条文から導いた停止点か（true）、実装の判断か（false）★★
  /// ★画面の文面にも出す。書かないと、次に「条文由来でないから外そう」となる。
  bool get isFromRules => switch (this) {
        playerAction || playerDeclaration || newWarning => true,
        refreshed || turnChanged => false,
      };
}

/// 自動進行が止まった理由 1 件（M-B7 / 決定 D98-1）。
///
/// ★★ 成立したものは**全部**出す。1 つに絞らない ★★
/// 新規警告とターン変化が同じ押下で成立することはある（盤面設計メモ §15-6）。
class BoardStopReason {
  const BoardStopReason({
    required this.kind,
    required this.cursor,
    this.warnings = const [],
    this.refreshCount = 0,
    this.turnNumber = 0,
  });

  final BoardStopReasonKind kind;

  /// 止まった位置。★条番号はここから取る（UI に書かない）。
  final StepCursor cursor;

  /// [BoardStopReasonKind.newWarning] のとき、**新しく**立った警告の種類。
  final List<RuleProcessWarningKind> warnings;

  /// [BoardStopReasonKind.refreshed] のとき、割り込んだ回数。
  final int refreshCount;

  /// [BoardStopReasonKind.turnChanged] のとき、変わったあとのターン番号。
  final int turnNumber;
}

/// 自動進行の途中経過。★停止判定の入力（M-B7 / 決定 D98-5）。
class BoardAdvanceProgress {
  const BoardAdvanceProgress({
    required this.state,
    required this.turnNumberBefore,
    required this.stepsTaken,
    required this.lastRefreshCount,
    required this.newWarnings,
  });

  /// 直前のステップを実行し終えた時点の盤面。★カーソルは**次に実行する**位置。
  final GameState state;

  /// この押下を始めた時点のターン番号。
  final int turnNumberBefore;

  /// この押下でここまでに実行したステップ数。★**必ず 1 以上**である。
  final int stepsTaken;

  /// 直前のステップで割り込んだリフレッシュの回数（10.2.1）。
  final int lastRefreshCount;

  /// ★直前の整理で**新しく**立った警告の種類（10.3 / 10.6）。
  final List<RuleProcessWarningKind> newWarnings;
}

/// ★★ 既定の停止判定（R-S1 + R-S2 / 決定 D92）★★
///
/// ★★ bool ではなく理由の一覧を返す ★★
/// 成立したものを**全部**出すためである（§15-6）。1 つに絞ると
/// 「なぜ止まったか」が押下ごとに片方だけ見える。
///
/// ★★ 10.4 / 10.5 の適用では止まらない ★★
/// 孤児カード・重複メンバーは**正規の中間状態**で、盤面に残っていれば毎 CT
/// 適用対象になる。止めると**正常な状態で止まり続ける。**
/// → **全件を報告するが、止まらない。**
List<BoardStopReason> autoAdvanceStops(BoardAdvanceProgress progress) {
  final cursor = progress.state.cursor;
  return [
    // ---- R-S1（静的 / 条文由来）----
    if (cursor.step.requiresPlayerAction)
      BoardStopReason(
          kind: BoardStopReasonKind.playerAction, cursor: cursor),
    if (cursor.step.decision == StepDecision.playerDeclared)
      BoardStopReason(
          kind: BoardStopReasonKind.playerDeclaration, cursor: cursor),
    // ---- R-S2（動的）----
    if (progress.newWarnings.isNotEmpty)
      BoardStopReason(
        kind: BoardStopReasonKind.newWarning,
        cursor: cursor,
        warnings: progress.newWarnings,
      ),
    if (progress.lastRefreshCount > 0)
      BoardStopReason(
        kind: BoardStopReasonKind.refreshed,
        cursor: cursor,
        refreshCount: progress.lastRefreshCount,
      ),
    if (progress.state.turnNumber != progress.turnNumberBefore)
      BoardStopReason(
        kind: BoardStopReasonKind.turnChanged,
        cursor: cursor,
        turnNumber: progress.state.turnNumber,
      ),
  ];
}

/// ★★ 直前の 1 押下の結果（M-B3 / 決定 D86 / ★M-B7 で押下 1 回ぶんへ広げた）★★
///
/// ★★ 単数だったものを列にした理由（新所見 D-21 の本体 / 決定 D98-2）★★
/// M-B6 までは `executed` / `taken` が**最後の 1 件**を指し、`cursorBefore` は
/// **合成全体の開始位置**だった。2 つ以上の `AdvanceStep` を合成すると
/// **2 つのフィールドが別のステップを指す。**
/// 自動進行（決定 D92）は 1 押下で平均 6 ステップ進むのでこれを直接踏む。
/// → **[steps] に全件を積む。**★`refreshCount` が元から `+=` だったのと同じ形である。
class BoardOperationLog {
  const BoardOperationLog({
    required this.cursorBefore,
    required this.cursorAfter,
    this.steps = const [],
    this.stops = const [],
    this.refreshCount = 0,
    this.skipped = const [],
  });

  /// その押下を始めた時点の進行位置。
  final StepCursor cursorBefore;

  /// ★★ その押下を終えた時点の進行位置（M-B7）★★
  ///
  /// ★[steps] から導けない —— 最後の遷移がフェイズを終える場合、着地先は
  /// 次のフェイズの先頭であり、さらに `skipForward` が飛ばした先になりうる。
  /// **導けないものを導いたことにしない。**
  final StepCursor cursorAfter;

  /// ★この押下で実行したステップ**全件**。★`AdvanceStep` 以外では空。
  final List<BoardStepLog> steps;

  /// ★★ 自動進行が止まった理由（M-B7 / 決定 D98-1）★★
  /// ★成立したものを**全部**。1 ステップだけ進める口では空である。
  final List<BoardStopReason> stops;

  /// この押下の中で割り込んだリフレッシュの合計回数（総合ルール 10.2.1）。
  ///
  /// ★内訳は [BoardStepLog.refreshCount]。★`AdvanceStep` 以外でも起こりうるので
  /// **合計は [steps] の和とは限らない**（だから別に持つ）。
  final int refreshCount;

  /// ★★ 実行せずに通り越したカーソル（決定 D88）★★
  /// ソロでのみ空でなくなる。**黙って飛ばさない** —— 1 回の「次へ」で
  /// 4 フェイズを跨ぐことがあるので、出さないと「勝手に飛んだ」ように見える。
  /// ★M-B7 で**押下ぶん連結**するようにした（最後の 1 件で上書きしない）。
  final List<StepCursor> skipped;

  /// たどった遷移の最後の 1 件。★1 ステップだけ進んだときの読みやすさのために持つ。
  BoardStepLog? get lastStep => steps.isEmpty ? null : steps.last;

  /// 見せるものが何も無いか。
  bool get isEmpty =>
      steps.isEmpty && refreshCount == 0 && skipped.isEmpty;
}

/// 直前の整理（チェックタイミング 9.5.3）の結果（M-B3 / 決定 D86 / D93）。
///
/// ★★ 整理が起きたときだけ差し替える ★★
/// ドラッグ 1 回で 10.3（勝利処理）の警告が消えると、**黙って落とした**のと同じになる。
/// → [GameStore.dispatchAll] は整理が 1 件も起きなかったとき**前の値を残す。**
/// 見出しに「直前の整理」と条番号を出すので、古い値が現在の状態に見えることはない。
///
/// ★★ 1 押下で**複数件**出る（決定 D93-5 / 盤面設計メモ §14-7 の持ち越し 4 つ目）★★
/// 手で押した [Tidy] は 1 件しか出さないが、**M-B7 の自動進行は 1 押下で
/// 複数のチェックタイミングを通る**ので N 件出る。
/// → [BoardState.tidies] は **`List`** である。★M-B6 の完成条件ではないが、
/// 単数で作り込むと M-B7 で作り直しになる（§15-12 の根拠 3）。
/// ★各件が自分の [cursor] を持つので、平坦に並べても**どの CT のものかが読める**
/// （§15-10「CT 単位に 1 行。フェイズ単位にまとめない」）。
class BoardTidyLog {
  const BoardTidyLog({
    required this.cursor,
    this.applied = const [],
    this.warnings = const [],
    this.unmovable = const [],
    this.manual = false,
  });

  /// どのチェックタイミングでの整理か。
  final StepCursor cursor;

  /// 実行したルール処理（10.4 / 10.5）。
  final List<RuleProcessKind> applied;

  /// ★自動実行せず警告に留めたもの（10.3 / 10.6）。
  final List<RuleProcessWarningKind> warnings;

  /// ★★ 動かせなかった札。**元の置き場に残っている**（決定 D95 / D-22）★★
  ///
  /// ★理由が 2 つあり（[UnmovableReason]）、利用者にできることが違う。
  ///   帯では理由ごとに 1 行を作る。件数だけに畳まない。
  final List<UnmovableCard> unmovable;

  /// [reason] の札の cardNumber（重複排除・昇順）。★帯の文面に入れる。
  List<String> unmovableNumbersFor(UnmovableReason reason) =>
      ({for (final c in unmovable) if (c.reason == reason) c.cardNumber}.toList()
        ..sort());

  /// [reason] の札の枚数。
  int unmovableCountFor(UnmovableReason reason) =>
      unmovable.where((c) => c.reason == reason).length;

  /// ★★ プレイヤーが「整理する」を押して起きた整理か（M-B6 / 決定 D93-5）★★
  ///
  /// ★★ 当たるものが無かったときの扱いが変わる ★★
  ///   自動（チェックタイミング）の整理は**ほとんど毎回空**なので、
  ///   空でも行を出すと帯が出っぱなしになる。
  ///   手で押したときは違う —— **押したのに何も出ないと「壊れている」と読まれる。**
  ///   → [manual] のときだけ [TidyFoundNothing] を出す。
  final bool manual;

  /// 10.4 / 10.5 が 1 件も当たらなかったか。
  ///
  /// ★★ 抑止できるのは「その押下が生んだ事実」だけ（盤面設計メモ §10-2）★★
  ///
  /// [warnings]（10.3 / 10.6）は `RuleProcessor.warningsFor` が
  /// **盤面を変更せずに返す「いま成立している条件」**であって、押した結果ではない。
  /// 押す前から真で、押した後も真である。
  /// → 条件に混ぜると、**押す前から在った 10.3 の警告が
  ///   「押しても何も起きなかった」を隠す。**（M-B6 の実機確認で実際に起きた / D94-2）
  ///
  /// ★[unmovable] は逆に混ぜる。**この押下の中で起きた**うえ、
  /// 動かせなかった札がある以上「当たるものは無かった」と**言い切れない**。
  ///
  /// ★★ 理由が 2 つあるが、抑止するかの答えは同じである（決定 D95）★★
  ///   [UnmovableReason.unknownCard] は「見えていない」（D-10 の区別そのもの）。
  ///   [UnmovableReason.noRuleForCardType] は種別まで分かっているが、
  ///   **当たる候補は在って行き先が無い**ので「当たるものが無かった」とは違う。
  ///   → どちらでも「ありませんでした」は出さない。
  /// ★黙りはしない —— [TidyUnknownCard] / [TidyNoRuleForCardType] が
  /// **この押下の結果として**答える。
  bool get appliedNothing => applied.isEmpty && unmovable.isEmpty;

  /// 帯に出す行。★描画は `ui/board/board_notice_bar.dart` が持つ。
  ///
  /// ★★ 早期 return を置かないこと ★★
  /// 各行は互いに独立した問いへの答えである。1 つの条件でまとめて畳むと、
  /// **どれか 1 つが立っただけで他の答えが消える。**
  /// （実際に [warnings] が立つと「ありませんでした」が消えていた）
  List<BoardNotice> get notices {
    final ruleRef = cursor.step.ruleRef;
    return [
      if (applied.isNotEmpty)
        RuleProcessApplied(stepRuleRef: ruleRef, kinds: applied),
      // ★手で押して何も当たらなかったことを黙らない（黙って効かないボタンにしない）。
      //   ★自動（チェックタイミング）では出さない —— ほとんど毎回空なので、
      //     出すと帯が出っぱなしになって本当に何か起きたときに気づけなくなる。
      if (manual && appliedNothing) TidyFoundNothing(stepRuleRef: ruleRef),
      if (warnings.isNotEmpty)
        RuleProcessNotAutomatic(stepRuleRef: ruleRef, kinds: warnings),
      // ★★ 理由ごとに 1 行。混ぜない（`state/board_notice.dart` の doc）★★
      if (unmovableCountFor(UnmovableReason.unknownCard) > 0)
        TidyUnknownCard(
          stepRuleRef: ruleRef,
          count: unmovableCountFor(UnmovableReason.unknownCard),
          cardNumbers: unmovableNumbersFor(UnmovableReason.unknownCard),
        ),
      if (unmovableCountFor(UnmovableReason.noRuleForCardType) > 0)
        TidyNoRuleForCardType(
          stepRuleRef: ruleRef,
          count: unmovableCountFor(UnmovableReason.noRuleForCardType),
          cardNumbers: unmovableNumbersFor(UnmovableReason.noRuleForCardType),
        ),
    ];
  }
}

/// ★★ 整理の帯を畳み始める行数（M-B7 / 決定 D98-3 / 盤面設計メモ §15-10）★★
///
/// ★★ この値は暫定である ★★
/// 条文にも外部標準にも根拠が無い（整理の報告量を定めた条は無い）。
/// **実装の判断**であり、判断基準を**測る前に**宣言してある ——
/// 「**整理の帯が U19 の採用値を押し上げないこと**」。
/// ★見直す条件: `test/board/board_min_width_test.dart` の U19 の測定で、
/// 最も混んだ押下の帯が採用値を押し上げたとき。
/// ★D61 / U16 / U20 が「外部標準 / 条文由来 / 実測」の格を分けたのと同じ扱いである。
const int kTidyNoticeFoldThreshold = 3;

/// ★★ 1 押下ぶんの整理の報告を帯の行へ畳む（M-B7 / 決定 D98-3）★★
///
/// ★★ 既定は「チェックタイミングごと・理由ごとに 1 行」である ★★
/// 自動進行は 1 押下で複数の CT を通るので、1 CT 最大 5 行 × 6 CT = 最大 30 行になる。
/// **「なんか出てる」を超えて画面を埋める**ので、[kTidyNoticeFoldThreshold] を
/// 超えたら畳む。
///
/// ★★ 種類を跨いで畳まない ★★
/// D94-2 / D95 が行を分けたのは「**次の一手が違う**」からである ——
/// カードデータを取り込み直す / 手で動かす / 手で処理する / 報告のみ。
/// **種類を混ぜると次の一手が消える。**
///
/// ★★ カード番号を落とさない ★★
/// `TidyUnknownCard` は「どの札を取り込み直すか」、`TidyNoRuleForCardType` は
/// 「どの札を手で動かすか」が**対処そのもの**である。
/// → 畳むときは**和集合・重複排除・昇順**にする。
///
/// ★★ どの時点かも落とさない ★★
/// 8.4 にはチェックタイミングが 4 つあり、まとめると「**どの時点で消えたか**」が
/// 読めなくなる（§15-10）。→ **起きた条番号を並べて残す。**
List<BoardNotice> foldedTidyNotices(
  List<BoardTidyLog> tidies, {
  int threshold = kTidyNoticeFoldThreshold,
}) {
  final flat = [for (final tidy in tidies) ...tidy.notices];
  if (flat.length <= threshold) return flat;

  final applied = <RuleProcessKind>[];
  final warnings = <RuleProcessWarningKind>[];
  final unknown = _FoldedUnmovable();
  final noRule = _FoldedUnmovable();
  final appliedRefs = <String>{};
  final warningRefs = <String>{};
  final nothing = <BoardNotice>[];

  for (final notice in flat) {
    switch (notice) {
      case RuleProcessApplied(:final stepRuleRef, :final kinds):
        applied.addAll(kinds);
        appliedRefs.add(stepRuleRef);
      case RuleProcessNotAutomatic(:final stepRuleRef, :final kinds):
        warnings.addAll(kinds);
        warningRefs.add(stepRuleRef);
      case TidyUnknownCard(:final stepRuleRef, :final count, :final cardNumbers):
        unknown.add(stepRuleRef, count, cardNumbers);
      case TidyNoRuleForCardType(
          :final stepRuleRef,
          :final count,
          :final cardNumbers
        ):
        noRule.add(stepRuleRef, count, cardNumbers);
      // ★手で押したときだけ出るので、自動進行の押下には現れない。畳まない。
      default:
        nothing.add(notice);
    }
  }

  return [
    if (applied.isNotEmpty)
      RuleProcessApplied(stepRuleRef: _joinRefs(appliedRefs), kinds: applied),
    ...nothing,
    if (warnings.isNotEmpty)
      RuleProcessNotAutomatic(
        stepRuleRef: _joinRefs(warningRefs),
        // ★警告は同じ種類が何度も立つ。行の意味は「立っている」なので重複を畳む。
        kinds: warnings.toSet().toList(),
      ),
    if (unknown.count > 0)
      TidyUnknownCard(
        stepRuleRef: _joinRefs(unknown.refs),
        count: unknown.count,
        cardNumbers: unknown.sortedNumbers,
      ),
    if (noRule.count > 0)
      TidyNoRuleForCardType(
        stepRuleRef: _joinRefs(noRule.refs),
        count: noRule.count,
        cardNumbers: noRule.sortedNumbers,
      ),
  ];
}

/// ★並びを決定的にする（`_countedRuleProcess` と同じ方針）。
String _joinRefs(Set<String> refs) => (refs.toList()..sort()).join(' / ');

class _FoldedUnmovable {
  final refs = <String>{};
  final _numbers = <String>{};
  var count = 0;

  void add(String ref, int n, List<String> numbers) {
    refs.add(ref);
    count += n;
    _numbers.addAll(numbers);
  }

  List<String> get sortedNumbers => _numbers.toList()..sort();
}

/// 直前の巻き戻しの結果（M-B5 / 決定 D78 / D90）。
///
/// ★★ 寿命は「次の操作まで」である ★★
/// 盤面設計メモ §10-2 の 3 系統のうち「進行の結果」と同じ扱いにしてある。
/// 巻き戻したことが読めないと、**盤面だけが黙って変わる。**
class BoardRewindLog {
  const BoardRewindLog({
    required this.wholeStep,
    required this.entriesPopped,
    required this.landedCursor,
    required this.landedTurnNumber,
    required this.landedOnSameStep,
    required this.rngConsumed,
  });

  /// `undoStep`（1 ステップ戻す）なら true。`undo`（1 操作戻す）なら false。
  final bool wholeStep;

  /// この巻き戻しで取り消した操作の件数。★`undoStep` では 2 件以上になりうる。
  final int entriesPopped;

  final StepCursor landedCursor;

  final int landedTurnNumber;

  /// ★★ 着地先が巻き戻す前と同じステップか ★★
  /// `undoStep` には着地点が 2 通りある（`history.dart`）——
  /// ①そのステップ内で操作していたなら**そのステップの入口**（カーソルは変わらない）
  /// ②入った直後なら**1 つ前のステップ**。
  /// ★「カーソルが変わったか」を成否の signal にしないためにここへ持つ。
  final bool landedOnSameStep;

  /// ★★ 取り消した操作が乱数を消費していたか（決定 D78）★★
  /// **真のときだけ**「引き直せない」注記を出す。毎回出すと無視される。
  /// ★判定は列挙ではなく [CountingRng] の実測。理由はそのファイルの doc。
  final bool rngConsumed;
}

/// 履歴 1 件ぶんの、UI 側の付随情報（M-B5）。
///
/// ★★ `GameHistory` は [GameState] しか持たない ★★
/// 「直前の操作」「直前の整理」「乱数を消費したか」は `loveca_core` の履歴に無いので、
/// UI が**並行して**同じ深さのスタックで持つ。
/// ★`loveca_core` に持たせない —— Phase 6 の権威サーバに UI の表示都合を持ち込まない。
class _AppliedLog {
  const _AppliedLog({
    required this.operation,
    required this.tidies,
    required this.rngConsumed,
  });

  final BoardOperationLog? operation;

  /// ★1 押下で起きた整理**全件**（決定 D93-5）。
  final List<BoardTidyLog> tidies;

  final bool rngConsumed;
}

/// 1 押下ぶんの積み上げ（M-B7 / 決定 D98-5）。
///
/// ★★ `refreshCount` / `tidies` / `steps` / `skipped` は**すべて積む** ★★
/// 最後の 1 件で上書きすると、自動進行が複数ステップ進んだときに
/// 途中の警告も分岐もスキップも黙って消える（新所見 **D-21**）。
class _Run {
  _Run(this.state, this._warningBaseline);

  GameState state;

  /// ★★ 直前に観測した警告の集合（決定 D92 / §15-5）★★
  /// 押下の中で走りながら更新する。
  Set<RuleProcessWarningKind> _warningBaseline;

  final applied = <GameAction>[];
  final steps = <BoardStepLog>[];
  final stops = <BoardStopReason>[];
  final tidies = <BoardTidyLog>[];
  final skipped = <StepCursor>[];
  var refreshCount = 0;

  /// 直前のアクションで割り込んだリフレッシュの回数。
  var lastRefreshCount = 0;

  /// ★直前の整理で**新しく**立った警告の種類。整理が起きなければ空。
  var lastNewWarnings = const <RuleProcessWarningKind>[];

  void absorb(StepCursor cursorBefore, GameAction action, ReduceReport report) {
    state = report.state;
    applied.add(action);
    refreshCount += report.refreshCount;
    lastRefreshCount = report.refreshCount;
    lastNewWarnings = const [];

    // ★★ 整理は**全件**積む（M-B6 / 決定 D93-5 / 新所見 D-21 の器）★★
    //   最後の 1 件で上書きすると、自動進行が複数の CT を通ったときに
    //   途中の 10.3 / 10.6 の警告が黙って落ちる。
    if (report.tidy case final result?) {
      tidies.add(BoardTidyLog(
        cursor: cursorBefore,
        applied: result.applied,
        warnings: result.warnings,
        unmovable: result.unmovable,
        // ★手で押した [Tidy] だけが「何も当たらなかった」を出す。
        manual: action is Tidy,
      ));
      // ★★ 同一視は**種類だけ**（決定 D92 / 未決 U25）★★
      //   `RuleProcessResult.warnings` は対象カードを 1 つも持たない。
      //   **持っていないものを比較に使わない。**
      lastNewWarnings = result.warnings
          .where((kind) => !_warningBaseline.contains(kind))
          .toSet()
          .toList();
      _warningBaseline = result.warnings.toSet();
    }

    // ★★ 進行も**全件**積む（M-B7 / 新所見 D-21 の本体 / 決定 D98-2）★★
    if (report.advance case final result?) {
      steps.add(BoardStepLog(
        cursor: cursorBefore,
        taken: result.taken,
        refreshCount: report.refreshCount,
      ));
      skipped.addAll(result.skipped);
    }
  }
}

/// 盤面 1 セッションぶんの状態。
class BoardState {
  const BoardState({
    required this.session,
    required this.viewerId,
    required this.mode,
    required this.seed,
    this.notices = const [],
    this.operation,
    this.tidies = const [],
    this.rewind,
    this.log = const [],
  });

  /// 盤面と履歴（決定 D36）。
  final GameSession session;

  /// ★★ 盤面の向きを決める唯一の値（決定 D75）★★
  /// 下段が常にこのプレイヤー。鏡像も袖の割り当ても手札の帯もここから決まる。
  ///
  /// ★手番（`turnPlayerOf`）とは別物。混ぜると 8.4.13 の入れ替え後に手番が誤る。
  final String viewerId;

  /// ★★ 盤面のモード（決定 D88）。開始時に決まり以降不変 ★★
  /// 切り替えると 6.2.1 をやり直すことになり「同じ seed で同じ盤面」が崩れる。
  final BoardMode mode;

  /// この盤面を作った seed（決定 D79）。★画面に出す。
  final int seed;

  /// 盤面セッションのあいだ出し続ける注記。★開始時に決まり以降不変。
  final List<BoardNotice> notices;

  /// 直前の 1 操作の結果。★まだ何もしていなければ null。
  final BoardOperationLog? operation;

  /// ★★ 直前の 1 押下で起きた整理**全件**（M-B6 / 決定 D93-5）★★
  ///
  /// ★整理が 1 件も起きるまで空。★**単数にしない** —— M-B7 の自動進行は
  /// 1 押下で複数のチェックタイミングを通るので N 件出る（盤面設計メモ §14-7）。
  final List<BoardTidyLog> tidies;

  /// 直前の巻き戻しの結果（M-B5）。★次の操作で消える。
  final BoardRewindLog? rewind;

  /// ★★ セッションのログ（決定 D78 / `board_session.dart`）★★
  /// 巻き戻しも発生順に載っている。**同じ seed・同じモードで再生できる。**
  final List<BoardLogEntry> log;

  GameState get state => session.state;

  /// [viewerId] の相手。★★ソロでは null★★（決定 D88 / §14-5）。
  ///
  /// ★`GameState.players` は 3 モードとも 2 人のままである（1.1.1）。
  /// **2 人居ることと、ソロに相手が居ることは別**なので、ここで型を落とす。
  /// ★これにより視点切替（[setViewer]）の呼び出し側がコンパイルエラーになる。
  String? get opponentId => mode.hasOpponent
      ? state.players.firstWhere((p) => p.playerId != viewerId).playerId
      : null;

  /// ★★ `clear*` を置いてある理由（M-B5）★★
  /// `x ?? this.x` だけだと **null にできない**。巻き戻すと「直前の操作」も
  /// 「直前の整理」も**その時点の値へ戻す**必要があり、戻した先が「まだ何もしていない」
  /// なら null にしなければならない。放っておくと古い「直前:」が現在の状態に見える。
  /// ★前例は `data/deck_list_store.dart` の `clearActionError`。
  BoardState copyWith({
    GameSession? session,
    String? viewerId,
    BoardOperationLog? operation,
    bool clearOperation = false,
    List<BoardTidyLog>? tidies,
    bool clearTidies = false,
    BoardRewindLog? rewind,
    bool clearRewind = false,
    List<BoardLogEntry>? log,
  }) =>
      BoardState(
        session: session ?? this.session,
        viewerId: viewerId ?? this.viewerId,
        mode: mode,
        seed: seed,
        notices: notices,
        operation: clearOperation ? null : (operation ?? this.operation),
        // ★null を渡すと「前の整理を残す」（[BoardTidyLog] の doc）。
        //   消すのは巻き戻しのときだけなので、明示の [clearTidies] で行う。
        tidies: clearTidies ? const [] : (tidies ?? this.tidies),
        rewind: clearRewind ? null : (rewind ?? this.rewind),
        log: log ?? this.log,
      );
}

class GameStore extends Store<BoardState> {
  /// ★★ [mode] は required である（core の既定 `twoPlayer` との非対称）★★
  /// `loveca_core` の [ProgressionMode] が既定を持つのは、モードが条文の概念ではなく
  /// （1.1.1）、[ReduceContext] を組むすべての経路がモードを意識する必要が無いため。
  /// ★**盤面はモードが必ず 1 つに決まる文脈**なので required にできる。
  /// 既定値は「指定し忘れがコンパイルで止まらない」= 漏れうる構造であり、
  /// D49 / D77 / D80 が一貫して退けてきた形である。
  /// ★利得: **どのテストがどのモードを試しているかが型で見える。**
  ///
  /// ★★ [historyMaxDepth] を引数にしてある理由（M-B5）★★
  /// 既定の 512 は**手では到達させられない**（512 回操作するテストは書けない）。
  /// 到達したことを帯に出す（決定 D78「捨てたことを黙らない」）以上、
  /// **到達を本当に起こすテスト**が要る。
  /// ★前例は `loveca_core` の `skipForward` が `isSkipped` を関数で受けていること ——
  /// 「到達しない列挙値を足す（＝ 死んだ枝を作る）代わりの手当て」と同じ形である。
  ///
  /// ★★ [rng] を [CountingRng] で包む（M-B5 / `counting_rng.dart`）★★
  /// 「乱数を消費したか」を**列挙ではなく実測で**判定するため。素通しの包みなので
  /// 同じ seed なら同じ列が出る（`test/state/counting_rng_test.dart` が固定）。
  /// ★包んだものを [_rng] と [_context] が**同じインスタンスとして**共有する必要が
  /// あるので、初期化子リストでは書けず私設コンストラクタへ委譲している。
  factory GameStore({
    required GameState initialState,
    required String viewerId,
    required BoardMode mode,
    required int seed,
    required Map<String, Card> cards,
    required DeterministicRng rng,
    List<BoardNotice> notices = const [],
    int historyMaxDepth = 512,
  }) =>
      GameStore._(
        initialState: initialState,
        viewerId: viewerId,
        mode: mode,
        seed: seed,
        cards: cards,
        rng: CountingRng(rng),
        notices: notices,
        historyMaxDepth: historyMaxDepth,
      );

  GameStore._({
    required GameState initialState,
    required String viewerId,
    required BoardMode mode,
    required int seed,
    required Map<String, Card> cards,
    required CountingRng rng,
    required List<BoardNotice> notices,
    required int historyMaxDepth,
  })  : _rng = rng,
        _context = ReduceContext(cards: cards, rng: rng, mode: mode.progression),
        super(BoardState(
          session: GameSession(
            state: initialState,
            history: GameHistory(maxDepth: historyMaxDepth),
          ),
          viewerId: viewerId,
          mode: mode,
          seed: seed,
          notices: notices,
        ));

  /// ★乱数はセッションのあいだ同じインスタンスを使い続ける。
  ///   毎回作り直すと同じ札が出続ける。
  final ReduceContext _context;

  /// [_context] が持っているものと**同じインスタンス**。消費数を読むために持つ。
  final CountingRng _rng;

  /// ★★ 履歴と同じ深さの並行スタック（M-B5）★★
  /// `GameHistory` は [GameState] しか持たないので、UI の付随情報はこちらに積む。
  /// **`_ops.length == value.session.history.depth` を常に保つ。**
  final _ops = <_AppliedLog>[];

  /// cardNumber -> Card。★集計（`state/board_summary.dart`）が要る。
  Map<String, Card> get cards => _context.cards;

  /// 1 つのアクションを適用する。★[dispatchAll] の 1 件版。
  void dispatch(GameAction action) => dispatchAll([action]);

  /// ★★ `reduce` を呼ぶ唯一の場所 ★★
  ///
  /// ★★ 合成コマンド（決定 D78 / 盤面設計メモ §8-2）★★
  /// `reduce` を N 回回して合成状態を作り、`record` を **1 回だけ**呼ぶ。
  /// これにより N 個のアクションが**履歴 1 件 = 1 undo** になる。
  /// `GameSession.apply` を N 回呼ぶと undo が N 回要るので、
  /// プレイヤーには 1 操作に見えるものが 1 回で戻らない。
  ///
  /// ★★ [dispatch] をここへ畳んである ★★
  /// 経路を 2 本にすると `reduce` の呼び出し口が 2 つになる。
  /// `test/board/reduce_call_site_test.dart` が「`game_store.dart` にちょうど 1 件」を
  /// 走査で固定しているのは、Phase 6 の差し替え点を 1 箇所に保つためである。
  ///
  /// ★★ 途中で投げたときの扱い ★★
  /// N 回のうち k 回目が投げたら、**1〜k-1 回目の結果も残らない。**
  /// [state] への代入がループの外に 1 回しか無いので、`value` は `identical` のまま。
  /// 履歴も 1 件も増えない（`record` に到達しない）。
  /// ★**ただし乱数は進む。**1〜k-1 回目が消費したぶんは戻せない。
  /// これは未決 **U15**（巻き戻しても乱数が張り直されない）と同じ性質であり、
  /// **同じ引き金を踏んだときに一緒に解く。**
  void dispatchAll(List<GameAction> actions) {
    var index = 0;
    _run((run) => index < actions.length ? actions[index++] : null);
  }

  /// ★★ 次の停止点まで進む（M-B7 / 決定 D92）。1 押下 = 履歴 1 件 ★★
  ///
  /// ★★ 最低 1 ステップは必ず実行する ★★
  /// 停止点の上で押したということは、プレイヤーがそこを済ませたということである。
  /// 実行してから、次の停止点まで進む。
  ///
  /// ★★ [stopsAt] を関数で受ける理由 ★★
  /// 「停止点が 1 つも無い設定」を**テストから実際に踏ませる**ため。
  /// `loveca_core` の `skipForward` が `isSkipped` を関数で受けているのと同じ手当てで、
  /// **到達しない列挙値を足す（＝死んだ枝を作る）代わり**である。
  /// ★bool ではなく**理由の一覧**を返す —— 成立したものを全部出すため（§15-6）。
  ///
  /// ★★ 無限ループの番人 ★★
  /// 1 押下で [maxPhaseHops] を超えてフェイズを跨いだら [StateError]。
  /// `skipForward` の `hop()` と同じ形である。
  ///
  /// ★★ 既定値には**到達できない**（実測で確かめた）★★
  /// 停止点を 1 つも持たない設定にしても、8.4.12 が `choice` なしで
  /// [ArgumentError] を投げるので、**フェイズを 1 周する前に必ず止まる。**
  /// → **番人が働くことを見るには上限を下げるしかない。**
  /// ★`historyMaxDepth`（512 は手では到達させられない / M-B5）と同じ手当てである。
  /// ★**本番でこれを渡さない。**
  ///
  /// ★[choice] は**最初の 1 ステップにだけ**渡る。2 歩目以降で宣言が要る位置
  /// （8.4.12）に着いたら、その手前で必ず止まる（`stopsAutoAdvance`）。
  void advanceToStop({
    StepTransition? choice,
    List<BoardStopReason> Function(BoardAdvanceProgress) stopsAt =
        autoAdvanceStops,
    int? maxPhaseHops,
  }) {
    final hopLimit = maxPhaseHops ?? phaseCycle.length;
    final turnNumberBefore = value.state.turnNumber;
    var phase = value.state.cursor.phase;
    var phaseHops = 0;

    _run((run) {
      if (run.steps.isNotEmpty) {
        final reasons = stopsAt(BoardAdvanceProgress(
          state: run.state,
          turnNumberBefore: turnNumberBefore,
          stepsTaken: run.steps.length,
          lastRefreshCount: run.lastRefreshCount,
          newWarnings: run.lastNewWarnings,
        ));
        if (reasons.isNotEmpty) {
          run.stops.addAll(reasons);
          return null;
        }
        if (run.state.cursor.phase != phase) {
          phase = run.state.cursor.phase;
          phaseHops++;
          if (phaseHops > hopLimit) {
            // ★停止点が 1 つも無い設定を入れると無限ループになる。数えて止める。
            throw StateError(
              '1 回の「次へ」でフェイズを $hopLimit 回より多く跨いだ。'
              '停止点が 1 つも無い設定になっている（${run.state.cursor}）',
            );
          }
        }
      }
      return AdvanceStep(choice: run.steps.isEmpty ? choice : null);
    });
  }

  /// ★★ `reduce` を呼ぶ唯一の場所 ★★
  ///
  /// ★★ 固定列（[dispatchAll]）も自動進行（[advanceToStop]）もここを通る ★★
  /// 経路を 2 本にすると `reduce` の呼び出し口が 2 つになる。
  /// `test/board/reduce_call_site_test.dart` が「`game_store.dart` にちょうど 1 件」を
  /// 走査で固定しているのは、Phase 6 の差し替え点を 1 箇所に保つためである。
  /// ★[nextAction] が null を返すまで回す。**次に何をするかだけが違う。**
  ///
  /// ★★ 合成コマンド（決定 D78 / 盤面設計メモ §8-2）★★
  /// `reduce` を N 回回して合成状態を作り、`record` を **1 回だけ**呼ぶ。
  /// これにより N 個のアクションが**履歴 1 件 = 1 undo** になる。
  /// ★N は固定列なら渡された件数、自動進行なら**実行時に決まる**が、
  /// 記録するのは**決まったあとの具体列**なので `board_session_test.dart` の
  /// 再生（`dispatchAll` / `undo` / `undoStep`）はそのまま通る。
  ///
  /// ★★ 途中で投げたときの扱い ★★
  /// N 回のうち k 回目が投げたら、**1〜k-1 回目の結果も残らない。**
  /// [state] への代入がループの外に 1 回しか無いので、`value` は `identical` のまま。
  /// 履歴も 1 件も増えない（`record` に到達しない）。
  /// ★**ただし乱数は進む。**1〜k-1 回目が消費したぶんは戻せない。
  /// これは未決 **U15**（巻き戻しても乱数が張り直されない）と同じ性質であり、
  /// **同じ引き金を踏んだときに一緒に解く。**
  void _run(GameAction? Function(_Run run) nextAction) {
    final before = value.state;
    final rngBefore = _rng.count;
    // ★★ 「新規の警告」の基準は**直前に観測した集合**である（決定 D92 / §15-5）★★
    //   ★`BoardTidyLog` は「次の整理まで残す」設計なので、最後の 1 件が最新の観測。
    //   ★押下の中で**走りながら更新する** —— 固定基準だと「押下の途中で解消され、
    //     同じ押下の中で再び立つ」を取りこぼす。
    final run = _Run(
      before,
      value.tidies.isEmpty ? const {} : value.tidies.last.warnings.toSet(),
    );

    while (true) {
      final action = nextAction(run);
      if (action == null) break;
      final cursorBefore = run.state.cursor;
      // ★★ 投げたらここで終わる。下の record にも state の代入にも到達しない ★★
      final report = reduceWithReport(run.state, action, context: _context);
      run.absorb(cursorBefore, action, report);
    }

    final operation = BoardOperationLog(
      cursorBefore: before.cursor,
      cursorAfter: run.state.cursor,
      steps: run.steps,
      stops: run.stops,
      refreshCount: run.refreshCount,
      // ★飛ばしたカーソルを黙って落とさない（決定 D88）。
      skipped: run.skipped,
    );
    final session = value.session.record(run.state);
    // ★整理が 1 件も起きていないときは前の値を残す（[BoardTidyLog] の doc）。
    _pushApplied(
      session,
      _AppliedLog(
        operation: operation,
        tidies: run.tidies.isEmpty ? value.tidies : run.tidies,
        rngConsumed: _rng.count > rngBefore,
      ),
    );

    state = value.copyWith(
      session: session,
      operation: operation,
      tidies: run.tidies.isEmpty ? null : run.tidies,
      // ★巻き戻しの行は次の操作で消す（寿命は「次の操作まで」）。
      clearRewind: true,
      log: [...value.log, Act(run.applied)],
    );
  }

  /// 1 操作戻す（決定 D78 / 盤面設計メモ §8-1）。戻せなければ何もしない。
  void undo() => _rewind(value.session.undo(), wholeStep: false, entry: const Undo());

  /// ★★ 1 ステップ戻す（決定 D78）★★
  ///
  /// 着地点は 2 通りある（`history.dart`）——
  /// ①そのステップ内で操作していたなら**そのステップの入口**（カーソルは変わらない）
  /// ②入った直後なら**1 つ前のステップ**。
  /// ★**「カーソルが変わったか」を成否の signal にしない。**null かどうかで見る。
  void undoStep() =>
      _rewind(value.session.undoStep(), wholeStep: true, entry: const UndoStep());

  void _rewind(
    GameSession? next, {
    required bool wholeStep,
    required BoardLogEntry entry,
  }) {
    if (next == null) return;

    final before = value.state;
    final popped = value.session.history.depth - next.history.depth;

    // ★★ 取り消した件数は履歴の深さの差から導く ★★
    //   `undoStep` の「カーソルが変わるまで pop」を UI で再実装しない（D-15 の型）。
    var rngConsumed = false;
    for (var i = 0; i < popped; i++) {
      final removed = _ops.removeLast();
      rngConsumed = rngConsumed || removed.rngConsumed;
    }

    // ★戻った先の「直前の操作 / 直前の整理」へ戻す。無ければ null に落とす。
    final restored = _ops.isEmpty ? null : _ops.last;

    state = value.copyWith(
      session: next,
      operation: restored?.operation,
      clearOperation: restored?.operation == null,
      tidies: restored?.tidies,
      clearTidies: restored == null || restored.tidies.isEmpty,
      rewind: BoardRewindLog(
        wholeStep: wholeStep,
        entriesPopped: popped,
        landedCursor: next.state.cursor,
        landedTurnNumber: next.state.turnNumber,
        landedOnSameStep: next.state.cursor == before.cursor,
        rngConsumed: rngConsumed,
      ),
      log: [...value.log, entry],
    );
  }

  /// `_ops` の深さを履歴に合わせる。
  ///
  /// ★`GameHistory.push` は [GameHistory.maxDepth] を超えると**先頭から捨てる**。
  ///   並行スタックも同じ規則で捨てないと、巻き戻しの対応がずれる。
  void _pushApplied(GameSession session, _AppliedLog applied) {
    _ops.add(applied);
    final overflow = _ops.length - session.history.depth;
    if (overflow > 0) _ops.removeRange(0, overflow);
  }

  /// 盤面の向きを変える（決定 D75）。★`GameAction` ではない。
  ///
  /// ★★ ソロでは呼ばれない ★★ 切替先が無いので画面にボタンを出さない（D88）。
  void setViewer(String playerId) {
    if (playerId == value.viewerId) return;
    state = value.copyWith(viewerId: playerId);
  }

  /// 4.1.2.2「枚数はいつでも全プレイヤーが確認できます」。
  ///
  /// ★★ 非公開領域（4.8 / 4.9）について盤面が答えてよいのはこれだけ ★★
  /// 中身を返す getter をここに足さないこと（決定 D77）。
  /// ★例外は [topOfMainDeck] で、5.7.1 の**一時的な開示**にだけ使う。
  int countIn(String playerId, Zone zone) =>
      cardsIn(value.state, playerId, zone).length;

  /// エネルギーデッキから 1 枚出せるか（4.9.2 / 決定 D73）。
  ///
  /// ★★ 出せないときにボタンを消さず、無効にして理由を出すため ★★
  /// エネルギーは控え室を経由しない閉ループ（10.5.4）なので、
  /// メインデッキのようなリフレッシュ（10.2）が無い。6.1.1.3 の 12 枚を
  /// 使い切ると出せなくなる。**黙って何も起きない形にしない。**
  bool canDrawEnergy(String playerId) => countIn(playerId, Zone.energyDeck) > 0;

  /// 戻せる操作があるか（決定 D78）。
  ///
  /// ★★ false でもボタンを消さない ★★
  /// 無効にして理由を出す。黙って効かないボタンを作らない
  /// （`canDrawEnergy` と同じ方針）。
  bool get canUndo => value.session.canUndo;

  /// 「1 つ戻す」の着地先。★**押す前に**出すために要る（決定 D78）。
  GameState? get undoTarget => value.session.history.last?.state;

  /// 「1 ステップ戻す」の着地先。
  ///
  /// ★`GameSession` はイミュータブルなので、試しに呼んでも副作用が無い。
  ///   ★着地点が現在と同じカーソルになることがある（そのステップの入口）。
  GameState? get undoStepTarget => value.session.undoStep()?.state;

  /// ★★ 履歴が上限に達しているか（決定 D78 / `history.dart`）★★
  /// 上限を超えると**古いものから黙って捨てられる。**捨てたことを黙らないため、
  /// 帯に出す（`state/board_summary.dart` の `derivedBoardNotices`）。
  bool get isHistoryAtMaxDepth =>
      value.session.history.depth >= value.session.history.maxDepth;

  /// 保持している履歴の上限。★UI に 512 を書かないため。
  int get historyMaxDepth => value.session.history.maxDepth;

  /// 次へ進むのにプレイヤーの宣言が要るか。
  ///
  /// ★★ 判定は `loveca_core` の `StepEngine` に委ねる ★★
  /// true になるのは 8.4.12 だけだが、**UI にその条番号を書かない。**
  /// 列挙を 2 箇所に持つと必ず食い違う（`ルール整合性チェック_v1.06.md` D-15）。
  bool get requiresChoice => _context.engine.requiresChoice(value.state);

  /// 現在のステップの後続候補。★`step.dart` の遷移表が唯一の権威。
  ///
  /// ★分岐の選択肢の文言も [StepTransition.label] から取る。UI で書かない。
  List<StepTransition> get transitions =>
      _context.engine.transitionsFrom(value.state);

  /// ★★ メインデッキ置き場を上から [count] 枚（総合ルール 5.7.1）★★
  ///
  /// ★★ これは 5.7 の**一時的な開示**専用の口である ★★
  /// 4.8.2 によりメインデッキ置き場は非公開領域で、盤面は中身を出さない（決定 D77）。
  /// 5.7.1「指定プレイヤーはそのメインデッキ置き場の一番上から（数値）枚の情報を
  /// 知ることができます」がこの口の唯一の根拠であり、
  /// **常設の一覧を作るために呼んではいけない。**
  ///
  /// ★`LookAtTop` を dispatch した**あと**に呼ぶこと。10.2.2.2 のリフレッシュが
  /// 先に起きないと、足りない枚数のまま読むことになる。
  ///
  /// ★★ エネルギーデッキ置き場（4.9）には同じ口を作らない ★★
  /// 5.7.1 / 5.7.2 / 10.2.2.2 はいずれもメインデッキ置き場についての規定で、
  /// 4.9 を対象にした条は**存在しない**（決定 D73 / 盤面設計メモ §2-5）。
  /// ★禁止されているのではなく、条文が定めていない。定めていないものを足さない。
  List<CardInstance> topOfMainDeck(String playerId, int count) =>
      cardsIn(value.state, playerId, Zone.mainDeck).take(count).toList();
}
