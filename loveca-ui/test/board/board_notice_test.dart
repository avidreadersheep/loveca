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
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/board_notice.dart';
import 'package:loveca_ui/src/state/board_summary.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _member = parallelMemberNormal;
const _live = drawLivePrinting;

/// ★描くプレイヤーを**受け取る**形になった（決定 D88 / §14-5）。
/// 既定は視点側 → 相手側の順（`BoardView.drawnPlayers` と同じ並び）。
List<BoardNotice> _derived(GameState state, {List<String>? playerIds}) =>
    derivedBoardNotices(
      state: state,
      cards: realShapedCatalog().cards,
      players: [
        for (final id in playerIds ?? const [kSelfPlayerId, kOpponentPlayerId])
          state.playerOf(id),
      ],
      labelOf: (playerId) => playerId == kSelfPlayerId ? '自分' : '相手',
    );

GameStore _storeFor(GameState state) => GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      mode: BoardMode.localVersus,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );

void main() {
  group('★★ 集計から落ちたものを見せる（CLAUDE.md §6）★★', () {
    test('解決領域にカタログ外の札があると 8.3.12 と 8.3.14 に出る', () {
      final state = withGhostInResolution(handcraftedBoard(), kSelfPlayerId);
      final excluded = _derived(state).whereType<AggregationExcluded>().toList();

      expect(excluded.map((e) => e.ruleRef).toSet(), {'8.3.14', '8.3.12'});
      // ★8.3.12 は共有領域の話なので、プレイヤーごとに 2 回出さない。
      expect(excluded.where((e) => e.ruleRef == '8.3.12'), hasLength(1));
      expect(excluded.first.cardNumbers, [ghostCardNumber]);
      expect(excluded.first.count, 1);
    });

    test('★相手の 8.3.14 には出ない（4.14.1 の共有領域を ownerId で絞るため）', () {
      final state = withGhostInResolution(handcraftedBoard(), kSelfPlayerId);
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

      expect(store.value.tidies.single.warnings,
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

      expect(store.value.tidies.single.warnings,
          isNot(contains(RuleProcessWarningKind.victory)));
    });

    test('★10.6: 解決領域にカードがあると出る', () {
      final store = _storeFor(handcraftedBoard(
        selfResolution: const [_live],
        cursor: atCheckTiming,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidies.single.warnings,
          contains(RuleProcessWarningKind.invalidResolution));
    });

    test('★対: 解決領域が空なら出ない', () {
      final store = _storeFor(handcraftedBoard(cursor: atCheckTiming));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(store.value.tidies.single.warnings, isEmpty);
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
      expect(store.value.tidies.single.warnings, isNotEmpty);

      // ★整理を伴わない操作（手札 → 控え室）。
      final card = store.value.state.playerOf(kSelfPlayerId).hand.single;
      store.dispatch(MoveCard(
        instanceId: card.instanceId,
        fromPlayerId: kSelfPlayerId,
        from: Zone.hand,
        toPlayerId: kSelfPlayerId,
        to: Zone.waitingRoom,
      ));

      expect(store.value.tidies.single.warnings,
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

      expect(store.value.tidies.single.applied,
          contains(RuleProcessKind.orphanMember));
      // ★対: 実際に盤面が動いている（表示だけではない）。
      expect(store.value.state.playerOf(kSelfPlayerId).waitingRoom,
          hasLength(1));
    });

    test('★カタログを引けず動かせなかった枚数が出る', () {
      final store = _storeFor(withGhostOrphan(
        handcraftedBoard(
          cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        ),
        kSelfPlayerId,
        MemberAreaSlot.center,
      ));
      addTearDown(store.dispose);

      store.dispatch(const AdvanceStep());

      expect(
          store.value.tidies.single
              .unmovableCountFor(UnmovableReason.unknownCard),
          1);
      expect(
          store.value.tidies.single
              .unmovableNumbersFor(UnmovableReason.unknownCard),
          [ghostCardNumber]);
    });

    test('★★ 動かせない孤児は常設の帯でも「待っている」と区別される（決定 D95）★★', () {
      // ★★ 区別できないと、押しても消えない帯に「移ります」と言い続ける ★★
      //   `OrphanCardsPresent` は「整理で控え室・エネルギーデッキへ移ります」と言う。
      //   動かない札にそれを言うと嘘になる。
      final notices = derivedBoardNotices(
        state: handcraftedBoard(selfOrphans: const {
          MemberAreaSlot.center: [drawLivePrinting],
        }),
        cards: realShapedCatalog().cards,
        players: [
          handcraftedBoard(selfOrphans: const {
            MemberAreaSlot.center: [drawLivePrinting],
          }).playerOf(kSelfPlayerId),
        ],
        labelOf: (_) => '自分',
      );

      expect(notices.whereType<OrphanCardsStuck>(), hasLength(1));
      expect(notices.whereType<OrphanCardsStuck>().single.reason,
          UnmovableReason.noRuleForCardType);
      expect(notices.whereType<OrphanCardsPresent>(), isEmpty,
          reason: '★「整理で移ります」は動かない札には掛けない');
    });

    test('★対: 動く孤児では「待っている」側が出る', () {
      // ★これが通らないと、上の検査は「常に Stuck を出す実装」でも通る。
      final state = handcraftedBoard(selfOrphans: const {
        MemberAreaSlot.center: [parallelMemberNormal],
      });
      final notices = derivedBoardNotices(
        state: state,
        cards: realShapedCatalog().cards,
        players: [state.playerOf(kSelfPlayerId)],
        labelOf: (_) => '自分',
      );

      expect(notices.whereType<OrphanCardsPresent>(), hasLength(1));
      expect(notices.whereType<OrphanCardsStuck>(), isEmpty);
    });

    test('★同じエリアに両方あれば 2 行とも出る', () {
      final state = handcraftedBoard(selfOrphans: const {
        MemberAreaSlot.center: [parallelMemberNormal, drawLivePrinting],
      });
      final notices = derivedBoardNotices(
        state: state,
        cards: realShapedCatalog().cards,
        players: [state.playerOf(kSelfPlayerId)],
        labelOf: (_) => '自分',
      );

      expect(notices.whereType<OrphanCardsPresent>(), hasLength(1));
      expect(notices.whereType<OrphanCardsStuck>(), hasLength(1));
    });
  });

  group('★ 画面に出る（実物の経路）', () {
    Future<void> pumpBoard(
      WidgetTester tester,
      GameState state, {
      // ★★ 既定の 512 は手では到達させられない（M-B5）★★
      int historyMaxDepth = 512,
    }) async {
      tester.view.physicalSize = const Size(1800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: state,
          viewerId: kSelfPlayerId,
          mode: BoardMode.localVersus,
          seed: 1,
          historyMaxDepth: historyMaxDepth,
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    testWidgets('孤児 / 重複 / 集計の除外が帯に出る', (tester) async {
      await pumpBoard(
        tester,
        withGhostInResolution(
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
      expect(find.textContaining(ghostCardNumber), findsWidgets);
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

    // =====================================================================
    // ★★ 履歴の上限（M-B5 / 決定 D78）★★
    // =====================================================================

    testWidgets('★★ 上限に達すると帯に出る（★本当に到達させる）★★', (tester) async {
      // ★★ 押したときではなく**到達した時点**で見える必要がある ★★
      //   `canUndo` は真のままなので、出さないと気づけない。
      await pumpBoard(tester, handcraftedBoard(), historyMaxDepth: 2);

      final store =
          tester.widget<BoardView>(find.byType(BoardView).first).store;

      // ★手前では出ない（出る側と対で見る）。
      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      await tester.pumpAndSettle();
      expect(find.textContaining('巻き戻せるのは直前の'), findsNothing);

      store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('board-notices')),
          matching: find.textContaining('巻き戻せるのは直前の 2 操作までです'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('これより前の操作は履歴から外れており'), findsOneWidget);
    });

    testWidgets('★★ 対: 上限（512）に達していなければ出ない ★★', (tester) async {
      // ★これが落ちたら、上の検査は「常に出す実装」でも通っている。
      await pumpBoard(tester, handcraftedBoard());

      final store =
          tester.widget<BoardView>(find.byType(BoardView).first).store;
      for (var i = 0; i < 3; i++) {
        store.dispatch(const DrawEnergy(playerId: kSelfPlayerId));
      }
      await tester.pumpAndSettle();

      expect(store.canUndo, isTrue, reason: '★操作はしている');
      expect(find.textContaining('巻き戻せるのは直前の'), findsNothing);
    });
  });
}
