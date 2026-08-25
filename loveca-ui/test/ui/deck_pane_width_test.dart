/// デッキペインの最小幅（未決 **U8** の検算 / 決定 D61）.
///
/// ★★ U8 の論点は「320 が実測ではなく見積りである」ことだった ★★
/// `PaneScaffold.twoPaneMinWidth = 840` の根拠は 2 段あり、格が違う。
///
/// | # | 根拠 | 格 |
/// |---|---|---|
/// | (a) | Material 3 の expanded 境界 840dp | 外部の標準。確か |
/// | (b) | 一覧 3 列（444）+ デッキペイン（**320**）+ 余白 | ★M4 まで見積り |
///
/// ここで測るのは (b) のデッキペイン側である。
///
/// ★★ 測る前に「削らないもの」を決めてある ★★
/// `lib/src/ui/deck/deck_pane.dart` の doc に 6 項目として書いた
/// （名前+保存 / メモ / 中身の一覧 / ゴミ箱 / 縮退 / P1 常設）。
/// **320 に収まるよう表示を削ってから測ると検算にならない。**
///
/// ★★ この値は「構造の下限」であって寸法の正ではない ★★
/// `flutter test` は**テスト用フォント**で組む（日本語の実幅ではない）。
/// **正は実機の値**で、`docs/UI設計メモ.md` §9-6 に置く。
/// ここは (1) 回帰ガード（レイアウトを変えて広がったら落ちる）と
/// (2) 実機で測る前の当たりをつけるためのもの。
///
/// ★debug / profile でこの値は変わらない。レイアウトは同じ RenderObject・
/// 同じ制約・同じフォントで計算され、`kDebugMode` は寸法に影響しない。
/// §9-3 の注記（**時間**は debug と profile で違う）とは別の話である。
///
/// ★★★ 2026-08-25 訂正: 二分探索が溢れを取りこぼしていた（M-B2 で発覚）★★★
/// `DebugOverflowIndicatorMixin._overflowReportNeeded` は一度報告すると false になり、
/// **`reassemble`（ホットリロード）でしか戻らない。**
/// 幅を変えて同じツリーを `pumpWidget` し直しても `RenderObject` は使い回されるので、
/// **2 回目以降の溢れが黙って落ちていた。**
/// → 探索は「1 回目だけ真、あとは全部偽」になり、**下限のすぐ上に収束していた。**
///
/// | | 訂正前 | 訂正後 |
/// |---|---:|---:|
/// | 溢れの下限（テスト用フォント） | 151 | **198** |
///
/// ★★ 決定 D61 の結論は変わらない ★★
/// 採用値 `kDeckPaneMinWidth = 320` はどちらの値も上回っており、
/// 「2 ペインにした瞬間に一覧が 3 列を割らない」という根拠 (b) は成立したまま。
/// **変わったのは記録されていた数値であって判断ではない。**
///
/// ★手当ては「毎回ツリーを捨ててから組み直す」。
/// ★これは D-10（検知手段自身が同じ罠を踏む）の実例である。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/state/deck_edit_store.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';
import 'package:loveca_ui/src/ui/deck/deck_pane.dart';
import 'package:loveca_ui/src/ui/layout/pane_scaffold.dart';

import '../support/fake_deck_repository.dart';

/// 全区分 + 未知の刷り + 並べ替え済み（縮退 2 本）という**最も混んだ状態**で測る。
Deck _crowdedDeck() => Deck(
      deckId: 'a',
      name: 'デッキ',
      entries: const [
        DeckEntry(printingId: 'M-1-N', count: 4),
        DeckEntry(printingId: 'M-2-N', count: 3),
        DeckEntry(printingId: 'L-1-N', count: 2),
        DeckEntry(printingId: 'E-1-N', count: 12),
        DeckEntry(printingId: '知らない刷り', count: 1),
      ],
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

Widget _pane(DeckEditStore store, double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            height: 900,
            child: DeckPane(
              store: store,
              imageSource: const LocalDirectoryCardImageSource(null),
              config: RuleConfig.standard,
              nameController: TextEditingController(text: 'デッキ'),
              memoController: TextEditingController(),
              onSave: () {},
      onEditMeta: () {},
            ),
          ),
        ),
      ),
    );

