/// ★★ `thumb`（200px）が★モバイルの物理セル幅を下回るか（`docs/UI設計メモ.md` §7 の 1）★★
///
/// ★★ 何を測るか ★★
/// ★**§7 の 1 は「★PC の実測セル幅は 120 物理px（＝縮小方向）。★モバイルは DPR 2.5〜3 で
/// ★3 列なら 300〜400 物理px になり、★★原寸 200px を超える★★」と書いている。**
/// ★★**実物に当てる。★文章ではなくテストで固定する**★★（`card_art_test.dart` と同じ作法）。
///
/// ★★ エミュレータは要らない ★★
/// ★**`tester.view.physicalSize` と `devicePixelRatio` を★★渡せば済む★★**
/// （★`card_art_test.dart` が★DPR 3 で同じことをしている）。
/// ★**エミュレータで測ったのは★★別のもの★★である**（★sqlite3 の能力 / `spike/main_sqlite_caps.dart`）。
///
/// ★★ 直していない。★いまの挙動を固定している ★★
/// ★**直すと★この群が落ちる。★★それが合図である★★**（★先例は **D-24** の押下回数）。
/// ★**直すには★§3-3 のキャッシュの見積り（1 枚 74 KB / 1000 枚）を★★測り直す必要がある★★**
/// （★§7 の 1 が自らそう書いている）。★**それは実データとモバイルの実行が要る。**
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/ui/browse/card_browse_page.dart';
import 'package:path/path.dart' as p;

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

/// ★★ エミュレータ「Medium Phone API 36」の実物の値 ★★
/// ★1080 × 2400 物理px / 420dpi → ★**DPR = 420 / 160 = 2.625**。
/// ★**この 3 つは★★機械の値であって★このプロジェクトの決定ではない★★**（**§7-10**）。
const double _phonePhysicalWidth = 1080;
const double _phonePhysicalHeight = 2400;
const double _phoneDpr = 2.625;

/// ★PC の 2 ペイン（`card_art_test.dart` と同じ値）。
const double _twoPaneWidth = 1400;

Finder _cell(String printingId) => find.byKey(ValueKey('cardCell:$printingId'));

