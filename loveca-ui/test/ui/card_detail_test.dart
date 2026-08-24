/// R5 カード詳細（M5 / 決定 D66 / `docs/UI設計メモ.md` §2-1 / §2-2）.
///
/// ★★ M5 の主題は「ペイン抽象が 2 通りの器で成立すること」★★
/// したがってここで固定するのは
///
/// - 2 ペイン（PC）でも 1 ペイン（モバイル相当）でも**同じ `CardDetailPane`** が出る
/// - **R3 からも R4 からも**開ける
/// - `normal`（500px / 決定 D57）の `cacheWidth` が原寸を超えない（§7）
/// - `imageHash` が空ならプレースホルダのまま（★空でなければ絵が出る、と対で）
/// - ★**色ハートと `bladeHeartEffects` が混ざらない**（CLAUDE.md §6）
///
/// ★fixture は実データから写したもの（`test/support/real_shaped_catalog.dart`）。
/// 1 枚のダミーカードで通るテストにしない（M4 の教訓）。
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/ui/browse/card_browse_page.dart';
import 'package:loveca_ui/src/ui/browse/filter_panel.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_pane.dart';
import 'package:loveca_ui/src/ui/detail/card_detail_page.dart';
import 'package:loveca_ui/src/ui/detail/card_detail_pane.dart';
import 'package:path/path.dart' as p;

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

/// 2 ペインになる幅 / ならない幅（決定 D61 のしきい値 840 の前後）。
const double _twoPaneWidth = 1400;
const double _onePaneWidth = 700;

Finder _cell(String printingId) =>
    find.byKey(ValueKey('cardCell:$printingId'));

Finder _detailImage() => find.descendant(
      of: find.byKey(const Key('cardDetailImage')),
      matching: find.byType(Image),
    );

