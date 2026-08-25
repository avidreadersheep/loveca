/// カードの絵の枠は種別で選ぶ（決定 D72 / 未決 **U11** の解消）.
///
/// ★★ ここで見るのは「箱は変えず、中の枠だけ種別で選ぶ」ことである ★★
/// 実データの thumb は種別で比が違う（2026-08-24 に 2,527 枚を全数計測）。
///
/// | 種別 | 寸法 | 比 |
/// |---|---|---|
/// | メンバー | 200×279（1,036）/ 200×280（483） | 縦長 **0.717** |
/// | エネルギー | 200×279（484）/ 200×280（228）/ 200×273（5） | 縦長 **0.717** |
/// | ★**ライブ** | **200×143（290）/ 200×144（1）** | **横長 1.399** |
///
/// 以前は全部を 200:279 の箱に `cover` で入れていたため、ライブは
/// **左右 48.7% が切り落とされ、1.951 倍に拡大されていた。**
///
/// ★★ D-10 の適用 ★★
/// 「ライブが正しくなった」だけを見ると、**全部を横長にする実装でも通る。**
/// だから **メンバー / エネルギーが変わっていないこと**を必ず対で固定する。
///
/// ★★ 決定 D42 の測定条件が動いていないことも、ここで機械的に固定する ★★
/// D42 の数値が依存するのは (1) セル幅 (2) `cacheWidth` (3) デコード幅 の 3 つ。
/// タイルの比を変えていないので (1) は不変、枠の幅 == タイルの幅なので (2) も不変、
/// `ResizeImage(width:)` は幅だけを指定するので (3) も不変——というのが
/// 「再測定は不要」の根拠である。**文章ではなくテストで固定する。**
///
/// ★掴める / 押せる矩形が帯を含むことは
/// `test/ui/deck_edit_page_test.dart`（決定 D46 の群）が固定している。
library;

import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/ui/browse/card_browse_page.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';
import 'package:path/path.dart' as p;

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

/// 実測の比（`docs/UI設計メモ.md` §5-1）。★数の出どころは `card_thumb.dart`。
const double _live = kLiveCardAspectRatio;
const double _portrait = kCardAspectRatio;

const double _twoPaneWidth = 1400;

Finder _cell(String printingId) => find.byKey(ValueKey('cardCell:$printingId'));
Finder _deckRow(String printingId) =>
    find.byKey(ValueKey('deckRow:$printingId'));
Finder _cover(String printingId) =>
    find.byKey(ValueKey('metaCover:$printingId'));

/// 箱の中の「絵」。★`CardArt` が作る枠がそのまま [CardThumb] の矩形になる。
Finder _art(Finder box) =>
    find.descendant(of: box, matching: find.byType(CardThumb));

/// 下地（`CardThumb` の `_Placeholder`）。★private なので `ColoredBox` で拾う。
/// セルの中に `ColoredBox` は下地 1 つしかない。
Finder _placeholder(Finder box) =>
    find.descendant(of: box, matching: find.byType(ColoredBox));

/// ドラッグ中の feedback の器（`card_drag.dart` の `_FeedbackShell`）。
/// ★`Opacity` 0.85 はここにしか無い（`childWhenDragging` は 0.3）。
final Finder _feedback =
    find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.85);

