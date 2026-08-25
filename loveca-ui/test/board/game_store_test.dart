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
import 'package:loveca_ui/src/state/board_mode.dart';
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
      mode: BoardMode.localVersus,
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

      // ★ローカル対戦では相手が居るので null にならない（決定 D88）。
      store.setViewer(store.value.opponentId!);

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

  group('★★ reduce が投げたら履歴に積まない（決定 D86）★★', () {
    // ★★ 「同じはず」で済ませない ★★
    //   M-B3 で `session.apply`（= `record(reduce(...))`）を
    //   `reduceWithReport` + `record` に分けた。Dart は引数を先に評価するので
    //   順序は変わらない**はず**だが、分けた以上その事実を固定しておく。
    test('例外が出ても盤面も履歴も動かない', () {
      final store = storeWith();
      final before = store.value.session;

      expect(
        // ★存在しない instanceId は呼び出し側のバグ（`reduce.dart` の `_takeOut`）。
        () => store.dispatch(const MoveCard(
          instanceId: 'no-such-instance',
          fromPlayerId: kSelfPlayerId,
          from: Zone.hand,
          toPlayerId: kSelfPlayerId,
          to: Zone.waitingRoom,
        )),
        throwsArgumentError,
      );

      expect(identical(store.value.session, before), isTrue,
          reason: '★record に到達していない');
      expect(store.value.session.canUndo, isFalse);
      expect(store.value.operation, isNull, reason: '★直前の操作も残らない');
      store.dispose();
    });

    test('★対: 通る操作なら履歴が 1 件増えて直前の操作が残る', () {
      final store = storeWith();

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));

      expect(store.value.session.history.depth, 1);
      expect(store.value.operation, isNotNull);
      expect(store.value.operation!.cursorBefore,
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
      // ★DrawEnergy は進行ではないので遷移も整理も無い。
      expect(store.value.operation!.taken, isNull);
      expect(store.value.tidy, isNull);
      store.dispose();
    });
  });

  group('★ 分岐の判定は StepEngine に委ねる（決定 D86）', () {
    test('7.4.1 では宣言が要らず、後続候補は 1 つ', () {
      final store = storeWith();
      expect(store.requiresChoice, isFalse);
      expect(store.transitions, hasLength(1));
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
        BoardPage(initialState: initial, viewerId: kSelfPlayerId, mode: BoardMode.localVersus, seed: 7),
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
          mode: BoardMode.localVersus,
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

  group('★★ 「エネルギーを1枚出す」は両プレイヤーの袖に出る（決定 D87）★★', () {
    // ★★ M-B1 は視点側の袖にしか渡していなかった ★★
    //   一人回しは 1 人が両プレイヤーを操作する（D77 / D84）のに、相手側の
    //   エネルギーを手で出すには視点を切り替えるしかなかった。
    //   ★M-B3 でメインデッキの口を両側に出したことでこの非対称が見えたので直した。
    Future<void> pumpBoard(WidgetTester tester, GameState state) async {
      tester.view.physicalSize = const Size(1800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(initialState: state, viewerId: kSelfPlayerId, mode: BoardMode.localVersus, seed: 3),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    /// ★エネルギーデッキ置き場（4.9）の残り枚数。★どちらの山から出たかが分かる。
    ///   （エネルギー置き場の見出しは箱の**兄弟**なので `descendant` で辿れない）
    Finder deckCount(String playerId, int count) => find.descendant(
          of: find.byKey(ValueKey('pile-energy-$playerId')),
          matching: find.text('$count'),
        );

    testWidgets('両側にボタンがあり、どちらも押せる', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.energyDeck: [energyPrinting, energyPrinting],
          },
          opponentZones: const {
            Zone.energyDeck: [energyPrinting, energyPrinting],
          },
        ),
      );

      for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
        final button = find.byKey(ValueKey('draw-energy-$playerId'));
        expect(button, findsOneWidget, reason: '★$playerId 側のボタンが無い');
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      }
    });

    testWidgets('★★ 相手側を押すと増えるのは相手のエネルギー ★★', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.energyDeck: [energyPrinting, energyPrinting],
          },
          opponentZones: const {
            Zone.energyDeck: [energyPrinting, energyPrinting],
          },
        ),
      );

      await tester
          .tap(find.byKey(const ValueKey('draw-energy-$kOpponentPlayerId')));
      await tester.pumpAndSettle();

      expect(deckCount(kOpponentPlayerId, 1), findsOneWidget,
          reason: '★相手のエネルギーデッキが 2 → 1');
      // ★対: 自分のエネルギーデッキは減っていない（取り違えの検査）。
      expect(deckCount(kSelfPlayerId, 2), findsOneWidget);
    });

    testWidgets('★片側だけ空なら、そちらだけ無効になる', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.energyDeck: [energyPrinting],
          },
        ),
      );

      expect(
        tester
            .widget<FilledButton>(
                find.byKey(const ValueKey('draw-energy-$kSelfPlayerId')))
            .onPressed,
        isNotNull,
      );
      // ★消さずに無効にして理由を出す。
      final empty =
          find.byKey(const ValueKey('draw-energy-$kOpponentPlayerId'));
      expect(empty, findsOneWidget);
      expect(tester.widget<FilledButton>(empty).onPressed, isNull);
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
          mode: BoardMode.localVersus,
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
          mode: BoardMode.localVersus,
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
          mode: BoardMode.localVersus,
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
