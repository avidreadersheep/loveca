/// 盤面のモード（M-B4 / 決定 D88 / 盤面設計メモ §14）.
///
/// ★★ ソロは「相手側を空にする」ではなく「相手側が存在しない」★★
/// 空にすると、0 枚の手札・0 枚のデッキが並んだ**幽霊の盤面**になる。
/// 見た目が似ているので、**出ない側だけを見ると区別がつかない** ——
/// だから **対（ローカル対戦では出る）を必ず一緒に置く**（D-10）。
///
/// ★★ 数（ソロ 42 / ローカル対戦 73）はここに書かない ★★
/// 導出と番人 6 つは `loveca-core/test/step_engine_test.dart` が持つ。
/// 同じ数を 2 箇所に書けば必ず食い違う（`ルール整合性チェック_v1.06.md` D-15）。
/// ここが見るのは **UI の経路がモードを core まで通していること**である ——
/// 「後攻フェイズと相手を要求するステップを 1 つも通らない」を
/// `turnPlayerRole` / `requiresOpponent` から**導いて**確かめる。
library;

import 'package:flutter/material.dart' hide Card;
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

const _live = drawLivePrinting;
const _member = parallelMemberNormal;
const _energy = energyPrinting;

/// 両者に札のある盤面。★ソロでも相手側は `GameState` に存在する（1.1.1）。
GameState _board() => handcraftedBoard(
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

GameStore _storeFor(BoardMode mode, {GameState? state}) => GameStore(
      initialState: state ?? _board(),
      viewerId: kSelfPlayerId,
      mode: mode,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );

Future<void> _pump(
  WidgetTester tester,
  BoardMode mode, {
  GameState? state,
  List<BoardNotice> notices = const [],
}) async {
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(
      initialState: state ?? _board(),
      viewerId: kSelfPlayerId,
      mode: mode,
      seed: 1,
      notices: notices,
    ),
    decks: FakeDeckRepository(),
    catalog: realShapedCatalog(),
  );
}

/// 1 ターン回して、通ったカーソルを返す。
List<StepCursor> _walkOneTurn(GameStore store) {
  final visited = <StepCursor>[];
  while (store.value.state.turnNumber == 1) {
    visited.add(store.value.state.cursor);
    store.dispatch(AdvanceStep(
      choice: store.requiresChoice
          ? store.transitions.firstWhere((t) => t.target == StepId.s8_4_13)
          : null,
    ));
    if (visited.length > 200) fail('進行が止まらない（${store.value.state.cursor}）');
  }
  return visited;
}

