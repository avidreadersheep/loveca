/// 盤面の警告（M-B3 / 盤面設計メモ §10-2 / 決定 D86）.
///
/// ★★★ 「起きる入力で出る」と「起きなければ出ない」を必ず対で置く ★★★
/// 出る側だけを見ると、**常に出す実装**でも通ってしまう（M3 の教訓 / D-10）。
///
/// ★★ 2 系統ある。混ぜない ★★
///
/// | 系統 | 出典 | 寿命 | 出る場所 |
/// |---|---|---|---|
/// | 盤面の状態から導く | 集計の除外 / 孤児 / 重複メンバー | いまそうなっている間 | 常設の帯 |
/// | 整理の結果 | 10.4・10.5 の実行 / ★10.3・10.6 の警告 | 次の整理まで | 直前の整理の帯 |
///
/// ★後者を「毎操作で消える」形にしていない。ドラッグ 1 回で 10.3 が消えると
/// **黙って落とした**のと同じになる。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_notice.dart';
import 'package:loveca_ui/src/state/board_summary.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _member = parallelMemberNormal;
const _live = drawLivePrinting;

/// ★カタログに無い刷り。集計も整理もこれを引けない。
const _ghostCardNumber = 'GHOST-bp9-999';

CardInstance _ghost(String playerId, int n) => CardInstance(
      instanceId: '$playerId:ghost:$n',
      printingId: '$_ghostCardNumber-X',
      cardNumber: _ghostCardNumber,
      ownerId: playerId,
    );

/// 解決領域（共有 / 4.14.1）にカタログに無い札を混ぜる。
GameState _withGhostInResolution(GameState state, String playerId) =>
    state.copyWith(resolution: [...state.resolution, _ghost(playerId, 1)]);

/// メンバーエリアに、上にメンバーが居ないカタログ外の札を置く。
GameState _withGhostOrphan(
  GameState state,
  String playerId,
  MemberAreaSlot slot,
) {
  final areas = [
    for (final area in state.playerOf(playerId).memberAreas)
      if (area.slot == slot)
        area.copyWith(orphans: [...area.orphans, _ghost(playerId, 2)])
      else
        area,
  ];
  return state.copyWith(players: [
    for (final player in state.players)
      if (player.playerId == playerId)
        player.copyWith(memberAreas: areas)
      else
        player,
  ]);
}

List<BoardNotice> _derived(GameState state) => derivedBoardNotices(
      state: state,
      cards: realShapedCatalog().cards,
      viewerId: kSelfPlayerId,
      labelOf: (playerId) => playerId == kSelfPlayerId ? '自分' : '相手',
    );

GameStore _storeFor(GameState state) => GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );

