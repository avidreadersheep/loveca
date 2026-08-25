/// R2 → R7 の入口と開始ダイアログ（決定 D79 / D80 / D81 / D88）.
///
/// ★★ 6.2.1.4 の 2 段を UI が潰していないこと ★★
/// 条文は「無作為にどちらかのプレイヤーを選択し、**そのプレイヤーが**
/// どちらが先攻となるかを選びます」の 2 段。ローカル対戦では形骸化するが、
/// **UI が構造を潰すと Phase 6 で組み直しになる。**
///
/// ★★ 2 段を保つのはローカル対戦だけである（決定 D88 / D81 の訂正）★★
/// 条文は「**各プレイヤーは**無作為に…」であり、**1 人では手順が成立しない。**
/// ★ソロでは出さないが、**黙って飛ばさず理由を出す**ことを対で固定する。
///
/// ★★ 6.1 違反は通す。未知の刷りは通さない ★★
/// 前者はサンドボックス（D-A）として正当。後者は `CardInstance` を作れない。
/// **どちらも黙って扱わない。**
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
  Future<FakeDeckRepository> openDeckList(
    WidgetTester tester, {
    List<Deck>? decks,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repository = FakeDeckRepository(
      catalog: realShapedCatalog(),
      decks: decks ?? [boardFixtureDeck()],
    );
    await pumpInAppScope(
      tester,
      const DeckListPage(),
      decks: repository,
      catalog: realShapedCatalog(),
    );
    return repository;
  }

  /// ★★ 入口はモードごとに 2 本ある（決定 D88 / D81 の訂正）★★
  /// 既定はローカル対戦 —— この群が見ているのは 6.2.1.4 の 2 段であり、
  /// **それを保つのはローカル対戦だけ**だからである。
  Future<void> openStartDialog(
    WidgetTester tester, {
    BoardMode mode = BoardMode.localVersus,
  }) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(mode.label));
    await tester.pumpAndSettle();
  }

  group('★ R2 のデッキメニューが唯一の入口（決定 D81 / D88）', () {
    testWidgets('★★ 入口が 2 本ある（ソロ / ローカル対戦）★★', (tester) async {
      await openDeckList(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('ソロ'), findsOneWidget);
      expect(find.text('ローカル対戦'), findsOneWidget);
      // ★廃止した語が画面にもコードにも残っていないことは
      //   `test/board/abolished_term_test.dart` が走査で見ている
      //   （★ここに literal を書くと、その走査自身が 0 件にならない）。
    });

    testWidgets('「ローカル対戦」からダイアログが開く', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      expect(find.text('ローカル対戦を始める'), findsOneWidget);
    });

    testWidgets('★条番号が画面に出る（根拠が追える）', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      expect(find.text('6.2.1.1'), findsOneWidget);
      expect(find.text('6.2.1.4'), findsOneWidget);
    });
  });

  group('★★ 6.2.1.4 は 2 段のまま出す ★★', () {
    testWidgets('①選ぶ人 →②その人が先攻を選ぶ、の 2 段が出ている', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      expect(find.text('① 選ぶ人を決める'), findsOneWidget);
      expect(find.text('② その人が先攻を選ぶ'), findsOneWidget);
      // ★条文の文言そのものも出す（読み替えを画面に残さない）。
      expect(find.textContaining('無作為にどちらかのプレイヤーを選択し'),
          findsOneWidget);
    });

    testWidgets('★無作為はその場で引いて結果を見せる', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      // ★引く前は結果が出ていない（「常に出す」実装を潰す）。
      expect(find.byKey(const ValueKey('resolved-chooser')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('resolve-chooser')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('resolved-chooser')), findsOneWidget);
      expect(find.textContaining('選ばれたのは:'), findsOneWidget);
    });
  });

  group('★ seed（決定 D79）', () {
    testWidgets('既定で seed が入っていて、書き換えられる', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      final field = find.byKey(const ValueKey('seed-field'));
      expect(tester.widget<TextField>(field).controller!.text, isNotEmpty);

      await tester.enterText(field, '4242');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      // ★入れた seed がそのまま盤面に出る（書き写して再現できる）。
      expect(find.text('seed 4242'), findsOneWidget);
    });

    testWidgets('★★ 同じ seed なら同じ初期盤面になる ★★', (tester) async {
      Future<List<String>> handWith(String seed) async {
        await openDeckList(tester);
        await openStartDialog(tester);
        await tester.enterText(find.byKey(const ValueKey('seed-field')), seed);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('start-board')));
        await tester.pumpAndSettle();

        final page = tester.widget<BoardPage>(find.byType(BoardPage));
        final hand = page.initialState.playerOf(kSelfPlayerId).hand;

        // ★★ 次の回の前に R7 を閉じる ★★
        //   `pumpWidget` は同じ型の `MaterialApp` なら要素を作り直さないので、
        //   閉じないと **Navigator に前回の盤面が残ったまま**になり、
        //   2 回目の「ローカル対戦」が見つからない。
        await tester.pageBack();
        await tester.pumpAndSettle();

        return hand.map((c) => c.instanceId).toList();
      }

      final a = await handWith('777');
      final b = await handWith('777');
      final c = await handWith('778');

      expect(a, equals(b), reason: '★同じ seed なら同じ手札');
      expect(a, isNot(equals(c)), reason: '★対: seed が違えば違う手札');
    });
  });

  group('★ デッキの選択（6.2.1.1 / 決定 D81）', () {
    testWidgets('★既定は同じデッキ（そう書いてある）', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      expect(find.textContaining('（同じデッキ）'), findsWidgets);
    });

    testWidgets('★同じデッキで始めても instanceId が衝突しない', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      final page = tester.widget<BoardPage>(find.byType(BoardPage));
      final ids = [
        for (final player in page.initialState.players) ...[
          ...player.hand.map((c) => c.instanceId),
          ...player.mainDeck.map((c) => c.instanceId),
          ...player.energyDeck.map((c) => c.instanceId),
          ...player.energyField.map((c) => c.instanceId),
        ],
      ];

      expect(ids.toSet().length, ids.length, reason: '★重複が 1 つも無い');
    });
  });

  group('★★ 6.1 を満たさないデッキ — 通すが黙らない ★★', () {
    testWidgets('ダイアログに違反の中身が出る', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      // fixture は実在の 6 種しか無いので 6.1.1.1 を満たせない。
      expect(find.byKey(const ValueKey('invalid-自分')), findsOneWidget);
      expect(find.textContaining('このまま回せます'), findsWidgets);
      // ★件数だけにしない。何が足りないかが読める。
      expect(find.textContaining('メンバーカード'), findsWidgets);
    });

    testWidgets('★★ 開始でき、盤面にも帯が残る ★★', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      expect(find.byType(BoardPage), findsOneWidget);
      expect(find.textContaining('6.1 の構築条件を満たしていません'), findsWidgets);
      // ★6.2.1.6 を経ていないことも盤面から読める。
      expect(find.textContaining('マリガンはまだありません'), findsOneWidget);
    });
  });

  group('★★ 未知の刷りを含むデッキ — 始められない（決定 D35 / D80）★★', () {
    testWidgets('理由と printingId が出て、開始ボタンが無効になる', (tester) async {
      await openDeckList(tester, decks: [boardFixtureDeckWithUnknown()]);
      await openStartDialog(tester);

      expect(find.byKey(const ValueKey('unknown-自分')), findsOneWidget);
      // ★どの刷りが引けないかを出す（黙って消さない）。
      expect(find.textContaining('GHOST-bp9-999-X'), findsWidgets);

      final start = find.byKey(const ValueKey('start-board'));
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
    });

    testWidgets('★対: 未知が無ければ押せる（常に無効ではない）', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);

      final start = find.byKey(const ValueKey('start-board'));
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    });
  });

  group('★ 6.2.1 の結果が盤面に出ている', () {
    testWidgets('手札 6 枚 / エネルギー 3 枚', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      final page = tester.widget<BoardPage>(find.byType(BoardPage));
      for (final player in page.initialState.players) {
        expect(player.hand.length, 6, reason: '6.2.1.5');
        expect(player.energyField.length, 3, reason: '6.2.1.7');
      }

      expect(find.textContaining('自分の手札 4.11'), findsOneWidget);
      expect(find.textContaining('6 枚'), findsWidgets);
    });

    testWidgets('★押したデッキが自分側（下段）になる（決定 D81）', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester);
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      expect(tester.widget<BoardPage>(find.byType(BoardPage)).viewerId,
          kSelfPlayerId);
    });
  });

  // =========================================================================
  // ★★ ソロの入口（決定 D88 / 盤面設計メモ §14-1 / D81 の訂正）★★
  //
  // ★★ 「出さない」だけでは足りない ★★
  //   6.2.1.4 を単に消すと「このアプリは 6.2.1.4 を実装していない」と読まれる。
  //   **成立しない理由を画面に出す**ことまでが D88 の要求である。
  // =========================================================================
  group('★★ ソロ: 成立しない手順は理由つきで出さない ★★', () {
    testWidgets('タイトルがモードを名乗る', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester, mode: BoardMode.solo);

      expect(find.text('ソロを始める'), findsOneWidget);
    });

    testWidgets('★★ 6.2.1.4 を出さず、成立しない理由を出す ★★', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester, mode: BoardMode.solo);

      expect(find.text('① 選ぶ人を決める'), findsNothing);
      expect(find.text('② その人が先攻を選ぶ'), findsNothing);
      // ★黙って飛ばしていないこと。
      expect(find.byKey(const ValueKey('solo-first-player-note')),
          findsOneWidget);
      expect(find.textContaining('プレイヤーが 1 人ではこの手順が成立しません'),
          findsOneWidget);
    });

    testWidgets('★★ 6.2.1.1 の相手デッキを選ばせず、理由を出す ★★', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester, mode: BoardMode.solo);

      expect(find.byKey(const ValueKey('opponent-deck')), findsNothing);
      expect(find.byKey(const ValueKey('solo-opponent-note')), findsOneWidget);
      // ★1.1.1 に触れる（players が 2 人のままである理由 / §14-5）。
      expect(find.textContaining('1.1.1'), findsOneWidget);
    });

    testWidgets('★対: ローカル対戦では両方とも出る', (tester) async {
      // ★これが無いと「キーを間違えていて常に findsNothing」でも通る。
      await openDeckList(tester);
      await openStartDialog(tester);

      expect(find.byKey(const ValueKey('opponent-deck')), findsOneWidget);
      expect(find.text('① 選ぶ人を決める'), findsOneWidget);
      expect(find.byKey(const ValueKey('solo-first-player-note')), findsNothing);
      expect(find.byKey(const ValueKey('solo-opponent-note')), findsNothing);
    });

    testWidgets('★ 相手の 6.1 違反は出さない（幽霊の違反にしない）', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester, mode: BoardMode.solo);

      // fixture は 6.1 を満たせないので、自分側は必ず出る（前提）。
      expect(find.byKey(const ValueKey('invalid-自分')), findsOneWidget);
      expect(find.byKey(const ValueKey('invalid-相手')), findsNothing);
    });

    testWidgets('★★ 始めるとソロの盤面が立ち、自分が先攻になる ★★', (tester) async {
      await openDeckList(tester);
      await openStartDialog(tester, mode: BoardMode.solo);
      await tester.tap(find.byKey(const ValueKey('start-board')));
      await tester.pumpAndSettle();

      final page = tester.widget<BoardPage>(find.byType(BoardPage));
      expect(page.mode, BoardMode.solo);
      expect(page.viewerId, kSelfPlayerId);
      // ★ソロは常に先攻（決定 D88）。
      expect(page.initialState.firstPlayerId, kSelfPlayerId);
      // ★1.1.1: players は 2 人のまま（描かないだけではなく参照しない / §14-5）。
      expect(page.initialState.players, hasLength(2));
      // ★相手側には自分と同じデッキが入っているので手札 6 枚（6.2.1.5）。
      expect(page.initialState.playerOf(kOpponentPlayerId).hand, hasLength(6),
          reason: '★空の Deck を採らない（条文に無い状態を作らない / §14-5）');
      // ★盤面の帯にも相手の 6.1 違反は出ない。
      expect(find.textContaining('相手のデッキは 6.1'), findsNothing);
    });
  });
}
