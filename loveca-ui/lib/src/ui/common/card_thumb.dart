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

import '../../data/card_image_source.dart';

class CardThumb extends StatelessWidget {
  const CardThumb({
    super.key,
    required this.source,
    required this.imageHash,
    required this.logicalWidth,
    this.size = CardImageSize.thumb,
  });

  final CardImageSource source;

  /// 空文字なら絵は出ない（`build --skip-images` 由来の dist）。
  final String imageHash;

  /// セルの論理幅。物理px への変換はこのウィジェットの中で行う。
  final double logicalWidth;

  final CardImageSize size;

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
            fit: BoxFit.cover,
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