/// ライブを含むデッキ。★実在の刷りだけで組む。
Deck _deck() => Deck(
      deckId: 'deck-1',
      name: 'テストデッキ',
      entries: const [
        DeckEntry(printingId: trioMemberPrinting, count: 1),
        DeckEntry(printingId: drawLivePrinting, count: 1),
      ],
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

void _expectRatio(Rect rect, double ratio, {required String reason}) =>
    expect(rect.width / rect.height, closeTo(ratio, 0.01), reason: reason);

void main() {
  /// R4（カード閲覧）を開く。
  Future<void> openBrowse(
    WidgetTester tester, {
    double dpr = 1.0,
    CardImageSource? imageSource,
  }) async {
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = Size(_twoPaneWidth * dpr, 1000 * dpr);
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      const CardBrowsePage(),
      decks: FakeDeckRepository(catalog: realShapedCatalog()),
      catalog: realShapedCatalog(),
      imageSource: imageSource,
    );
  }

  /// R3（デッキ編集）を 2 ペインで開く。
  Future<void> openDeckEdit(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(_twoPaneWidth, 1000);
    addTearDown(tester.view.reset);

    final deck = _deck();
    await pumpInAppScope(
      tester,
      DeckEditPage(deck: deck),
      decks: FakeDeckRepository(decks: [deck], catalog: realShapedCatalog()),
      catalog: realShapedCatalog(),
    );
  }

  group('★★ 一覧のセル（R4 / 決定 D72）★★', () {
    testWidgets('★★ ライブのセルの絵は横長（実測 200×143）★★', (tester) async {
      await openBrowse(tester);

      final cell = tester.getRect(_cell(drawLivePrinting));
      final art = tester.getRect(_art(_cell(drawLivePrinting)));

      _expectRatio(art, _live, reason: 'ライブの thumb は 200×143');
      // ★枠の幅はタイルの幅そのもの。★★ここが崩れると cacheWidth も崩れる（D42）★★
      expect(art.width, closeTo(cell.width, 0.01));
      expect(art.height, lessThan(cell.height));
      // 上下に等しく帯が残る。
      expect(art.center.dy, closeTo(cell.center.dy, 0.01));
      // 帯（片側）は 0.340 × セル幅。★プランの算術をそのまま固定する。
      expect((cell.height - art.height) / 2, closeTo(0.340 * cell.width, 0.5));
    });

    testWidgets('★対: メンバーのセルは 200:279 のままタイル全面を埋める',
        (tester) async {
      // ★★ 出る側だけ見ると「全部を横長にする実装」でも通る ★★
      await openBrowse(tester);

      final cell = tester.getRect(_cell(trioMemberPrinting));
      final art = tester.getRect(_art(_cell(trioMemberPrinting)));

      _expectRatio(art, _portrait, reason: 'メンバーの thumb は 200×279');
      expect(art.width, closeTo(cell.width, 0.01));
      expect(art.height, closeTo(cell.height, 0.01),
          reason: 'メンバーは枠 == タイル。帯は 1px も出ない');
    });

    testWidgets('★対: エネルギーもメンバーと同じ縦長（実データ 567 種）',
        (tester) async {
      await openBrowse(tester);

      final cell = tester.getRect(_cell(energyPrinting));
      final art = tester.getRect(_art(_cell(energyPrinting)));

      _expectRatio(art, _portrait, reason: 'エネルギーの thumb も 200×279');
      expect(art.height, closeTo(cell.height, 0.01));
    });

    testWidgets('★★ タイルの寸法は種別で変わらない（決定 D42 の測定条件）★★',
        (tester) async {
      // ★★ ここが「再測定は不要」の土台である ★★
      //   タイルの比を種別で変えると、セル幅 120 物理px という前提が動き、
      //   `ResizeImage` の効果もキャッシュの見積りも測り直しになる。
      await openBrowse(tester);

      final live = tester.getSize(_cell(drawLivePrinting));
      final member = tester.getSize(_cell(trioMemberPrinting));
      final energy = tester.getSize(_cell(energyPrinting));

      expect(live, member);
      expect(live, energy);
      expect(live.width / live.height, closeTo(_portrait, 0.01),
          reason: 'タイルは 200:279（`spike/main_grid.dart` の再現条件）');
    });
  });

  group('★★ 読み込み中と読み込み済みを取り違えない（決定 D42 の下地）★★', () {
    // ★★ 帯が「絵が出ていない」に見えないか、を形で固定する ★★
    //   読み込み中のメンバーは**タイル全面**が下地、
    //   読み込み中のライブは**横長の枠だけ**が下地。**形が違う。**
    testWidgets('★ライブの下地は横長の枠だけ（タイル全面ではない）', (tester) async {
      await openBrowse(tester);

      final cell = tester.getRect(_cell(drawLivePrinting));
      final base = tester.getRect(_placeholder(_cell(drawLivePrinting)));

      _expectRatio(base, _live, reason: '下地も枠の形');
      expect(base.height, lessThan(cell.height));
    });

    testWidgets('★対: メンバーの下地はタイル全面', (tester) async {
      await openBrowse(tester);

      final cell = tester.getRect(_cell(trioMemberPrinting));
      final base = tester.getRect(_placeholder(_cell(trioMemberPrinting)));

      expect(base.height, closeTo(cell.height, 0.01));
    });
  });

  group('★★ 決定 D42 の cacheWidth が動いていない ★★', () {
    late Directory tmp;

    setUp(() {
      // ★実在するファイルを置く。存在しないパスだとデコード失敗が本筋を隠す。
      tmp = Directory.systemTemp.createTempSync('loveca_card_art');
      for (final size in CardImageSize.values) {
        Directory(p.join(tmp.path, size.directoryName))
            .createSync(recursive: true);
      }
      for (final hash in const [
        'eb37cd1dcab44c4c855f5f42b6d90ce3', // drawLivePrinting
        '2637683a982e97d6217371d8728b4b6c', // trioMemberPrinting
        '66aaea84d46ec559680b76a8f62422e0', // energyPrinting
      ]) {
        File(p.join(tmp.path, CardImageSize.thumb.directoryName, '$hash.webp'))
            .writeAsBytesSync(_onePixelPng);
      }
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    int widthOf(WidgetTester tester, String printingId) {
      final image = tester.widget<Image>(
        find.descendant(of: _cell(printingId), matching: find.byType(Image)),
      );
      return (image.image as ResizeImage).width!;
    }

    testWidgets('★★ ライブとメンバーで同じ。タイル論理幅 × DPR に等しい ★★',
        (tester) async {
      // ★★ これが「D42 の条件は動いていない」の機械的な証明である ★★
      //   `ResizeImage(width:)` は幅だけを指定し、高さは比を保って決まる。
      //   したがってライブは変更前も変更後も 120×86 にデコードされ、
      //   §3-2 / §3-3 の測定はそのまま生きる。
      await openBrowse(tester, imageSource: LocalDirectoryCardImageSource(tmp));

      final tileWidth = tester.getSize(_cell(drawLivePrinting)).width;

      expect(widthOf(tester, drawLivePrinting), tileWidth.round());
      expect(widthOf(tester, trioMemberPrinting), tileWidth.round());
      expect(widthOf(tester, energyPrinting), tileWidth.round());
    });

    testWidgets('★DPR 3 でも原寸 200px で頭打ち（§7 の規則 / 画面から通した経路）',
        (tester) async {
      await openBrowse(
        tester,
        dpr: 3.0,
        imageSource: LocalDirectoryCardImageSource(tmp),
      );

      // タイル論理幅 × 3 は 200 を超える。規則が効いていなければそのまま出る。
      expect(tester.getSize(_cell(drawLivePrinting)).width * 3,
          greaterThan(CardImageSize.thumb.sourceWidth));
      expect(widthOf(tester, drawLivePrinting), CardImageSize.thumb.sourceWidth);
      expect(
          widthOf(tester, trioMemberPrinting), CardImageSize.thumb.sourceWidth);
    });
  });

  group('★★ デッキ行のサムネ（R3 / 34×48 の箱）★★', () {
    testWidgets('★ライブの行の絵は横長', (tester) async {
      await openDeckEdit(tester);

      final art = tester.getRect(_art(_deckRow(drawLivePrinting)));
      _expectRatio(art, _live, reason: '行の中でもライブは横長');
    });

    testWidgets('★対: メンバーの行の絵は縦長のまま', (tester) async {
      await openDeckEdit(tester);

      final art = tester.getRect(_art(_deckRow(trioMemberPrinting)));
      _expectRatio(art, _portrait, reason: 'メンバーは変わっていない');
    });
  });

  group('★★ ドラッグ中の feedback は箱そのものが札（決定 D72）★★', () {
    // ★枠を中に作ると宙に浮くので、feedback だけは**箱の高さ**を種別で決める。
    Future<Size> feedbackFrom(WidgetTester tester, Finder from) async {
      final gesture = await tester.startGesture(tester.getCenter(from));
      // ★kTouchSlop（18）を超えないとドラッグが始まらない。
      //   16 では feedback が作られず「見つからない」で落ちる。
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      final size = tester.getSize(_feedback);
      await gesture.up();
      await tester.pumpAndSettle();
      return size;
    }

    testWidgets('★一覧のセル: ライブは横長 / ★対 メンバーは縦長', (tester) async {
      await openDeckEdit(tester);

      final live = await feedbackFrom(
        tester,
        find.byKey(const ValueKey('catalogCell:$drawLivePrinting')),
      );
      final member = await feedbackFrom(
        tester,
        find.byKey(const ValueKey('catalogCell:$trioMemberPrinting')),
      );

      expect(live.width / live.height, closeTo(_live, 0.01));
      expect(member.width / member.height, closeTo(_portrait, 0.01));
    });

    testWidgets('★デッキ行: ライブは横長 / ★対 メンバーは縦長', (tester) async {
      await openDeckEdit(tester);

      final live = await feedbackFrom(tester, _deckRow(drawLivePrinting));
      final member = await feedbackFrom(tester, _deckRow(trioMemberPrinting));

      expect(live.width / live.height, closeTo(_live, 0.01));
      expect(member.width / member.height, closeTo(_portrait, 0.01));
    });
  });

  group('★★ P3 カバー選択（幅 56 の箱）★★', () {
    Future<FakeDeckRepository> openMeta(WidgetTester tester) async {
      final deck = _deck();
      final decks =
          FakeDeckRepository(decks: [deck], catalog: realShapedCatalog());
      await pumpInAppScope(
        tester,
        const DeckListPage(),
        decks: decks,
        catalog: realShapedCatalog(),
      );
      await tester.tap(find.byTooltip('このデッキの操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('情報を編集'));
      await tester.pumpAndSettle();
      return decks;
    }

    testWidgets('★ライブの候補は横長 / ★対 メンバーは縦長', (tester) async {
      await openMeta(tester);

      await tester.ensureVisible(_cover(drawLivePrinting));
      await tester.pumpAndSettle();

      _expectRatio(tester.getRect(_art(_cover(drawLivePrinting))), _live,
          reason: 'カバー候補もライブは横長');
      _expectRatio(tester.getRect(_art(_cover(trioMemberPrinting))), _portrait,
          reason: 'メンバーは変わっていない');
    });

    testWidgets('★★ 帯を叩いても選べる（決定 D46）★★', (tester) async {
      // ★★ 絵が箱を埋めなくなったので、押せる矩形は外側が作っている ★★
      //   支えは 2 つあり、実測ではどちらか片方でも成立する——
      //   (a) `Container` の `BoxDecoration`（`RenderDecoratedBox.hitTestSelf` が
      //   `Decoration.hitTest` に委ね、矩形の中ならどこでも true）
      //   (b) `InkWell` の `HitTestBehavior.opaque`
      //   ★★ このテストが固定するのは**振る舞い**であって、どちらが効いているかではない ★★
      //   両方消せば落ちる。片方だけ消しても落ちないので、**両方消さないこと。**
      final decks = await openMeta(tester);

      await tester.ensureVisible(_cover(drawLivePrinting));
      await tester.pumpAndSettle();

      final box = tester.getRect(_cover(drawLivePrinting));
      final art = tester.getRect(_art(_cover(drawLivePrinting)));
      final band = art.top - box.top;
      // ★★ ここを緩くすると、枠を外しても通ってしまう ★★
      //   枠が無いと枠の外周は「枠線 1 + 余白 2」の 3px しかない。
      //   `> 2` だとそれで満たされ、**帯を叩いていないのに通る**（D-10 の形）。
      expect(band, greaterThan(10), reason: '帯が実際にある（枠線と余白ではない）');

      // ★帯のちょうど真ん中を叩く。枠の外・箱の中。
      await tester.tapAt(Offset(box.center.dx, box.top + band / 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.coverPrintingId, drawLivePrinting);
    });

    testWidgets('★対: 絵の中央でも選べる（「帯だけ効く」実装を潰す）', (tester) async {
      final decks = await openMeta(tester);

      await tester.ensureVisible(_cover(drawLivePrinting));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(_art(_cover(drawLivePrinting))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.coverPrintingId, drawLivePrinting);
    });
  });

  // =========================================================================
  // ★★ 絵が出ない理由を撃ち分ける（M-B4 / 決定 D89 / `docs/UI設計メモ.md` §11-2）★★
  //
  // ★★ 「空」と「失敗」を同じ表示で表さない（§3-4(2)）★★
  //   `imageHash` が空は**データ**の問題（`build --skip-images` 由来 / D-4）、
  //   置き場が無いのは**設定**の問題（dist 未解決 / D60）。
  //   ★原因も対処も違うのに、同じプレースホルダに畳まれていた。
  //   実機で 2 人が別々の誤診をしたのがそれである。
  //
  // ★★ 2×2 の全部を見る ★★
  //   出る側だけを見ると「常に出す実装」でも通り、
  //   出ない側だけを見ると「常に出さない実装」でも通る（D-10）。
  // =========================================================================
  group('★★ 置き場が無いことを、データが無いことと区別して出す（D89）★★', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('loveca_no_store');
      for (final size in CardImageSize.values) {
        Directory(p.join(tmp.path, size.directoryName))
            .createSync(recursive: true);
      }
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    Finder noStoreMark(String printingId) => find.descendant(
          of: _cell(printingId),
          matching: find.byKey(const ValueKey('no-image-store')),
        );

    testWidgets('★★ 置き場が無い: 専用の印が出る ★★', (tester) async {
      // ★`imagesRoot == null` = dist が解決できていない（決定 D60）。
      await openBrowse(
        tester,
        imageSource: const LocalDirectoryCardImageSource(null),
      );

      expect(noStoreMark(trioMemberPrinting), findsOneWidget);
      expect(noStoreMark(drawLivePrinting), findsOneWidget);
      // ★下地は残る（セルが透明にならない / 決定 D42・D46）。
      expect(_placeholder(_cell(trioMemberPrinting)), findsOneWidget);
    });

    testWidgets('★★ 対: 置き場はあるが imageHash が空 → 従来のプレースホルダのまま ★★',
        (tester) async {
      // ★★ 撃ち分けが片側へ倒れていないことの確認 ★★
      //   これが無いと「常に置き場が無いと言う実装」でも上のテストは通る。
      await pumpInAppScope(
        tester,
        const CardBrowsePage(),
        decks: FakeDeckRepository(catalog: realShapedCatalogWithoutImages()),
        catalog: realShapedCatalogWithoutImages(),
        imageSource: LocalDirectoryCardImageSource(tmp),
      );

      expect(noStoreMark(trioMemberPrinting), findsNothing,
          reason: '★これはデータの問題であって設定の問題ではない');
      expect(_placeholder(_cell(trioMemberPrinting)), findsOneWidget);
    });

    testWidgets('★ 対: 置き場もデータもある → 印は出ない', (tester) async {
      for (final hash in const [
        'eb37cd1dcab44c4c855f5f42b6d90ce3', // drawLivePrinting
        '2637683a982e97d6217371d8728b4b6c', // trioMemberPrinting
      ]) {
        File(p.join(tmp.path, CardImageSize.thumb.directoryName, '$hash.webp'))
            .writeAsBytesSync(_onePixelPng);
      }
      await openBrowse(tester, imageSource: LocalDirectoryCardImageSource(tmp));

      expect(noStoreMark(trioMemberPrinting), findsNothing);
      expect(noStoreMark(drawLivePrinting), findsNothing);
    });

    test('★ 撃ち分けの出どころは `CardImageSource` 1 か所（D57 の抽象）', () {
      // ★★ 画面が `Directory` を直接見て判断しない ★★
      //   ネットワーク実装を足したときに、UI 側の分岐が嘘になる。
      expect(const LocalDirectoryCardImageSource(null).hasImageStore, isFalse);
      expect(LocalDirectoryCardImageSource(Directory.systemTemp).hasImageStore,
          isTrue);
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
