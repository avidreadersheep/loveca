/// 共有形式の入出力の画面（`docs/UI設計メモ.md` §2-5 / 決定 D67 / D68 / D69 / D35）.
///
/// ★★ 出る側と出ない側を対で固定する ★★
/// 「未知が出る」だけを見ると、**常に出す**実装でも通ってしまう。
///
/// ★役割を混ぜない。書式そのものと既定の刷りの選び方は
/// `test/data/deck_share_test.dart` が実データの形で固定している。
/// ここで見るのは**画面がそれをどう出し、何を返すか**だけである。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

Deck _deck({
  List<DeckEntry> entries = const [
    DeckEntry(printingId: trioMemberPrinting, count: 2),
  ],
  String name = 'テストデッキ',
}) =>
    Deck(
      deckId: 'deck-1',
      name: name,
      entries: entries,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

/// R2 のメニューから書き出しダイアログを開く。
Future<void> _openExport(WidgetTester tester, {Deck? deck}) async {
  final resolved = deck ?? _deck();
  final catalog = realShapedCatalog();
  await pumpInAppScope(
    tester,
    const DeckListPage(),
    decks: FakeDeckRepository(decks: [resolved], catalog: catalog),
    catalog: catalog,
  );

  await tester.tap(find.byTooltip('このデッキの操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('共有形式をコピー'));
  await tester.pumpAndSettle();
}

/// R3 から取り込みダイアログを開く。
Future<FakeDeckRepository> _openImport(WidgetTester tester, {Deck? deck}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1200);
  addTearDown(tester.view.reset);

  final resolved = deck ?? _deck();
  final catalog = realShapedCatalog();
  final decks = FakeDeckRepository(decks: [resolved], catalog: catalog);
  await pumpInAppScope(
    tester,
    DeckEditPage(deck: resolved),
    decks: decks,
    catalog: catalog,
  );

  await tester.tap(find.byTooltip('共有形式から取り込む'));
  await tester.pumpAndSettle();
  return decks;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('shareImportField')), text);
  await tester.pumpAndSettle();
}

