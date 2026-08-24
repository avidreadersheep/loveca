/// P3 デッキのメタ編集（`docs/UI設計メモ.md` §2-3 / 決定 D70 / M6）.
///
/// ★★ R2 と R3 で「同じダイアログ」が出ることを固定する ★★
/// 器だけ替えて置く、という §2-1 の方針。2 つ書き分けると片方だけ腐る。
///
/// ★★ 違うのは保存のタイミングだけである ★★
/// R3 はドラフトへ適用する（保存 0 回）。R2 は「未保存」の器が無いので
/// 決定がそのまま保存 1 回に相当する。**どちらも畳むのは 1 回だけ**（§9-1）。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';

Deck _deck({
  String name = 'テストデッキ',
  List<DeckEntry> entries = const [DeckEntry(printingId: 'M-1-N', count: 2)],
  List<String> tags = const [],
  String? cover,
  String memo = '',
}) =>
    Deck(
      deckId: 'deck-1',
      name: name,
      entries: entries,
      memo: memo,
      tags: tags,
      coverPrintingId: cover,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

final _nameField = find.byKey(const Key('metaNameField'));
final _memoField = find.byKey(const Key('metaMemoField'));
final _tagField = find.byKey(const Key('metaTagField'));

/// ★ダイアログの中身は `SingleChildScrollView`。下のほう（カバー）は
/// 見えていないことがあり、そのまま叩くと**外れても例外にならない**
/// （`warnIfMissed` の警告が出るだけで、テストは「何も起きなかった」を見る）。
Future<void> _tapInDialog(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// R2 の一覧からメニュー経由で開く。
Future<FakeDeckRepository> _openFromList(
  WidgetTester tester, {
  Deck? deck,
}) async {
  final decks = FakeDeckRepository(decks: [deck ?? _deck()]);
  await pumpInAppScope(tester, const DeckListPage(), decks: decks);

  await tester.tap(find.byTooltip('このデッキの操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('情報を編集'));
  await tester.pumpAndSettle();
  return decks;
}

/// R3 の編集画面から開く。
///
/// ★2 ペインで開く。1 ペインだとデッキペインが横に出ないので、
/// そこに乗っている「デッキの情報」も見えない（決定 D61）。
Future<FakeDeckRepository> _openFromEditor(
  WidgetTester tester, {
  Deck? deck,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1400, 1000);
  addTearDown(tester.view.reset);

  final resolved = deck ?? _deck();
  final decks = FakeDeckRepository(decks: [resolved]);
  await pumpInAppScope(tester, DeckEditPage(deck: resolved), decks: decks);

  await tester.tap(find.byTooltip('デッキの情報'));
  await tester.pumpAndSettle();
  return decks;
}

void main() {
  group('★★ 同じダイアログが R2 と R3 の両方から出る（§2-1）★★', () {
    testWidgets('R2（一覧）から出る', (tester) async {
      await _openFromList(tester);
      expect(find.text('デッキの情報'), findsWidgets);
      expect(_nameField, findsOneWidget);
      expect(_memoField, findsOneWidget);
      expect(_tagField, findsOneWidget);
    });

    testWidgets('R3（編集）から出る', (tester) async {
      await _openFromEditor(tester);
      expect(find.text('デッキの情報'), findsWidgets);
      expect(_nameField, findsOneWidget);
      expect(_memoField, findsOneWidget);
      expect(_tagField, findsOneWidget);
    });
  });

  group('★★ 保存のタイミングが器で違う（§9-1）★★', () {
    testWidgets('★R3 では保存されない（ドラフトに入るだけ）', (tester) async {
      final decks = await _openFromEditor(tester);

      await tester.enterText(_nameField, '新しい名前');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      // ★★ 打鍵でも決定でも保存しない ★★
      //   保存すると revision が跳ね、Phase 4 の同期で
      //   「大量に更新された」ように見える。
      expect(decks.saveCalls, 0);
      expect(find.text('未保存の変更があります'), findsOneWidget);
    });

    testWidgets('★R3 で保存ボタンを押すとちょうど 1 回', (tester) async {
      final decks = await _openFromEditor(tester);

      await tester.enterText(_nameField, '新しい名前');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 1);
      expect(decks.lastSaved!.name, '新しい名前');
    });

    testWidgets('★R2 では決定がそのまま保存 1 回になる', (tester) async {
      final decks = await _openFromList(tester);

      await tester.enterText(_nameField, 'R2 で改名');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 1);
      expect(decks.lastSaved!.name, 'R2 で改名');
    });

    testWidgets('★やめると何も起きない（上の対）', (tester) async {
      final decks = await _openFromList(tester);

      await tester.enterText(_nameField, '捨てられる名前');
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 0,
          reason: '決定側だけ見ると、常に保存する実装でも通ってしまう');
    });
  });

  group('★ メモ / タグ（DB の列を生かす）', () {
    testWidgets('メモが保存される', (tester) async {
      final decks = await _openFromList(tester);

      await tester.enterText(_memoField, '青単。エネルギー多め。');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.memo, '青単。エネルギー多め。');
    });

    testWidgets('タグを足せる', (tester) async {
      final decks = await _openFromList(tester);

      await tester.enterText(_tagField, '青');
      await tester.tap(find.text('足す'));
      await tester.pumpAndSettle();
      await tester.enterText(_tagField, '大会用');
      await tester.tap(find.text('足す'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('metaTag:青')), findsOneWidget);
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.tags, ['青', '大会用']);
    });

    testWidgets('★同じタグは 2 つ入らない（deck_tags の主キーが {deckId, tag}）',
        (tester) async {
      final decks = await _openFromList(tester);

      await tester.enterText(_tagField, '青');
      await tester.tap(find.text('足す'));
      await tester.pumpAndSettle();
      await tester.enterText(_tagField, '青');
      await tester.tap(find.text('足す'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.tags, ['青'], reason: '重ねると保存で主キー衝突する');
    });

    testWidgets('タグを消せる', (tester) async {
      final decks = await _openFromList(
        tester,
        deck: _deck(tags: const ['消される']),
      );

      expect(find.byKey(const ValueKey('metaTag:消される')), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('metaTag:消される')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.tags, isEmpty);
    });
  });

  group('★★ カバー（決定 D70 が無いと外せない）★★', () {
    testWidgets('デッキの中のカードから選べる', (tester) async {
      final decks = await _openFromList(tester);

      await _tapInDialog(tester, find.byKey(const ValueKey('metaCover:M-1-N')));
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.coverPrintingId, 'M-1-N');
    });

    testWidgets('★★ 外せる（Deck.copyWith では書けなかった）★★', (tester) async {
      final decks = await _openFromList(
        tester,
        deck: _deck(cover: 'M-1-N'),
      );

      await _tapInDialog(tester, find.text('カバーを外す'));
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.coverPrintingId, isNull,
          reason: 'copyWith の coverPrintingId ?? this.coverPrintingId では書けない');
    });

    testWidgets('★外さなければ残る（上の対）', (tester) async {
      final decks = await _openFromList(
        tester,
        deck: _deck(cover: 'M-1-N'),
      );

      await tester.enterText(_nameField, '名前だけ変える');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.coverPrintingId, 'M-1-N',
          reason: '「外せる」だけを見ると、常に外す実装でも通ってしまう');
    });

    testWidgets('★カードが 1 枚も無ければ「入れると選べます」と言う', (tester) async {
      await _openFromList(tester, deck: _deck(entries: const []));

      expect(find.text('デッキにカードを入れると、その中から選べます'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('metaCover:M-1-N')), findsNothing);
    });

    testWidgets('★カバーが未設定なら「外す」は押せない', (tester) async {
      await _openFromList(tester);

      final button = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'カバーを外す'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('★ 名前が空のままでは決定させない', () {
    testWidgets('空白だけなら押せない', (tester) async {
      await _openFromList(tester);

      await tester.enterText(_nameField, '   ');
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '決定'),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('★ 複製（決定 D71）', () {
    testWidgets('★刷りを保ったまま写す。名前は「のコピー」', (tester) async {
      final decks = FakeDeckRepository(
        decks: [
          _deck(entries: const [
            DeckEntry(printingId: 'M-1-N', count: 2),
            DeckEntry(printingId: 'M-1-P', count: 1),
          ]),
        ],
      );
      await pumpInAppScope(tester, const DeckListPage(), decks: decks);

      await tester.tap(find.byTooltip('このデッキの操作'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('複製'));
      await tester.pumpAndSettle();

      expect(decks.duplicateCalls, 1);
      expect(decks.lastDuplicated!.name, 'テストデッキ のコピー');
      // ★共有形式ではここが 1 行に潰れる（決定 D67）。複製だけが保てる。
      expect(
        {for (final e in decks.lastDuplicated!.entries) e.printingId: e.count},
        {'M-1-N': 2, 'M-1-P': 1},
      );
      expect(find.text('複製しました'), findsOneWidget);
    });
  });
}