void main() {
  group('★★ ソロでは相手側の置き場が 1 つも出ない（★対つき）★★', () {
    /// 相手側にしか無いもの。★キーで名指しする。
    const opponentOnly = <String>[
      'pile-main-$kOpponentPlayerId',
      'pile-energy-$kOpponentPlayerId',
      'draw-energy-$kOpponentPlayerId',
      'zone-liveStage-$kOpponentPlayerId',
      'zone-successLive-$kOpponentPlayerId',
      'zone-energyField-$kOpponentPlayerId',
      'zone-waitingRoom-$kOpponentPlayerId',
      'zone-exile-$kOpponentPlayerId',
      'hand-$kOpponentPlayerId',
      'free-area-$kOpponentPlayerId',
      'summary-$kOpponentPlayerId',
    ];

    testWidgets('ソロ: 1 つも出ない', (tester) async {
      await _pump(tester, BoardMode.solo);

      for (final key in opponentOnly) {
        expect(find.byKey(ValueKey(key)), findsNothing, reason: '★$key');
      }
      for (final slot in MemberAreaSlot.values) {
        expect(
          find.byKey(ValueKey('member-$kOpponentPlayerId-${slot.name}')),
          findsNothing,
        );
      }
      // ★視点切替も出さない（切替先が無い）。
      expect(find.byKey(const ValueKey('swap-viewer')), findsNothing);
      // ★解決領域は 4.14 の箱として残るが、「相手のカード」の列は出ない。
      expect(find.byKey(const ValueKey('resolution-shared')), findsOneWidget);
      expect(find.textContaining('相手のカード'), findsNothing);
    });

    testWidgets('★対: ローカル対戦では全部出る', (tester) async {
      // ★★ これが無いと「キーを間違えていて常に findsNothing」でも通る ★★
      await _pump(tester, BoardMode.localVersus);

      for (final key in opponentOnly) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '★$key');
      }
      for (final slot in MemberAreaSlot.values) {
        expect(
          find.byKey(ValueKey('member-$kOpponentPlayerId-${slot.name}')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const ValueKey('swap-viewer')), findsOneWidget);
      expect(find.textContaining('相手のカード'), findsOneWidget);
    });

    testWidgets('★対: ソロでも自分側は全部出る（消しすぎていない）', (tester) async {
      await _pump(tester, BoardMode.solo);

      for (final key in <String>[
        'pile-main-$kSelfPlayerId',
        'pile-energy-$kSelfPlayerId',
        'draw-energy-$kSelfPlayerId',
        'zone-liveStage-$kSelfPlayerId',
        'zone-successLive-$kSelfPlayerId',
        'zone-energyField-$kSelfPlayerId',
        'zone-waitingRoom-$kSelfPlayerId',
        'zone-exile-$kSelfPlayerId',
        'hand-$kSelfPlayerId',
        'free-area-$kSelfPlayerId',
        'summary-$kSelfPlayerId',
        // ★8.3.12 は解決領域の共有集計。プレイヤーの数と関係なく出る。
        'summary-shared',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '★$key');
      }
      for (final slot in MemberAreaSlot.values) {
        expect(
          find.byKey(ValueKey('member-$kSelfPlayerId-${slot.name}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('★ モードが AppBar から読める', (tester) async {
      await _pump(tester, BoardMode.solo);
      expect(find.text('ソロ'), findsOneWidget);
      expect(find.text('ローカル対戦'), findsNothing);
    });
  });

  group('★★ ソロでは相手の注記が出ない（幽霊の 6.1 違反にしない）★★', () {
    testWidgets('相手の孤児カードの注記が出ない', (tester) async {
      final state = handcraftedBoard(
        opponentOrphans: const {
          MemberAreaSlot.center: [_energy],
        },
      );
      await _pump(tester, BoardMode.solo, state: state);

      expect(find.textContaining('相手の'), findsNothing);
    });

    testWidgets('★対: ローカル対戦では出る', (tester) async {
      final state = handcraftedBoard(
        opponentOrphans: const {
          MemberAreaSlot.center: [_energy],
        },
      );
      await _pump(tester, BoardMode.localVersus, state: state);

      expect(find.textContaining('相手のセンターエリア'), findsOneWidget);
    });
  });

  group('★★ ソロでは相手を要求する手順を通らない（決定 D88 / §14-4）★★', () {
    test('★後攻フェイズも requiresOpponent のステップも 1 つも通らない', () {
      final store = _storeFor(BoardMode.solo);
      addTearDown(store.dispose);

      final visited = _walkOneTurn(store);

      // ★★ 期待値を `turnPlayerRole` / `requiresOpponent` から導く ★★
      expect(
        visited.where((c) => c.phase.turnPlayerRole == PhaseRole.second),
        isEmpty,
      );
      expect(visited.where((c) => c.step.requiresOpponent), isEmpty);
      // ★前提: 空リストを検査していない。
      expect(visited, isNotEmpty);
      expect(store.value.state.turnNumber, 2, reason: '★8.4.14 でターンが進む');
    });

    test('★対: ローカル対戦では両方を通る', () {
      // ★これが通らなければ、上の「1 つも無い」は何も検知していない。
      final store = _storeFor(BoardMode.localVersus);
      addTearDown(store.dispose);

      final visited = _walkOneTurn(store);

      expect(
        visited.where((c) => c.phase.turnPlayerRole == PhaseRole.second),
        isNotEmpty,
      );
      expect(visited.where((c) => c.step.requiresOpponent), isNotEmpty);
    });

    test('★★ 8.4.7 は通る —— 手動判定の着地点（D10 / D18）★★', () {
      final store = _storeFor(BoardMode.solo);
      addTearDown(store.dispose);

      expect(
        _walkOneTurn(store),
        contains(const StepCursor(PhaseId.liveJudgement, StepId.s8_4_7)),
      );
    });

    test('★ 飛ばしたカーソルが黙って捨てられていない', () {
      final store = _storeFor(BoardMode.solo);
      addTearDown(store.dispose);

      final skipped = <StepCursor>[];
      while (store.value.state.turnNumber == 1) {
        store.dispatch(AdvanceStep(
          choice: store.requiresChoice
              ? store.transitions.firstWhere((t) => t.target == StepId.s8_4_13)
              : null,
        ));
        skipped.addAll(store.value.operation!.skipped);
      }

      expect(skipped, isNotEmpty);
      expect(
        skipped.every((c) =>
            c.phase.turnPlayerRole == PhaseRole.second ||
            c.step.requiresOpponent),
        isTrue,
        reason: '★飛ばしてよいものだけを飛ばしている',
      );
    });
  });

  group('★★ 飛ばしたことが画面から読める（決定 D88 / §14-3）★★', () {
    testWidgets('ソロ: 後攻フェイズを跨いだ「次へ」で行が出る', (tester) async {
      // 先攻メインの終端（7.7.3）から進むと、後攻通常フェイズ 4 つを跨ぐ。
      await _pump(
        tester,
        BoardMode.solo,
        state: handcraftedBoard(
          cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_3),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('skipped-steps'));
      expect(line, findsOneWidget);
      // ★フェイズ単位でまとめて出る。条番号のまま（`StepId` の enum 名は出さない）。
      expect(
        find.descendant(of: line, matching: find.textContaining('後攻アクティブ 7.4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: line, matching: find.textContaining('後攻メイン 7.7')),
        findsOneWidget,
      );
      // ★理由を添える（条文が定める分岐と混ぜて読ませない）。
      expect(
        find.descendant(of: line, matching: find.textContaining('相手が居ないため')),
        findsOneWidget,
      );
    });

    testWidgets('★対: ローカル対戦では行が出ない', (tester) async {
      await _pump(
        tester,
        BoardMode.localVersus,
        state: handcraftedBoard(
          cursor: const StepCursor(PhaseId.firstMain, StepId.s7_7_3),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('skipped-steps')), findsNothing);
    });
  });

  group('★★ 10.3 の警告にソロの但し書きが付く（決定 D88 / §14-4）★★', () {
    /// 成功ライブが勝利条件に達した盤面。★10.3.1 の検出そのものはモードに依らない。
    GameState wonBoard() => handcraftedBoard(
          selfZones: const {
            Zone.successLive: [_live, _live, _live],
          },
          cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        );

    Future<void> tidyOnce(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();
    }

    testWidgets('ソロ: 1.2.1.1 の比較相手が居ないことを添える', (tester) async {
      await _pump(tester, BoardMode.solo, state: wonBoard());
      await tidyOnce(tester);

      expect(find.textContaining('勝利処理 10.3'), findsOneWidget);
      expect(find.textContaining('1.2.1.1 の比較相手が居ない'), findsOneWidget);
    });

    testWidgets('★対: ローカル対戦では添えない', (tester) async {
      await _pump(tester, BoardMode.localVersus, state: wonBoard());
      await tidyOnce(tester);

      // ★検出そのものは同じように出る（但し書きだけが違う）。
      expect(find.textContaining('勝利処理 10.3'), findsOneWidget);
      expect(find.textContaining('1.2.1.1 の比較相手が居ない'), findsNothing);
    });
  });
}
