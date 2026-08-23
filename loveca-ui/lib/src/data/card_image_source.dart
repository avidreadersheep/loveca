/// カード画像の供給（決定 D57 / `docs/UI設計メモ.md` §5-2）.
///
/// ★★ `FileImage` / `ResizeImage` を構築する唯一の場所 ★★
/// `ImageProvider` を組むのは UI ではなくここである。D57 が抽象を置いた理由は
/// 「実装をもう 1 本足すだけで UI が変わらない」ことなので、
/// **ネットワーク実装は別の `ImageProvider` を返せなければならない。**
/// 組む場所を UI に置くと、その差し替えが成立しない。
///
/// `Image` ウィジェットを作り、セルの物理px を計算するのは `ui/common/card_thumb.dart`。
/// どちらも「唯一の場所」である。
///
/// ★★ 実装は Release 1 では [LocalDirectoryCardImageSource] の 1 本だけ ★★
/// 決定 D43「UI にネットワーク取得の口を作らない」は**実装が 1 本しかないこと**で守る。
/// 抽象を置くこと自体は口を増やさない（D43 の理由は「経路が 2 つあると
/// どちらから来た画像かで不具合の切り分けができなくなる」ことであり、
/// 実装が 1 本なら経路は 1 つのままである）。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

/// 使う段。★Release 1 は `large`（1000px / 380MB）を使わない（決定 D57）。
enum CardImageSize {
  /// 一覧のセル。原寸 200px。
  thumb(200),

  /// カード詳細（M5）。原寸 500px。
  normal(500);

  const CardImageSize(this.sourceWidth);

  /// 配信物の原寸幅。★`cacheWidth` の上限に使う。
  final int sourceWidth;

  String get directoryName => name;
}

abstract class CardImageSource {
  /// [imageHash] が空なら null を返す（＝プレースホルダのまま）。
  ///
  /// [cacheWidthPx] は**物理ピクセル**（決定 D42）。
  /// 論理px を渡すと DPR 倍だけ小さくデコードされ、拡大表示になってぼやける。
  ImageProvider? provider(
    String imageHash,
    CardImageSize size, {
    required int cacheWidthPx,
  });
}

/// ローカルの `dist/images/{段}/{imageHash}.webp` を読む。
///
/// ★このファイル名の組み立ては**こちらが決めた規約**なので行ってよい（決定 D43）。
/// **公式サイトの `picture` から URL を組み立ててはいけない**（CLAUDE.md §5-(3)）。
/// これは別の話であり、緩めない。
class LocalDirectoryCardImageSource implements CardImageSource {
  const LocalDirectoryCardImageSource(this.imagesRoot);

  /// `dist/images`。★dist が無いまま起動している場合は null（決定 D60）。
  final Directory? imagesRoot;

  @override
  ImageProvider? provider(
    String imageHash,
    CardImageSize size, {
    required int cacheWidthPx,
  }) {
    final root = imagesRoot;
    // ★存在しないパスを読ませない。例外か無言の空白になる。
    if (root == null || imageHash.isEmpty || cacheWidthPx <= 0) return null;

    final file = File(
      p.join(root.path, size.directoryName, '$imageHash.webp'),
    );

    // ★★ 物理ピクセルで、かつ原寸を上限にする ★★
    // `docs/UI設計メモ.md` §7 の規則: cacheWidth = min(セル物理px, 原寸幅)。
    // 原寸を超える値を渡してもデコード結果は大きくならないが、
    // 上限を明示しておくと「なぜぼやけるのか」を追える。
    // ★モバイルでは物理セル幅が thumb の原寸 200px を超えうる（§7-1 の未検証項目）。
    final width = cacheWidthPx < size.sourceWidth ? cacheWidthPx : size.sourceWidth;

    // ★決定 D42: ResizeImage が無いと実際にフレームが落ちる
    //   （browse 速度で予算超え 25 フレーム → 0）。
    return ResizeImage(FileImage(file), width: width);
  }
}