void main() {
  group('★ 書き出し（決定 D67）', () {
    testWidgets('カード番号と枚数が出る', (tester) async {
      await _openExport(tester);

      final text = tester
          .widget<SelectableText>(find.byKey(const Key('shareExportText')))
          .data;
      expect(text, '# テストデッキ\nLL-bp1-001 x2');
    });

    testWidgets('★★ 刷りの違いが残らないことを先に言う ★★', (tester) async {
      await _openExport(tester);

      expect(find.textContaining('刷り違いは合算されます'), findsNothing);
      expect(find.textContaining('取り込み直すと刷りが変わる'), findsOneWidget,
          reason: 'あとから気づくと「取り込んだら別の絵になった」になる');
      expect(find.textContaining('「複製」を使ってください'), findsOneWidget);
    });

    testWidgets('★★ 未知の刷りが落ちたら必ず言う（決定 D35）★★', (tester) async {
      await _openExport(
        tester,
        deck: _deck(entries: const [
          DeckEntry(printingId: trioMemberPrinting, count: 1),
          DeckEntry(printingId: 'UNKNOWN-1', count: 3),
        ]),
      );

      expect(find.textContaining('1 種類 （3 枚）は共有形式に出せませんでした'),
          findsOneWidget);
      // ★内部語彙は畳むが捨てない。
      await tester.tap(find.text('詳しい内容'));
      await tester.pumpAndSettle();
      expect(find.text('UNKNOWN-1 x3'), findsOneWidget);
    });

    testWidgets('★全部既知なら警告を出さない（出ない側）', (tester) async {
      await _openExport(tester);

      expect(find.textContaining('共有形式に出せませんでした'), findsNothing,
          reason: '出る側だけ見ると、常に警告する実装でも通ってしまう');
    });
  });

  group('★ 取り込みの前に見せる（§2-5）', () {
    testWidgets('貼っただけでは取り込まない。件数を先に出す', (tester) async {
      final decks = await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x4\nPL!-bp1-000 x12');

      expect(find.textContaining('2 種類 / 16 枚を取り込みます'), findsOneWidget);
      expect(decks.saveCalls, 0, reason: '取り込みは保存ではない');
    });

    testWidgets('★★ 未知 cardNumber を黙って捨てない（A-3）★★', (tester) async {
      await _openImport(tester);

      await _type(tester, 'ZZ-none-001 x2\nLL-bp1-001 x1');

      expect(find.byKey(const Key('shareImportUnknown')), findsOneWidget);
      expect(find.textContaining('1 件のカード番号が見つかりません'), findsOneWidget);
      // ★入力欄にも同じ文字列があるので、枠の中に絞って見る。
      expect(
        find.descendant(
          of: find.byKey(const Key('shareImportUnknown')),
          matching: find.textContaining('ZZ-none-001 x2'),
        ),
        findsOneWidget,
      );
      // ★断りが要るときは押すボタンの文言が変わる。
      expect(find.text('このまま取り込む'), findsOneWidget);
    });

    testWidgets('★全部既知なら出ない（出ない側）', (tester) async {
      await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x1');

      expect(find.byKey(const Key('shareImportUnknown')), findsNothing,
          reason: '出る側だけ見ると、常に出す実装でも通ってしまう');
      expect(find.text('取り込む'), findsOneWidget);
      expect(find.text('このまま取り込む'), findsNothing);
    });

    testWidgets('★★ 読めない行は未知 cardNumber と別枠で出る ★★', (tester) async {
      await _openImport(tester);

      await _type(tester, 'これは行ではない\nZZ-none-001 x1\nLL-bp1-001 x1');

      // ★原因も対処も違うので、1 行にまとめない。
      expect(find.byKey(const Key('shareImportUnparsed')), findsOneWidget);
      expect(find.byKey(const Key('shareImportUnknown')), findsOneWidget);
      expect(find.textContaining('1 行を読めませんでした'), findsOneWidget);
    });

    testWidgets('★読める入力では読めない行の枠が出ない（出ない側）', (tester) async {
      await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x1');

      expect(find.byKey(const Key('shareImportUnparsed')), findsNothing);
    });

    testWidgets('★★ 4 枚超過は弾かず、そのまま取り込むと言う（決定 D69）★★',
        (tester) async {
      await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x5');

      expect(find.byKey(const Key('shareImportOverLimit')), findsOneWidget);
      expect(find.textContaining('4 枚を超えています'), findsOneWidget);
      expect(find.textContaining('検証に違反として出ます'), findsOneWidget);
      // ★取り込ませないのではない。押せる。
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'このまま取り込む'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('★4 枚以下では出ない（出ない側）', (tester) async {
      await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x4');

      expect(find.byKey(const Key('shareImportOverLimit')), findsNothing);
    });

    testWidgets('★★ エネルギーには 4 枚制限が無い（6.1.1.3）★★', (tester) async {
      await _openImport(tester);

      await _type(tester, 'PL!-bp1-000 x12');

      expect(find.byKey(const Key('shareImportOverLimit')), findsNothing,
          reason: '同じエネルギーカードを 12 枚入れることは認められている');
    });

    testWidgets('★1 枚も取り込めないなら押させない', (tester) async {
      await _openImport(tester);

      await _type(tester, 'ZZ-none-001 x1');

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'このまま取り込む'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('★★ 既定の刷りと差し替え（決定 D68 / U7）★★', () {
    testWidgets('★非パラレルが複数ある件数を開示する（実データで 19 種）',
        (tester) async {
      await _openImport(tester);

      await _type(tester, '$multiNormalCardNumber x4');

      expect(find.byKey(const Key('shareImportAmbiguous')), findsOneWidget);
      expect(find.textContaining('1 件は通常の刷りが複数あります'), findsOneWidget);
    });

    testWidgets('★★ 刷りが複数でも非パラレルが 1 つなら開示しない（出ない側）★★',
        (tester) async {
      await _openImport(tester);

      // PL!HS-bp1-002 は 3 刷りあるが非パラレルは 1 つだけ。
      await _type(tester, 'PL!HS-bp1-002 x1');

      expect(find.byKey(const Key('shareImportAmbiguous')), findsNothing,
          reason: '600 件に警告を出すと 19 件の意味が消える');
      // ★それでも差し替えはできる。
      expect(find.byKey(const ValueKey('shareImportPick:PL!HS-bp1-002')),
          findsOneWidget);
    });

    testWidgets('★刷りが 1 つなら選ばせない', (tester) async {
      await _openImport(tester);

      await _type(tester, 'LL-bp1-001 x1');

      expect(find.byKey(const ValueKey('shareImportPick:LL-bp1-001')),
          findsNothing,
          reason: '出すと「選べるのに選ばなかった」ように見える');
      expect(find.text(trioMemberPrinting), findsOneWidget);
    });

    testWidgets('★★ 既定は -SD。差し替えると -SD2 で取り込まれる ★★',
        (tester) async {
      final decks = await _openImport(tester);

      await _type(tester, '$multiNormalCardNumber x4');

      final pick = find.byKey(ValueKey('shareImportPick:$multiNormalCardNumber'));
      expect(tester.widget<DropdownButton<String>>(pick).value,
          multiNormalFirst, reason: '既定は非パラレルの printingId 昇順の先頭');

      await tester.tap(pick);
      await tester.pumpAndSettle();
      await tester.tap(find.text(multiNormalSecond).last);
      await tester.pumpAndSettle();

      // ★★ 曖昧さは「断り」ではない ★★
      //   既定を選んであり差し替えもできるので、取り込めなかったものは無い。
      //   ボタンの文言が変わるのは unknown / unparsed / overLimit のときだけ。
      expect(find.text('このまま取り込む'), findsNothing);
      await tester.tap(find.text('取り込む'));
      await tester.pumpAndSettle();

      // ★取り込みは保存ではない。ドラフトに入るだけ（未保存表示が出る）。
      expect(decks.saveCalls, 0);
      expect(find.text('未保存の変更があります'), findsOneWidget);
      expect(find.textContaining('1 種類を取り込みました（未保存）'),
          findsOneWidget);
    });
  });

  group('★ 取り込みは置き換えであり、保存ではない', () {
    testWidgets('★中止すると何も変わらない', (tester) async {
      final decks = await _openImport(tester);

      await _type(tester, 'PL!-bp1-000 x12');
      await tester.tap(find.text('中止する'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 0);
      expect(find.text('未保存の変更があります'), findsNothing,
          reason: 'ドラフトにも入らない');
    });

    testWidgets('★★ 置き換えると言い、保存しなければ戻せる ★★', (tester) async {
      final decks = await _openImport(tester);

      expect(find.textContaining('いまのデッキの中身を'), findsOneWidget);
      expect(find.textContaining('保存しなければ元に戻せます'), findsOneWidget);

      await _type(tester, 'PL!-bp1-000 x12');
      await tester.tap(find.text('取り込む'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 0, reason: '保存ボタンを押すまで DB は変わらない');
      expect(find.text('未保存の変更があります'), findsOneWidget);
    });
  });
}
