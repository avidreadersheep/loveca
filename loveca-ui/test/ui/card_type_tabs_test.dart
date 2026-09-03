/// カテゴリタブ（`docs/Android UI 決定.md` §1-2 / §3-5）.
///
/// ★★ 種別を絞り込みパネルから外し、タブへ移した ★★
/// ★**Windows も同じ**（★申し送りが明記している）。
///
/// ★★ 移す前は★対が 1 つも無かった ★★
/// ★2026-09-03 に実測した —— ★**`filter_panel.dart` から 種別 の `Dropdown` を
/// ★★丸ごと消しても 1220 件が全部通った★★**（**D-20** / **D-27**）。
/// → ★**移した先には★★最初から対を置く★★。**
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/card_browse_store.dart';
import 'package:loveca_ui/src/ui/browse/card_type_tabs.dart';
import 'package:loveca_ui/src/ui/browse/filter_panel.dart';

import '../support/fake_card_catalog_repository.dart';

CardListRow _row(String printingId, CardType type) => CardListRow(
      printingId: printingId,
      cardNumber: printingId,
      name: printingId,
      cardType: type,
      expansion: 'bp1',
      rarity: 'N',
      isParallel: false,
      imageHash: '',
      cost: type == CardType.member ? 1 : null,
    );

final _rows = [
  _row('M', CardType.member),
  _row('L', CardType.live),
  _row('E', CardType.energy),
];

CardBrowseStore _store() => CardBrowseStore(
      rows: _rows,
      catalog: FakeCardCatalogRepository(),
      searchLimit: SearchLimitSetting.standard,
    );

Finder _tab(String key) => find.byKey(ValueKey('cardTypeTab:$key'));

void main() {
  Future<CardBrowseStore> pumpTabs(WidgetTester tester) async {
    final store = _store();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: CardTypeTabs(store: store))),
    );
    await tester.pumpAndSettle();
    return store;
  }

  group('★★ 並びは `kCardTypeTabs` が正である ★★', () {
    test('4 つ。★先頭は「すべて」（§3-5）', () {
      expect(kCardTypeTabs.map((e) => e.$2),
          ['すべて', 'メンバー', 'ライブ', 'エネルギー']);
      expect(kCardTypeTabs.first.$1, isNull);
    });

    test('★対: 3 種別が 1 つ残らず在る（★落とすと落ちる）', () {
      expect(
        kCardTypeTabs.map((e) => e.$1).whereType<CardType>().toSet(),
        CardType.values.toSet(),
      );
    });

    test('★★「お気に入り」は置かない（§3-5）★★', () {
      expect(kCardTypeTabs.length, CardType.values.length + 1);
    });

    testWidgets('★画面はこの並びをそのまま出す（★書き写していない）', (tester) async {
      await pumpTabs(tester);

      for (final (_, label) in kCardTypeTabs) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });

  group('★★ 押すと `CardListFilter.cardType` が動く ★★', () {
    testWidgets('メンバーを押すとメンバーだけになる', (tester) async {
      final store = await pumpTabs(tester);

      await tester.tap(_tab('member'));
      await tester.pumpAndSettle();

      expect(store.value.filter.cardType, CardType.member);
    });

    testWidgets('★対: エネルギーを押すとエネルギーになる（★「常にメンバー」でない）',
        (tester) async {
      final store = await pumpTabs(tester);

      await tester.tap(_tab('energy'));
      await tester.pumpAndSettle();

      expect(store.value.filter.cardType, CardType.energy);
    });

    testWidgets('★「すべて」を押すと外れる', (tester) async {
      final store = await pumpTabs(tester);

      await tester.tap(_tab('live'));
      await tester.pumpAndSettle();
      await tester.tap(_tab('all'));
      await tester.pumpAndSettle();

      expect(store.value.filter.cardType, isNull);
    });

    testWidgets('★★選ばれているものを押しても外れない★★', (tester) async {
      // ★外せると「どれも選ばれていない」状態ができ、
      //   ★★それは「すべて」と同じなのに見た目が違う★★。
      final store = await pumpTabs(tester);

      await tester.tap(_tab('live'));
      await tester.pumpAndSettle();
      await tester.tap(_tab('live'));
      await tester.pumpAndSettle();

      expect(store.value.filter.cardType, CardType.live);
    });

    testWidgets('★選ばれているタブだけが選択状態である', (tester) async {
      await pumpTabs(tester);

      ChoiceChip chipOf(String key) => tester.widget<ChoiceChip>(_tab(key));

      // ★既定は「すべて」。
      expect(chipOf('all').selected, isTrue);
      expect(chipOf('member').selected, isFalse);

      await tester.tap(_tab('member'));
      await tester.pumpAndSettle();

      expect(chipOf('all').selected, isFalse);
      expect(chipOf('member').selected, isTrue);
      expect(chipOf('live').selected, isFalse);
    });
  });

  group('★★ 絞り込みパネルに種別は残っていない（§1-2）★★', () {
    testWidgets('「種別」の欄が 1 つも無い', (tester) async {
      final store = _store();
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: FilterPanel(store: store)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('種別'), findsNothing);
      // ★★対: 残した 3 つは在る（★「パネルが空になった」ではない）★★
      expect(find.text('商品'), findsOneWidget);
      expect(find.text('コスト（以下）'), findsOneWidget);
      expect(find.text('パラレルを表示'), findsOneWidget);
    });
  });
}
