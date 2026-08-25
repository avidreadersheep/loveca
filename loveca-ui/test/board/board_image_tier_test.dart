/// 盤面の画像の段（未決 **U5** の解消 / 決定 D82 / D76）.
///
/// ★★ 判定は 1 つに還元されている（決定 D76）★★
/// 箱の比を種別で変えないので `ResizeImage(width:)` に渡す値も種別で同じになり、
/// thumb の原寸幅はどの種別も 200px。よって
/// **「スロットの物理幅が 200px を超えるか」の 1 判定**しか残らない。
///
/// ★★ 答えは定数ではなく DPR の関数である ★★
/// スロット物理幅 = 論理幅 × DPR。盤面のスロット（論理 76）は
/// DPR 1 / 2 では thumb、**DPR 3 で 228 になり初めて normal が要る**。
///
/// ★★ 決定 D42 のキャッシュ見積りはやり直しにならない ★★
/// `ResizeImage(width:)` は**物理幅**であって段ではない。
/// 段が変えるのは読む原本だけで、デコード後の寸法は同じ。
/// **それをここで機械的に固定する**（文章より強い）。
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_slot.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:path/path.dart' as p;

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _live = drawLivePrinting;
const _member = trioMemberPrinting;

/// `real_shaped_catalog.dart` の実データ由来のハッシュ。
const _hashes = <String>[
  'eb37cd1dcab44c4c855f5f42b6d90ce3', // drawLivePrinting
  '2637683a982e97d6217371d8728b4b6c', // trioMemberPrinting
  '66aaea84d46ec559680b76a8f62422e0', // energyPrinting
];

void main() {
  group('★★ cardImageSizeFor: 段は物理幅で決まる（決定 D82）★★', () {
    test('スロット論理 76 は DPR 1 / 2 で thumb', () {
      expect(cardImageSizeFor(kBoardSlotWidth, 1), CardImageSize.thumb);
      expect(cardImageSizeFor(kBoardSlotWidth, 2), CardImageSize.thumb);
      expect(kBoardSlotWidth * 2, lessThanOrEqualTo(200), reason: '★前提');
    });

    test('★対: DPR 3 で 200px を超えるので normal', () {
      expect(kBoardSlotWidth * 3, greaterThan(200), reason: '★前提: 228px');
      expect(cardImageSizeFor(kBoardSlotWidth, 3), CardImageSize.normal);
    });

    test('★境界はちょうど 200px（超えたら normal）', () {
      expect(cardImageSizeFor(200, 1), CardImageSize.thumb);
      expect(cardImageSizeFor(200.5, 1), CardImageSize.normal);
    });

    test('★箱ごとに答えが違う（手札の帯は DPR 3 でも thumb）', () {
      // ★盤面には大きさの違う箱がある。1 つの定数で決められない。
      const handWidth = kBoardSlotWidth * 0.72;
      expect(handWidth * 3, lessThanOrEqualTo(200), reason: '★164px');
      expect(cardImageSizeFor(handWidth, 3), CardImageSize.thumb);
    });
  });

  group('★★ 画面から通した経路 ★★', () {
    late Directory tmp;

    setUp(() {
      // ★実在するファイルを置く。存在しないパスだとデコード失敗が本筋を隠す。
      tmp = Directory.systemTemp.createTempSync('loveca_board_tier');
      for (final size in CardImageSize.values) {
        Directory(p.join(tmp.path, size.directoryName))
            .createSync(recursive: true);
        for (final hash in _hashes) {
          File(p.join(tmp.path, size.directoryName, '$hash.webp'))
              .writeAsBytesSync(_onePixelPng);
        }
      }
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    Future<void> pump(WidgetTester tester, double dpr) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(1600 * dpr, 1300 * dpr);
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: handcraftedBoard(selfZones: const {
            Zone.liveStage: [_live],
            Zone.successLive: [_member],
          }),
          viewerId: kSelfPlayerId,
          seed: 1,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
        imageSource: LocalDirectoryCardImageSource(tmp),
      );
    }

    ResizeImage resize(WidgetTester tester, Zone zone) {
      final image = tester.widget<Image>(
        find
            .descendant(
              of: find.byKey(ValueKey('zone-${zone.name}-$kSelfPlayerId')),
              matching: find.byType(Image),
            )
            .first,
      );
      return image.image as ResizeImage;
    }

    String dir(WidgetTester tester, Zone zone) =>
        p.split((resize(tester, zone).imageProvider as FileImage).file.path)
            .reversed
            .elementAt(1);

    testWidgets('DPR 1: thumb を読む', (tester) async {
      await pump(tester, 1);
      expect(dir(tester, Zone.liveStage), 'thumb');
      expect(dir(tester, Zone.successLive), 'thumb');
    });

    testWidgets('★★ DPR 3: normal を読む（U5 の答え）★★', (tester) async {
      await pump(tester, 3);
      expect(dir(tester, Zone.liveStage), 'normal');
      expect(dir(tester, Zone.successLive), 'normal');
    });

    testWidgets('★★ 種別で割れない（決定 D76 の副産物）★★', (tester) async {
      // ★D72 は「U5 は種別ごとに見ること」と書いていたが、
      //   箱の比を種別で変えない D76 のもとでは**同じ値**になる。
      await pump(tester, 3);

      expect(resize(tester, Zone.liveStage).width,
          resize(tester, Zone.successLive).width);
    });

    testWidgets('★★ デコード幅は段で変わらない（D42 の見積りが生きる）★★',
        (tester) async {
      // ★★ これが「キャッシュの見積りはやり直しにならない」の機械的な証明である ★★
      //   `ResizeImage(width:)` は物理幅。段が変えるのは読む原本だけ。
      await pump(tester, 3);
      final width = resize(tester, Zone.liveStage).width;

      expect(width, (kBoardSlotWidth * 3).round(), reason: '★228px');
      expect(width, lessThan(CardImageSize.normal.sourceWidth),
          reason: '★原寸 500px には届かない（頭打ちが効く前）');
    });
  });
}

/// 1x1 の透明 PNG（デコーダは拡張子ではなく中身を見るので `.webp` でも読める）。
const List<int> _onePixelPng = [
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
