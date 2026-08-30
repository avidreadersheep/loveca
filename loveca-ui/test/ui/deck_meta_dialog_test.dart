/// P3 デッキのメタ編集（`docs/UI設計メモ.md` §2-3 / 決定 D70 / M6）.
///
/// ★★ R2 と R3 で「同じダイアログ」が出ることを固定する ★★
/// 器だけ替えて置く、という §2-1 の方針。2 つ書き分けると片方だけ腐る。
///
/// ★★ 違うのは保存のタイミングだけである ★★
/// R3 はドラフトへ適用する（保存 0 回）。R2 は「未保存」の器が無いので
/// 決定がそのまま保存 1 回に相当する。**どちらも畳むのは 1 回だけ**（§9-1）。
///
/// ★★ 2026-08-30: R2 も `DeckEditStore` を通るようになった（決定 **D110-2** の A-i）★★
/// 穴 (a) を塞いだ結果、**器が同じになった**（`docs/同期設計メモ.md` §15-7-3）。
/// ★§15-7-3 が測った**挙動の差 3 つ**の受けを、この下の群が持つ ——
/// **差 1** `canSave` の門 / **差 2** 失敗表示 / **差 3** 一覧の読み直し。
/// ★**上の「保存のタイミングが器で違う」は 1 文字も動いていない**（R3 は今も保存 0 回）。
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

  // ---------------------------------------------------------------------------
  // ★★ A-i の挙動の差 3 つ（決定 **D110-2** / `docs/同期設計メモ.md` §15-7-3）★★
  // ---------------------------------------------------------------------------

  group('★★ R2 も `DeckEditStore` を通る（穴 (a) を塞いだ差）★★', () {
    testWidgets('★★ 差 1: 何も変えずに決定しても保存されない（`canSave` の門）★★',
        (tester) async {
      // ★★ A-i の前は保存されていた ★★
      //   `DeckListStore.saveMeta` は無条件に `DeckRepository.save` を呼んでいたので、
      //   **中身が 1 文字も変わっていなくても `revision` が +1 されていた**（決定 D101）。
      //   ★R3 の保存ボタンは前から `canSave` で止めており、**R2 だけが素通しだった。**
      //
      // ★★ §15-7-3 の測定「R2 経路の 13 件のうち決定を押す 8 件は 8 件とも
      //   先に何かを変えているので 1 件も反転しない」は、実装後に実測して当たっていた ★★
      //   → ★**だからこの 1 件を新しく置く。★門そのものを見ているテストが 0 件だった。**
      final decks = await _openFromList(tester);

      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 0, reason: '★無変更のまま `revision` を +1 しない');
      // ★対は上の「★R2 では決定がそのまま保存 1 回になる」である
      //   —— ★門だけを見ると「常に保存しない実装」でも通ってしまう。
    });

    testWidgets('★★ 差 2: 保存に失敗したら R2 に出る（★黙って落とさない）★★',
        (tester) async {
      // ★★ ここは A-i で**黙って落ちるはずだった** ★★
      //   失敗は `DeckListStore._act` → `actionError` → 一覧画面のスナックバー、
      //   という経路で出ていた。★`DeckEditStore.actionError` を R2 は描かないので、
      //   経路を移した瞬間に**表示だけが消える。**
      //   ★§15-7-3 は「見ているテストが 0 件」と測っており、**再走査でもそうだった**
      //   （`failSave` の使用は R3 の `deck_edit_page_test.dart` の 1 件のみ。
      //    `deck_list_page_test.dart` が持つのは `failSoftDelete` ＝ 削除側の受けである）。
      //   → ★**塞いだうえで、この 1 件を受けに置く。**
      final decks = await _openFromList(tester);
      decks.failSave = StateError('書き込めません');

      await tester.enterText(_nameField, '書けない名前');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.saveCalls, 1, reason: '★保存は試みている（門で止まったのではない）');
      expect(find.textContaining('書き込めません'), findsOneWidget);
      // ★一覧は消えない（決定 D53 / §3-4(3)）。★失敗で `Loadable` を倒さない。
      expect(find.text('テストデッキ'), findsOneWidget);
    });

    testWidgets('★対: 成功したときは失敗の表示を出さない', (tester) async {
      // ★出る側だけを見ると、**常に出す実装**でも通ってしまう。
      await _openFromList(tester);

      await tester.enterText(_nameField, '書ける名前');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(find.textContaining('操作に失敗しました'), findsNothing);
    });

    testWidgets('★★ 差 3: 決定のあと一覧が読み直される ★★', (tester) async {
      // ★★ `DeckListStore._act` の `load()` が経路から消えた ★★
      //   明示に足さないと、**保存はできているのに一覧が古い名前のまま**になる。
      //   ★`lastSaved` を見るだけでは検知できない（保存は成功しているため）。
      final decks = await _openFromList(tester);

      await tester.enterText(_nameField, '一覧にも出る名前');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(decks.lastSaved!.name, '一覧にも出る名前');
      expect(find.text('一覧にも出る名前'), findsOneWidget);
      expect(find.text('テストデッキ'), findsNothing);
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