void main() {
  group('★★ 集計から落ちたものを見せる（CLAUDE.md §6）★★', () {
    test('解決領域にカタログ外の札があると 8.3.12 と 8.3.14 に出る', () {
      final state = _withGhostInResolution(handcraftedBoard(), kSelfPlayerId);
      final excluded = _derived(state).whereType<AggregationExcluded>().toList();

      expect(excluded.map((e) => e.ruleRef).toSet(), {'8.3.14', '8.3.12'});
      // ★8.3.12 は共有領域の話なので、プレイヤーごとに 2 回出さない。
      expect(excluded.where((e) => e.ruleRef == '8.3.12'), hasLength(1));
      expect(excluded.first.cardNumbers, [_ghostCardNumber]);
      expect(excluded.first.count, 1);
    });

    test('★相手の 8.3.14 には出ない（4.14.1 の共有領域を ownerId で絞るため）', () {
      final state = _withGhostInResolution(handcraftedBoard(), kSelfPlayerId);
      final excluded = _derived(state).whereType<AggregationExcluded>();

      expect(
        excluded.where((e) => e.ruleRef == '8.3.14').map((e) => e.scope),
        ['自分'],
      );
    });

    test('★★ 対: カタログにある札だけなら 1 件も出ない ★★', () {
      final state = handcraftedBoard(
        selfResolution: const [_live],
        selfZones: const {
          Zone.liveStage: [_live],
        },
      );
      expect(_derived(state).whereType<AggregationExcluded>(), isEmpty);
    });
  });

  group('★★ 孤児と重複メンバーは「正規の中間状態」として見せる ★★', () {
    test('孤児があるとエリア名つきで出る', () {
      final state = handcraftedBoard(selfOrphans: const {
        MemberAreaSlot.center: [_member],
      });
      final orphans = _derived(state).whereType<OrphanCardsPresent>().toList();

      expect(orphans, hasLength(1));
      expect(orphans.single.playerLabel, '自分');
      expect(orphans.single.areaLabels, ['センターエリア']);
    });

    test('★対: 孤児が無ければ出ない', () {
      expect(_derived(handcraftedBoard()).whereType<OrphanCardsPresent>(),
          isEmpty);
    });

    test('1 エリアに 2 人いると出る', () {
      final state = handcraftedBoard(selfMembers: const {
        MemberAreaSlot.leftSide: [_member, _member],
      });
      final duplicates =
          _derived(state).whereType<DuplicateMembersPresent>().toList();

      expect(duplicates, hasLength(1));
      expect(duplicates.single.areaLabels, ['左サイドエリア']);
    });

    test('★対: 1 人なら出ない', () {
      final state = handcraftedBoard(selfMembers: const {
        MemberAreaSlot.leftSide: [_member],
      });
      expect(
          _derived(state).whereType<DuplicateMembersPresent>(), isEmpty);
    });
  });

  group('★★★ 10.3 / 10.6 は自動実行せず警告に留める（D10 / D-A）★★★', () {
    /// チェックタイミングのあるステップ（7.4.3）。ここで整理が回る（9.5.3.1）。
    const atCheckTiming = StepCursor(PhaseId.firstActive, StepId.s7_4_3);

    test('★10.3: 成功ライブが勝利条件に達すると出る', () {
      expect(RuleConfig.standard.winCondition, 3, reason: '★前提: 1.2.1.1 の枚数');

      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.successLive: [_live, _live, _live],
        },
        cursor: atCheckTiming,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.warnings,
          contains(RuleProcessWarningKind.victory));
    });

    test('★対: 1 枚足りなければ出ない', () {
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.successLive: [_live, _live],
        },
        cursor: atCheckTiming,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.warnings,
          isNot(contains(RuleProcessWarningKind.victory)));
    });

    test('★10.6: 解決領域にカードがあると出る', () {
      final store = _storeFor(handcraftedBoard(
        selfResolution: const [_live],
        cursor: atCheckTiming,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.warnings,
          contains(RuleProcessWarningKind.invalidResolution));
    });

    test('★対: 解決領域が空なら出ない', () {
      final store = _storeFor(handcraftedBoard(cursor: atCheckTiming));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.warnings, isEmpty);
    });

    test('★★ 別の操作をしても消えない（黙って落とさない）★★', () {
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.successLive: [_live, _live, _live],
          Zone.hand: [_member],
        },
        cursor: atCheckTiming,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());
      expect(store.value.tidy!.warnings, isNotEmpty);

      // ★整理を伴わない操作（手札 → 控え室）。
      final card = store.value.state.playerOf(kSelfPlayerId).hand.single;
      store.dispatch(MoveCard(
        instanceId: card.instanceId,
        fromPlayerId: kSelfPlayerId,
        from: Zone.hand,
        toPlayerId: kSelfPlayerId,
        to: Zone.waitingRoom,
      ));

      expect(store.value.tidy!.warnings,
          contains(RuleProcessWarningKind.victory),
          reason: '★ドラッグ 1 回で勝利処理の警告が消えてはいけない');
    });
  });

  group('★ 整理が実行したこと / 引けなかったことも見せる', () {
    test('10.5.3 で孤児が片付いたことが出る', () {
      final store = _storeFor(handcraftedBoard(
        selfOrphans: const {
          MemberAreaSlot.center: [_member],
        },
        cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_3),
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.applied,
          contains(RuleProcessKind.orphanMember));
      // ★対: 実際に盤面が動いている（表示だけではない）。
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom,
          hasLength(1));
    });

    test('★カタログを引けず動かせなかった枚数が出る', () {
      final store = _storeFor(_withGhostOrphan(
        handcraftedBoard(
          cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        ),
        kSelfPlayerId,
        MemberAreaSlot.center,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidy!.excludedCount, 1);
      expect(store.value.tidy!.unknownCardNumbers, [_ghostCardNumber]);
    });
  });

  group('★ 画面に出る（実物の経路）', () {
    Future<void> pumpBoard(WidgetTester tester, GameState state) async {
      tester.view.physicalSize = const Size(1800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(initialState: state, viewerId: kSelfPlayerId, seed: 1),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    testWidgets('孤児 / 重複 / 集計の除外が帯に出る', (tester) async {
      await pumpBoard(
        tester,
        _withGhostInResolution(
          handcraftedBoard(
            selfOrphans: const {
              MemberAreaSlot.center: [_member],
            },
            selfMembers: const {
              MemberAreaSlot.leftSide: [_member, _member],
            },
          ),
          kSelfPlayerId,
        ),
      );

      expect(find.textContaining('上にメンバーが居なくなったカード'), findsOneWidget);
      expect(find.textContaining('不具合ではありません'), findsWidgets);
      expect(find.textContaining('メンバーが 2 人以上います'), findsOneWidget);
      expect(find.textContaining('集計から 1 枚を外しています'), findsWidgets);
      expect(find.textContaining(_ghostCardNumber), findsWidgets);
    });

    testWidgets('★対: 何も起きていなければ帯に 1 行も出ない', (tester) async {
      await pumpBoard(tester, handcraftedBoard());

      expect(find.textContaining('上にメンバーが居なくなったカード'), findsNothing);
      expect(find.textContaining('メンバーが 2 人以上います'), findsNothing);
      expect(find.textContaining('集計から'), findsNothing);
      // ★対の対: 盤面そのものは出ている（描かれていないから通った、ではない）。
      expect(find.byKey(const ValueKey('progress-bar')), findsOneWidget);
    });

    testWidgets('★★ 10.3 / 10.6 が「アプリは実行しません」として出る ★★',
        (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.successLive: [_live, _live, _live],
          },
          selfResolution: const [_live],
          cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        ),
      );

      // ★整理はチェックタイミングで走る。進めるまでは出ない。
      expect(find.textContaining('アプリは実行しません'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      expect(find.textContaining('アプリは実行しません'), findsOneWidget);
      expect(find.textContaining('勝利処理 10.3'), findsOneWidget);
      expect(find.textContaining('不正解決領域処理 10.6'), findsOneWidget);
      expect(find.textContaining('直前の整理'), findsOneWidget);
    });
  });
}
