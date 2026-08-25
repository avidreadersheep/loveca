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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_image_source.dart';
import '../../state/board_mode.dart';
import '../common/card_thumb.dart';
import 'board_view.dart';

/// スロット 1 つの論理幅。
///
/// ★★ 未決 U16 は決定 D83 で解消済み。この値は動かしていない ★★
/// 盤面は置き場 11 + 共有 1 が同時に見える必要があり、
/// `PaneScaffold` のしきい値 840（D61）とは別の値になる。
/// ★**札の大きさはウィンドウ幅で変わらない。**可読性はこの値の話であって
/// [kBoardMinWidth] の話ではない（D83 の (b-3)）。
const double kBoardSlotWidth = 76;

/// 袖 1 本ぶんの横幅（メインデッキ / エネルギーデッキ / 控え室…の列）。
///
/// ★内訳: `_Sleeve` の箱（[kBoardSlotWidth] + 左右の余白 24）+ 盤面との間隔 12。
/// ★★ これが「ソロで横方向から消えるもの」のすべてである（決定 D88 / U20）★★
/// 行 3 段（相手の後列 / メンバー列 / 手札の帯）は**縦**に消える。
const double kBoardSleeveWidth = kBoardSlotWidth + 24 + 12;

/// ローカル対戦（両側を描く）で盤面が成立する最小の論理幅。
///
/// ★★ 決定 D83 で確定した（未決 U16 の解消）★★
/// 内訳: 袖 2 本 + 前列 3 スロット + 余白。
/// 実測の下限は (b-1) 506 / (b-2) 496 / ★**(b-3) 696（条文由来 / 6.2.1.5）**で、
/// 採用値はそのすべてを上回る。
/// ★下回ったら盤面ごとスクロールする（`PaneScaffold` を使わない / D75）。
const double kBoardMinWidth = 1100;

/// ★★ ソロで盤面が成立する最小の論理幅（未決 U20 の解消 / 決定 D88）★★
///
/// **袖 1 本ぶんだけ狭い。**構成が「袖 2 本 + 前列 3 スロット + 余白」から
/// 「袖 1 本 + …」に変わるので、[kBoardMinWidth] からその 1 本を引く。
///
/// ★★ 実測して分けると決めた（2026-08-25 / テスト用フォント）★★
///
/// | 下限 | ローカル対戦 | ソロ | 差 |
/// |---|---:|---:|---:|
/// | (b-1) 置き場が横スクロールなしで収まる | 506 | **394** | 112 |
/// | (b-2) 盤面以外が溢れない | 496 | **496** | 0 |
/// | ★**(b-3) 6.2.1.5 の初期手札 6 枚が同時に見える** | 696 | **584** | **112** |
/// | 拘束する下限（最大値） | **696** | **584** | **112** |
///
/// ★★ 判断基準は測る前に宣言してあった ★★
/// 「ソロの下限が 112 論理px 以上小さいときだけ分ける」——
/// 112 は袖 1 本ぶんで、**それだけがソロで横方向から消えるもの**だからである。
/// 実測の差はちょうど 112 で、基準を満たした。
///
/// ★★ 測る前の予測は外れていた ★★
/// 「(b-3) は自分の手札 6 枚が決めるので不変」と書いたが、**(b-3) が測るのは
/// 窓の幅**であって帯の幅ではない。袖が 1 本消えると同じ帯が 112 狭い窓で収まる。
/// ★これを測らずに「据え置き」と書いていたら、ソロで無用の横スクロールが残っていた。
const double kSoloBoardMinWidth = kBoardMinWidth - kBoardSleeveWidth;

/// モードに応じた盤面の最小幅（決定 D88 / U20）。
double boardMinWidthOf(BoardMode mode) => switch (mode) {
      BoardMode.solo => kSoloBoardMinWidth,
      BoardMode.localVersus => kBoardMinWidth,
    };

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
    final face = card.face == FaceState.faceDown
        ? BoardFaceDown(width: width)
        : _art(view, MediaQuery.devicePixelRatioOf(context));

    // ★★ 4.3.2.2 のウェイト状態は「マスターから見て横向き」★★
    //   描かないと「向きを変える」が黙って何も起きない操作になる。
    if (card.orientation != CardOrientation.wait) return face;

    // ★★ 箱の寸法は変えない ★★
    //   変えると D76（箱は例外なく `kCardAspectRatio`）と
    //   D47（`DropEdge` はスロット高さ基準）の前提が両方崩れる。
    //   → **中身だけ**を回し、箱に収まるよう一様に縮める。
    //   縮小率は 箱の幅 / 箱の高さ = `kCardAspectRatio`。
    return Transform(
      key: ValueKey('board-card-wait-${card.instanceId}'),
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(
          kCardAspectRatio,
          kCardAspectRatio,
          kCardAspectRatio,
          1,
        )
        ..rotateZ(math.pi / 2),
      child: face,
    );
  }

  Widget _art(BoardView view, double devicePixelRatio) {
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
      // ★★ 段は物理幅で決める（未決 U5 の解消 / 決定 D82）★★
      //   盤面の札は一覧のセルより大きくなりうる。thumb の原寸は 200px なので、
      //   物理幅がそれを超えると**拡大されてぼやける**。
      size: cardImageSizeFor(width, devicePixelRatio),
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
