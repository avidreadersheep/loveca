/// 盤面の視点を配る（決定 D75）.
///
/// ★★ 判断点を 1 箇所にする ★★
/// 鏡像（4.5.7.1）も袖の割り当ても手札の帯も、すべて [BoardView.viewerId] から決まる。
/// D66 が「どちらに出すかを決めるのは 1 行だけ」と定めたのと同じ理由で、
/// **`state.players[0]` / `[1]` を各ウィジェットから直接読まない。**
/// 2 箇所で読むと「相手側だけ直っていない」が起きる。
///
/// ★★ 視点と手番は別物である ★★
/// `AdvanceStep` の対象は `turnPlayerOf(state, phase)` から決まり、[viewerId] とは無関係。
/// 7.2.1.2 により手番を指定しないフェイズ（8.2 / 8.4）のアクティブプレイヤーは
/// **先攻**であって視点ではない。**混ぜると 8.4.13 の入れ替え後に手番が誤る。**
///
/// ★★ 描画の視点と `redact` の視点を同じ変数にしない（決定 D77）★★
/// [viewerId] は**上下の向き**を決めるだけで、**何が見えるか**は決めない。
/// 一人回しでは両者の手札が見える（1 人が両方を操作するため）。
/// `redact` はここに一切関与しない。
library;

import 'package:flutter/widgets.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_image_source.dart';
import '../../data/master_catalog.dart';
import '../../state/game_store.dart';
import '../common/card_drag.dart';

class BoardView extends InheritedWidget {
  const BoardView({
    super.key,
    required this.state,
    required this.viewerId,
    required this.catalog,
    required this.imageSource,
    required this.store,
    this.dragStartMode = DragStartMode.immediate,
    required super.child,
  });

  final GameState state;

  /// ★★ `reduce` を呼ぶ唯一の場所（決定 D53）★★
  /// 盤面の各所は写像の答え（`board_drag.dart`）をここへ渡すだけで、
  /// **自分で `GameState` を書き換えない。**
  final GameStore store;

  /// ドラッグの開始方法（決定 D46 / D52 (d)）。
  ///
  /// ★PC（マウス）は 3 方式とも成立するので既定の [DragStartMode.immediate] でよい
  /// （`docs/UI技術検証メモ.md` §6-4）。
  /// ★[DragStartMode.longPress] は PC では使われない。**使われない経路は
  /// `spike/` と同じ性質で静かに腐る**ので、`test/board/board_drag_test.dart` が
  /// 両値を通している。ここを差し替えられる形にしてあるのはそのためである。
  final DragStartMode dragStartMode;

  /// ★下段に出るプレイヤー。盤面の向きはこれ 1 つで決まる。
  final String viewerId;

  final MasterCatalog catalog;
  final CardImageSource imageSource;

  /// 下段（視点）のプレイヤー。
  PlayerState get viewer => state.playerOf(viewerId);

  /// 上段（相手）のプレイヤー。★2 人ちょうどなので必ず定まる。
  PlayerState get opponent =>
      state.players.firstWhere((p) => p.playerId != viewerId);

  /// 表示用の呼び名。★playerId を画面に出さない（内部語彙）。
  String labelOf(String playerId) => playerId == viewerId ? '自分' : '相手';

  /// 上段の行に並べるスロットの順（総合ルール 4.5.7.1）。
  ///
  /// ★★ 下段は 4.5.2.2 のとおり 左サイド → センター → 右サイド ★★
  /// 上段を同じ順に並べると**正面同士が縦に揃わない**。
  /// 「左サイドエリアの正面は他プレイヤーの右サイドエリア」なので、
  /// 下段の各列に対応する上段の列は `opposing` である。
  ///
  /// ★`MemberAreaSlot.opposing`（`zone.dart`）が既にこの写像を持つ。**再実装しない。**
  static const List<MemberAreaSlot> viewerRow = MemberAreaSlot.values;

  static List<MemberAreaSlot> get opponentRow =>
      [for (final slot in viewerRow) slot.opposing];

  /// ★★ ダイアログへ同じ視点を配り直す ★★
  /// `showDialog` は `Navigator` の別のサブツリーに載るので、
  /// このウィジェットは**祖先にならない**。フィールドを 1 つずつ書き写す形に
  /// すると増えたときに片方だけ直されるので、ここ 1 か所にまとめる。
  BoardView provideTo(Widget child) => BoardView(
        state: state,
        viewerId: viewerId,
        catalog: catalog,
        imageSource: imageSource,
        store: store,
        dragStartMode: dragStartMode,
        child: child,
      );

  static BoardView of(BuildContext context) {
    final view = context.dependOnInheritedWidgetOfExactType<BoardView>();
    assert(view != null, 'BoardView が上に無い。盤面の内側で使うこと。');
    return view!;
  }

  @override
  bool updateShouldNotify(BoardView oldWidget) =>
      !identical(oldWidget.state, state) ||
      oldWidget.viewerId != viewerId ||
      oldWidget.dragStartMode != dragStartMode ||
      !identical(oldWidget.catalog, catalog);
}
