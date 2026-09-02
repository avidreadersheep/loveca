/// カード画像の解決（決定 D42 / D57 / `docs/UI設計メモ.md` §5-2）.
///
/// ★★ ここが `FileImage` / `ResizeImage` を組む唯一の場所である ★★
/// 規則を設計メモに書いただけで確かめていなかったので固定する
/// （D-6 と同じ「仕組みは置いたが働くことを誰も確かめていない」型）。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late Directory images;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_image_test');
    images = Directory(p.join(tmp.path, 'images'))..createSync(recursive: true);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  CardImageSource source() => LocalDirectoryCardImageSource(images);

  /// `ResizeImage` の `width` を取り出す。
  int? resizeWidthOf(ImageProvider? provider) =>
      provider is ResizeImage ? provider.width : null;

  String? filePathOf(ImageProvider? provider) {
    final inner = provider is ResizeImage ? provider.imageProvider : provider;
    return inner is FileImage ? inner.file.path : null;
  }

  group('★ 絵が出せない条件では null を返す（プレースホルダのまま）', () {
    test('★imageHash が空（`build --skip-images` 由来の dist）', () {
      // 設計メモ §5-2(4)。組み立てて存在しないパスを読むと
      // 例外か無言の空白になる。
      expect(source().provider('', CardImageSize.thumb, cacheWidthPx: 120),
          isNull);
    });

    test('★dist が無いまま起動している（決定 D60 の続行経路）', () {
      const noRoot = LocalDirectoryCardImageSource(null);

      expect(noRoot.provider('abc', CardImageSize.thumb, cacheWidthPx: 120),
          isNull);
    });

    test('セル幅がまだ確定していない（0 以下）', () {
      expect(
          source().provider('abc', CardImageSize.thumb, cacheWidthPx: 0), isNull);
      expect(source().provider('abc', CardImageSize.thumb, cacheWidthPx: -1),
          isNull);
    });
  });

  group('パスの組み立て', () {
    test('{段}/{imageHash}.webp を組む', () {
      final provider =
          source().provider('deadbeef', CardImageSize.thumb, cacheWidthPx: 120);

      expect(
        p.canonicalize(filePathOf(provider)!),
        p.canonicalize(p.join(images.path, 'thumb', 'deadbeef.webp')),
      );
    });

    test('段ごとにディレクトリが変わる', () {
      final normal =
          source().provider('deadbeef', CardImageSize.normal, cacheWidthPx: 300);

      expect(filePathOf(normal), contains('normal'));
    });
  });

  group('★★ cacheWidth = min(セル物理px, 原寸幅)（設計メモ §7）★★', () {
    test('原寸より小さいセルはセル幅でデコードする（決定 D42）', () {
      // thumb の原寸は 200px。PC の実測セル幅は 120 物理px。
      final provider =
          source().provider('h', CardImageSize.thumb, cacheWidthPx: 120);

      expect(resizeWidthOf(provider), 120);
    });

    test('★原寸を超えるセルは原寸で頭打ちにする', () {
      // ★モバイルでは DPR 2.5〜3 で物理セル幅が thumb の原寸 200px を
      //   超えうる（`docs/UI設計メモ.md` §7-1 の未検証項目）。
      //   原寸を超える値を渡してもデコード結果は大きくならないが、
      //   上限を明示しておくと「なぜぼやけるのか」を追える。
      final provider =
          source().provider('h', CardImageSize.thumb, cacheWidthPx: 400);

      expect(resizeWidthOf(provider), CardImageSize.thumb.sourceWidth);
      expect(resizeWidthOf(provider), 200);
    });

    test('normal の原寸は 500px', () {
      expect(CardImageSize.normal.sourceWidth, 500);
      expect(
        resizeWidthOf(
            source().provider('h', CardImageSize.normal, cacheWidthPx: 9999)),
        500,
      );
    });

    test('ちょうど原寸なら原寸', () {
      expect(
        resizeWidthOf(
            source().provider('h', CardImageSize.thumb, cacheWidthPx: 200)),
        200,
      );
    });
  });

  test('★必ず ResizeImage を通す（決定 D42）', () {
    // ResizeImage が無いと browse 速度で予算超え 25 フレームになる
    // （`docs/UI技術検証メモ.md` §3-2）。素の FileImage を返さない。
    final provider =
        source().provider('h', CardImageSize.thumb, cacheWidthPx: 120);

    expect(provider, isA<ResizeImage>());
  });

  test('★Release 1 は large を持たない（決定 D57）', () {
    // 380MB あり配布物の 2/3 を占めるので使わない。
    // 段が増えていたらこのテストが落ちて再判断を促す。
    expect(CardImageSize.values.map((e) => e.name), ['thumb', 'normal']);
  });

  // ★★ 画像の読み先の段（★決定 **D137-1** ＝ 画経-4 ／ **D149-2**）★★
  //
  // ★★ 何を守っているか ★★
  // ★**読み先は★★常に 1 つである★★**（**D137-4** の柵 1 —— ★2 つ読むと **D43** の害が戻る）。
  // ★**段 1 が先である** —— ★★PC の形を 1 ミリも変えない★★（**D137-2** の決め手）。
  group('★★ 画像の読み先の段（決定 D149-2）★★', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('loveca_img_root'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Directory sub(String name) => Directory(p.join(tmp.path, name));

    test('★★ 段 1 —— ★dist が解決できていれば `dist/images` ★★', () {
      final dist = sub('dist')..createSync();

      final got =
          resolveCardImagesRoot(distDir: dist, deviceImagesDir: sub('device'));

      expect(got.source, CardImagesSource.dist);
      expect(got.root!.path, p.join(dist.path, 'images'));
    });

    test('★★ 段 1 が先である —— ★端末の領域が★実在していても勝たない ★★', () {
      // ★★ 逆にすると★PC で★端末の写しのほうが勝つ（★配信物のほうが完全である）★★
      final dist = sub('dist')..createSync();
      final device = sub('device')..createSync();

      final got = resolveCardImagesRoot(distDir: dist, deviceImagesDir: device);

      expect(got.source, CardImagesSource.dist);
    });

    test('★★ 段 2 —— ★dist が無く、★端末の領域が★実在すれば★そちら ★★', () {
      final device = sub('device')..createSync();

      final got =
          resolveCardImagesRoot(distDir: null, deviceImagesDir: device);

      expect(got.source, CardImagesSource.device);
      expect(got.root!.path, device.path);
    });

    test('★★ 段 2 は★★実在するときだけ★★である（★理由は D89）★★', () {
      // ★★ 実在しなくても採ると `hasImageStore` が常に真になり、
      //   ★★「設定の問題」と「データの問題」が 1 つに畳まれる★★（★D89 が撃ち分けた分）。
      final got = resolveCardImagesRoot(
          distDir: null, deviceImagesDir: sub('not-there'));

      expect(got.source, isNull);
      expect(got.root, isNull);
    });

    test('★ どちらも無ければ null（★今日までの形）', () {
      final got = resolveCardImagesRoot(distDir: null, deviceImagesDir: null);

      expect(got.root, isNull);
      expect(got.source, isNull);
    });

    test('★★ 対: ★`hasImageStore` は★段が決まったときだけ真である（D89）★★', () {
      final none = LocalDirectoryCardImageSource(
          resolveCardImagesRoot(distDir: null, deviceImagesDir: null).root);
      final device = sub('device')..createSync();
      final some = LocalDirectoryCardImageSource(
          resolveCardImagesRoot(distDir: null, deviceImagesDir: device).root);

      expect(none.hasImageStore, isFalse, reason: '★★設定の問題として出せる★★');
      expect(some.hasImageStore, isTrue);
    });

    test('★★ 出所は★段と対で持つ（★`DistSource` と同じ形 / D60）★★', () {
      expect(CardImagesSource.dist.label, contains('dist'));
      expect(CardImagesSource.device.label, contains('端末'));
      expect(CardImagesSource.values, hasLength(2),
          reason: '★★段は 2 つである。★増やすなら★読み先が 1 つであることを確かめ直すこと★★');
    });
  });
}