/// 詳細は `ListView` なので、下のほうのセクションは**まだ作られていない**。
///
/// ★スクロールしないと `find` に出ないのは「無い」のではなく「まだ作っていない」。
/// 混同すると「出ないこと」のテストが**常に通る**（D-10 と同じ形）ので、
/// **出ない側を見るときはスクロールしきってから見る**か、
/// 上のほうに出るはずのものだけを見る。
Future<void> _scrollDetailTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    120,
    // ★.first を付ける。SelectableText（EditableText）も Scrollable を持つので
    //   絞らないと 'Too many elements' になる。外側の ListView が先に見つかる。
    scrollable: find
        .descendant(
          of: find.byType(CardDetailPane),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Deck _deck() => Deck(
      deckId: 'a',
      name: 'テストデッキ',
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

void main() {
  /// R4（カード閲覧）を開く。
  Future<void> openBrowse(
    WidgetTester tester, {
    double width = _twoPaneWidth,
    double dpr = 1.0,
    MasterCatalog? catalog,
    CardImageSource? imageSource,
  }) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(width * dpr, 1000 * dpr);
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      const CardBrowsePage(),
      decks: FakeDeckRepository(catalog: realShapedCatalog()),
      catalog: catalog ?? realShapedCatalog(),
      imageSource: imageSource,
    );
  }

  /// R3（デッキ編集）を開く。
  Future<void> openDeckEdit(
    WidgetTester tester, {
    double width = _twoPaneWidth,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 1000);
    addTearDown(tester.view.reset);

    final deck = _deck();
    await pumpInAppScope(
      tester,
      DeckEditPage(deck: deck),
      decks: FakeDeckRepository(decks: [deck], catalog: realShapedCatalog()),
      catalog: realShapedCatalog(),
    );
  }

  group('★★ 器は 2 通り、中身は 1 つ（決定 D66 / §2-1）★★', () {
    testWidgets('2 ペイン: secondary が詳細に変わる（一覧は残る）', (tester) async {
      await openBrowse(tester);

      // 開く前は絞り込みが横に出ている。
      expect(find.byType(FilterPanel), findsOneWidget);
      expect(find.byType(CardDetailPane), findsNothing);

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPane), findsOneWidget);
      // ★ルートは押されていない（ペインに出た）。
      expect(find.byType(CardDetailPage), findsNothing);
      // ★★ 一覧は残っている。これが secondary を差し替える理由 ★★
      expect(_cell(trioMemberPrinting), findsOneWidget);
      // 絞り込みは一時的に隠れる。
      expect(find.byType(FilterPanel), findsNothing);
    });

    testWidgets('★2 ペイン: 閉じると元の secondary（絞り込み）に戻る', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('詳細を閉じる'));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPane), findsNothing);
      expect(find.byType(FilterPanel), findsOneWidget);
    });

    testWidgets('1 ペイン: R5 ルートが押される', (tester) async {
      await openBrowse(tester, width: _onePaneWidth);

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      // ★ルートの器。★中身は 2 ペインと同じ Widget。
      expect(find.byType(CardDetailPage), findsOneWidget);
      expect(find.byType(CardDetailPane), findsOneWidget);
      // ★ルートでは閉じるボタンを出さない（AppBar の戻るが担う）。
      expect(find.byTooltip('詳細を閉じる'), findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('★★ どちらの器でも中身は同じ CardDetailPane ★★', (tester) async {
      // 2 ペイン
      await openBrowse(tester);
      await tester.tap(_cell(drawLivePrinting));
      await tester.pumpAndSettle();
      final twoPane = tester.widget<CardDetailPane>(
        find.byType(CardDetailPane),
      );
      expect(twoPane.printingId, drawLivePrinting);
      expect(twoPane.onClose, isNotNull, reason: '2 ペインは閉じるを持つ');

      // 1 ペイン
      await openBrowse(tester, width: _onePaneWidth);
      await tester.tap(_cell(drawLivePrinting));
      await tester.pumpAndSettle();
      final onePane = tester.widget<CardDetailPane>(
        find.byType(CardDetailPane),
      );
      expect(onePane.printingId, drawLivePrinting);
      expect(onePane.onClose, isNull, reason: 'ルートは AppBar の戻るが担う');
    });
  });

  group('★★ R3 / R4 のどちらからも開ける（§2-2）★★', () {
    testWidgets('R4 / 2 ペイン', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPane), findsOneWidget);
    });

    testWidgets('R4 / 1 ペイン', (tester) async {
      await openBrowse(tester, width: _onePaneWidth);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPane), findsOneWidget);
    });

    testWidgets('R3 / 2 ペイン（★デッキペインと入れ替わる）', (tester) async {
      await openDeckEdit(tester);
      expect(find.byType(DeckPane), findsOneWidget);

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPane), findsOneWidget);
      expect(find.byType(DeckPane), findsNothing);
      // ★一覧は残る。
      expect(_cell(trioMemberPrinting), findsOneWidget);
    });

    testWidgets('R3 / 1 ペイン', (tester) async {
      await openDeckEdit(tester, width: _onePaneWidth);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailPage), findsOneWidget);
      expect(find.byType(CardDetailPane), findsOneWidget);
    });
  });

  group('★★ R3 でデッキが隠れることを画面で分かるようにする（決定 D66）★★', () {
    // ★★ デッキを編集中に詳細を開いてデッキが消えると、
    //   保存していない編集が失われたように見える ★★
    testWidgets('★未保存のまま詳細を開いても「未保存の変更があります」が見え続ける',
        (tester) async {
      await openDeckEdit(tester);

      // 名前を変えて未保存にする（M2 から出している表示）。
      await tester.enterText(find.byKey(const Key('deckNameField')), '編集した名前');
      await tester.pumpAndSettle();
      expect(find.text('未保存の変更があります'), findsOneWidget);

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      // ★デッキペインは消えたが、未保存であることは消えない。
      expect(find.byType(DeckPane), findsNothing);
      expect(find.text('未保存の変更があります（戻れば残っています）'), findsOneWidget);
      expect(find.text('デッキ編集中'), findsOneWidget);
    });

    testWidgets('★未保存でなければ「閉じるとデッキに戻ります」と出る（出ない側と対）',
        (tester) async {
      await openDeckEdit(tester);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.text('閉じるとデッキに戻ります'), findsOneWidget);
      expect(find.text('未保存の変更があります（戻れば残っています）'), findsNothing);
    });

    testWidgets('★「デッキに戻る」で戻り、編集が残っている', (tester) async {
      await openDeckEdit(tester);
      await tester.enterText(find.byKey(const Key('deckNameField')), '編集した名前');
      await tester.pumpAndSettle();

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'デッキに戻る'));
      await tester.pumpAndSettle();

      expect(find.byType(DeckPane), findsOneWidget);
      expect(find.byType(CardDetailPane), findsNothing);
      // ★★ 編集は失われていない ★★
      expect(find.text('未保存の変更があります'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(const Key('deckNameField'))).controller!.text,
        '編集した名前',
      );
    });
  });

  group('★★ normal（500px / 決定 D57）を初めて使う ★★', () {
    late Directory tmp;

    setUp(() {
      // ★実在するファイルを置く。存在しないパスだと
      //   デコード失敗の例外がテストの本筋を隠す。
      tmp = Directory.systemTemp.createTempSync('loveca_detail_image');
      for (final size in CardImageSize.values) {
        Directory(p.join(tmp.path, size.directoryName))
            .createSync(recursive: true);
      }
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    /// 1x1 の PNG（デコーダは拡張子ではなく中身を見るので `.webp` でも読める）。
    void placeImage(String imageHash, CardImageSize size) {
      File(p.join(tmp.path, size.directoryName, '$imageHash.webp'))
          .writeAsBytesSync(_onePixelPng);
    }

    testWidgets('★詳細は normal の段を読む', (tester) async {
      const hash = '2637683a982e97d6217371d8728b4b6c';
      placeImage(hash, CardImageSize.normal);
      placeImage(hash, CardImageSize.thumb);

      await openBrowse(tester,
          imageSource: LocalDirectoryCardImageSource(tmp));
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      final provider =
          tester.widget<Image>(_detailImage()).image as ResizeImage;
      final file = (provider.imageProvider as FileImage).file.path;

      // ★一覧は thumb、詳細は normal（決定 D57 / §5-2(1)）。
      expect(p.basename(p.dirname(file)), 'normal');
    });

    testWidgets('★★ cacheWidth が原寸 500px を超えない（§7）★★', (tester) async {
      const hash = '2637683a982e97d6217371d8728b4b6c';
      placeImage(hash, CardImageSize.normal);
      placeImage(hash, CardImageSize.thumb);

      // ★DPR 3。詳細の絵は最大 360 論理px なので 1080 物理px を要求する。
      //   規則が効いていなければ 1080 のままになる。
      await openBrowse(
        tester,
        dpr: 3.0,
        imageSource: LocalDirectoryCardImageSource(tmp),
      );
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      final provider =
          tester.widget<Image>(_detailImage()).image as ResizeImage;

      expect(provider.width, CardImageSize.normal.sourceWidth);
      expect(provider.width, 500);
    });

    testWidgets('★DPR 1 なら表示物理px のままデコードする（頭打ちの対）', (tester) async {
      const hash = '2637683a982e97d6217371d8728b4b6c';
      placeImage(hash, CardImageSize.normal);
      placeImage(hash, CardImageSize.thumb);

      await openBrowse(tester,
          imageSource: LocalDirectoryCardImageSource(tmp));
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      final provider =
          tester.widget<Image>(_detailImage()).image as ResizeImage;

      // 2 ペインの secondary は 320 論理px、左右の余白 16+16 を引いて 288。
      expect(provider.width, lessThan(CardImageSize.normal.sourceWidth));
      expect(provider.width, 288);
    });

    testWidgets('★★ ライブの枠は横長になる（実測 200×143）★★', (tester) async {
      // ★★ 実データの thumb 2,527 枚を全数計測して分かったこと ★★
      //   メンバー / エネルギーは 200×279 の縦長だが、**ライブは 200×143 の横長**。
      //   縦長の枠に入れると contain では上下が大きく空き、cover では左右が切れる。
      await openBrowse(tester);

      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();
      final member = tester.getSize(find.byKey(const Key('cardDetailImage')));
      expect(member.width, lessThan(member.height), reason: 'メンバーは縦長');

      await tester.tap(find.byTooltip('詳細を閉じる'));
      await tester.pumpAndSettle();
      await tester.tap(_cell(drawLivePrinting));
      await tester.pumpAndSettle();
      final live = tester.getSize(find.byKey(const Key('cardDetailImage')));

      expect(live.width, greaterThan(live.height), reason: 'ライブは横長');
      expect(live.width / live.height, closeTo(200 / 143, 0.01));
    });

    testWidgets('★★ imageHash が空ならプレースホルダのまま（§5-2(4)）★★',
        (tester) async {
      // `build --skip-images` で作った dist を模す。実データには 0 件。
      await openBrowse(
        tester,
        catalog: realShapedCatalogWithoutImages(),
        imageSource: LocalDirectoryCardImageSource(tmp),
      );
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      // ★下地は描かれているが `Image` は作られない。
      expect(find.byKey(const Key('cardDetailImage')), findsOneWidget);
      expect(_detailImage(), findsNothing);
    });

    testWidgets('★空でなければ絵が出る（上の対）', (tester) async {
      const hash = '2637683a982e97d6217371d8728b4b6c';
      placeImage(hash, CardImageSize.normal);
      placeImage(hash, CardImageSize.thumb);

      await openBrowse(tester,
          imageSource: LocalDirectoryCardImageSource(tmp));
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(_detailImage(), findsOneWidget);
    });
  });

  group('★★ 実データの多様性がそのまま出る ★★', () {
    testWidgets('★複数キャラ名（2.3.2.1）と複数グループ名（2.4.2.1）', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.text('キャラクター'), findsOneWidget);
      for (final name in ['上原歩夢', '澁谷かのん', '日野下花帆']) {
        expect(find.text(name), findsOneWidget, reason: '＆ 区切りの $name');
      }
      expect(find.text('グループ'), findsOneWidget);
      for (final group in ['虹ヶ咲', 'Liella!', '蓮ノ空']) {
        expect(find.text(group), findsOneWidget);
      }
    });

    testWidgets('メンバーの数値とハート（2.6 / 2.8 / 2.9）', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(trioMemberPrinting));
      await tester.pumpAndSettle();

      expect(find.text('コスト'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('ブレード'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      // 系統C の表記（CLAUDE.md §5-(2)）。
      expect(find.text('桃 3'), findsOneWidget);
      expect(find.text('緑 3'), findsOneWidget);
      expect(find.text('紫 3'), findsOneWidget);
      // ★合計はエンティティから出す（UI で数え直さない）。
      expect(find.text('合計 9'), findsOneWidget);
      // ★ライブの欄は出ない。
      expect(find.text('スコア'), findsNothing);
      expect(find.text('必要ハート'), findsNothing);
    });

    testWidgets('★★ 色ハートと bladeHeartEffects が混ざらない（CLAUDE.md §6）★★',
        (tester) async {
      // AWOKE: bladeHearts {BLUE:1} + bladeHeartEffects {DRAW:1}。
      // 実データで 59 種あるこの同居が、画面で 1 つに見えてはいけない。
      await openBrowse(tester);
      await tester.tap(_cell(drawLivePrinting));
      await tester.pumpAndSettle();

      // ★別々の見出し。
      expect(find.text('ブレードハート'), findsOneWidget);
      expect(find.text('ブレードハートのアイコン'), findsOneWidget);
      // ★色は色として、アイコンはアイコンとして。
      expect(find.text('青 1'), findsOneWidget);
      expect(find.text('ドロー 1'), findsOneWidget);
      // ★★ 合算していない ★★
      //   合算すると「青 2」やアイコン込みの合計が出るはず。出ない。
      expect(find.text('青 2'), findsNothing);
      // ★内部語彙を出さない。
      expect(find.textContaining('DRAW'), findsNothing);
      // 必要ハートに「無」(GRAY / 2.1.1.2) が出る。
      expect(find.text('必要ハート'), findsOneWidget);
      expect(find.text('無 6'), findsOneWidget);
      expect(find.text('青 6'), findsOneWidget);
      expect(find.text('合計 12'), findsOneWidget);
    });

    testWidgets('★SCORE のライブ（色ブレードハートは無い側）', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(scoreLivePrinting));
      await tester.pumpAndSettle();

      expect(find.text('ブレードハートのアイコン'), findsOneWidget);
      expect(find.text('スコア 1'), findsOneWidget);
      // ★色のブレードハートは無いので、見出しごと出ない。
      //   ★末尾まで送ってから見る（まだ作っていないだけ、と区別する）。
      await _scrollDetailTo(tester, find.text('この刷り'));
      expect(find.text('ブレードハート'), findsNothing);
      expect(find.textContaining('SCORE'), findsNothing);
    });

    testWidgets('★ALL（2.1.1.3）は色の側に出る', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(allBladeLivePrinting));
      await tester.pumpAndSettle();

      expect(find.text('ブレードハート'), findsOneWidget);
      expect(find.text('ALL 1'), findsOneWidget);
      // ★アイコンは無いので見出しごと出ない（末尾まで送ってから見る）。
      await _scrollDetailTo(tester, find.text('この刷り'));
      expect(find.text('ブレードハートのアイコン'), findsNothing);
    });

    testWidgets('★★ エネルギーは空の欄が消える（壊れて見えない）★★', (tester) async {
      // 実データの 567 種すべてが「名前とキャラ名しか無い」形。
      await openBrowse(tester);
      await tester.tap(_cell(energyPrinting));
      await tester.pumpAndSettle();

      // ★出ない側を見るので、末尾まで送ってから確かめる。
      await _scrollDetailTo(tester, find.text('この刷り'));

      // 出るもの。
      expect(find.text('高坂穂乃果'), findsWidgets);
      expect(find.text('キャラクター'), findsOneWidget);
      expect(find.text('この刷り'), findsOneWidget);
      // ★出ないもの（空の見出しを並べない）。
      expect(find.text('グループ'), findsNothing);
      expect(find.text('ユニット'), findsNothing);
      expect(find.text('ステータス'), findsNothing);
      expect(find.text('ハート'), findsNothing);
      expect(find.text('必要ハート'), findsNothing);
      expect(find.text('ブレードハート'), findsNothing);
      expect(find.text('効果'), findsNothing);
    });
  });

  group('★★ 同じ cardNumber のほかの刷り（決定 D11 / CLAUDE.md §5-(4)）★★', () {
    testWidgets('3 刷りが並び、パラレルが分かる', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(parallelMemberNormal));
      await tester.pumpAndSettle();
      await _scrollDetailTo(tester, find.text('ほかの刷り'));

      expect(find.text('ほかの刷り'), findsOneWidget);
      for (final id in [
        parallelMemberParallel,
        parallelMemberNormal,
        parallelMemberOtherProduct,
      ]) {
        expect(find.byKey(ValueKey('siblingPrinting:$id')), findsOneWidget);
      }
      // ★パラレルには印が付く（P / RM がパラレル、R が通常刷り）。
      //   ★「この刷り」の欄にも同じレアリティ文字が出るので、
      //     ほかの刷りの行に絞って見る。
      String labelOf(String id) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('siblingPrinting:$id')),
              matching: find.byType(Text),
            ),
          )
          .data!;

      expect(labelOf(parallelMemberParallel), 'P☆');
      expect(labelOf(parallelMemberOtherProduct), 'RM☆');
      expect(labelOf(parallelMemberNormal), 'R');
    });

    testWidgets('★叩くと表示中の刷りが切り替わる', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(parallelMemberNormal));
      await tester.pumpAndSettle();
      await _scrollDetailTo(tester, find.text('この刷り'));
      expect(find.text(parallelMemberNormal), findsOneWidget);

      await _scrollDetailTo(
        tester,
        find.byKey(ValueKey('siblingPrinting:$parallelMemberOtherProduct')),
      );
      await tester.tap(
        find.byKey(ValueKey('siblingPrinting:$parallelMemberOtherProduct')),
      );
      await tester.pumpAndSettle();

      // ★刷りの欄が入れ替わる。商品もまたぐ（BP01 → BP05）。
      await _scrollDetailTo(tester, find.text('この刷り'));
      expect(find.text(parallelMemberOtherProduct), findsOneWidget);
      expect(find.text('BP05'), findsOneWidget);
      expect(find.text('RM（パラレル）'), findsOneWidget);
    });

    testWidgets('刷りが 1 つなら「ほかの刷り」を出さない（出ない側）', (tester) async {
      await openBrowse(tester);
      await tester.tap(_cell(drawLivePrinting));
      await tester.pumpAndSettle();
      // ★★ 出ない側は「まだ作っていない」と区別する ★★
      //   末尾（この刷り）まで送ってから見る。送らずに見ると常に通る。
      await _scrollDetailTo(tester, find.text('この刷り'));

      expect(find.text('ほかの刷り'), findsNothing);
    });
  });

  testWidgets('★★ 見つからない刷りは黙って空白にしない ★★', (tester) async {
    // ★この経路は一覧セルからは到達しない。Phase 4 の同期 / M6 の共有形式で
    //   未知の printingId が入りうるための防御（`card_detail.dart` の doc）。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(_onePaneWidth, 1000);
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      const CardDetailPage(printingId: '同期で降ってきた知らない刷り'),
      decks: FakeDeckRepository(catalog: realShapedCatalog()),
      catalog: realShapedCatalog(),
    );

    expect(find.text('このカードのデータがありません'), findsOneWidget);
    // ★どの刷りが引けなかったのかを出す（見出しと本文の 2 箇所）。
    expect(find.text('同期で降ってきた知らない刷り'), findsWidgets);
  });
}

/// 1x1 の透明 PNG。
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
