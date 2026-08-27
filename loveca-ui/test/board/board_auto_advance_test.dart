/// 自動進行（M-B7 / 決定 D92 / D98 / 盤面設計メモ §15）.
///
/// ★★★ 「止まるべきで止まる」だけでは足りない ★★★
/// **「止まらなくてよいステップで止まらない」を対で置く**（`ルール整合性チェック_v1.06.md`
/// **D-10**）。片側だけを見ると、**常に止まる実装**でも**一度も止まらない実装**でも
/// 片方は通ってしまう。
///
/// ★★ 期待値を手で書かない（D-15）★★
/// 押下の区切りは `phaseCycle` / `PhaseSteps` / `skipsCursor` / `stopsAutoAdvance` から
/// **導く**。実際に動かすのは `stepGraph` なので、**期待値と実際が別の表から来ている。**
/// 手で 12 行書くと、この相互検査が消える。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';

import '../support/board_fixture.dart';
import '../support/board_signature.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _live = drawLivePrinting;
const _member = parallelMemberNormal; // ブレード 2
const _energy = energyPrinting;

// ===========================================================================
// ★ 期待値の導出（手で並べない）
// ===========================================================================

/// [mode] で 1 ターンに通るカーソル。★飛ばす判定は `loveca_core` に委ねる。
List<StepCursor> _cursorsFor(BoardMode mode) => [
      for (final phase in phaseCycle)
        for (final step in phase.steps)
          if (!skipsCursor(StepCursor(phase, step), mode.progression))
            StepCursor(phase, step),
    ];

bool _defaultStops(StepId step) => step.stopsAutoAdvance;

/// 1 押下ぶんに区切る。
///
/// ★★ 停止判定は「**次に実行するステップ**が停止点か」である ★★
/// 停止点の上で押したということは、プレイヤーがそこを済ませたということなので、
/// **必ず 1 ステップは実行する。**
///
/// ★[stops] を差し替えられるようにしてあるのは**対照実験のため**（番人 1）。
List<List<StepCursor>> _pressesFor(
  BoardMode mode, {
  bool Function(StepId) stops = _defaultStops,
}) {
  final cursors = _cursorsFor(mode);
  final presses = <List<StepCursor>>[];
  var current = <StepCursor>[];
  for (var i = 0; i < cursors.length; i++) {
    current.add(cursors[i]);
    // ★末尾は 8.4.14。実行するとターン番号が変わるので必ずそこで切れる。
    if (i == cursors.length - 1 || stops(cursors[i + 1].step)) {
      presses.add(current);
      current = [];
    }
  }
  return presses;
}

// ===========================================================================
// ★ 実際に回す（本番の口を通す）
// ===========================================================================

/// ★★ §15-8 の見積りの前提を**すべて**満たす盤面 ★★
///
/// | # | 前提 | この盤面での満たし方 |
/// |---|---|---|
/// | 1 | 8.3.6 が早期終了しない | ライブカード置き場に札を置く |
/// | 2 | 8.4.12 を 1 回で選ぶ | `_noMore` が「処理は無い」を選ぶ |
/// | 3 | ★**動的停止が起きない** | ★**メンバーを置かない**（ブレード合計 0 → 8.3.11 の
///       エールが 1 枚も動かず、解決領域が空のまま = 10.6 の警告が立たない）/
///       メインデッキを十分に深くする（10.2.1 のリフレッシュが起きない） |
///
/// ★★ 3 を「起きないはず」で済ませない ★★
/// メンバーを置いた盤面では**実際に動的停止が起きる**。それは
/// 「★★ 実戦的な盤面 ★★」の群が別に測る（利用者の要望どおり静的 / 動的の両方）。
GameState _staticBoard({StepCursor? cursor}) => handcraftedBoard(
      selfZones: const {
        Zone.mainDeck: [_member, _live, _member, _live, _member, _live],
        Zone.energyDeck: [_energy, _energy],
        Zone.liveStage: [_live],
        Zone.hand: [_member],
      },
      opponentZones: const {
        Zone.mainDeck: [_member, _live, _member, _live, _member, _live],
        Zone.energyDeck: [_energy, _energy],
        Zone.liveStage: [_live],
        Zone.hand: [_member],
      },
      cursor: cursor ?? const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
    );

