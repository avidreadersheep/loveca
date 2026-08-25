/// R7 盤面（決定 D75 / D77 / D79 / D81 / D86 / 盤面設計メモ §4 / §11）.
///
/// ★★ ルートを増やすのは R7 だけ ★★
/// R3〜R6 は同じ一覧ペイン・同じ詳細ペインを器だけ替えて置いているが、
/// 盤面は**別の能力**なのでルートを分ける（CLAUDE.md §8 / 決定 D75）。
///
/// ★★ `PaneScaffold` を使わない（決定 D75）★★
/// 唯一の判断点が「幅で 1/2 ペインを切り替える」ことだが、
/// **盤面は 1 ペインに縮退できない**（置き場が同時に見えないと物理操作にならない）。
/// 使うと「1 ペインのとき盤面はどうなるか」という**答えの無い分岐**が生まれる。
///
/// ★★ 縦の並びと、それぞれの寿命 ★★
///
/// | 段 | 中身 | 寿命 |
/// |---|---|---|
/// | 進行バー | ターン / フェイズ / ステップ / 手番 / 次へ / 直前の操作 | 毎操作 |
/// | 直前の整理 | 10.4・10.5 で実行したもの / ★10.3・10.6 の警告 | ★**整理が起きるまで残る** |
/// | 常設の帯 | マリガン未実装・6.1 違反・盤面から導く警告 | セッション / 盤面の状態 |
/// | 集計 | 8.3.10 / 8.3.12 / 8.3.14 / 8.4.2 | 盤面の状態 |
/// | 盤面 | `BoardLayout` | — |
///
/// ★**警告の帯は折りたためない。**畳めるのは集計だけ（黙って落とさないため）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/app_scope.dart';
import '../../state/board_mode.dart';
import '../../state/board_notice.dart';
import '../../state/board_summary.dart';
import '../../state/game_store.dart';
import '../common/card_drag.dart';
import 'board_layout.dart';
import 'board_notice_bar.dart';
import 'board_progress.dart';
import 'board_summary_panel.dart';
import 'board_view.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({
    super.key,
    required this.initialState,
    required this.viewerId,
    required this.mode,
    required this.seed,
    this.notices = const [],
    this.dragStartMode = DragStartMode.immediate,
  });

  /// ★6.2.1 を通した初期状態（`GameSetup` / 決定 D79）。
  /// **ここで開始手順を走らせない。** 走らせると seed が画面に出る前に消費される。
  final GameState initialState;

  final String viewerId;

  /// ★★ 既定値を置かない（決定 D88）★★
  /// 既定は「指定し忘れがコンパイルで止まらない」= 漏れうる構造で、
  /// D49 / D77 / D80 が一貫して退けてきた形である。
  /// ★`loveca_core` の `ProgressionMode` が既定を持つのとは非対称だが、
  /// 理由がある —— あちらはモードに無関係な経路も `ReduceContext` を組むのに対し、
  /// **盤面はモードが必ず 1 つに決まる文脈**だから required にできる。
  /// ★利得: **どのテストがどのモードを試しているかが型で見える。**
  final BoardMode mode;

  final int seed;
  final List<BoardNotice> notices;

  /// ドラッグの開始方法（決定 D46 / D52 (d)）。
  ///
  /// ★PC は既定の [DragStartMode.immediate] でよい。
  /// ★**使われない `longPress` の経路が静かに腐らないように**、
  /// `test/board/board_drag_test.dart` が両値を通す口としてここを開けてある。
  final DragStartMode dragStartMode;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  GameStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) return;

    final env = AppScope.of(context).environment;
    _store = GameStore(
      initialState: widget.initialState,
      viewerId: widget.viewerId,
      mode: widget.mode,
      seed: widget.seed,
      cards: env.cards,
      // ★盤面セッションのあいだ 1 つの乱数源を使い続ける（決定 D79）。
      //   ★開始手順で使ったものとは別のインスタンスだが、同じ seed から作るので
      //   「seed を控えれば同じ盤面が出る」は成立する（開始手順は決定的）。
      rng: SeededRng(widget.seed),
      notices: widget.notices,
    );
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store!;
    final env = AppScope.of(context).environment;

    return ValueListenableBuilder<BoardState>(
      valueListenable: store,
      builder: (context, board, _) => BoardView(
        state: board.state,
        viewerId: board.viewerId,
        mode: board.mode,
        catalog: env.catalog,
        imageSource: env.imageSource,
        // ★★ `reduce` を呼ぶ唯一の場所を盤面の各所へ配る（決定 D53）★★
        //   落とす側は写像の答えを `dispatch` へ渡すだけで、
        //   **自分で `GameState` を書き換えない。**
        store: store,
        dragStartMode: widget.dragStartMode,
        // ★★ 段はすべて `BoardView` の**内側**に置く（決定 D88）★★
        //   `drawnPlayers`（描くプレイヤーの反復元）を配れるのは内側だけである。
        //   外で組むと、同じ反復を 2 か所に持つことになる。
        child: _BoardScaffold(board: board, store: store),
      ),
    );
  }
}

