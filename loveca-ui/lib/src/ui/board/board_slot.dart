/// 盤面のスロットと札（決定 D76 / D46 / D72）.
///
/// ★★ スロットの箱は例外なく [kCardAspectRatio] である（決定 D76）★★
/// 中に置く枠だけを `cardAspectRatioOf` で選ぶ（D72 と同じ形）。
/// ライブの札はスロットの上下に帯ができる（片側 0.340 × スロット幅）。
///
/// 例外を作れない理由 3 つ。**どれか 1 つでも成り立てば十分。**
///
/// 1. ★D47 の `DropEdge` は**スロット高さ**を基準にしている
///    （`card_drag.dart` の `local.dy < box.size.height / 2`）。高さが場所ごとに
///    変わると「上半分 / 下半分」の帯の高さが場所ごとに違い、**操作が読めなくなる。**
/// 2. ★`CardArt` の不変（箱が枠より縦長 ⇒ 枠の幅 == 箱の幅）が全箇所で成立する。
///    `card_thumb.dart` が「箱が枠より横長になる置き方をするときは `logicalWidth` に
///    **枠の幅**を渡すこと」と警告しており、**横長の箱を 1 つでも作ると
///    `logicalWidth` の計算が 2 通りになる。**
/// 3. ★**4.6 ライブカード置き場はライブ専用にできない。**
///    8.2.2 / 8.2.4 は「手札の**カード**」を裏向きに置くと定めており、
///    ライブ以外を裏向きに置くブラフは正規戦術で 8.3.4 がその後始末を定める。
///    さらに**裏向きの間はそもそも種別が読めない**ので、種別で箱を選べない。
///
/// ★★ 副産物: 未決 U5 が種別で割れない ★★
/// 箱の幅が種別で同じ ⇒ `ResizeImage(width:)` に渡す値が種別で同じ ⇒
/// thumb の原寸幅はどの種別も 200px なので、**足りなくなる閾値が 1 つに戻る。**
/// U5 は「スロットの物理幅が 200px を超えるか」の 1 つの判定に還元される（M-B2 で実測）。
///
/// ★★ 空きスロット・領域の背景・札の枠は必ず描画物にする（決定 D46）★★
/// D72 のあと**絵はスロットを埋めない**（ライブは上下に透明な帯）。
/// 掴める / 落とせる矩形を作るのは絵ではなく**外側のラッパ**である。
/// M-B1 にドラッグは無いが、**背景を先に置いておかないと M-B2 で
/// 「ライブだけ帯を掴めない」という種別依存の不具合になる。**
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../common/card_thumb.dart';
import 'board_view.dart';

/// スロット 1 つの論理幅。
///
/// ★★ 暫定値である（未決 U16 / M-B2 で実測して検算する）★★
/// U8 / D61 と同じ手順 —— 暫定値を置き、実装が動く段で測り直す。
/// 盤面は置き場 11 + 共有 1 が同時に見える必要があり、
/// `PaneScaffold` のしきい値 840（D61）とは別の値になる。
const double kBoardSlotWidth = 76;

/// 盤面が成立する最小の論理幅。
///
/// ★★ 暫定値である（未決 U16）★★
/// 内訳: 袖 2 本 + 前列 3 スロット + 余白。**M-B2 で実測して置き換える。**
/// ★下回ったら盤面ごとスクロールする（`PaneScaffold` を使わない / D75）。
///
/// ★★ 暫定値を「置いただけ」にしない ★★
/// この幅で**溢れないこと**は `test/board/board_layout_test.dart` が固定してある
/// （置き場 11 + 共有 1 がすべて存在し、`RenderFlex` の溢れが出ない）。
/// U16 が残しているのは**物理px と可読性の実測**であって、成立するかどうかではない。
///
/// ★M-B1 の実機確認（1800 論理px / 実データ）では余裕をもって収まった。
const double kBoardMinWidth = 1100;

/// 空きスロットと札の共通の箱。
///
/// ★[child] が null なら「空きスロット」。**背景は必ず描く**（決定 D46）。
class BoardSlot extends StatelessWidget {
  const BoardSlot({
    super.key,
    this.width = kBoardSlotWidth,
    this.child,
    this.label,
    this.emphasis = false,
    this.overlay,
  });

  final double width;
  final Widget? child;

  /// スロットの下に出す短い見出し（「左サイド」など）。
  final String? label;

  /// ★共有解決領域など、他と区別したいスロット。
  final bool emphasis;

  /// 落ちる意味を出す帯（`board_drop.dart` の `_EdgeOverlay` / 決定 D47）。
  ///
  /// ★[child] の**上**に重ねる。札の絵で隠れると出す意味が無い。
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(4);

    final box = SizedBox(
      width: width,
      // ★★ 例外なくこの比（決定 D76）★★
      height: width / kCardAspectRatio,
      child: DecoratedBox(
        // ★ColoredBox 相当の塗りを必ず持たせる（決定 D46）。
        //   透明にするとヒットテストが通らない。
        decoration: BoxDecoration(
          color: emphasis
              ? scheme.tertiaryContainer.withValues(alpha: 0.35)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: radius,
        ),
        // ★★ 枠線は前景に描く ★★
        //   札（`BoardPiece`）は D46 のために**箱いっぱいの不透明な矩形**になる。
        //   枠線を背景側に描くと札に覆われ、スロットの境目が消える。
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: radius,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?child,
              ?overlay,
            ],
          ),
        ),
      ),
    );

    if (label == null) return box;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        box,
        const SizedBox(height: 2),
        SizedBox(
          width: width,
          child: Text(
            label!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

/// 表向きの札 1 枚。
///
/// ★★ 箱は [BoardSlot]（[kCardAspectRatio]）のまま。中の枠だけ種別で選ぶ ★★
/// `CardArt` が `cardAspectRatioOf(cardType)` の枠を作って中央に置く（決定 D72）。
///
/// ★キーに printingId を載せてある。**秘匿のテストがこれを見る**
/// （`test/board/board_secrecy_test.dart` / 決定 D77）。
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.card,
    this.width = kBoardSlotWidth,
  });

  final CardInstance card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final view = BoardView.of(context);

    // 4.3.3.2: 裏向きのカードは情報が書かれている面が見えない。
    if (card.face == FaceState.faceDown) {
      return BoardFaceDown(width: width);
    }

    final printing = view.catalog.printings[card.printingId];
    final cardType =
        view.catalog.cards[card.cardNumber]?.cardType ?? CardType.member;

    return CardArt(
      key: ValueKey('board-card-${card.instanceId}'),
      source: view.imageSource,
      imageHash: printing?.imageHash ?? '',
      cardType: cardType,
      // ★箱が枠より縦長なので枠の幅 == 箱の幅（`card_thumb.dart` の不変）。
      logicalWidth: width,
      borderRadius: BorderRadius.circular(3),
    );
  }
}

/// 裏向きの札。総合ルール 4.3.3.2。
///
/// ★★ ドラッグ中の feedback からも使う ★★
/// feedback は `Overlay` に載るので `BoardView` が祖先にならない。
/// **カタログを引く前の値だけで描ける**ことがここでは要る。
///
/// ★★ 絵を要求しない ★★
/// `CardImageSource.provider` を呼ばないので、**裏向きの札の画像は
/// デコードもキャッシュもされない。**
class BoardFaceDown extends StatelessWidget {
  const BoardFaceDown({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Icon(
          Icons.hide_source,
          size: width * 0.3,
          color: scheme.onInverseSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
