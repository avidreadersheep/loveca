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

/// 使う段を**物理幅**から決める（未決 **U5** の解消 / 決定 D82）.
///
/// ```
/// 段 = スロット物理幅 <= 200 なら thumb、超えるなら normal   （`docs/UI設計メモ.md` §7）
/// ```
///
/// ★★ 定数で `thumb` と書かない ★★
/// スロット物理幅 = 論理幅 × DPR なので、**答えは DPR の関数**である。
/// 盤面のスロット（論理 76）なら DPR 1 / 2 では 76 / 152 で thumb、
/// **DPR 3 で 228 になり初めて 200 を超える**。
/// 手札の帯（論理 54.7）は DPR 3 でも 164 なので thumb のまま——
/// **箱ごとに答えが違う**ので、箱ごとに呼ぶ。
///
/// ★★ 決定 D42 のキャッシュ見積りはやり直しにならない ★★
/// `ResizeImage(width:)` に渡すのは**物理幅**であって段ではない。
/// 段が変えるのは**読む原本**だけで、デコード後の寸法は同じである。
/// 段を上げて増えるのはファイル読み込みの一時領域だけ。
///
/// ★★ 一覧（R4）には使わない ★★
/// D42 の測定条件（セル 120 物理px / thumb）を動かさないため。
/// 一覧のセルは論理 140 で、DPR 2 で 280 と 200 を超えるが、
/// **測定条件のほうを正とする**（変えるなら測り直しが要る / `card_art_test.dart`）。
CardImageSize cardImageSizeFor(double logicalWidth, double devicePixelRatio) =>
    logicalWidth * devicePixelRatio > CardImageSize.thumb.sourceWidth
        ? CardImageSize.normal
        : CardImageSize.thumb;

/// ★★ 画像の読み先の出所（★段 / 決定 **D137-1** ＝ 画経-4 ＋ **D149**）★★
///
/// ★**`DistSource`（**D60**）と★同じ形である** —— ★★「どの段で解決したか」を値として持つ★★。
enum CardImagesSource {
  /// 段 1: ★配信物の中（`dist/images`）。★**PC の既定。★今日までの唯一の形。**
  dist,

  /// ★★段 2: ★端末の領域（★取り込みが書いた写し）★★。★**モバイルの既定。**
  device;

  String get label => switch (this) {
        CardImagesSource.dist => '配信物の中（dist/images）',
        CardImagesSource.device => '端末の領域（取り込みが書いた写し）',
      };
}

/// 解決の答え。★**根と★段を★対で持つ。**
typedef CardImagesLocation = ({Directory? root, CardImagesSource? source});

/// ★★ 画像の読み先を決める（★決定 **D137-1** ＝ 画経-4 の「段を 1 つ足す」）★★
///
/// ## ★★ 読み先は★常に 1 つである（**D137-4** の柵 1）★★
///
/// ★**2 つを同時に読むと★★D43 の害がそのまま戻る★★**
///   （★どちらから来た画像かで★不具合の切り分けができなくなる）。
/// → ★**この関数は★★どちらか 1 つしか返さない★★**（★対で固定した）。
///
/// | 段 | 出所 | ★条件 |
/// |---|---|---|
/// | ★**1** | ★`dist/images` | ★**dist が解決できている**（**D60**） |
/// | ★★**2**★★ | ★★**端末の領域**★★ | ★**dist が解決できていない ★かつ★ ★★そのディレクトリが実在する★★** |
///
/// ## ★★ 段 1 が先である —— ★★今日の形を 1 ミリも変えないため★★
///
/// ★**PC では dist が解決できる**ので、★★段 2 に落ちない★★（**D137-2** の決め手そのもの）。
/// ★**逆にすると、★★PC で★端末の写しのほうが勝つ★★** —— ★配信物のほうが★★完全である★★。
///
/// ## ★★ 段 2 は「実在するときだけ」である。★理由は **D89** ★★
///
/// ★**実在しなくても採ると、★★`hasImageStore` が★常に真になる★★。**
/// → ★**D89 が撃ち分けた「★★設定の問題★★」と「★★データの問題★★」が★★1 つに畳まれる★★。**
/// ★★**それは★実機で 2 人が別々の誤診をした形そのものである**★★（★あちらの doc）。
///
/// ## ★★ 「モバイルで画像が出るようになった」と読まないこと ★★
///
/// ★**この関数は★★読み先を決めるだけである★★。**
/// ★**書く側（取り込み）も、★★いつ取りに行くか★★も★別である**（★§32-6 の 8 の 2 / 3 / 5）。
CardImagesLocation resolveCardImagesRoot({
  required Directory? distDir,
  required Directory? deviceImagesDir,
}) {
  // ★★ 段 1 —— 配信物の中 ★★
  if (distDir != null) {
    return (
      root: Directory(p.join(distDir.path, 'images')),
      source: CardImagesSource.dist,
    );
  }
  // ★★ 段 2 —— 端末の領域（★実在するときだけ）★★
  if (deviceImagesDir != null && deviceImagesDir.existsSync()) {
    return (root: deviceImagesDir, source: CardImagesSource.device);
  }
  return (root: null, source: null);
}

abstract class CardImageSource {
  /// ★★ 画像の置き場そのものがあるか（決定 D89）★★
  ///
  /// ★★ 「空」と「失敗」を同じ型で表さない（`docs/UI設計メモ.md` §3-4(2)）★★
  /// [provider] が null を返す理由は 2 つあり、**原因も対処も違う。**
  ///
  /// | 理由 | 何の問題か | 対処 |
  /// |---|---|---|
  /// | `imageHash` が空（`build --skip-images` 由来の dist / **D-4**） | **データ** | 配信物を作り直す |
  /// | ★**置き場そのものが無い**（dist 未解決 / D60） | **設定** | 設定画面で場所を指定する |
  ///
  /// この口が無いと、画面は 2 つを**同じプレースホルダ**で表すしかない。
  /// 実機で 2 人が別々の誤診をしたのがまさにそれである（決定 D89）。
  bool get hasImageStore;

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

  /// ★dist が解決できていれば置き場はある（決定 D89）。
  @override
  bool get hasImageStore => imagesRoot != null;

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
