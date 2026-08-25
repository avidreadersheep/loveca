/// 盤面で掴める 1 枚（決定 D46 / D47 / D72 / D76）.
///
/// ★★ 掴める矩形を作るのは絵ではない ★★
/// D72 のあと **絵はスロットを埋めない**。ライブの札（200:143）は
/// 縦長の箱（200:279）の上下に**透明な帯**を残す。
/// 掴める矩形を作るのは `CardDragSource.background` の `ColoredBox` である。
///
/// ★★ 怠ると「ライブだけ帯を掴めない」という種別依存の不具合になる ★★
/// 例外も出ず、`flutter analyze` も通る。だから
/// `test/board/board_drag_test.dart` が**盤面の 5 か所すべて**で
/// 「絵の外・箱の中」から掴めることを固定してある。
///
/// ★★ [BoardSlot] の箱いっぱいに広げる ★★
/// 箱より小さくすると、箱と絵のあいだにもう 1 本の透明な帯ができる。
/// D47 の [DropEdge] は**スロット高さ**基準なので、掴める矩形と
/// 落ちる矩形がずれると「上半分に落としたつもりが下半分」になる。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;

import '../../data/card_image_source.dart';

import '../common/card_drag.dart';
import '../common/card_thumb.dart';
import 'board_card_menu.dart';
import 'board_drag.dart';
import 'board_slot.dart';
import 'board_view.dart';

/// 掴める札 1 枚。★[BoardSlot] の `child` に渡す。
class BoardPiece extends StatelessWidget {
  const BoardPiece({
    super.key,
    required this.drag,
    this.width = kBoardSlotWidth,
  });

  /// 掴んだ札とその出どころ。★落とす側はこれだけを受け取る。
  final BoardDrag drag;

  /// 箱の論理幅。★絵の枠の幅でもある（`card_thumb.dart` の不変）。
  final double width;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);
    final scheme = Theme.of(context).colorScheme;

    // ★★ feedback の材料はここで引く ★★
    //   feedback は `Overlay` に載るので `BoardView` が祖先にならない。
    //   中で `BoardView.of` を呼ぶと**掴んだ瞬間に落ちる**。
    final faceDown = drag.card.face == FaceState.faceDown;
    final printing = view.catalog.printings[drag.card.printingId];

    return CardDragSource<BoardDrag>(
      data: drag,
      // ★★ ここが D46 の手当てそのもの ★★
      //   帯（絵の外・箱の中）を掴めるようにしているのはこの色である。
      background: scheme.surfaceContainerHighest,
      // ★PC は即時でよい（技術検証メモ §6-4）。★両経路をテストが通す（D52 (d)）。
      mode: view.dragStartMode,
      feedback: _Feedback(
        width: width,
        faceDown: faceDown,
        // ★★ 裏向きは種別を漏らさない（4.3.3.2）★★
        //   ライブだけ横長の feedback が出ると、裏向きのまま種別が分かってしまい
        //   8.2.2 / 8.2.4 のブラフが成立しなくなる。
        cardType: faceDown
            ? CardType.member
            : view.catalog.cards[drag.card.cardNumber]?.cardType ??
                CardType.member,
        imageHash: faceDown ? '' : printing?.imageHash ?? '',
        source: view.imageSource,
      ),
      child: SizedBox.expand(
        // ★★ 押す側も矩形を作る（決定 D46）★★
        //   `HitTestBehavior.opaque` なので**帯を叩いてもメニューが開く**。
        //   絵の上だけで開く形にすると、ライブの札だけ操作しにくくなる。
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showBoardCardMenu(context, drag),
          child: BoardCard(card: drag.card, width: width),
        ),
      ),
    );
  }
}

/// ドラッグ中についてくる絵。
///
/// ★★ feedback は箱そのものが札である（決定 D72）★★
/// 枠を中に作ると宙に浮くので、箱の高さを種別で決める。
///
/// ★★ `BoardView` を読まない ★★
/// `Overlay` に載るのでこのウィジェットの祖先に `BoardView` は無い。
/// 材料は掴む側（[BoardPiece]）が引いて値で渡す。
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.width,
    required this.faceDown,
    required this.cardType,
    required this.imageHash,
    required this.source,
  });

  final double width;
  final bool faceDown;
  final CardType cardType;
  final String imageHash;
  final CardImageSource source;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: width / cardAspectRatioOf(cardType),
        child: faceDown
            // 4.3.3.2: 情報が書かれている面が見えない。
            ? BoardFaceDown(width: width)
            : CardArt(
                source: source,
                imageHash: imageHash,
                cardType: cardType,
                logicalWidth: width,
              ),
      );
}
