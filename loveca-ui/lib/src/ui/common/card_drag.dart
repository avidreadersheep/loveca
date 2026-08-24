/// ドラッグの唯一の実装（決定 D46 / D47 / D58）.
///
/// ★★ 素の `Draggable` / `DragTarget` を UI コードで直接使わない ★★
/// D51 は `spike/` のコードを流用しないと定めたので知見は書き写すことになるが、
/// **書き写した知見は、次に書く人が知らなければ守られない。**
/// D46 の発見（掴める領域は描画物の上にしか無い）は**知らないと必ず踏み、
/// 踏んでも例外が出ない。**「たまに掴めない」という再現条件の分かりにくい不具合になる。
/// → 知見はこのファイルに **1 回だけ**実装する（`docs/UI設計メモ.md` §6-1）。
///
/// 実装している知見は 5 つ。
///
/// | # | 知見 | 出典 | ここでの実装 |
/// |---|---|---|---|
/// | 1 | 掴める領域は**実際に描かれているもの**の上にしか無い | D46 / 技術検証メモ §6-1 | [CardDragSource.background] / [CardDropTarget.background] を**必須**にし、`ColoredBox` で必ず包む |
/// | 2 | `DragTargetDetails.offset` は feedback の左上でポインタ位置ではない | D47 / 同 §6-3 | `dragAnchorStrategy: pointerDragAnchorStrategy` を**常に**指定する |
/// | 3 | 落下点の上半分／下半分を撃ち分ける | D47 / 同 §6-3 | [CardDropTarget] が `globalToLocal` で [DropEdge] を出す |
/// | 4 | `onDragEnd` は当てにならない（落下先が元の行を作り直すと呼ばれない） | D46 / 同 §6-6 | ★**API に出さない。**確定は [CardDropTarget.onDrop] だけ |
/// | 5 | タッチは長押し起点にする（スクロールとアリーナを奪い合う） | D46 / 同 §7-2 | [DragStartMode] で開始ジェスチャだけ差し替える |
///
/// ★★ `ReorderableListView` を採らない（D46 / 同 §6-2）★★
/// 行のドラッグを自分で握るため行を `Draggable` にできず、
/// 「並べ替え」と「デッキから外す」を同じ行で両立できない。
/// 行ごとに [CardDropTarget] を置くこと。**lint では検知できないので、ここに書いておく。**
///
/// ★使われない経路は静かに腐る（D51 と同じ性質）。
/// [DragStartMode] の**両方**を `test/common/card_drag_test.dart` が通している。
library;

import 'package:flutter/material.dart';

/// ドラッグの開始方法（決定 D46 / `docs/UI技術検証メモ.md` §7-2）.
///
/// ★デスクトップ（マウス）では 3 方式とも成立する（同 §6-4）ので [immediate] でよい。
/// ★タッチでは同じ縦方向の指の動きがスクロールとドラッグのどちらにも解釈でき、
/// スクロール側が勝ちやすい。**Phase 5 では [longPress] を使う想定**。
/// ただし**実機未検証**であり、Phase 5 の前に確かめ直すこと。
enum DragStartMode { immediate, longPress }

/// 落下点が対象の前寄りか後ろ寄りか（決定 D47）.
///
/// 縦に並ぶリストなら「上半分＝手前に差し込む」「下半分＝後ろに差し込む」。
/// ★盤面（Phase 3b）の重ね置き（4.5.5）でも同じ判定を使う。
enum DropEdge { leading, trailing }

/// 掴む側。
///
/// ★[background] は必須。`null` 許容にしない（決定 D46）。
/// 省略できるようにすると、省略した箇所だけ**行の余白を押しても掴めない**という
/// 再現条件の分かりにくい不具合になる。spike では並べ替え 0/5・削除 0/3 だった。
class CardDragSource<T extends Object> extends StatelessWidget {
  const CardDragSource({
    super.key,
    required this.data,
    required this.background,
    required this.feedback,
    required this.child,
    this.mode = DragStartMode.immediate,
    this.enabled = true,
  });

  /// 落下先へ渡す値。
  final T data;

  /// ★★ 掴める矩形を作るための色（決定 D46）★★
  /// 色も装飾も持たない `Container` / `Row` / `Column` は自分の矩形をヒットテストしない。
  /// そのため**行の余白**（テキスト行の隙間など）を押しても `Draggable` まで届かず、
  /// ドラッグがそもそも始まらない。
  final Color background;

