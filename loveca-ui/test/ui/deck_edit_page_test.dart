/// R3 デッキ編集（★M2 最小版 / `docs/UI設計メモ.md` §9-1）.
///
/// ★★ 見るのは「保存が何回呼ばれたか」である ★★
/// `revision` の増え方そのものは実 DB の
/// `test/data/deck_repository_test.dart` が固定している。
/// ここで確かめるのは**画面が編集のたびに保存していないこと**——
/// つまり `Deck.copyWith` を踏む回数が編集操作の回数に比例しないことである。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/ui/deck/deck_edit_page.dart';

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';

Deck _deck({String name = 'もとの名前', String memo = ''}) => Deck(
      deckId: 'a',
      name: name,
      memo: memo,
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

void main() {
  testWidgets('★★ 編集しただけでは保存されない（revision を跳ねさせない / §9-1）★★',
      (tester) async {
    final deck = _deck();
    final decks = FakeDeckRepository(decks: [deck]);

    await pumpInAppScope(tester, DeckEditPage(deck: deck), decks: decks);

    // ★Key で掴む。1 打ごとに中身が変わるので、テキストでは次から外れる。
    final nameField = find.byKey(const Key('deckNameField'));
    await tester.enterText(nameField, 'あ');
    await tester.enterText(nameField, 'あい');
    await tester.enterText(nameField, 'あいう');
    await tester.pumpAndSettle();

    // ★★ 3 回編集して保存は 0 回 ★★
    // キー入力ごとに保存すると Phase 4 の同期で「大量に更新された」ように見える。
    expect(decks.saveCalls, 0);
    expect(find.text('未保存の変更があります'), findsOneWidget);
  });

  testWidgets('保存を押すとちょうど 1 回だけ保存される', (tester) async {
    final deck = _deck();
    final decks = FakeDeckRepository(decks: [deck]);

    await pumpInAppScope(tester, DeckEditPage(deck: deck), decks: decks);

    await tester.enterText(find.byKey(const Key('deckNameField')), '新しい名前');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(decks.saveCalls, 1);
    expect(find.text('保存しました'), findsOneWidget);
    // 保存後は「未保存」が消え、タイトルが新しい名前になる。
    expect(find.text('未保存の変更があります'), findsNothing);
    expect(find.widgetWithText(AppBar, '新しい名前'), findsOneWidget);
  });

  testWidgets('★変更が無ければ保存ボタンを押させない（無意味な revision +1 を防ぐ）',
      (tester) async {
    final deck = _deck();
    await pumpInAppScope(tester, DeckEditPage(deck: deck),
        decks: FakeDeckRepository(decks: [deck]));

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('★名前を空にしたら保存させない', (tester) async {
    final deck = _deck();
    await pumpInAppScope(tester, DeckEditPage(deck: deck),
        decks: FakeDeckRepository(decks: [deck]));

    await tester.enterText(find.byKey(const Key('deckNameField')), '   ');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('★保存に失敗したら握らずに画面へ出す（決定 D53）', (tester) async {
    final deck = _deck();
    final decks = FakeDeckRepository(decks: [deck])
      ..failSave = StateError('書き込めません');

    await pumpInAppScope(tester, DeckEditPage(deck: deck), decks: decks);

    await tester.enterText(find.byKey(const Key('deckNameField')), 'X');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.textContaining('書き込めません'), findsOneWidget);
    // ★失敗したのに「保存しました」を出さない。
    expect(find.text('保存しました'), findsNothing);
    expect(find.text('未保存の変更があります'), findsOneWidget);
  });

  group('★★ DeckValidator の経路が通っている（決定 D55 / D28）★★', () {
    // ★M1 で MasterCatalog の構築までは確かめたが、そこから DeckValidator を
    //   作って使う経路は一度も通っていなかった。M2 で初めて通す。
    testWidgets('空のデッキは構築条件を満たさず、内訳が出る', (tester) async {
      final deck = _deck();
      await pumpInAppScope(tester, DeckEditPage(deck: deck),
          decks: FakeDeckRepository(decks: [deck]));

      expect(find.text('構築条件を満たしていません'), findsOneWidget);
      // 総合ルール 6.1.1.1 / 6.1.1.3。★期待値は RuleConfig から来ている。
      expect(find.text('メンバー 0 / 48'), findsOneWidget);
      expect(find.text('ライブ 0 / 12'), findsOneWidget);
      expect(find.text('エネルギー 0 / 12'), findsOneWidget);
      expect(find.text('未達 3 件'), findsOneWidget);
    });

    testWidgets('★カードを入れると DeckValidator の数え方がそのまま出る', (tester) async {
      // 4 枚制限（6.1.1.2）に引っかかる枚数を入れて、UI が自分で数えていない
      // ことを確かめる。UI 側で数え直すと決定 D28 の「唯一の実装」が崩れる。
      final deck = Deck(
        deckId: 'a',
        name: 'X',
        entries: const [DeckEntry(printingId: 'M-1-N', count: 5)],
        createdAt: fakeNow(),
        updatedAt: fakeNow(),
      );
      await pumpInAppScope(tester, DeckEditPage(deck: deck),
          decks: FakeDeckRepository(decks: [deck]));

      expect(find.text('メンバー 5 / 48'), findsOneWidget);
      // 4 枚超過 + メンバー数不一致 + ライブ + エネルギー = 4 件。
      expect(find.text('未達 4 件'), findsOneWidget);
    });

    testWidgets('★マスタに無い刷りを黙って落とさない（決定 D35）', (tester) async {
      final deck = Deck(
        deckId: 'a',
        name: 'X',
        entries: const [DeckEntry(printingId: '知らない刷り', count: 1)],
        createdAt: fakeNow(),
        updatedAt: fakeNow(),
      );
      await pumpInAppScope(tester, DeckEditPage(deck: deck),
          decks: FakeDeckRepository(decks: [deck]));

      expect(
        find.textContaining('カードデータが未取得の刷りが 1 件あります'),
        findsOneWidget,
      );
    });
  });

  testWidgets('★M2 の範囲であることが画面に書いてある', (tester) async {
    // ★doc コメントは実行時に見えない。触っている人が誤解するのは画面の前なので、
    //   「作りかけではなく M2 の範囲である」ことを画面にも出す。
    final deck = _deck();
    await pumpInAppScope(tester, DeckEditPage(deck: deck),
        decks: FakeDeckRepository(decks: [deck]));

    expect(find.textContaining('M4 で入ります'), findsOneWidget);
  });
}
