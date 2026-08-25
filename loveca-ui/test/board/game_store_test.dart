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

GameStore storeWith({
  int seed = 1,
  GameState? state,
  // ★★ 512 は手では到達させられない（M-B5）★★ 到達を本当に起こすために下げる。
  int historyMaxDepth = 512,
}) =>
    GameStore(
      initialState: state ?? boardFixtureState(),
      viewerId: kSelfPlayerId,
      mode: BoardMode.localVersus,
      seed: seed,
      cards: realShapedCatalog().cards,
      rng: SeededRng(seed),
      historyMaxDepth: historyMaxDepth,
    );

void main() {
  group('★ DB を要らない（決定 D55）', () {
    test('リポジトリを 1 つも受け取らない', () {
      // ★引数は値だけ（GameState / cards / rng）。
      //   盤面は保存も同期もしないので、DB へ行く用事が無い。
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

    test('★履歴に積まれる（M-B5 の undo がそのまま効く）', () {
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

  group('★★ 合成コマンド（M-B5 / 決定 D78 / 盤面設計メモ §8-2）★★', () {
    test('★★ N 個のアクションで履歴は 1 件だけ増える ★★', () {
      final store = storeWith();
      final card = store.value.state.playerOf(kSelfPlayerId).hand.first;

      store.dispatchAll([
        MoveCard(
          instanceId: card.instanceId,
          fromPlayerId: kSelfPlayerId,
          from: Zone.hand,
          toPlayerId: kSelfPlayerId,
          to: Zone.waitingRoom,
        ),
        MoveCard(
          instanceId: card.instanceId,
          fromPlayerId: kSelfPlayerId,
          from: Zone.waitingRoom,
          toPlayerId: kSelfPlayerId,
          to: Zone.exile,
        ),
      ]);

      expect(store.value.session.history.depth, 1,
          reason: '★2 件積まれると undo が 2 回要る');
      expect(store.value.state.playerOf(kSelfPlayerId).exile, hasLength(1));

      // ★1 回の undo で**両方**戻る。
      store.undo();
      expect(store.value.state.playerOf(kSelfPlayerId).exile, isEmpty);
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom, isEmpty,
          reason: '★中間状態が残っていたら合成になっていない');
      expect(store.value.state.playerOf(kSelfPlayerId).hand.map((c) => c.instanceId),
          contains(card.instanceId));
      store.dispose();
    });

    test('★★ 途中で投げたら 1〜k-1 回目の結果も残らない ★★', () {
      // ★★ M-B3 の単発版（例外が出たら record に到達しない）の合成版 ★★
      //   合成では中間状態が生じるので、**黙って中途半端な状態にしない**ことを固定する。
      final store = storeWith();
      final before = store.value;
      final card = store.value.state.playerOf(kSelfPlayerId).hand.first;

      expect(
        () => store.dispatchAll([
          MoveCard(
            instanceId: card.instanceId,
            fromPlayerId: kSelfPlayerId,
            from: Zone.hand,
            toPlayerId: kSelfPlayerId,
            to: Zone.waitingRoom,
          ),
          // ★2 つ目で投げる。1 つ目は成功している。
          const MoveCard(
            instanceId: 'no-such-instance',
            fromPlayerId: kSelfPlayerId,
            from: Zone.waitingRoom,
            toPlayerId: kSelfPlayerId,
            to: Zone.exile,
          ),
        ]),
        throwsArgumentError,
      );

      expect(identical(store.value, before), isTrue,
          reason: '★state への代入はループの外に 1 回だけ');
      expect(store.value.session.canUndo, isFalse);
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom, isEmpty,
          reason: '★1 つ目の移動も残らない');
      expect(store.value.log, isEmpty);
      store.dispose();
    });

    test('★ dispatch は dispatchAll の 1 件版（同じ形で積まれる）', () {
      final one = storeWith();
      final many = storeWith();

      one.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      many.dispatchAll(const [DrawEnergy(playerId: kSelfPlayerId)]);

      expect(many.value.session.history.depth, one.value.session.history.depth);
      expect(many.value.operation!.cursorBefore, one.value.operation!.cursorBefore);
      one.dispose();
      many.dispose();
    });
  });

  group('★★ 巻き戻し（M-B5 / 決定 D78）★★', () {
    test('★ 戻せないときは何も起きない（例外にしない）', () {
      final store = storeWith();
      final before = store.value;

      store.undo();
      store.undoStep();

      expect(identical(store.value, before), isTrue);
      expect(store.canUndo, isFalse);
      expect(store.undoTarget, isNull);
      expect(store.undoStepTarget, isNull);
      store.dispose();
    });

    test('★★ 着地先を押す前に読める（決定 D78）★★', () {
      final store = storeWith();
      final at = store.value.state.cursor;

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));

      expect(store.canUndo, isTrue);
      // ★「押したらどこへ着くか」を押す前に問える。
      expect(store.undoTarget!.cursor, at);
      expect(store.undoStepTarget!.cursor, at);
      store.dispose();
    });

    test('★★ 巻き戻すと「直前の操作」も戻る（古い表示を残さない）★★', () {
      final store = storeWith();

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      expect(store.value.operation, isNotNull);

      store.undo();

      expect(store.value.operation, isNull,
          reason: '★戻した先は「まだ何もしていない」。直前: が残ると嘘になる');
      expect(store.value.rewind, isNotNull);
      expect(store.value.rewind!.entriesPopped, 1);
      expect(store.value.rewind!.wholeStep, isFalse);
      store.dispose();
    });

    test('★ 次の操作で巻き戻しの行は消える（寿命は次の操作まで）', () {
      final store = storeWith();

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      store.undo();
      expect(store.value.rewind, isNotNull);

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));

      expect(store.value.rewind, isNull);
      expect(store.value.operation, isNotNull);
      store.dispose();
    });

    test('★★ 履歴と並行スタックの深さがずれない ★★', () {
      // ★ずれると、巻き戻したときに別の操作の「直前:」が復活する。
      final store = storeWith();

      for (var i = 0; i < 3; i++) {
        store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      }
      expect(store.value.session.history.depth, 3);

      store.undo();
      expect(store.value.session.history.depth, 2);
      expect(store.value.operation, isNotNull, reason: '★2 件目の操作が戻ってくる');

      store.undo();
      store.undo();
      expect(store.value.session.history.depth, 0);
      expect(store.value.operation, isNull);
      expect(store.canUndo, isFalse);
      store.dispose();
    });
  });

  group('★★ maxDepth に達したことを黙らない（決定 D78）★★', () {
    test('★★ 到達すると立つ / ★対 到達していなければ立たない ★★', () {
      // ★★ 512 件は手では作れないので、上限を小さくして**本当に到達させる** ★★
      //   「起きない入力で出ないこと」も対で見る（M3 の縮退テストと同じ手法）。
      final store = storeWith(historyMaxDepth: 3);
      expect(store.isHistoryAtMaxDepth, isFalse, reason: '★空なら立たない');
      expect(store.historyMaxDepth, 3);

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      expect(store.isHistoryAtMaxDepth, isFalse, reason: '★★ 手前では立たない ★★');

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      expect(store.isHistoryAtMaxDepth, isTrue);

      // ★★ 超えても canUndo は真のまま = 黙って捨てられている ★★
      //   だから帯に出す必要がある。
      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      expect(store.value.session.history.depth, 3, reason: '★深さは飽和する');
      expect(store.canUndo, isTrue);
      expect(store.isHistoryAtMaxDepth, isTrue);

      store.dispose();
    });

    test('★★ 捨てられても並行スタックがずれない ★★', () {
      // ★捨てる規則が食い違うと、巻き戻したときに別の操作の「直前:」が出る。
      final store = storeWith(historyMaxDepth: 2);
      for (var i = 0; i < 5; i++) {
        store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      }

      store.undo();
      store.undo();

      expect(store.value.session.history.depth, 0);
      expect(store.value.operation, isNull);
      expect(store.canUndo, isFalse);
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
    //   ローカル対戦は 1 人が両プレイヤーを操作する（D77 / D84）のに、相手側の
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