/// 盤面の段。★`BoardView` の内側にあるので `drawnPlayers` を読める。
class _BoardScaffold extends StatelessWidget {
  const _BoardScaffold({required this.board, required this.store});

  final BoardState board;
  final GameStore store;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final env = AppScope.of(context).environment;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        // ★モードを名乗る。★「一人回し」という語は使わない（決定 D88-1）。
        title: Text(board.mode.label),
        actions: [
          // ★★ 視点の切替（決定 D75）★★
          //   これは GameAction ではない。盤面の向きは UI の状態である。
          //   ★ソロでは出さない —— 切替先が無い（D88）。
          if (board.opponentId case final opponentId?)
            TextButton.icon(
              key: const ValueKey('swap-viewer'),
              onPressed: () => store.setViewer(opponentId),
              icon: const Icon(Icons.swap_vert),
              label: Text('下段: ${_shortLabel(board)}'),
            ),
          _SeedChip(seed: board.seed),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BoardProgressBar(board: board, store: store),
          // ★整理の結果は「起きたときだけ差し替わり、次の操作では消えない」。
          BoardNoticeBar(
            key: const ValueKey('tidy-notices'),
            notices: board.tidy?.notices ?? const [],
            mode: board.mode,
            background: scheme.tertiaryContainer,
            heading: '直前の整理（9.5.3 のチェックタイミング）',
          ),
          BoardNoticeBar(
            key: const ValueKey('board-notices'),
            notices: [
              ...board.notices,
              // ★★ 盤面の状態から導く注記（毎 build 作り直す）★★
              //   「いまそうなっていること」なので、操作 1 回で消えてはいけない。
              ...derivedBoardNotices(
                state: board.state,
                cards: env.cards,
                // ★描くプレイヤーだけを見る。★ソロで「相手」の注記は幽霊である。
                players: view.drawnPlayers,
                // ★「自分 / 相手」の対応づけは `BoardView` 1 か所に置く。
                labelOf: view.labelOf,
              ),
            ],
            mode: board.mode,
            background: scheme.secondaryContainer,
          ),
          // ★畳めるのはここだけ（警告は畳めない）。既定は開く。
          BoardSummaryPanel(players: view.drawnPlayers),
          Expanded(
            child: BoardLayout(
              // ★★ 描くプレイヤーぶんを渡す（決定 D87 / D88）★★
              //   ローカル対戦は 1 人が両方を操作する（D77 / D84）。
              //   ★ソロは袖が 1 つなので、渡る playerId も 1 つだけになる。
              onDrawEnergy: (playerId) => store.canDrawEnergy(playerId)
                  ? () => store.dispatch(DrawEnergy(playerId: playerId))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _shortLabel(BoardState board) =>
      board.viewerId == board.state.firstPlayerId ? '先攻' : '後攻';
}

/// ★★ seed を画面に出す。書き写せる形にする（決定 D79）★★
/// CLAUDE.md §1 が「同じ seed で盤面を再現できないと不具合を追えない」を
/// `DeterministicRng` を置く理由に挙げている以上、**見えなければその理由が果たされない。**
class _SeedChip extends StatelessWidget {
  const _SeedChip({required this.seed});

  final int seed;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: '押すと seed をコピーします。開始ダイアログに入れると同じ盤面が出ます。',
        child: TextButton.icon(
          key: const ValueKey('board-seed'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '$seed'));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('seed $seed をコピーしました')),
              );
            }
          },
          icon: const Icon(Icons.casino_outlined, size: 18),
          label: Text('seed $seed'),
        ),
      );
}
