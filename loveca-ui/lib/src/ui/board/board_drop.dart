/// 盤面で落とす側（決定 D46 / D47 / D53 / D85）.
///
/// ★★ 帯を出す条件をフラグで持たない ★★
/// 「順番を管理する領域かどうか」を落とし先ごとに手で書くと、必ずどこかで食い違う
/// （D-15 の「列挙による断定は黙って古くなる」と同じ形）。
/// → **上半分に落としたときと下半分に落としたときの答えが違うときだけ帯を出す。**
/// 答えを出すのは `board_drag.dart` の写像なので、条件は写像 1 か所から導かれる。
///
/// 結果として次がすべて自動的に成立する。
///
/// | 落とす先 | 帯 | なぜそうなるか |
/// |---|---|---|
/// | 4.8 メインデッキ / 4.10 成功ライブ | ○ 一番上 / 一番下 | `to.isOrdered == true` なので `ZonePosition` が上下で変わる |
/// | メンバーエリア（メンバーが 1 人以上） | ○ 上に置く / 下に置く | 4.5.1 と 4.5.5 / 5.10.1 で `GameAction` が変わる |
/// | メンバーエリア（メンバーが 0 人） | ✗ | 「下に置く」先が無く、上下とも `PlaceMemberInArea` |
/// | ★メンバーを別のスロットへ | ✗ | 上下とも `MoveMemberBetweenAreas`。**意味が 1 つ** |
/// | 順番を管理しない領域（4.1.3） | ✗ | `to.isOrdered == false` なので上下で何も変わらない |
///
/// ★★ 順番を管理しない領域で帯を出さない理由 ★★
/// 4.5.3 / 4.6.2 / 4.7.2 / ★**4.9.2** / 4.11.2 / 4.12.2 / 4.13.2 / 4.14.2 は
/// いずれも「カードの順番は管理されません」と定める（★4.14.2 だけ「順番**が**」）。
/// 帯を出すと**順番があるように見え**、プレイヤーが意味のない並べ替えをしてしまう。
///
/// ★★ この列挙から `isOrdered` を導かないこと ★★
/// **4.9.2 が長らく抜けていた**（実害は無い —— 4.9 は非公開なので帯の出しようが無い）。
/// 正しい不変条件は補集合の側で、**順番が管理されるのは 4.8 と 4.10 の 2 つだけ**である。
/// ★答えは `Zone.isOrdered` から取ること。この列挙は理由の説明であって根拠ではない。
///
/// ★★ そして `isOrdered` だけでは足りない（決定 D91-4）★★
/// 4.10.2 は「順番が管理されます」に続けて「**この領域にカードが置かれる場合、
/// これまでに置かれているカードの上に置かれます**」と**置き場所まで**定める。
/// `Zone.isOrdered` が捉えているのは 1 文目だけなので、
/// 位置は `positionIn`（`loveca_core`）を通した答えで決める。
///
/// ★★ 帯を出さなくても「乗っている」ことは出す ★★
/// 出さないと落とせるかどうかが分からない。枠のハイライトで出す。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../common/card_drag.dart';
import 'board_drag.dart';
import 'board_slot.dart';
import 'board_stack_choice.dart';
import 'board_view.dart';

/// 落とした結果を盤面へ反映する**唯一の口**（決定 D53 / D85）。
///
/// ★`reduce` を呼ぶのは `GameStore.dispatch` だけ。ここは写像の答えを渡すだけで、
/// **`GameState` を組み立てない。**
Future<void> applyBoardMove(BuildContext context, BoardMove move) async {
  final store = BoardView.of(context).store;
  final messenger = ScaffoldMessenger.of(context);

  switch (move) {
    case MoveAction(:final action):
      store.dispatch(action);

    // ★★ 合成は 1 操作として積む（M-B5 / 決定 D78 / 盤面設計メモ §8-2）★★
    //   `reduce` を N 回回して `record` は 1 回だけ。**1 回の undo で戻る。**
    case MoveActions(:final actions):
      store.dispatchAll(actions);

    case NeedsMemberChoice(:final before):
      // ★★ 2 択では足りないので選ばせる（4.5.5 / 5.10.1）★★
      final chosen = await showStackUnderChoice(context, move);
      // ★キャンセルしたら dispatch しない（履歴が増えない）。
      if (chosen == null) return;
      // ★中継が要るときも 1 操作にまとめる（[NeedsMemberChoice.before]）。
      store.dispatchAll([...before, move.withMember(chosen)]);

    case MoveRefused(:final reason):
      // ★落ちたのに何も起きないと「アプリが壊れている」と読まれる。
      messenger.showSnackBar(SnackBar(content: Text(reason)));

    case MoveIgnored():
      break;
  }
}

/// 札 1 枚ぶんの箱を落とし先にする（メンバーエリア / 各領域の山）。
class BoardDropSlot extends StatelessWidget {
  const BoardDropSlot({
    super.key,
    required this.resolve,
    this.width = kBoardSlotWidth,
    this.label,
    this.emphasis = false,
    this.child,
  });