/// ★1 × 1 の PNG。★**実在するファイルを置く**（★存在しないと★デコードの失敗が本筋を隠す）。
const List<int> _onePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_mobile_tier');
    for (final size in CardImageSize.values) {
      Directory(p.join(tmp.path, size.directoryName)).createSync(recursive: true);
    }
    for (final hash in const [
      'eb37cd1dcab44c4c855f5f42b6d90ce3', // drawLivePrinting
      '2637683a982e97d6217371d8728b4b6c', // trioMemberPrinting
      '66aaea84d46ec559680b76a8f62422e0', // energyPrinting
    ]) {
      for (final size in CardImageSize.values) {
        File(p.join(tmp.path, size.directoryName, '$hash.webp'))
            .writeAsBytesSync(_onePixelPng);
      }
    }
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> openBrowse(
    WidgetTester tester, {
    required double logicalWidth,
    required double logicalHeight,
    required double dpr,
  }) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(logicalWidth * dpr, logicalHeight * dpr);
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      const CardBrowsePage(),
      decks: FakeDeckRepository(catalog: realShapedCatalog()),
      catalog: realShapedCatalog(),
      imageSource: LocalDirectoryCardImageSource(tmp),
    );
    await tester.pumpAndSettle();
  }

  ({int decoded, CardImageSize size, double logicalWidth}) readCell(
    WidgetTester tester,
    String printingId,
    double dpr,
  ) {
    final image = tester.widget<Image>(
      find.descendant(of: _cell(printingId), matching: find.byType(Image)),
    );
    final resize = image.image as ResizeImage;
    // ★★ どの段を読んだかは★ファイルの置き場（ディレクトリ名）で分かる ★★
    final file = (resize.imageProvider as FileImage).file.path;
    final size = CardImageSize.values.firstWhere(
      (s) => file.contains(s.directoryName),
    );
    return (
      decoded: resize.width!,
      size: size,
      logicalWidth: tester.getSize(_cell(printingId)).width,
    );
  }

  group('★★ 前提 —— ★PC では縮小方向である（★陽性対照 / **D-10**）★★', () {
    testWidgets('★★ PC の 2 ペイン / DPR 1 では★原寸 200px を超えない ★★',
        (tester) async {
      await openBrowse(
        tester,
        logicalWidth: _twoPaneWidth,
        logicalHeight: 1000,
        dpr: 1,
      );

      final live = readCell(tester, drawLivePrinting, 1);
      expect(live.size, CardImageSize.thumb);
      expect(live.logicalWidth * 1,
          lessThanOrEqualTo(CardImageSize.thumb.sourceWidth.toDouble()),
          reason: '★PC では★物理セル幅が原寸を超えない（★§7 の 1 の「120 物理px」）');
      expect(live.decoded, lessThanOrEqualTo(CardImageSize.thumb.sourceWidth));
    });
  });

  group('★★ §7 の 1 —— ★★モバイルでは★原寸を超える（★拡大になる）★★', () {
    testWidgets('★★ 電話の画面 / DPR 2.625 では★原寸 200px を超える ★★',
        (tester) async {
      await openBrowse(
        tester,
        logicalWidth: _phonePhysicalWidth / _phoneDpr,
        logicalHeight: _phonePhysicalHeight / _phoneDpr,
        dpr: _phoneDpr,
      );

      final live = readCell(tester, drawLivePrinting, _phoneDpr);

      // ★★ これが §7 の 1 の断定そのものである ★★
      //   ★**測るのは★★物理セル幅★★であって★デコード幅ではない**（★下の群）。
      expect(live.logicalWidth * _phoneDpr,
          greaterThan(CardImageSize.thumb.sourceWidth.toDouble()),
          reason: '★§7 の 1: 「モバイルは… ★★原寸 200px を超える★★」');

      // ★★ 実測値を固定する（★§7 の 1 は「300〜400」と幅で書いていた）★★
      //   ★**3 列 / ★論理 129.14 / ★★物理 339★★**（★2026-09-01 / ★実測）。
      //   ★**動いたら★§7 の 1 の見積りも動く**（★測り直しの合図である）。
      expect(live.logicalWidth * _phoneDpr, closeTo(339, 0.5));
    });

    testWidgets('★★ デコード幅は★原寸で頭打ちになる（★だから★★拡大になる★★）★★',
        (tester) async {
      // ★★ 最初はここを「200 を超える」と書いた。★★偽だった★★ ★★
      //   ★`card_image_source.dart` が★★`cacheWidthPx` を原寸で切る★★（★実読）。
      //   → ★**デコードは 200px で止まり、★★360 物理px のセルへ引き伸ばされる★★。**
      //   ★**これが「ぼやける」の中身である。**★測って分かった（**D-15 (j)**）。
      await openBrowse(
        tester,
        logicalWidth: _phonePhysicalWidth / _phoneDpr,
        logicalHeight: _phonePhysicalHeight / _phoneDpr,
        dpr: _phoneDpr,
      );

      final live = readCell(tester, drawLivePrinting, _phoneDpr);
      expect(live.decoded, CardImageSize.thumb.sourceWidth,
          reason: '★原寸で頭打ち');
      expect(live.logicalWidth * _phoneDpr, greaterThan(live.decoded),
          reason: '★★セルのほうが広い ＝ 引き伸ばされる★★');
    });

    testWidgets('★★ それでも★読むのは `thumb` のままである（★段が切り替わらない）★★',
        (tester) async {
      // ★★ ここが「直っていない」ことの実物である ★★
      //   ★**`cardImageSizeFor`（決定 **D82**）は★★物理幅から段を選ぶ★★**が、
      //   ★★一覧は★それを 1 度も呼ばない★★（`CardThumb` の既定が `thumb` である）。
      //   ★**盤面（`board_slot.dart`）だけが★呼んでいる。**
      await openBrowse(
        tester,
        logicalWidth: _phonePhysicalWidth / _phoneDpr,
        logicalHeight: _phonePhysicalHeight / _phoneDpr,
        dpr: _phoneDpr,
      );

      final live = readCell(tester, drawLivePrinting, _phoneDpr);
      expect(live.size, CardImageSize.thumb,
          reason: '★★直すとここが落ちる。★それが合図である★★（★先例は D-24）');
    });

    testWidgets('★★ 対: 同じ物理幅を★`cardImageSizeFor` に渡すと `normal` を選ぶ ★★',
        (tester) async {
      // ★★ 手当ては★既に在る。★一覧が呼んでいないだけである ★★
      //   ★**この対が無いと「★段を切り替える手段がそもそも無い」と読める。**
      await openBrowse(
        tester,
        logicalWidth: _phonePhysicalWidth / _phoneDpr,
        logicalHeight: _phonePhysicalHeight / _phoneDpr,
        dpr: _phoneDpr,
      );

      final live = readCell(tester, drawLivePrinting, _phoneDpr);

      expect(cardImageSizeFor(live.logicalWidth, _phoneDpr),
          CardImageSize.normal,
          reason: '★決定 **D82** の関数は★同じ入力で `normal` を選ぶ');
    });

    testWidgets('★★ 対: PC の物理幅では★`cardImageSizeFor` も `thumb` を選ぶ ★★',
        (tester) async {
      // ★★ 上の対が「何を渡しても normal」で通らないこと ★★
      await openBrowse(
        tester,
        logicalWidth: _twoPaneWidth,
        logicalHeight: 1000,
        dpr: 1,
      );

      final live = readCell(tester, drawLivePrinting, 1);
      expect(cardImageSizeFor(live.logicalWidth, 1), CardImageSize.thumb);
    });
  });
}
