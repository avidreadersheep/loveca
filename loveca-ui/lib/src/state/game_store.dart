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

/// 直前の 1 操作の結果（M-B3 / 決定 D86）。
///
/// ★[GameState] を保持しない。値だけを写し取る。
class BoardOperationLog {
  const BoardOperationLog({
    required this.cursorBefore,
    this.executed,
    this.taken,
    this.refreshCount = 0,
    this.skipped = const [],
  });

  /// その操作を行った時点の進行位置。
  final StepCursor cursorBefore;

  /// 実行したステップ。★`AdvanceStep` のときだけ非 null。
  final StepId? executed;

  /// たどった遷移。★8.3.6 の早期終了もこれで読める。
  final StepTransition? taken;

  /// この操作の中で割り込んだリフレッシュの回数（総合ルール 10.2.1）。
  final int refreshCount;

  /// ★★ 実行せずに通り越したカーソル（決定 D88）★★
  /// ソロでのみ空でなくなる。**黙って飛ばさない** —— 1 回の「次へ」で
  /// 4 フェイズを跨ぐことがあるので、出さないと「勝手に飛んだ」ように見える。
  final List<StepCursor> skipped;

  /// 見せるものが何も無いか。
  bool get isEmpty =>
      taken == null && refreshCount == 0 && skipped.isEmpty;
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
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
    this.manual = false,
  });

  /// どのチェックタイミングでの整理か。
  final StepCursor cursor;

  /// 実行したルール処理（10.4 / 10.5）。
  final List<RuleProcessKind> applied;

  /// ★自動実行せず警告に留めたもの（10.3 / 10.6）。
  final List<RuleProcessWarningKind> warnings;

  /// カードマスタに無く種別を判定できなかった枚数。
  final int excludedCount;

  final List<String> unknownCardNumbers;

  /// ★★ プレイヤーが「整理する」を押して起きた整理か（M-B6 / 決定 D93-5）★★
  ///
  /// ★★ 当たるものが無かったときの扱いが変わる ★★
  ///   自動（チェックタイミング）の整理は**ほとんど毎回空**なので、
  ///   空でも行を出すと帯が出っぱなしになる。
  ///   手で押したときは違う —— **押したのに何も出ないと「壊れている」と読まれる。**
  ///   → [manual] のときだけ [TidyFoundNothing] を出す。
  final bool manual;

  bool get isEmpty => applied.isEmpty && warnings.isEmpty && excludedCount == 0;

  /// 帯に出す行。★描画は `ui/board/board_notice_bar.dart` が持つ。
  List<BoardNotice> get notices {
    final ruleRef = cursor.step.ruleRef;
    // ★手で押して何も当たらなかったことを黙らない（黙って効かないボタンにしない）。
    if (isEmpty) {
      return manual ? [TidyFoundNothing(stepRuleRef: ruleRef)] : const [];
    }
    return [
      if (applied.isNotEmpty)
        RuleProcessApplied(stepRuleRef: ruleRef, kinds: applied),
      if (warnings.isNotEmpty)
        RuleProcessNotAutomatic(stepRuleRef: ruleRef, kinds: warnings),
      if (excludedCount > 0)
        TidyExcluded(
          stepRuleRef: ruleRef,
          count: excludedCount,
          cardNumbers: unknownCardNumbers,
        ),
    ];
  }
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
    final before = value.state;
    final rngBefore = _rng.count;

    var next = before;
    var refreshCount = 0;
    final tidies = <BoardTidyLog>[];
    AdvanceResult? advance;
    var skipped = const <StepCursor>[];

    for (final action in actions) {
      final cursorBefore = next.cursor;
      // ★★ 投げたらここで終わる。下の record にも state の代入にも到達しない ★★
      final report = reduceWithReport(next, action, context: _context);
      next = report.state;
      refreshCount += report.refreshCount;
      // ★★ 整理は**全件**積む（M-B6 / 決定 D93-5 / 新所見 D-21 の器）★★
      //   最後の 1 件で上書きすると、M-B7 の自動進行が複数の CT を通ったときに
      //   途中の 10.3 / 10.6 の警告が黙って落ちる。
      if (report.tidy case final result?) {
        tidies.add(BoardTidyLog(
          cursor: cursorBefore,
          applied: result.applied,
          warnings: result.warnings,
          excludedCount: result.excludedCount,
          unknownCardNumbers: result.unknownCardNumbers,
          // ★手で押した [Tidy] だけが「何も当たらなかった」を出す。
          manual: action is Tidy,
        ));
      }
      // ★★ 進行はまだ「最後に起きたもの」を採る（新所見 D-21 の本体は M-B7）★★
      //   いま合成に [AdvanceStep] が入る経路は無い（1 件版からしか渡らない）。
      //   ★自動進行はこれを直接踏むので、そのとき同じ形へ直す。
      advance = report.advance ?? advance;
      if (report.skipped.isNotEmpty) skipped = report.skipped;
    }

    final operation = BoardOperationLog(
      cursorBefore: before.cursor,
      executed: advance?.executed,
      taken: advance?.taken,
      refreshCount: refreshCount,
      // ★飛ばしたカーソルを黙って落とさない（決定 D88）。
      skipped: skipped,
    );
    final session = value.session.record(next);
    // ★整理が 1 件も起きていないときは前の値を残す（[BoardTidyLog] の doc）。
    _pushApplied(
      session,
      _AppliedLog(
        operation: operation,
        tidies: tidies.isEmpty ? value.tidies : tidies,
        rngConsumed: _rng.count > rngBefore,
      ),
    );

    state = value.copyWith(
      session: session,
      operation: operation,
      tidies: tidies.isEmpty ? null : tidies,
      // ★巻き戻しの行は次の操作で消す（寿命は「次の操作まで」）。
      clearRewind: true,
      log: [...value.log, Act(actions)],
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