/// ★★ 実戦的な盤面（メンバーが居るのでエールが動く）★★
/// ★8.3.11 が解決領域へ札を置くので、そのあとの CT で 10.6 の警告が**新しく**立つ。
GameState _realisticBoard() => handcraftedBoard(
      selfZones: const {
        Zone.mainDeck: [_member, _live, _member, _live, _member, _live],
        Zone.energyDeck: [_energy, _energy],
        Zone.liveStage: [_live],
        Zone.hand: [_member],
      },
      opponentZones: const {
        Zone.mainDeck: [_member, _live, _member, _live, _member, _live],
        Zone.energyDeck: [_energy, _energy],
        Zone.liveStage: [_live],
        Zone.hand: [_member],
      },
      selfMembers: const {
        MemberAreaSlot.center: [_member],
      },
      opponentMembers: const {
        MemberAreaSlot.center: [_member],
      },
    );

GameStore _storeFor(BoardMode mode, {GameState? state, int seed = 1}) =>
    GameStore(
      initialState: state ?? _staticBoard(),
      viewerId: kSelfPlayerId,
      mode: mode,
      seed: seed,
      cards: realShapedCatalog().cards,
      rng: SeededRng(seed),
    );

/// 8.4.12 で「処理は無い」を選ぶ（§15-8 の見積りの前提 2）。
StepTransition _noMore(GameStore store) =>
    store.transitions.firstWhere((t) => t.target == StepId.s8_4_13);

/// 1 ターンぶん「次へ」を押し、**押下ごとに実行したカーソル列**を返す。
List<List<StepCursor>> _pressUntilTurnEnds(GameStore store) {
  final presses = <List<StepCursor>>[];
  final turn = store.value.state.turnNumber;
  while (store.value.state.turnNumber == turn) {
    store.advanceToStop(
      choice: store.requiresChoice ? _noMore(store) : null,
    );
    presses.add(store.value.operation!.steps.map((s) => s.cursor).toList());
    if (presses.length > 100) fail('進行が止まらない（${store.value.state.cursor}）');
  }
  return presses;
}

