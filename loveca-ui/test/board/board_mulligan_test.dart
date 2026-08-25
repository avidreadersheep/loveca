/// 6.2.1.6 マリガンの画面（決定 D93 / M-B6）.
///
/// ★★ 分岐が 3 つあるので、出る側と出ない側を対で置く（D-10）★★
///   「0 枚選べる」「N 枚選べる」「1 枚以上戻したらシャッフル」。
///   ★シャッフルの有無そのものは `loveca-core/test/game_setup_test.dart` が
///   **乱数の消費回数**で固定している。ここは**画面から通せること**を見る。
///
/// ★★ 「やめる」は「0 枚」ではない ★★
///   キャンセルしたら盤面を開かない。★対で「決定すると開く」を置く
///   （開かない側だけを見ると、**何をしても開かない実装**でも通る）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/deck/deck_list_page.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

void main() {
  Future<void> openDeckList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      const DeckListPage(),
      decks: FakeDeckRepository(
        catalog: realShapedCatalog(),
        decks: [boardFixtureDeck()],
      ),
      catalog: realShapedCatalog(),
    );
  }

  /// R2 のメニューから開始ダイアログを開き、「開始」まで押す。
  Future<void> openMulligan(
    WidgetTester tester, {
    BoardMode mode = BoardMode.localVersus,
  }) async {
    await openDeckList(tester);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(mode.label));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-board')));
    await tester.pumpAndSettle();
  }

  /// いま出ている段の手札の札（`Wrap` の子）。
  Finder handCards() => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('mulligan-card-'));

  group('★★ ソロ（決定 D88 / §14-5）★★', () {
    testWidgets('★ 自分の手札 6 枚だけが出て、相手の段が無い', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      expect(find.byKey(const ValueKey('mulligan-dialog')), findsOneWidget);
      expect(handCards(), findsNWidgets(6), reason: '★6.2.1.5 の初期手札');
      // ★1 段しかない（= 相手を選ばせない）。
      expect(find.byKey(const ValueKey('mulligan-next')), findsNothing);
      expect(find.byKey(const ValueKey('mulligan-done')), findsOneWidget);
      expect(find.textContaining('（1 / 1）'), findsOneWidget);
    });

    testWidgets('★★ 相手を 0 枚として扱う理由が読める（黙って飛ばさない）★★',
        (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      expect(find.byKey(const ValueKey('mulligan-solo-note')), findsOneWidget);
      expect(find.textContaining('乱数も消費しません'), findsOneWidget);
    });

    testWidgets('★対: ローカル対戦ではその理由を出さない', (tester) async {
      await openMulligan(tester);

      // ★出る側だけを見ると「常に出す実装」でも通る。
      expect(find.byKey(const ValueKey('mulligan-solo-note')), findsNothing);
    });
  });

  group('★★ ローカル対戦は先攻 → 後攻の 2 段（6.2.1.6「先攻プレイヤーから順に」）★★',
      () {
    testWidgets('★ 1 段目は先攻、2 段目は後攻', (tester) async {
      await openMulligan(tester);

      expect(find.textContaining('先攻のマリガン 6.2.1.6'), findsOneWidget);
      expect(find.textContaining('（1 / 2）'), findsOneWidget);
      // ★1 段目では「決定」を出さない（後攻を飛ばせてしまう）。
      expect(find.byKey(const ValueKey('mulligan-done')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('mulligan-next')));
      await tester.pumpAndSettle();

      expect(find.textContaining('後攻のマリガン 6.2.1.6'), findsOneWidget);
      expect(find.textContaining('（2 / 2）'), findsOneWidget);
      expect(find.byKey(const ValueKey('mulligan-next')), findsNothing);
      expect(find.byKey(const ValueKey('mulligan-done')), findsOneWidget);
    });
  });

  group('★★ 0 枚 / N 枚 ★★', () {
    testWidgets('★ 0 枚で決定すると盤面が開き、手札は選ぶ前と同じ', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      expect(find.textContaining('選択 0 枚'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mulligan-done')));
      await tester.pumpAndSettle();

      final page = tester.widget<BoardPage>(find.byType(BoardPage));
      expect(page.initialState.playerOf(kSelfPlayerId).hand, hasLength(6));
    });

    testWidgets('★★ N 枚選ぶと、その札が盤面の手札から消える ★★', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      // ★選ぶ前の手札を控える（`mulligan-card-{instanceId}` のキーから読む）。
      final before = tester
          .widgetList(handCards())
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(before, hasLength(6));

      await tester.tap(find.byKey(ValueKey(before.first)));
      await tester.tap(find.byKey(ValueKey(before[1])));
      await tester.pumpAndSettle();
      expect(find.textContaining('選択 2 枚'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('mulligan-done')));
      await tester.pumpAndSettle();

      final hand = tester
          .widget<BoardPage>(find.byType(BoardPage))
          .initialState
          .playerOf(kSelfPlayerId)
          .hand;
      expect(hand, hasLength(6), reason: '★同じ枚数を引き直す');

      final chosen = {
        before.first.replaceFirst('mulligan-card-', ''),
        before[1].replaceFirst('mulligan-card-', ''),
      };
      expect(hand.map((c) => c.instanceId).toSet().intersection(chosen), isEmpty,
          reason: '★選んだ 2 枚は脇に置かれてメインデッキへ戻っている');
    });

    testWidgets('★ タップでトグルできる（選び直せる）', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      final first = tester
          .widgetList(handCards())
          .map((w) => (w.key! as ValueKey<String>).value)
          .first;

      await tester.tap(find.byKey(ValueKey(first)));
      await tester.pumpAndSettle();
      expect(find.textContaining('選択 1 枚'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey(first)));
      await tester.pumpAndSettle();
      expect(find.textContaining('選択 0 枚'), findsOneWidget);
    });

    testWidgets('★★ シャッフルが起きる側と起きない側を画面から読める ★★',
        (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      // ★0 枚 —— 起きない側。
      expect(find.textContaining('シャッフル（5.5.1）は行われません'), findsOneWidget);

      final first = tester
          .widgetList(handCards())
          .map((w) => (w.key! as ValueKey<String>).value)
          .first;
      await tester.tap(find.byKey(ValueKey(first)));
      await tester.pumpAndSettle();

      // ★対: 1 枚以上 —— 起きる側。
      expect(find.textContaining('シャッフルします（5.5.1）'), findsOneWidget);
      expect(find.textContaining('シャッフル（5.5.1）は行われません'), findsNothing);
    });
  });

  group('★★ やめる ★★', () {
    testWidgets('★ 盤面を開かない（0 枚として開始しない）', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      await tester.tap(find.byKey(const ValueKey('mulligan-cancel')));
      await tester.pumpAndSettle();

      expect(find.byType(BoardPage), findsNothing);
      // ★R2 へ戻っている（どこにも行かないのではない）。
      expect(find.byType(DeckListPage), findsOneWidget);
    });

    testWidgets('★対: 決定すれば開く（何をしても開かない実装ではない）', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);

      await tester.tap(find.byKey(const ValueKey('mulligan-done')));
      await tester.pumpAndSettle();

      expect(find.byType(BoardPage), findsOneWidget);
    });
  });

  group('★★ 実装したので「未実装」の帯は出ない ★★', () {
    testWidgets('★ 盤面のどこにも出ない', (tester) async {
      await openMulligan(tester, mode: BoardMode.solo);
      await tester.tap(find.byKey(const ValueKey('mulligan-done')));
      await tester.pumpAndSettle();

      expect(find.textContaining('マリガンはまだありません'), findsNothing);
      // ★対: 盤面は出ている（何も描かれていないから通った、ではない）。
      expect(find.byKey(const ValueKey('progress-bar')), findsOneWidget);
      // ★脇置きは 6.2.1.6 の手順内にしか存在しない → 盤面では常に 0 枚。
      expect(find.textContaining('脇置き 6.2.1.6 = 0 枚'), findsOneWidget);
    });
  });
}
