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
/// `GameState` しか返さない。★これは盤面設計メモ §8-2 が M-B4 / M-B5 の
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

/// 直前の整理（チェックタイミング 9.5.3）の結果（M-B3 / 決定 D86）。
///
/// ★★ 整理が起きたときだけ差し替える ★★
/// ドラッグ 1 回で 10.3（勝利処理）の警告が消えると、**黙って落とした**のと同じになる。
/// → [GameStore.dispatch] は `report.tidy == null` のとき**前の値を残す。**
/// 見出しに「直前の整理」と条番号を出すので、古い値が現在の状態に見えることはない。
class BoardTidyLog {
  const BoardTidyLog({
    required this.cursor,
    this.applied = const [],
    this.warnings = const [],
    this.excludedCount = 0,
    this.unknownCardNumbers = const [],
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

  bool get isEmpty => applied.isEmpty && warnings.isEmpty && excludedCount == 0;

  /// 帯に出す行。★描画は `ui/board/board_notice_bar.dart` が持つ。
  List<BoardNotice> get notices {
    final ruleRef = cursor.step.ruleRef;
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

/// 盤面 1 セッションぶんの状態。
class BoardState {
  const BoardState({
    required this.session,
    required this.viewerId,
    required this.mode,
    required this.seed,
    this.notices = const [],
    this.operation,
    this.tidy,
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

  /// 直前の整理の結果。★整理が起きるまで null。
  final BoardTidyLog? tidy;

  GameState get state => session.state;

  /// [viewerId] の相手。★★ソロでは null★★（決定 D88 / §14-5）。
  ///
  /// ★`GameState.players` は 3 モードとも 2 人のままである（1.1.1）。
  /// **2 人居ることと、ソロに相手が居ることは別**なので、ここで型を落とす。
  /// ★これにより視点切替（[setViewer]）の呼び出し側がコンパイルエラーになる。
  String? get opponentId => mode.hasOpponent
      ? state.players.firstWhere((p) => p.playerId != viewerId).playerId
      : null;

  BoardState copyWith({
    GameSession? session,
    String? viewerId,
    BoardOperationLog? operation,
    BoardTidyLog? tidy,
  }) =>
      BoardState(
        session: session ?? this.session,
        viewerId: viewerId ?? this.viewerId,
        mode: mode,
        seed: seed,
        notices: notices,
        operation: operation ?? this.operation,
        // ★null を渡すと「前の整理を残す」。消したい場面が無いので clear 引数を置かない。
        tidy: tidy ?? this.tidy,
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
  GameStore({
    required GameState initialState,
    required String viewerId,
    required BoardMode mode,
    required int seed,
    required Map<String, Card> cards,
    required DeterministicRng rng,
    List<BoardNotice> notices = const [],
  })  : _context =
            ReduceContext(cards: cards, rng: rng, mode: mode.progression),
        super(BoardState(
          session: GameSession(state: initialState),
          viewerId: viewerId,
          mode: mode,
          seed: seed,
          notices: notices,
        ));

  /// ★乱数はセッションのあいだ同じインスタンスを使い続ける。
  ///   毎回作り直すと同じ札が出続ける。
  final ReduceContext _context;

  /// cardNumber -> Card。★集計（`state/board_summary.dart`）が要る。
  Map<String, Card> get cards => _context.cards;

  /// ★★ `reduce` を呼ぶ唯一の場所 ★★
  ///
  /// ★複数のアクションを 1 操作として戻したい場合（11.10 / 11.11 の補助コマンド、
  /// ライブカードセット）は、`reduce` を N 回回して `record` を 1 回だけ呼ぶ
  /// （決定 D78 / 盤面設計メモ §8-2 / M-B5）。ここはその 1 回版である。
  void dispatch(GameAction action) {
    final before = value.state;

    // ★★ 投げたらここで終わる。下の record に到達しない ★★
    final report = reduceWithReport(before, action, context: _context);
    final tidy = report.tidy;

    state = value.copyWith(
      session: value.session.record(report.state),
      operation: BoardOperationLog(
        cursorBefore: before.cursor,
        executed: report.advance?.executed,
        taken: report.advance?.taken,
        refreshCount: report.refreshCount,
        // ★飛ばしたカーソルを黙って落とさない（決定 D88）。
        skipped: report.skipped,
      ),
      // ★整理が起きていないときは前の値を残す（[BoardTidyLog] の doc）。
      tidy: tidy == null
          ? null
          : BoardTidyLog(
              cursor: before.cursor,
              applied: tidy.applied,
              warnings: tidy.warnings,
              excludedCount: tidy.excludedCount,
              unknownCardNumbers: tidy.unknownCardNumbers,
            ),
    );
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
