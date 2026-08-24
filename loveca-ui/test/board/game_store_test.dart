/// `GameStore`（決定 D53 / D55 / D73 / D75）.
///
/// ★★ `dispatch` が `reduce` を呼ぶ唯一の場所である ★★
/// M-B1 で実際に投げるアクションは `DrawEnergy` 1 つだけだが、
/// **呼び出し元を持たないまま「層が通った」と言わない**ため、
/// ここと実機の両方で通す。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_notice.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

GameStore storeWith({int seed = 1, GameState? state}) => GameStore(
      initialState: state ?? boardFixtureState(),
      viewerId: kSelfPlayerId,
      seed: seed,
      cards: realShapedCatalog().cards,
      rng: SeededRng(seed),
    );

void main() {
  group('★ DB を要らない（決定 D55）', () {
    test('リポジトリを 1 つも受け取らない', () {
      // ★引数は値だけ（GameState / cards / rng）。
      //   一人回しは保存も同期もしないので、盤面が DB へ行く用事が無い。
      final store = storeWith();
      expect(store.value.state.players.length, 2);
      store.dispose();
    });
  });

  group('★★ dispatch(DrawEnergy) が層を通る（決定 D73）★★', () {
    test('エネルギー置き場が +1 / エネルギーデッキが -1', () {
      final store = storeWith();
      final before = store.value.state.playerOf(kSelfPlayerId);
      expect(before.energyDeck.length, 3, reason: '★前提: 6 枚 - 6.2.1.7 の 3 枚');

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));

      final after = store.value.state.playerOf(kSelfPlayerId);
      expect(after.energyDeck.length, 2);
      expect(after.energyField.length, before.energyField.length + 1);
      store.dispose();
    });

    test('★同じ seed で同じ札 / ★対 違う seed で別の札', () {
      // ★同じ初期状態に対して store の seed だけ変える。
      final initial = boardFixtureState();

      String drawWith(int seed) {
        final store = storeWith(seed: seed, state: initial);
        store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
        final id = store.value.state
            .playerOf(kSelfPlayerId)
            .energyField
            .first
            .instanceId;
        store.dispose();
        return id;
      }

      expect(drawWith(5), drawWith(5), reason: '再現性');
      final bySeed = {for (var s = 1; s <= 8; s++) drawWith(s)};
      expect(bySeed.length, greaterThan(1), reason: '★seed で結果が変わる');
    });

    test('★同じ store で 2 回引くと違う札（乱数源を使い回している）', () {
      final store = storeWith();
      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      final first =
          store.value.state.playerOf(kSelfPlayerId).energyField.first.instanceId;

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      final second =
          store.value.state.playerOf(kSelfPlayerId).energyField.first.instanceId;

      expect(first, isNot(second),
          reason: '★毎回 SeededRng を作り直していると同じ札が出続ける');
      store.dispose();
    });

    test('★履歴に積まれる（M-B4 の undo がそのまま効く）', () {
      final store = storeWith();
      expect(store.value.session.canUndo, isFalse);

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));

      expect(store.value.session.canUndo, isTrue);
      store.dispose();
    });
  });

  group('★ エネルギーデッキが空のとき（10.5.4 の閉ループ）', () {
    test('canDrawEnergy が false になる', () {
      // ★エネルギーちょうど 3 枚 → 6.2.1.7 で使い切る。
      final store = storeWith(
        state: boardFixtureState(
          self: boardFixtureDeckWithExactEnergy(),
          opponent: boardFixtureDeckWithExactEnergy(),
        ),
      );

      expect(store.value.state.playerOf(kSelfPlayerId).energyDeck, isEmpty);
      expect(store.canDrawEnergy(kSelfPlayerId), isFalse);
      // ★対: 残っていれば true（判定が常に false ではないこと）
      expect(storeWith().canDrawEnergy(kSelfPlayerId), isTrue);
      store.dispose();
    });
  });

  group('★ setViewer は GameAction ではない（決定 D75）', () {
    test('盤面の状態も履歴も変わらない', () {
      final store = storeWith();
      final before = store.value.session;

      store.setViewer(store.value.opponentId);

      expect(store.value.viewerId, kOpponentPlayerId);
      expect(identical(store.value.session, before), isTrue,
          reason: '★視点は UI の状態。reduce を通さない');
      expect(store.value.session.canUndo, isFalse);
      store.dispose();
    });

    test('同じ視点を指定しても通知しない', () {
      final store = storeWith();
      var notified = 0;
      store.addListener(() => notified++);

      store.setViewer(kSelfPlayerId);

      expect(notified, 0);
      store.dispose();
    });
  });

  group('★ 4.1.2.2 の枚数は答える / 中身は答えない（決定 D77）', () {
    test('countIn が枚数を返す', () {
      final store = storeWith();
      expect(store.countIn(kSelfPlayerId, Zone.mainDeck), 6);
      expect(store.countIn(kSelfPlayerId, Zone.energyDeck), 3);
      store.dispose();
    });
  });

  group('★ 画面から dispatch が通る（実物の経路）', () {
    testWidgets('ボタンを押すとエネルギーが増える', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final initial = boardFixtureState();
      await pumpInAppScope(
        tester,
        BoardPage(initialState: initial, viewerId: kSelfPlayerId, seed: 7),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-energy-$kSelfPlayerId')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('draw-energy-$kSelfPlayerId')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-energy-$kSelfPlayerId')),
          matching: find.text('2'),
        ),
        findsOneWidget,
        reason: '★dispatch → reduce → 再描画 が実物として通っている',
      );
    });

    testWidgets('★空なら無効になり、理由が読める', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: boardFixtureState(
            self: boardFixtureDeckWithExactEnergy(),
            opponent: boardFixtureDeckWithExactEnergy(),
          ),
          viewerId: kSelfPlayerId,
          seed: 1,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );

      final button = find.byKey(const ValueKey('draw-energy-$kSelfPlayerId'));
      // ★★ 消さない。無効にして理由を出す ★★
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.text('エネルギーが空'), findsWidgets);
      expect(
        find.byTooltip(
          'エネルギーデッキが空です。エネルギーは控え室を経由しない'
          '閉ループ（10.5.4）なので、リフレッシュ（10.2）は起きません。',
        ),
        findsWidgets,
      );
    });
  });

  group('★ seed を画面に出す（決定 D79）', () {
    testWidgets('AppBar に seed が出る', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: boardFixtureState(seed: 12345),
          viewerId: kSelfPlayerId,
          seed: 12345,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );

      expect(find.text('seed 12345'), findsOneWidget);
    });
  });

  group('★ 盤面の帯（BoardNotice / 盤面設計メモ §10-3）', () {
    testWidgets('★★ マリガンが未実装であることを盤面から読める ★★', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: boardFixtureState(),
          viewerId: kSelfPlayerId,
          seed: 1,
          notices: const [MulliganNotImplemented()],
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );

      // ★「6.2.1.6」だけで探さない —— ルール外の置き場の見出し
      //   （「脇置き 6.2.1.6」）にも同じ条番号が出る。
      expect(find.textContaining('マリガンはまだありません'), findsOneWidget);
      expect(find.textContaining('0 枚として開始'), findsOneWidget);
    });

    testWidgets('★対: 注記が無ければ帯は出ない', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: boardFixtureState(),
          viewerId: kSelfPlayerId,
          seed: 1,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );

      expect(find.textContaining('マリガンはまだありません'), findsNothing);
      // ★対: 盤面そのものは出ている（何も描かれていないから通った、ではない）
      expect(find.byKey(const ValueKey('progress-bar')), findsOneWidget);
    });
  });
}