  /// 落ちた札を [BoardMove] へ写す。★`board_drag.dart` の関数をそのまま渡す。
  ///
  /// ★★ 乗っているあいだにも上下 2 通りを呼んで帯を決める ★★
  ///   純関数なので何度呼んでも副作用が無い。
  final BoardMove Function(BoardDrag drag, DropEdge edge) resolve;

  final double width;
  final String? label;
  final bool emphasis;

  /// 置かれている札（`BoardPiece`）。null なら空きスロット。
  final Widget? child;

  @override
  Widget build(BuildContext context) => CardDropTarget<BoardDrag>(
        // ★ラッパが `ColoredBox` で包む（決定 D46）。塗りは `BoardSlot` が持つので透明。
        background: Colors.transparent,
        onDrop: (drag, edge) => applyBoardMove(context, resolve(drag, edge)),
        builder: (context, hovering) => BoardSlot(
          width: width,
          label: label,
          emphasis: emphasis,
          overlay: _EdgeOverlay(hovering: hovering, resolve: resolve),
          child: child,
        ),
      );
}

/// 箱の形をしていない落とし先（手札の帯 / 解決領域 / 盤の外）。
///
/// ★これらはいずれも順番を管理しない（4.11.2 / 4.14.2）ので [DropEdge] を取らない。
class BoardDropRegion extends StatelessWidget {
  const BoardDropRegion({
    super.key,
    required this.resolve,
    required this.builder,
  });

  final BoardMove Function(BoardDrag drag) resolve;

  /// [hovering] が true なら乗っている。
  final Widget Function(BuildContext context, bool hovering) builder;

  @override
  Widget build(BuildContext context) => CardDropTarget<BoardDrag>(
        background: Colors.transparent,
        onDrop: (drag, _) => applyBoardMove(context, resolve(drag)),
        builder: (context, hovering) => builder(context, hovering != null),
      );
}

/// 乗っているあいだの表示（決定 D47）。
///
/// ★★ どちらの意味で落ちるかを出さないと利用者は気づけない ★★
class _EdgeOverlay extends StatelessWidget {
  const _EdgeOverlay({required this.hovering, required this.resolve});

  final DropHover<BoardDrag>? hovering;
  final BoardMove Function(BoardDrag drag, DropEdge edge) resolve;

  @override
  Widget build(BuildContext context) {
    final hover = hovering;
    if (hover == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    // ★★ 上下で答えが違うときだけ帯を出す ★★
    final leading = boardEdgeLabel(resolve(hover.data, DropEdge.leading));
    final trailing = boardEdgeLabel(resolve(hover.data, DropEdge.trailing));

    if (leading == null || trailing == null || leading == trailing) {
      // ★帯は出さないが、乗っていることは出す（落とせるかが分からなくなる）。
      return DecoratedBox(
        key: const ValueKey('drop-hover'),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.primary, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final isLeading = hover.edge == DropEdge.leading;
    return Align(
      alignment: isLeading ? Alignment.topCenter : Alignment.bottomCenter,
      child: Container(
        key: ValueKey(isLeading ? 'drop-band-leading' : 'drop-band-trailing'),
        width: double.infinity,
        color: scheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          isLeading ? leading : trailing,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// 帯に出す文言。★**null なら「上下で意味が変わらない」**（＝ 帯を出さない）。
///
/// ★条番号を添える。何のルールでそうなるかが読めないと、
/// 上下に何かが出ていること自体が意味を持たない。
String? boardEdgeLabel(BoardMove move) => switch (move) {
      MoveAction(:final action) => _actionEdgeLabel(action),
      // ★★ 合成の意味を決めるのは最後のアクションである（M-B5）★★
      //   手札への中継（前半）は上下で変わらない。上下を撃ち分けるのは後半だけ。
      MoveActions(:final actions) => _actionEdgeLabel(actions.last),
      // 4.5.5 / 5.10.1「下に置く」。★どのメンバーの下かはこのあと選ばせる。
      NeedsMemberChoice() => '下に置く 4.5.5',
      // ★落とせない / 何も起きないなら上下の区別も無い。
      MoveRefused() || MoveIgnored() => null,
    };

String? _actionEdgeLabel(GameAction action) => switch (action) {
      // ★★ 4.1.3: 順番が管理されない領域では上下に意味が無い ★★
      //   `to` を見て決めるので、領域名の一覧を UI に持たなくてよい。
      MoveCard(:final to, :final position) => _positionLabel(to, position),
      MoveFromResolution(:final to, :final position) =>
        _positionLabel(to, position),
      MoveMemberOut(:final to, :final position) => _positionLabel(to, position),
      MoveFromOutOfRule(:final to, :final position) =>
        _positionLabel(to, position),
      PlaceMemberInArea() => '上に置く 4.5.1',
      StackUnderMember() => '下に置く 4.5.5',
      // ★上下とも同じ答えになるので、この文言が画面に出ることは無い。
      MoveMemberBetweenAreas() => '移す 4.5.5.3',
      _ => null,
    };

String? _positionLabel(Zone to, ZonePosition position) {
  if (to.isOrdered != true) return null;
  return switch (position) {
    ZonePosition.top => '一番上へ ${to.ruleRef}',
    ZonePosition.bottom => '一番下へ ${to.ruleRef}',
  };
}
