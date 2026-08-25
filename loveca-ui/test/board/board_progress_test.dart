/// 進行（M-B3 / 決定 D86 / 盤面設計メモ §11）.
///
/// ★★★ まず「手法そのものが成立しているか」を疑う ★★★
/// M-B2 で、溢れの二分探索が **`RenderObject` ごとに 1 回しか報告されない**ことに
/// 気づかず下限のすぐ上に収束していた（決定 D83 / `board_min_width_test.dart`）。
/// 同じ手法を使っていた U8 の記録値まで誤っていた。
///
/// ここで確かめたいのは「12 フェイズ・のべ 73 ステップが端から端まで通る」である。
/// **素朴に 73 回進めて最後にターン番号が 2 になったことを見る形では足りない** ——
/// 8.3.6 が早期終了すると 8.3.7〜8.3.17 を**正当に飛ばす**ので、
/// 飛んでもターン番号は 2 になる。「通った」と「飛んだ」が区別できない。
///
/// → **通ったカーソルを 1 つずつ記録し、`phaseCycle` と `PhaseSteps` から導いた
///   期待値と丸ごと突き合わせる。** 1 つでも飛べば列が食い違って落ちる。
///
/// ★★ そのうえで、比較が本当に「飛び」を検知するかを対照実験で見る ★★
/// 同じ比較を**わざと飛ばした盤面**に掛け、**落ちる側になる**ことを確かめる。
/// これをやらないと、期待値の作り方を間違えて常に通る形になっていても気づけない。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _live = drawLivePrinting;
const _member = parallelMemberNormal; // ブレード 2
const _energy = energyPrinting;

/// ★★ 期待値を列挙しない ★★
/// `phaseCycle`（7.1.2 / 7.3.3 / 8.1.2）と `PhaseSteps`（`step.dart`）から導く。
/// 手で 73 行書くと、実装を直したときに**期待値のほうが古くなる**。
final _allCursors = <StepCursor>[
  for (final phase in phaseCycle)
    for (final step in phase.steps) StepCursor(phase, step),
];

/// 1 ターンぶんの盤面。★両者のライブカード置き場にライブの札を置く。
///
/// ★これが無いと 8.3.6 が早期終了して 8.3.7〜8.3.17 を通らない。
GameState _oneTurnBoard() => handcraftedBoard(
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

GameStore _storeFor(GameState state, {int seed = 1}) => GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      seed: seed,
      cards: realShapedCatalog().cards,
      rng: SeededRng(seed),
    );

/// 8.4.12 で「処理は無い」を選ぶ。★文言も遷移先も遷移表から取る。
StepTransition _noMore(GameStore store) =>
    store.transitions.firstWhere((t) => t.target == StepId.s8_4_13);

/// 1 ターン回して、**実行したステップのカーソルを順に**返す。
List<StepCursor> _walkOneTurn(GameStore store) {
  final executed = <StepCursor>[];
  while (store.value.state.turnNumber == 1) {
    executed.add(store.value.state.cursor);
    store.dispatch(
      AdvanceStep(choice: store.requiresChoice ? _noMore(store) : null),
    );
    if (executed.length > 200) {
      fail('進行が止まらない（${store.value.state.cursor}）');
    }
  }
  return executed;
}

