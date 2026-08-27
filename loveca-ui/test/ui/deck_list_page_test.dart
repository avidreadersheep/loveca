/// R2 デッキ一覧（`docs/UI設計メモ.md` §2-2 / M2）.
///
/// ★★ ここで見るのは「画面の振る舞い」である ★★
/// 保存が本当に残るかは実 DB の `test/data/deck_repository_test.dart` が固定する。
/// 役割を混ぜると、落ちたときに層の問題か画面の問題か切り分けられない（§2-4）。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/boot/boot_steps.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';

import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';

Deck _deck(String id, String name, {int totalCount = 0}) => Deck(
      deckId: id,
      name: name,
      entries: [
        if (totalCount > 0)
          DeckEntry(printingId: 'M-1-N', count: totalCount),
      ],
      createdAt: fakeNow(),
      updatedAt: fakeNow(),
    );

/// R2 のデッキごとの操作はメニューになった（M6）。
/// ★アイコン 1 つでは複製・共有・メタ編集が置けないため。
Future<void> _openDeckMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('このデッキの操作'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('削除'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('一覧が出る', (tester) async {
    final decks = FakeDeckRepository(
      decks: [_deck('a', '青デッキ', totalCount: 60), _deck('b', '赤デッキ')],
    );

    await pumpInAppScope(tester, const DeckListPage(), decks: decks);

    expect(find.text('青デッキ'), findsOneWidget);
    expect(find.text('赤デッキ'), findsOneWidget);
    expect(find.textContaining('60 枚'), findsOneWidget);
  });

  testWidgets('★「空」を「失敗」と同じ見た目にしない（§3-4(2)）', (tester) async {
    await pumpInAppScope(tester, const DeckListPage(),
        decks: FakeDeckRepository());

    expect(find.text('デッキがまだありません'), findsOneWidget);
    // ★エラー表示ではないこと。同じにすると利用者は「壊れている」と誤解する。
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('★読めなかったら空一覧にすり替えずエラーを出す（決定 D53）', (tester) async {
    final decks = FakeDeckRepository()..failAll = StateError('DB が読めません');

    await pumpInAppScope(tester, const DeckListPage(), decks: decks);

    // ★LoadableView に onError を渡していないので既定のエラーが出る（§3-4(1)）。
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('DB が読めません'), findsOneWidget);
    expect(find.text('デッキがまだありません'), findsNothing);
  });

  testWidgets('新規デッキを作ると一覧に出る', (tester) async {
    final decks = FakeDeckRepository();
    await pumpInAppScope(tester, const DeckListPage(), decks: decks);

    await tester.tap(find.text('新規デッキ'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'テストデッキ');
    await tester.tap(find.text('作る'));
    await tester.pumpAndSettle();

    expect(decks.createCalls, 1);
    // ★作ったら開く（R3 へ push）。M2 の「作る / 開く」がつながっていること。
    expect(find.text('未保存の変更があります'), findsNothing);
    // ★ここは R3（作った直後に push された編集画面）を見ている。
    //   R2 のメニューではない。
    expect(find.byTooltip('削除'), findsOneWidget);

    // 戻ると一覧に出ている。
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('テストデッキ'), findsOneWidget);
  });

  testWidgets('★名前が空のままでは作らせない', (tester) async {
    final decks = FakeDeckRepository();
    await pumpInAppScope(tester, const DeckListPage(), decks: decks);

    await tester.tap(find.text('新規デッキ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '作る'),
    );
    expect(button.onPressed, isNull);
    expect(decks.createCalls, 0);
  });

  group('★ 論理削除（決定 D102）', () {
    testWidgets('確認してから消える。★戻せないことを画面に書いてある', (tester) async {
      final decks = FakeDeckRepository(decks: [_deck('a', '消すデッキ')]);
      await pumpInAppScope(tester, const DeckListPage(), decks: decks);

      await _openDeckMenu(tester);
      await tester.pumpAndSettle();

      // ★★ M2 には戻す口が無い。誤操作の手当てとして確認を 1 枚挟む（未決 U9）★★
      expect(find.text('デッキを削除しますか'), findsOneWidget);
      expect(find.textContaining('戻すことはできません'), findsOneWidget);

      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();

      expect(decks.softDeleteCalls, 1);
      expect(find.text('消すデッキ'), findsNothing);
      expect(find.text('デッキがまだありません'), findsOneWidget);
    });

    testWidgets('やめると消えない', (tester) async {
      final decks = FakeDeckRepository(decks: [_deck('a', '消さないデッキ')]);
      await pumpInAppScope(tester, const DeckListPage(), decks: decks);

      await _openDeckMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('やめる'));
      await tester.pumpAndSettle();

      expect(decks.softDeleteCalls, 0);
      expect(find.text('消さないデッキ'), findsOneWidget);
    });

    testWidgets('★失敗したら一覧を消さずにエラーを出す', (tester) async {
      // ★一覧ごと Failed へ倒すと、読めていた一覧が画面から消える。
      //   かといって黙って握ると「押しても何も起きない画面」になる（A-3 と同じ型）。
      final decks = FakeDeckRepository(decks: [_deck('a', '消えないデッキ')])
        ..failSoftDelete = StateError('書き込めません');
      await pumpInAppScope(tester, const DeckListPage(), decks: decks);

      await _openDeckMenu(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('削除する'));
      await tester.pumpAndSettle();

      expect(find.textContaining('書き込めません'), findsOneWidget);
      expect(find.text('消えないデッキ'), findsOneWidget);
    });
  });

  testWidgets('★★ 起動時の警告がホーム（R2）に出る（決定 D39 / D60）★★', (tester) async {
    // ★M1 では Notice が R4 の中にあった。ホームが R2 に移った以上、
    //   ここに出ないと「R4 へ移動しないと警告が見えない」状態になる。
    await pumpInAppScope(
      tester,
      const DeckListPage(),
      decks: FakeDeckRepository(),
      notices: const [
        BootNotice('カードデータを更新できませんでした', details: [r'C:\dist']),
      ],
    );

    expect(find.text('カードデータを更新できませんでした'), findsOneWidget);

    // ★詳細（探した場所）まで辿れること。省くと利用者は直せない。
    await tester.tap(find.text('詳細'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'C:\dist'), findsOneWidget);
  });

  testWidgets('★R4（カード閲覧）へ行ける。M1 の資産を到達不能にしない', (tester) async {
    await pumpInAppScope(tester, const DeckListPage(),
        decks: FakeDeckRepository());

    await tester.tap(find.byTooltip('カードを見る'));
    await tester.pumpAndSettle();

    expect(find.text('カード'), findsOneWidget);
  });
}