void main() {
  group('★★★ 押下の区切りが導出した期待値と 1 つ残らず一致する ★★★', () {
    test('★前提: 期待値そのものが空でない（比較の前提）', () {
      // ★★ 0 件 / 空リストとの比較は何も証明しない ★★
      expect(_cursorsFor(BoardMode.localVersus), hasLength(73));
      expect(_cursorsFor(BoardMode.solo), hasLength(42));
      expect(_pressesFor(BoardMode.localVersus), isNotEmpty);
      expect(_pressesFor(BoardMode.solo), isNotEmpty);
    });

    for (final mode in BoardMode.values) {
      test('★★ $mode: 1 押下で通過したカーソル列が期待値と一致する ★★', () {
        final store = _storeFor(mode);
        addTearDown(store.dispose);

        final actual = _pressUntilTurnEnds(store);
        final expected = _pressesFor(mode);

        // ★1 つでも余分に止まれば、あるいは止まり損ねれば、列が割れて落ちる。
        expect(actual, expected);
        // ★足し合わせると 73 / 42 に戻る（黙って飛ばしていない）。
        expect(actual.expand((press) => press).toList(), _cursorsFor(mode));
        expect(store.value.state.turnNumber, 2);

        // ignore: avoid_print
        print('★M-B7 押下回数の実測（$mode / ★静的停止のみ）: ${actual.length} 回'
            '（のべ ${_cursorsFor(mode).length} ステップ）');
      });
    }

    test('★★ 対照: requiresPlayerAction を 1 つ外すと押下回数が変わる ★★', () {
      // ★★ これが無いと、期待値の作り方を間違えて常に通る形になっていても
      //   気づけない（`step_engine_test.dart` の番人 5 と同じ形）★★
      final loosened = _pressesFor(
        BoardMode.localVersus,
        stops: (step) => step == StepId.s8_2_2 ? false : step.stopsAutoAdvance,
      );
      expect(loosened, isNot(_pressesFor(BoardMode.localVersus)));
      expect(loosened.length, _pressesFor(BoardMode.localVersus).length - 1);
    });

    test('★★ 陽性対照: 「1 ステップ」の口では 73 / 42 のまま ★★', () {
      // ★M-B3（D86）/ M-B4（D88）が固定した成果が、本番の口を通り続けている。
      for (final entry in const [
        (BoardMode.localVersus, 73),
        (BoardMode.solo, 42),
      ]) {
        final store = _storeFor(entry.$1);
        addTearDown(store.dispose);

        var count = 0;
        while (store.value.state.turnNumber == 1) {
          store.dispatch(AdvanceStep(
              choice: store.requiresChoice ? _noMore(store) : null));
          if (++count > 200) fail('進行が止まらない');
        }
        expect(count, entry.$2, reason: '★${entry.$1}');
      }
    });
  });

  group('★★ 押下回数（★実戦的な盤面 = 動的停止を含む）★★', () {
    // ★★ 静的だけを測って「12 回」と書くと、実際に回した人と食い違う ★★
    //   §15-8 の見積りは「動的停止が起きない」を前提にしているが、
    //   ★**メンバーが居る盤面では毎ターン必ず 1 回多く止まる。**
    //
    // ★★ 原因: 8.3.11 のエールが解決領域へ札を置くと 10.6 の警告が立つ ★★
    //   `RuleProcessor.warningsFor` は `state.resolution.isNotEmpty` だけを見る。
    //   ★**10.6.1 は「エール処理中（8.3.11）である以外のカード」と書いており、
    //     エール中の札は対象外である。**
    //   ★M-B6 までは帯に 1 行出るだけだったが、M-B7 では**停止**になる。
    //   → 新所見として記録した（`ルール整合性チェック_v1.06.md`）。
    //   ★ここでは**いまの挙動をそのまま固定する。**直すのは別の論点である。
    for (final mode in BoardMode.values) {
      test('★★ $mode: 実戦的な盤面では静的より多く止まる ★★', () {
        final store = _storeFor(mode, state: _realisticBoard());
        addTearDown(store.dispose);

        final actual = _pressUntilTurnEnds(store);
        final staticCount = _pressesFor(mode).length;

        // ignore: avoid_print
        print('★M-B7 押下回数の実測（$mode / ★動的停止あり）: ${actual.length} 回'
            '（静的のみ $staticCount 回）');

        expect(actual.length, greaterThan(staticCount),
            reason: '★動的停止が 1 回も起きないなら、この盤面の作り方が誤っている');
        // ★足し合わせれば 73 / 42 に戻る（止まる位置が増えただけで、飛んでいない）。
        expect(actual.expand((press) => press).toList(), _cursorsFor(mode));
      });
    }

    test('★★ 余分な停止は 8.3.11 のあとの新規警告（10.6）である ★★', () {
      // ★「多く止まった」だけでは理由が分からない。**どの理由でどこか**まで見る。
      final store = _storeFor(BoardMode.solo, state: _realisticBoard());
      addTearDown(store.dispose);

      final stopped = <StepCursor, List<BoardStopReasonKind>>{};
      final turn = store.value.state.turnNumber;
      while (store.value.state.turnNumber == turn) {
        store.advanceToStop(
          choice: store.requiresChoice ? _noMore(store) : null,
        );
        final operation = store.value.operation!;
        stopped[operation.steps.last.cursor] =
            operation.stops.map((s) => s.kind).toList();
      }

      final warned = stopped.entries
          .where((e) => e.value.contains(BoardStopReasonKind.newWarning))
          .toList();
      expect(warned, hasLength(1), reason: '★1 ターンに 1 回だけ（2 回目は基準集合に入る）');
      // ★止まった位置はエールより後のチェックタイミングである。
      final steps = warned.single.key.phase.steps;
      expect(steps.indexOf(warned.single.key.step),
          greaterThan(steps.indexOf(StepId.s8_3_11)));
      expect(warned.single.key.step.checkTiming, isTrue);
    });
  });

  group('★★ 番人 4: 停止ステップは盤面を触らない ★★', () {
    test('★★ 停止点から 1 歩進めても、整理以外は署名が変わらない ★★', () {
      // ★★ アプリが代行できる処理をプレイヤーに押しつけていないことの検査 ★★
      //   触るステップを停止点にすると「押したのに何も起きない」ではなく
      //   「押す前にアプリが勝手にやってしまう」状態になる。
      //   ★整理が空振りする盤面を使う（7.7.2 だけ checkTiming: true）。
      final stops =
          StepId.values.where((step) => step.requiresPlayerAction).toList();
      expect(stops, hasLength(7), reason: '★前提: 空リストと比べていない');

      for (final step in stops) {
        final phase = phaseCycle.firstWhere((p) => p.steps.contains(step));
        final store = _storeFor(
          BoardMode.localVersus,
          state: handcraftedBoard(cursor: StepCursor(phase, step)),
        );
        final before = boardSignature(store.value.state);
        store.dispatch(const AdvanceStep());
        final after = boardSignature(store.value.state);

        // ★カーソルだけが動く。★それ以外の差は無い。
        expect(
          after.split('\n').where((line) => !line.startsWith('cursor=')),
          before.split('\n').where((line) => !line.startsWith('cursor=')),
          reason: '★${step.ruleRef} が盤面を触っている',
        );
        store.dispose();
      }
    });

    test('★★ 対: 盤面を触るステップでは署名が変わる ★★', () {
      // ★これが落ちたら、上の比較は何も検知していない。
      final store = _storeFor(
        BoardMode.localVersus,
        state: handcraftedBoard(
          selfZones: const {
            Zone.mainDeck: [_member, _live],
          },
          // ★7.6.2（ドロー）はアプリが実行する。
          cursor: const StepCursor(PhaseId.firstDraw, StepId.s7_6_2),
        ),
      );
      addTearDown(store.dispose);

      final before = boardSignature(store.value.state);
      store.dispatch(const AdvanceStep());
      expect(
        boardSignature(store.value.state)
            .split('\n')
            .where((line) => !line.startsWith('cursor=')),
        isNot(before.split('\n').where((line) => !line.startsWith('cursor='))),
      );
    });
  });

  group('★★ 番人 5: 動的停止を本当に起こす（R-S2）★★', () {
    /// 7.6.2 のドローで 10.2.1 のリフレッシュを起こす盤面。
    GameState refreshBoard({required bool empty}) => handcraftedBoard(
          selfZones: {
            Zone.mainDeck: empty ? const [] : const [_member, _live],
            Zone.waitingRoom: const [_member, _live, _member],
          },
          opponentZones: const {
            Zone.mainDeck: [_member, _live],
          },
        );

    test('★★ リフレッシュが割り込んだら止まる ★★', () {
      final store = _storeFor(
        BoardMode.localVersus,
        state: refreshBoard(empty: true),
      );
      addTearDown(store.dispose);

      store.advanceToStop();

      expect(store.value.operation!.refreshCount, greaterThan(0));
      expect(store.value.state.cursor.step, StepId.s7_6_3,
          reason: '★7.6.2 を実行し終えたところで止まる');
      expect(
        store.value.operation!.stops.map((s) => s.kind),
        contains(BoardStopReasonKind.refreshed),
      );
    });

    test('★ 対: リフレッシュが起きなければ 7.7.2 まで進む', () {
      final store = _storeFor(
        BoardMode.localVersus,
        state: refreshBoard(empty: false),
      );
      addTearDown(store.dispose);

      store.advanceToStop();

      expect(store.value.operation!.refreshCount, 0);
      expect(store.value.state.cursor.step, StepId.s7_7_2);
    });

    test('★★ 新規の警告（10.6）で止まる / ★対 2 回目は止まらない ★★', () {
      // ★★ 出しっぱなしのものが停止という強い手段に化けない（§15-5）★★
      //   解決領域に札が在る限り、10.6 の警告は**毎チェックタイミング**立つ。
      //   2 回目以降も止まると、正常な状態で止まり続ける。
      final store = _storeFor(
        BoardMode.localVersus,
        state: handcraftedBoard(
          selfZones: const {
            Zone.mainDeck: [_member, _live, _member],
          },
          selfResolution: const [_live],
        ),
      );
      addTearDown(store.dispose);

      store.advanceToStop();
      expect(store.value.state.cursor.step, StepId.s7_5_1,
          reason: '★7.4.3 のチェックタイミングで初めて立つ');
      final first = store.value.operation!.stops;
      expect(first.map((s) => s.kind), contains(BoardStopReasonKind.newWarning));
      expect(
        first
            .firstWhere((s) => s.kind == BoardStopReasonKind.newWarning)
            .warnings,
        contains(RuleProcessWarningKind.invalidResolution),
      );

      // ★★ 対: 同じ警告は基準集合に入っているので、もう止まらない ★★
      store.advanceToStop();
      expect(
        store.value.operation!.stops.map((s) => s.kind),
        isNot(contains(BoardStopReasonKind.newWarning)),
      );
      expect(store.value.state.cursor.step, StepId.s7_7_2,
          reason: '★止まらずに次の R-S1 まで進む');
    });

    test('★ 対: 解決領域が空なら 1 回目から止まらない', () {
      final store = _storeFor(
        BoardMode.localVersus,
        state: handcraftedBoard(selfZones: const {
          Zone.mainDeck: [_member, _live, _member],
        }),
      );
      addTearDown(store.dispose);

      store.advanceToStop();
      expect(store.value.state.cursor.step, StepId.s7_7_2);
      expect(store.value.operation!.stops.map((s) => s.kind),
          isNot(contains(BoardStopReasonKind.newWarning)));
    });

    test('★★ ターン境界で止まる / ★対 ソロでも同じ位置で止まる ★★', () {
      // ★ソロは 8.4.13 を飛ばすが、ターン番号を変えるのは 8.4.14 なので
      //   判定は変わらない（§15-6）。「無いはず」で済ませない。
      for (final mode in BoardMode.values) {
        final store = _storeFor(mode);
        addTearDown(store.dispose);

        final presses = _pressUntilTurnEnds(store);
        expect(presses.last.last.step, StepId.s8_4_14, reason: '★$mode');
        expect(
          store.value.operation!.stops.map((s) => s.kind),
          contains(BoardStopReasonKind.turnChanged),
          reason: '★$mode',
        );
        expect(store.value.state.cursor,
            const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
      }
    });

    test('★ 止まった理由には格（条文由来 / 実装判断）が付いている', () {
      // ★混ぜると、次に問われたときに存在しない条文を探すことになる（D73 の作法）。
      expect(BoardStopReasonKind.playerAction.isFromRules, isTrue);
      expect(BoardStopReasonKind.playerDeclaration.isFromRules, isTrue);
      expect(BoardStopReasonKind.newWarning.isFromRules, isTrue);
      expect(BoardStopReasonKind.refreshed.isFromRules, isFalse);
      expect(BoardStopReasonKind.turnChanged.isFromRules, isFalse);
    });
  });

  group('★★ 番人 6: 停止点が 1 つも無い設定で無限ループにしない ★★', () {
    test('★★ 上限を超えて跨いだら StateError ★★', () {
      // ★★ 述語も上限も引数で受けているのは、これを**テストから実際に踏ませる**ため ★★
      //   `skipForward` が `isSkipped` を関数で受け、`GameStore` が
      //   `historyMaxDepth` を引数にしているのと同じ手当てである。
      final store = _storeFor(BoardMode.localVersus);
      addTearDown(store.dispose);

      expect(
        () => store.advanceToStop(stopsAt: (_) => const [], maxPhaseHops: 1),
        throwsStateError,
      );
      // ★投げたら履歴は 1 件も増えない（`_run` の doc）。
      expect(store.value.session.canUndo, isFalse);
    });

    test('★★ 既定の上限には到達できない —— 先に 8.4.12 が止める ★★', () {
      // ★★ 「番人が要らない」とは書かない。到達経路が別に在ることを固定する ★★
      //   停止点を 1 つも持たない設定にしても、8.4.12 は `choice` 無しでは
      //   進めない（`StepEngine._resolveTransition` が投げる）ので、
      //   **フェイズを 1 周する前に必ず止まる。**
      //   ★これが崩れたら（= 宣言の要る分岐が消えたら）番人が唯一の受けになる。
      final store = _storeFor(BoardMode.localVersus);
      addTearDown(store.dispose);

      expect(
        () => store.advanceToStop(stopsAt: (_) => const []),
        throwsArgumentError,
      );
      expect(store.value.session.canUndo, isFalse);
    });

    test('★ 対: 既定の判定なら投げない', () {
      final store = _storeFor(BoardMode.localVersus);
      addTearDown(store.dispose);
      store.advanceToStop();
      expect(store.value.session.history.depth, 1);
    });
  });

  group('★★ 番人 8: 1 押下 = 履歴 1 件（undo は押す前へ戻る）★★', () {
    test('★★ 10 ステップ進んでも履歴は 1 件で、1 回の undo で戻る ★★', () {
      final store = _storeFor(BoardMode.localVersus);
      addTearDown(store.dispose);

      final before = boardSignature(store.value.state);
      store.advanceToStop();

      expect(store.value.operation!.steps.length, greaterThan(1),
          reason: '★前提: 複数ステップ進んでいる');
      expect(store.value.session.history.depth, 1);

      store.undo();
      expect(boardSignature(store.value.state), before,
          reason: '★★ 押す前へ戻る ★★');
    });
  });

  group('★★ 番人 7: 画面から 2 つのボタンの役割分担が読める ★★', () {
    Future<void> pumpBoard(WidgetTester tester, GameState state) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: state,
          viewerId: kSelfPlayerId,
          mode: BoardMode.localVersus,
          seed: 1,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    testWidgets('★★ 「次へ」1 回で 7.4.1 から 7.7.2 まで進む ★★', (tester) async {
      await pumpBoard(tester, _staticBoard());

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ステップ 7.7.2'), findsOneWidget);
      expect(find.textContaining('先攻メイン 7.7'), findsOneWidget);
    });

    testWidgets('★対: 「1 ステップ」1 回では 7.4.2 に居る', (tester) async {
      await pumpBoard(tester, _staticBoard());

      await tester.tap(find.byKey(const ValueKey('advance-one-step')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ステップ 7.4.2'), findsOneWidget);
    });

    testWidgets('★ 2 つとも常に出ている（恒久 / 決定 D92-4）', (tester) async {
      await pumpBoard(tester, _staticBoard());
      expect(find.byKey(const ValueKey('advance-step')), findsOneWidget);
      expect(find.byKey(const ValueKey('advance-one-step')), findsOneWidget);
    });

    testWidgets('★★ 「次へ」を押して「1 つ戻す」で押す前に戻る ★★', (tester) async {
      await pumpBoard(tester, _staticBoard());
      final store =
          tester.widget<BoardView>(find.byType(BoardView).first).store;
      final before = boardSignature(store.value.state);

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();

      expect(boardSignature(store.value.state), before);
      expect(find.textContaining('ステップ 7.4.1'), findsOneWidget);
    });
  });
}
