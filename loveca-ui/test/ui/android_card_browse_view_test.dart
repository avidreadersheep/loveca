/// ★★ Android のカード検索 —— ★★縦の積み方★★（`docs/Android UI 決定.md` §3-3）★★
///
/// ★★ この試験の要点は「★★4 つの widget を★実際に呼んでいること★★」である ★★
/// ★**§3-2 / §3-4 / §3-5 / §3-15 は★★どれも「呼ぶ側 0」で置いてあった★★**（**D-20**）。
/// → ★**ここが 4 つの呼び出し側になったことを★★型ではなく★木で見る★★。**
///
/// ★★ この試験が覆わないもの（★言い切る）★★
/// ★**1)** ★★実機★★ —— ★ウィジェット試験は Android を 1 バイトも走らせない。
/// ★**2)** ★**絞り込みチップ（★§3-6）** —— ★★差し込み口だけである★★（**W-85** 待ち）。
/// ★**3)** ★**下段タブ** —— ★★`AndroidHomePage` が持つ★★（★同じものを 2 か所で描かない）。
/// ★**4)** ★**行の高さ / 1 画面に何行入るか** —— ★★測っていない★★（**D-28**）。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/card_browse_store.dart';
import 'package:loveca_ui/src/ui/android/android_card_browse_view.dart';
import 'package:loveca_ui/src/ui/browse/card_list_tile.dart';
import 'package:loveca_ui/src/ui/browse/card_sort.dart';
import 'package:loveca_ui/src/ui/browse/card_type_tabs.dart';
import 'package:loveca_ui/src/ui/deck/deck_counters_band.dart';

import '../support/fake_card_catalog_repository.dart';
import '../support/real_shaped_catalog.dart';
import '../support/recording_image_source.dart';

DeckValidationResult _validation() => const DeckValidationResult(
      issues: <DeckIssue>[],
      memberCount: 12,
      liveCount: 3,
      energyCount: 0,
      unknownPrintingIds: <String>[],
    );

void main() {
  late MasterCatalog catalog;
  late CardBrowseStore store;
  late CardSortOrder order;

  setUp(() {
    catalog = realShapedCatalog();
    store = CardBrowseStore(
      rows: catalog.rows,
      catalog: FakeCardCatalogRepository(),
      searchLimit: SearchLimitSetting.standard,
    );
    order = kDefaultCardSortOrder;
  });

  tearDown(() => store.dispose());

  Future<void> pump(
    WidgetTester tester, {
    List<CardListRow>? rows,
    DeckValidationResult? validation,
    Widget? filterChips,
    void Function(CardListRow row)? onTapRow,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AndroidCardBrowseView(
              rows: rows ?? catalog.rows,
              catalog: catalog,
              imageSource: RecordingImageSource(),
              store: store,
              order: order,
              onOrderChanged: (o) => order = o,
              onTapRow: onTapRow,
              filterChips: filterChips,
              validation: validation,
            ),
          ),
        ),
      );

  group('★★ 4 つの widget を★実際に呼ぶ（★§3-3 の積み方）★★', () {
    testWidgets('★★ 上部（§3-15）と★カテゴリタブ（§3-5）が★木に在る ★★',
        (tester) async {
      await pump(tester);
      expect(find.byType(CardSortHeader), findsOneWidget);
      expect(find.byType(CardTypeTabs), findsOneWidget);
    });

    testWidgets('★★ 一覧の 1 行（§3-2）が★木に在る ★★', (tester) async {
      await pump(tester);
      expect(find.byType(CardListTile), findsWidgets);
    });

    testWidgets('★★ カウンタ（§3-4）は★渡したときだけ出る ★★', (tester) async {
      await pump(tester);
      expect(find.byType(DeckCountersBand), findsNothing);

      await pump(
        tester,
        validation: _validation(),
      );
      expect(find.byType(DeckCountersBand), findsOneWidget);
    });
  });

  group('★★ 積む順は §3-3 の絵そのものである ★★', () {
    testWidgets('★★ 上から: ★上部 → ★一覧 → ★タブ → ★チップ → ★カウンタ ★★',
        (tester) async {
      await pump(
        tester,
        validation: _validation(),
        filterChips: const SizedBox(
          key: ValueKey('test:chips'),
          height: 24,
          width: double.infinity,
        ),
      );
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(find.byType(CardSortHeader)),
          lessThan(top(find.byKey(const ValueKey('androidBrowse:list')))));
      expect(top(find.byKey(const ValueKey('androidBrowse:list'))),
          lessThan(top(find.byType(CardTypeTabs))));
      expect(top(find.byType(CardTypeTabs)),
          lessThan(top(find.byKey(const ValueKey('test:chips')))));
      expect(top(find.byKey(const ValueKey('test:chips'))),
          lessThan(top(find.byType(DeckCountersBand))));
    });

    testWidgets('★★ 絞り込みチップは★渡さなければ★段そのものが無い ★★',
        (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('test:chips')), findsNothing);
    });
  });

  group('★★ 件数は★渡された行の数である（★★全件ではない★★）★★', () {
    testWidgets('★ 絞り込んだ結果の数が出る', (tester) async {
      await pump(tester, rows: catalog.rows.take(2).toList());
      expect(find.text('2 件'), findsOneWidget);
    });
  });

  group('★★ マスタに無い行を★黙って消さない（決定 D35）★★', () {
    testWidgets('★★ 1 行として出る（★★飛ばさない★★）★★', (tester) async {
      final ghost = CardListRow(
        printingId: 'GHOST-001-N',
        cardNumber: 'GHOST-001',
        name: 'ゆうれい',
        cardType: CardType.member,
        expansion: 'bp1',
        rarity: 'N',
        isParallel: false,
        imageHash: '',
        cost: null,
      );
      await pump(tester, rows: <CardListRow>[ghost]);
      expect(
        find.byKey(const ValueKey('androidBrowse:unknown:GHOST-001-N')),
        findsOneWidget,
      );
      // ★★ 対: ★件数は★1 のままである（★★落としていない★★）★★
      expect(find.text('1 件'), findsOneWidget);
    });
  });

  group('★★ 行を押したときに何が起きるかを★この層は決めない ★★', () {
    testWidgets('★ 渡した関数が★その行で呼ばれる', (tester) async {
      final tapped = <String>[];
      await pump(
        tester,
        rows: catalog.rows.take(1).toList(),
        onTapRow: (row) => tapped.add(row.printingId),
      );
      await tester.tap(find.byType(CardListTile).first);
      await tester.pump();
      expect(tapped, [catalog.rows.first.printingId]);
    });

    testWidgets('★★ 対: ★渡さなければ★押しても何も起きない ★★', (tester) async {
      await pump(tester, rows: catalog.rows.take(1).toList());
      await tester.tap(find.byType(CardListTile).first);
      await tester.pump();
      // ★★ 例外が出ないことを見る（★★`onTap` が null で通る★★）★★
      expect(tester.takeException(), isNull);
    });
  });

  group('★★ 下段タブは★ここに置かない（★§3-1 の入れ物が持つ）★★', () {
    testWidgets('★ `NavigationBar` が 1 つも無い', (tester) async {
      await pump(tester);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
