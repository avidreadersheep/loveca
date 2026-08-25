/// R7 盤面（決定 D75 / D77 / D79 / D81 / 盤面設計メモ §4 / §11）.
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
/// ★★ M-B1 の範囲 ★★
/// 層が通ることの確認だけ。ドラッグ（M-B2）・進行（M-B3）・巻き戻し（M-B4）・
/// 補助コマンド（M-B5）はここに書かない。
/// 唯一の操作が「エネルギーを1枚出す」で、これは**恒久の口**である（決定 D73 / D81）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../state/app_scope.dart';
import '../../state/board_notice.dart';
import '../../state/game_store.dart';
import '../common/card_drag.dart';
import '../common/degradation_line.dart';
import 'board_layout.dart';
import 'board_view.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({
    super.key,
    required this.initialState,
    required this.viewerId,
    required this.seed,
    this.notices = const [],
    this.dragStartMode = DragStartMode.immediate,
  });

  /// ★6.2.1 を通した初期状態（`GameSetup` / 決定 D79）。
  /// **ここで開始手順を走らせない。** 走らせると seed が画面に出る前に消費される。
  final GameState initialState;

  final String viewerId;
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
        catalog: env.catalog,
        imageSource: env.imageSource,
        // ★★ `reduce` を呼ぶ唯一の場所を盤面の各所へ配る（決定 D53）★★
        //   落とす側は写像の答えを `dispatch` へ渡すだけで、
        //   **自分で `GameState` を書き換えない。**
        store: store,
        dragStartMode: widget.dragStartMode,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('一人回し'),
            actions: [
              // ★★ 視点の切替（決定 D75）★★
              //   これは GameAction ではない。盤面の向きは UI の状態である。
              TextButton.icon(
                key: const ValueKey('swap-viewer'),
                onPressed: () => store.setViewer(board.opponentId),
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
              _ProgressBar(state: board.state),
              if (board.notices.isNotEmpty) _BoardNoticeBar(notices: board.notices),
              Expanded(
                child: BoardLayout(
                  onDrawEnergy: store.canDrawEnergy(board.viewerId)
                      ? () => store.dispatch(DrawEnergy(playerId: board.viewerId))
                      : null,
                ),
              ),
            ],
          ),
        ),
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

/// 進行バー。ターン / フェイズ / ステップ（条番号）/ 手番。
///
/// ★★ 手番は `turnPlayerOf` から取る。viewerId から取らない（決定 D75）★★
/// 7.2.1.2 により手番を指定しないフェイズ（8.2 / 8.4）のアクティブプレイヤーは
/// **先攻**であって視点ではない。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final theme = Theme.of(context);
    final turnPlayer = turnPlayerOf(state, state.cursor.phase);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        key: const ValueKey('progress-bar'),
        children: [
          Text('ターン ${state.turnNumber}',
              style: theme.textTheme.labelLarge),
          const SizedBox(width: 16),
          // ★条番号をそのまま出す。ステップ ID は条番号そのもの（3a-3）。
          Text('${state.cursor.phase.name} / ${state.cursor.step.ruleRef}',
              style: theme.textTheme.labelMedium),
          const SizedBox(width: 16),
          Text(
            turnPlayer == null
                ? '手番: なし（7.2.1.2）'
                : '手番: ${view.labelOf(turnPlayer)}',
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(width: 16),
          Text('先攻: ${view.labelOf(state.firstPlayerId)}',
              style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// 盤面の帯（盤面設計メモ §10-3 の 4 つ目の系統）。
///
/// ★描画は `ui/common/degradation_line.dart` を共有する。型は共有しない。
class _BoardNoticeBar extends StatelessWidget {
  const _BoardNoticeBar({required this.notices});

  final List<BoardNotice> notices;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final notice in notices) _line(notice),
          ],
        ),
      );

  Widget _line(BoardNotice notice) => switch (notice) {
        MulliganNotImplemented() => const DegradationLine(
            icon: Icons.construction_outlined,
            severity: DegradationSeverity.report,
            // ★暫定であることを盤面から読めるようにする。M-B5 で消す。
            text: '6.2.1.6 のマリガンはまだありません。'
                'この盤面は 0 枚として開始しています。',
          ),
        DeckNotValid(:final playerLabel, :final issues) => DegradationLine(
            icon: Icons.rule_outlined,
            severity: DegradationSeverity.warning,
            text: '$playerLabelのデッキは 6.1 の構築条件を満たしていません: '
                '${issues.map((i) => i.message).join(' / ')}',
          ),
      };
}
