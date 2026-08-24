/// カード画像の表示（決定 D42 / D57 / D58）.
///
/// ★★ `Image` ウィジェットを作る唯一の場所 ★★
/// ★★ セルの物理ピクセルを計算する唯一の場所 ★★
///
/// `ImageProvider`（`FileImage` / `ResizeImage`）を組むのは
/// `data/card_image_source.dart` 側（`docs/UI設計メモ.md` §5-2(2)）。
/// どちらも「唯一の場所」であり、役割が違う。
///
/// ★★ プレースホルダは必ず描く（決定 D42）★★
/// 速いスクロール（5,418 px/s）では 2,477 枚中 21〜41 枚しかデコードが
/// 間に合わない。このときフレーム統計は綺麗なままなので、
/// **「フレーム落ちなし」だけを見ると「空白を高速で流しているだけ」を
/// 快適と読み違える**（`docs/UI技術検証メモ.md` §3-4）。
///
/// ★`imageCache` の上限を触らない（決定 D42）。
/// `ResizeImage` を入れると枚数上限（1000 枚）側が先に効くため、
/// バイト上限を上げても載る枚数は変わらない（実測で 1000 枚 / 72.5 MiB のまま）。
/// **上限を触るのではなく 1 枚を小さくするのが正しい手当て。**
///
/// ★`precacheImage` の常時先読みを書かない（決定 D42）。
/// 60 セル先読みは速いスクロールでは実質「全件先読み」になり、
/// RSS ピークが 141〜151 MiB から 175〜178 MiB へ増える。
library;

import 'package:flutter/material.dart';
import 'package:loveca_core/loveca_core.dart';

import '../../data/card_image_source.dart';

/// カードの縦横比（`docs/UI技術検証メモ.md` §3 / §1-2 の実測）。
///
/// ★★ 縦長の札（メンバー / エネルギー）の比 ★★
/// 一覧のセル（`CardGrid`）はこの比で固定してある（D42 の測定条件）。
const double kCardAspectRatio = 200 / 279;

/// ★★ ライブの札は**横長**である ★★
///
/// 実データの thumb 2,527 枚を全数計測した結果（2026-08-24）。
///
/// | 種別 | 寸法 | 比 |
/// |---|---|---|
/// | メンバー | 200×279（1,036 枚）/ 200×280（483 枚） | 縦長 **0.717** |
/// | エネルギー | 200×279（484）/ 200×280（228）/ 200×273（5） | 縦長 **0.717** |
/// | ★**ライブ** | **200×143（290 枚）/ 200×144（1 枚）** | **横長 1.399** |
///
/// ★1px の揺れ（279 / 280）は 0.4% なので 1 つの値に丸めてよい。
/// **ライブとの差は丸められない。**
const double kLiveCardAspectRatio = 200 / 143;

/// 種別に合う枠の比。
///
/// ★★ カード詳細（R5）はこれを使う ★★
/// 縦長の枠にライブを入れると、`BoxFit.contain` では**上下が大きく空き**、
/// `BoxFit.cover` では**札の左右が切れる**。詳細は札を同定するための画面なので
/// どちらも困る。
///
/// ★一覧（`CardGrid`）は全セルを [kCardAspectRatio] のままにしてある。
/// セル幅 120 物理px という D42 の測定条件がその比で得られており、
/// **セルごとに高さが変わるグリッドは別の設計判断**になるため
/// （`docs/UI設計メモ.md` §10 の **U11**）。
double cardAspectRatioOf(CardType cardType) => switch (cardType) {
      CardType.live => kLiveCardAspectRatio,
      CardType.member || CardType.energy => kCardAspectRatio,
    };

/// カードの絵。
///
/// ★★ 名前は thumb だが `normal`（500px）も出す ★★
/// 段は [size] で選ぶ。**`Image` を作る場所を 2 つにしないため**、
/// M5 のカード詳細もこのウィジェットを通す（`docs/UI設計メモ.md` §5-2(2)）。
class CardThumb extends StatelessWidget {
  const CardThumb({
    super.key,
    required this.source,
    required this.imageHash,
    required this.logicalWidth,
    this.size = CardImageSize.thumb,
    this.fit = BoxFit.cover,
  });

  final CardImageSource source;

  /// 空文字なら絵は出ない（`build --skip-images` 由来の dist）。
  final String imageHash;

  /// セルの論理幅。物理px への変換はこのウィジェットの中で行う。
  final double logicalWidth;

  final CardImageSize size;

  /// 一覧のセルは [BoxFit.cover]（枠を埋める）。
  /// ★カード詳細は [BoxFit.contain]——**札の端まで見せるのが目的**なので、
  /// 切り落とすと同定の役に立たない。
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // ★★ 物理ピクセルで指定する（決定 D42）★★
    // 論理px を渡すと DPR 倍だけ小さくデコードされ、拡大表示になってぼやける。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = source.provider(
      imageHash,
      size,
      cacheWidthPx: (logicalWidth * dpr).round(),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // ★下地は常に描く。デコードが間に合わない間、セルが透明にならないように。
        //   ColoredBox にしてあるのでヒットテストも通る（決定 D46）。
        const _Placeholder(),
        if (provider != null)
          Image(
            image: provider,
            fit: fit,
            filterQuality: FilterQuality.medium,
            // ★出るまでは下地のまま。空白を挟まない。
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
                wasSynchronouslyLoaded || frame != null
                    ? child
                    : const SizedBox.expand(),
            // ★読めなかったことを黙って隠さない。下地の上に印を出す。
            errorBuilder: (context, error, stackTrace) => const _BrokenMark(),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      );
}

class _BrokenMark extends StatelessWidget {
  const _BrokenMark();

  @override
  Widget build(BuildContext context) => Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: Theme.of(context).disabledColor,
        ),
      );
}