  /// ドラッグ中についてくる絵。★見栄えで選んでよい（技術検証メモ §6-5。
  /// 画像でも単色でもフレーム統計に差は出なかった）。
  final Widget feedback;

  final Widget child;

  final DragStartMode mode;

  /// false なら掴めない（例: マスタに無い刷り / 決定 D35）。
  /// ★描画は変えない。**掴めないことは別に説明する**（黙って動かないだけにしない）。
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // ★★ ここが D46 の手当てそのもの ★★
    // ColoredBox は HitTestBehavior.opaque 相当で、矩形全体がヒットテストされる。
    final grabbable = ColoredBox(color: background, child: child);
    if (!enabled) return grabbable;

    final shell = _FeedbackShell(child: feedback);
    final whenDragging = Opacity(opacity: 0.3, child: grabbable);

    // ★★ onDragStarted / onDragEnd を受け取れる口を作らない ★★
    // 後始末を onDragEnd に置くと、落下先が元の行を作り直したときに呼ばれない
    // （実測: 開始 5 / 終了 0）。状態の確定は CardDropTarget.onDrop だけにする。
    return switch (mode) {
      DragStartMode.immediate => Draggable<T>(
          data: data,
          // ★★ ポインタ位置と feedback の左上を揃える（決定 D47）★★
          // 既定だと DragTargetDetails.offset が feedback の左上になり、
          // **札のどこを掴んだかで上下判定が変わる。**
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: shell,
          childWhenDragging: whenDragging,
          child: grabbable,
        ),
      DragStartMode.longPress => LongPressDraggable<T>(
          data: data,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: shell,
          childWhenDragging: whenDragging,
          child: grabbable,
        ),
    };
  }
}

/// feedback の器。
///
/// ★Overlay に載るので親の `Material` が効かない。自分で包む。
/// ★`pointerDragAnchorStrategy` だと feedback の左上がポインタ位置に来るので、
/// **見た目だけ**中央へ寄せる。判定（[DropEdge]）はポインタ位置で行うので影響しない。
class _FeedbackShell extends StatelessWidget {
  const _FeedbackShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Opacity(opacity: 0.85, child: child),
        ),
      );
}

/// 落とす側。
///
/// ★[background] は必須（掴む側と同じ理由 / 決定 D46）。
/// ★[builder] は「いまどちらの意味で落ちるか」を受け取る。
/// **出さないと利用者は気づけない**（決定 D47）。
class CardDropTarget<T extends Object> extends StatefulWidget {
  const CardDropTarget({
    super.key,
    required this.background,
    required this.onDrop,
    required this.builder,
    this.accepts,
  });

  final Color background;

  /// ★★ 状態の確定はここだけ（決定 D46 §6-6）★★
  final void Function(T data, DropEdge edge) onDrop;

  /// [hovering] が null なら乗っていない。
  final Widget Function(BuildContext context, DropEdge? hovering) builder;

  /// 受け取れるかどうか。null なら何でも受け取る。
  final bool Function(T data)? accepts;

  @override
  State<CardDropTarget<T>> createState() => _CardDropTargetState<T>();
}

class _CardDropTargetState<T extends Object> extends State<CardDropTarget<T>> {
  DropEdge? _hovering;

  /// 落下点が上半分か下半分か（決定 D47）。
  ///
  /// ★[global] は `pointerDragAnchorStrategy` のおかげで**ポインタ位置**である。
  /// 指定を外すと feedback の左上になり、掴んだ場所で結果が変わる。
  DropEdge? _edgeOf(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    return local.dy < box.size.height / 2
        ? DropEdge.leading
        : DropEdge.trailing;
  }

  void _setHovering(DropEdge? edge) {
    if (_hovering == edge) return;
    setState(() => _hovering = edge);
  }

  @override
  Widget build(BuildContext context) => DragTarget<T>(
        onWillAcceptWithDetails: (details) =>
            widget.accepts?.call(details.data) ?? true,
        onMove: (details) => _setHovering(_edgeOf(details.offset)),
        onLeave: (_) => _setHovering(null),
        onAcceptWithDetails: (details) {
          final edge = _edgeOf(details.offset) ?? DropEdge.leading;
          _setHovering(null);
          widget.onDrop(details.data, edge);
        },
        // ★掴む側と同じ手当て（決定 D46）。落とす側も描画物にしておく。
        builder: (context, candidate, rejected) => ColoredBox(
          color: widget.background,
          child: widget.builder(context, _hovering),
        ),
      );
}