void main() {
  /// その幅で溢れるか。★溢れは paint 時に FlutterError として上がる。
  Future<bool> overflowsAt(WidgetTester tester, double width) async {
    final store = DeckEditStore(
      FakeDeckRepository(decks: [_crowdedDeck()]),
      _crowdedDeck(),
    );
    // 並べ替えて縮退を 2 本とも出す（★いちばん縦にも横にも混む状態）。
    store.moveEntry('M-2-N', 'M-1-N', DropEdge.leading);
    // ★★ 溢れは複数箇所で同時に起きる ★★
    //   `takeException` は 1 つしか保持せず、2 つ目からは
    //   「Multiple exceptions」に化けて中身が読めない。自分で拾う。
    //   ★溢れ以外の例外は握らず、元のハンドラへ流す（決定 D53 と同じ考え方）。
    // ★★ ここが要（上の doc の訂正を参照）★★
    //   捨てないと `RenderObject` が使い回され、2 回目以降の溢れが報告されない。
    await tester.pumpWidget(const SizedBox.shrink());

    var overflowed = false;
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) {
        overflowed = true;
      } else {
        previous?.call(details);
      }
    };
    await tester.pumpWidget(_pane(store, width));
    FlutterError.onError = previous;

    store.dispose();
    return overflowed;
  }

  testWidgets('★★ U8: デッキペインの最小幅を測る ★★', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    // ★二分探索。下限は溢れる幅、上限は溢れない幅であることを先に確かめる。
    //   ★★ 下限が真になることだけでは足りない ★★
    //     溢れが 1 回しか報告されないと、下限だけ真であとは全部偽になる。
    //     探索の**途中でも真が出る**ことは、結果が下限 +1 でないことで分かる。
    expect(await overflowsAt(tester, 120), isTrue, reason: '狭すぎれば溢れるはず');
    expect(await overflowsAt(tester, 600), isFalse);

    var low = 120.0; // 溢れる
    var high = 600.0; // 溢れない
    while (high - low > 1) {
      final mid = ((low + high) / 2).roundToDouble();
      if (await overflowsAt(tester, mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }

    // ignore: avoid_print
    print('★U8 測定（テスト用フォント）: デッキペインが溢れない最小幅 = $high 論理px');

    // ★★ 回帰ガード ★★
    // 採用値がこれを下回っていたら、そもそも溢れる幅を使っていることになる。
    expect(
      high,
      lessThanOrEqualTo(kDeckPaneMinWidth),
      reason: '採用している kDeckPaneMinWidth では溢れてしまう',
    );
    // ★★ 探索が「下限 +1」に落ちていないこと ★★
    //   落ちていたら溢れの取りこぼし（上の訂正）が再発している。
    expect(high, greaterThan(121),
        reason: '★下限のすぐ上に収束している = 溢れが報告されていない');
  });

  testWidgets('採用値 kDeckPaneMinWidth では溢れない', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    expect(await overflowsAt(tester, kDeckPaneMinWidth), isFalse);
  });

  testWidgets('★★ 採用値で、行の名前に 120 論理px 以上が残る ★★', (tester) async {
    // ★★ 「溢れない」は「読める」ではない ★★
    //   名前は ellipsis で潰れるので、幅を削っても溢れずに**読めなくなるだけ**。
    //   上の 151 は**溢れの下限**であって使える幅ではない。
    //   そこで、フォントに依らない指標——**固定幅の部品を引いた残り**——を測る。
    //   サムネ・間隔・枚数コントロール・左右の余白はすべて論理px 固定なので、
    //   この値は debug / profile / 実機でも同じになる。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    final store = DeckEditStore(
      FakeDeckRepository(decks: [_crowdedDeck()]),
      _crowdedDeck(),
    );
    addTearDown(store.dispose);
    await tester.pumpWidget(_pane(store, kDeckPaneMinWidth));

    final thumbRight = tester.getRect(find.byType(CardThumb).first).right;
    final controlsLeft =
        tester.getRect(find.byIcon(Icons.remove).first).left;

    // ignore: avoid_print
    print('★U8 測定: 採用値 $kDeckPaneMinWidth 論理px で '
        '名前に残る幅 = ${controlsLeft - thumbRight} 論理px');

    expect(controlsLeft - thumbRight, greaterThanOrEqualTo(120));
  });

  test('★★ U8 の算数: 一覧 3 列 + 仕切り + デッキペイン ≤ しきい値 ★★', () {
    // 一覧 3 列（決定 D42 の寸法 / `card_grid.dart`）。
    const listThreeColumns = 3 * 140 + 6 * 4; // = 444
    const divider = 1;

    // ★★ ここが決定 D61 の根拠 (b) そのもの ★★
    // 320 は見積りだったが、M4 で実測に置き換えた（上のテスト）。
    expect(
      listThreeColumns + divider + kDeckPaneMinWidth,
      lessThanOrEqualTo(PaneScaffold.twoPaneMinWidth),
      reason: '2 ペインにした瞬間に一覧が 3 列を割るなら、しきい値が低すぎる',
    );
  });
}