void main() {
  group('★★★ 12 フェイズ・のべ 73 ステップが端から端まで通る ★★★', () {
    test('★期待値そのものが空でないこと（比較の前提）', () {
      // ★★ 0 件 / 空リストとの比較は何も証明しない ★★
      expect(_allCursors, hasLength(73),
          reason: '★`history.dart` と CLAUDE.md が「のべ 73 ステップ」と書いている');
      expect(phaseCycle, hasLength(12), reason: '★リーフフェイズは 12 個（7.1.2）');
      // ★終盤の 1 つを名指しで確かめる（導出が途中で切れていないこと）。
      expect(
        _allCursors,
        contains(const StepCursor(PhaseId.secondPerformance, StepId.s8_3_17)),
      );
      expect(_allCursors.last,
          const StepCursor(PhaseId.liveJudgement, StepId.s8_4_14));
    });

    test('★★ 通ったステップ列が期待値と 1 つ残らず一致する ★★', () {
      final store = _storeFor(_oneTurnBoard());
      addTearDown(store.dispose);

      final executed = _walkOneTurn(store);

      // ★1 つでも飛べば列が食い違って落ちる。
      expect(executed, _allCursors);
      expect(store.value.state.turnNumber, 2, reason: '★8.4.14 でターンが進む');
      expect(store.value.state.cursor,
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
          reason: '★次のターンの先頭へ戻る');
    });

    test('★★★ 対照実験: 同じ比較が「飛んだ」ときに落ちる側になる ★★★', () {
      // ★★ ライブカード置き場を空にすると 8.3.6 が早期終了する ★★
      //   通らないステップができる盤面を**わざと**作り、
      //   上のテストと同じ比較が**通らない**ことを見る。
      //   これが通ってしまうなら、上の比較は何も検知していない。
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.mainDeck: [_member, _member, _member],
        },
        opponentZones: const {
          Zone.mainDeck: [_member, _member, _member],
        },
      ));
      addTearDown(store.dispose);

      final executed = _walkOneTurn(store);

      expect(executed, isNot(_allCursors), reason: '★比較が「飛び」を検知している');

      // 8.3.7〜8.3.17 = 11 ステップ。パフォーマンスフェイズは 2 回ある。
      expect(executed, hasLength(73 - 11 * 2));
      expect(
        executed.map((c) => c.step),
        isNot(contains(StepId.s8_3_17)),
        reason: '★8.3.17 へジャンプさせない（8.3.17 の CT が余分に走る）',
      );
      // ★対: ライブカードがあれば 8.3.17 を通る（上のテストの `executed` に含まれる）。
      expect(_allCursors.map((c) => c.step), contains(StepId.s8_3_17));
    });
  });

  group('★ 揃えてはいけない 2 つ（7.4 と 7.7）が通しでも崩れていない', () {
    // ★★ どちらも `loveca_core` の性質だが、UI が独自に順序を持ったときに
    //   最初に壊れる場所なので、通しの列に対しても名指しで見る ★★
    test('★7.4 だけ誘発（7.4.2）より前にアクティブ化（7.4.1）が来る', () {
      final store = _storeFor(_oneTurnBoard());
      addTearDown(store.dispose);

      final executed = _walkOneTurn(store);
      final active = executed.indexOf(
          const StepCursor(PhaseId.firstActive, StepId.s7_4_1));
      final trigger = executed.indexOf(
          const StepCursor(PhaseId.firstActive, StepId.s7_4_2));

      expect(active, isNonNegative);
      expect(active, lessThan(trigger));
      // ★対: 7.5 / 7.6 / 7.7 は誘発が先頭（同じ形に揃えると 7.4 で順序が狂う）。
      expect(executed.indexOf(const StepCursor(PhaseId.firstEnergy, StepId.s7_5_1)),
          lessThan(executed
              .indexOf(const StepCursor(PhaseId.firstEnergy, StepId.s7_5_2))));
    });

    test('★★ 7.7.3 では整理が走らない（9.5.4.3 で閉じる）★★', () {
      // ★7.4.3 / 7.5.3 / 7.6.3 と非対称。★ここに CT を足すと画面にも
      //   「整理しました」が出てしまうので、UI 側からも見ておく。
      final store = _storeFor(handcraftedBoard(
        cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_3),
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());
      expect(store.value.tidy, isNull, reason: '★7.7.3 に終了時チェックタイミングは無い');
    });

    test('★対: 7.6.3 では整理が走る', () {
      final store = _storeFor(handcraftedBoard(
        cursor: const StepCursor(PhaseId.firstDraw, StepId.s7_6_3),
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());
      expect(store.value.tidy, isNotNull);
      expect(store.value.tidy!.cursor.step, StepId.s7_6_3);
    });
  });

  group('★ 8.3.6 の早期終了（automatic / 盤面の観測のみ）', () {
    test('空なら選ばせずフェイズが終わり、どちらへ行ったかが読める', () {
      final store = _storeFor(handcraftedBoard(
        cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_6),
      ));
      addTearDown(store.dispose);

      // ★8.3.6 は automatic なので宣言が要らない。
      expect(store.requiresChoice, isFalse);
      store.dispatch(const AdvanceStep());

      expect(store.value.state.cursor.phase, PhaseId.secondPerformance,
          reason: '★フェイズ終了 → 次のフェイズの先頭へ');
      expect(store.value.operation!.taken!.endsPhase, isTrue);
      expect(store.value.operation!.taken!.label, contains('空'));
    });

    test('★対: ライブカードがあれば 8.3.7 へ進む', () {
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.liveStage: [_live],
        },
        cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_6),
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.state.cursor,
          const StepCursor(PhaseId.firstPerformance, StepId.s8_3_7));
      expect(store.value.operation!.taken!.endsPhase, isFalse);
    });
  });

  group('★★ 8.4.12 はプレイヤーが宣言する（playerDeclared / D-A）★★', () {
    GameStore atLoopPoint() => _storeFor(handcraftedBoard(
          cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_12),
        ));

    test('宣言が要ると答え、後続候補が 2 つある', () {
      final store = atLoopPoint()..addListener(() {});
      addTearDown(store.dispose);

      expect(store.requiresChoice, isTrue);
      expect(store.transitions, hasLength(2));
      // ★文言は遷移表が持つ。UI にもテストにも書かない。
      expect(store.transitions.map((t) => t.label).toSet(), hasLength(2));
    });

    test('★choice を渡さないと投げる（＝アプリが判定しない）', () {
      final store = atLoopPoint();
      addTearDown(store.dispose);

      expect(() => store.dispatch(const AdvanceStep()), throwsArgumentError);
    });

    test('★★ ループを 2 周できる ★★', () {
      final store = atLoopPoint();
      addTearDown(store.dispose);

      final loop =
          store.transitions.firstWhere((t) => t.target == StepId.s8_4_9);

      for (var round = 1; round <= 2; round++) {
        store.dispatch(AdvanceStep(choice: loop));
        expect(store.value.state.cursor,
            const StepCursor(PhaseId.liveJudgement, StepId.s8_4_9),
            reason: '★$round 周目');
        // 8.4.9 → 8.4.10 → 8.4.11 → 8.4.12 まで戻す
        for (var i = 0; i < 3; i++) {
          store.dispatch(const AdvanceStep());
        }
        expect(store.value.state.cursor.step, StepId.s8_4_12);
      }

      // ★抜けられること（無限ループでない）。
      store.dispatch(AdvanceStep(choice: _noMore(store)));
      expect(store.value.state.cursor.step, StepId.s8_4_13);
    });

    test('★★ 2 周目の 8.4.9 の前任は 1 周目の 8.4.12（履歴スタック）★★', () {
      // ★★ 静的グラフの逆辺では決まらない ★★
      //   `stepGraph` 上で 8.4.9 の前任は 8.4.8 と 8.4.12 の 2 つある。
      //   どちらから来たかは**実際に通った履歴**にしかない（`history.dart`）。
      final store = _storeFor(handcraftedBoard(
        cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_8),
      ));
      addTearDown(store.dispose);

      // 8.4.8 → 8.4.9（1 周目）
      store.dispatch(const AdvanceStep());
      expect(store.value.state.cursor.step, StepId.s8_4_9);
      expect(store.value.session.history.last!.cursor,
          const StepCursor(PhaseId.liveJudgement, StepId.s8_4_8),
          reason: '★1 周目の前任は 8.4.8');

      // 8.4.9 → 8.4.10 → 8.4.11 → 8.4.12
      for (var i = 0; i < 3; i++) {
        store.dispatch(const AdvanceStep());
      }
      // 8.4.12 →（ループ）→ 8.4.9（2 周目）
      store.dispatch(AdvanceStep(
        choice: store.transitions.firstWhere((t) => t.target == StepId.s8_4_9),
      ));

      expect(store.value.state.cursor.step, StepId.s8_4_9);
      expect(store.value.session.history.last!.cursor,
          const StepCursor(PhaseId.liveJudgement, StepId.s8_4_12),
          reason: '★★2 周目の前任は 8.4.12（8.4.8 ではない）★★');
    });
  });

  group('★★ 視点と手番を混ぜない（決定 D75）★★', () {
    test('視点を切り替えても AdvanceStep の対象は手番プレイヤーのまま', () {
      // 7.5.2 は「手番プレイヤーは、自身のエネルギーデッキの…」。
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.energyDeck: [_energy, _energy],
        },
        opponentZones: const {
          Zone.energyDeck: [_energy, _energy],
        },
        // 先攻エネルギーフェイズ = 手番は先攻（= 自分）。
        cursor: const StepCursor(PhaseId.firstEnergy, StepId.s7_5_2),
      ));
      addTearDown(store.dispose);

      // ★視点だけ相手へ切り替える。
      store.setViewer(kOpponentPlayerId);
      store.dispatch(const AdvanceStep());

      final state = store.value.state;
      expect(state.playerOf(kSelfPlayerId).energyField, hasLength(1),
          reason: '★手番（先攻＝自分）のエネルギーが出た');
      expect(state.playerOf(kOpponentPlayerId).energyField, isEmpty,
          reason: '★視点のプレイヤーではない');
    });
  });

  group('★★ エール途中のリフレッシュ割り込み（10.2.1）★★', () {
    /// ブレード 5（`trioMemberPrinting`）/ メインデッキ 2 / 控え室 4。
    GameState yellBoard({required int mainDeck, required int waitingRoom}) =>
        handcraftedBoard(
          selfZones: {
            Zone.mainDeck: [for (var i = 0; i < mainDeck; i++) _member],
            Zone.waitingRoom: [for (var i = 0; i < waitingRoom; i++) _member],
          },
          selfMembers: const {
            MemberAreaSlot.center: [trioMemberPrinting],
          },
          cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_11),
        );

    test('デッキが尽きたら割り込んで続行する', () {
      final store = _storeFor(yellBoard(mainDeck: 2, waitingRoom: 4));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.operation!.refreshCount, 1);
      expect(store.value.state.resolution, hasLength(5),
          reason: '★8.3.10 の合計ブレード 5 枚ぶんを最後まで移す');
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom, isEmpty,
          reason: '★10.2.3 で控え室がメインデッキへ移る');
    });

    test('★対: 足りていれば割り込まない', () {
      final store = _storeFor(yellBoard(mainDeck: 6, waitingRoom: 4));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.operation!.refreshCount, 0);
      expect(store.value.state.resolution, hasLength(5));
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom, hasLength(4));
    });
  });

  group('★ 画面から進む（実物の経路）', () {
    Future<void> pumpBoard(WidgetTester tester, GameState state) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(initialState: state, viewerId: kSelfPlayerId, seed: 1),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    testWidgets('「次へ」でステップが進み、進行バーが変わる', (tester) async {
      await pumpBoard(tester, _oneTurnBoard());

      expect(find.textContaining('ステップ 7.4.1'), findsOneWidget);
      expect(find.textContaining('先攻アクティブ 7.4'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ステップ 7.4.2'), findsOneWidget);
      expect(find.textContaining('直前: 7.4.1 → 7.4.2'), findsOneWidget);
    });

    testWidgets('★★ 8.4.12 では「次へ」が消えて 2 択になる ★★', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_12),
        ),
      );

      expect(find.byKey(const ValueKey('advance-step')), findsNothing,
          reason: '★アプリが判定しない（D-A）ので勝手に進める口を出さない');
      expect(find.byKey(const ValueKey('advance-choice')), findsOneWidget);
      // ★文言は遷移表から出ている。
      expect(find.text('まだ処理がある'), findsOneWidget);
      expect(find.text('処理は無い'), findsOneWidget);

      await tester.tap(find.text('まだ処理がある'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ステップ 8.4.9'), findsOneWidget);
    });

    testWidgets('★対: 分岐でないステップでは 2 択が出ない', (tester) async {
      await pumpBoard(tester, _oneTurnBoard());

      expect(find.byKey(const ValueKey('advance-choice')), findsNothing);
      expect(find.byKey(const ValueKey('advance-step')), findsOneWidget);
    });

    testWidgets('★8.3.6 の早期終了が画面から読める', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          cursor: const StepCursor(PhaseId.firstPerformance, StepId.s8_3_6),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      // ★「ライブカード置き場が空」は集計の帯（8.4.2 が null の理由）にも出る。
      //   進行の行に絞って見る。
      final line = find.descendant(
        of: find.byKey(const ValueKey('last-operation')),
        matching: find.textContaining('8.3.6 → フェイズ終了'),
      );
      expect(line, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('last-operation')),
          matching: find.textContaining('ライブカード置き場が空'),
        ),
        findsOneWidget,
      );
    });
  });
}
