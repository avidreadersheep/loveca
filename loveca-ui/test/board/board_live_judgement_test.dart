/// ライブ勝敗の記録 8.4.6 / 8.4.7（決定 D10 / D25 / D93 / M-B6）.
///
/// ★★ 欄を 2 つに分けていること自体を固定する（決定 D25 の訂正）★★
/// 8.4.13 が参照するのは**勝敗ではなく 8.4.7 の移動実績**である。
/// 1 つにまとめると、同点で片方だけが移動したケース（8.4.7.1）を取りこぼす。
/// → **勝者だけを入れても入れ替わらない / 移動実績を入れると入れ替わる**を対で見る。
///
/// ★★ ソロでは口ごと出さない（決定 D88 / §14-7 の持ち越し 1）★★
/// ★対で「ローカル対戦では出る」を置く。出ない側だけを見ると
/// **どのモードでも出さない実装**でも通る。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

Future<void> _pumpBoard(
  WidgetTester tester, {
  BoardMode mode = BoardMode.localVersus,
  StepCursor cursor = const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(
      initialState: handcraftedBoard(cursor: cursor),
      viewerId: kSelfPlayerId,
      mode: mode,
      seed: 1,
    ),
    decks: FakeDeckRepository(),
    catalog: realShapedCatalog(),
  );
}

BoardView _view(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView).first);

/// 記録ダイアログを開く。
Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('live-judgement-open')));
  await tester.pumpAndSettle();
}

void main() {
  group('★★ ソロでは口ごと出さない（決定 D88 / §14-7）★★', () {
    testWidgets('★ ボタンが無く、理由が読める', (tester) async {
      await _pumpBoard(tester, mode: BoardMode.solo);

      expect(find.byKey(const ValueKey('live-judgement-open')), findsNothing);
      expect(find.byKey(const ValueKey('summary-live-judgement')), findsNothing);
      // ★★ 黙って消さない ★★
      expect(find.byKey(const ValueKey('live-judgement-solo-note')),
          findsOneWidget);
      expect(find.textContaining('8.4.13 も相手を要求する'), findsOneWidget);
    });

    testWidgets('★対: ローカル対戦では出る（どのモードでも出さない実装ではない）',
        (tester) async {
      await _pumpBoard(tester);

      expect(find.byKey(const ValueKey('live-judgement-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('live-judgement-solo-note')), findsNothing);
    });
  });

  group('★★ 勝者（8.4.6）と移動実績（8.4.7）は別の欄（決定 D25 の訂正）★★', () {
    testWidgets('★ 2 つの欄がそれぞれ両プレイヤーぶんある', (tester) async {
      await _pumpBoard(tester);
      await _openDialog(tester);

      expect(find.byKey(const ValueKey('live-judgement')), findsOneWidget);
      for (final id in [kSelfPlayerId, kOpponentPlayerId]) {
        expect(find.byKey(ValueKey('winner-$id')), findsOneWidget);
        expect(find.byKey(ValueKey('mover-$id')), findsOneWidget);
      }
      // ★8.4.13 が参照するのはどちらかを画面に書いてある。
      expect(find.textContaining('8.4.13 が参照するのは勝敗ではなく'), findsOneWidget);
    });

    testWidgets('★ 記録すると集計に 2 つとも出る', (tester) async {
      await _pumpBoard(tester);
      await _openDialog(tester);

      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mover-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      final record = _view(tester).state.liveJudgement!;
      expect(record.winnerIds, {kSelfPlayerId});
      expect(record.movedToSuccessIds, {kOpponentPlayerId});
      // ★★ まとめて 1 つに見せない ★★
      expect(find.textContaining('勝者 8.4.6: 自分'), findsOneWidget);
      expect(find.textContaining('移動実績 8.4.7: 相手'), findsOneWidget);
    });

    testWidgets('★ 8.4.6.2 の両者勝利と 8.4.6.1 の勝者なしが入る', (tester) async {
      await _pumpBoard(tester);
      await _openDialog(tester);

      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('winner-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      expect(_view(tester).state.liveJudgement!.winnerIds,
          {kSelfPlayerId, kOpponentPlayerId});

      // ★★ 勝者なし（8.4.6.1）は「記録を消す」とは別である ★★
      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('winner-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      expect(_view(tester).state.liveJudgement, isNotNull,
          reason: '★勝者なしも記録である（8.4.6.1）');
      expect(_view(tester).state.liveJudgement!.winnerIds, isEmpty);
    });

    testWidgets('★ 「記録を消す」は未設定に戻す', (tester) async {
      await _pumpBoard(tester);
      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();
      expect(_view(tester).state.liveJudgement, isNotNull);

      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('live-judgement-clear')));
      await tester.pumpAndSettle();

      expect(_view(tester).state.liveJudgement, isNull);
      expect(find.textContaining('未設定'), findsOneWidget);
    });

    testWidgets('★ やめると何も記録しない（履歴が増えない）', (tester) async {
      await _pumpBoard(tester);
      final before = _view(tester).store.value.session.history.depth;

      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-cancel')));
      await tester.pumpAndSettle();

      expect(_view(tester).state.liveJudgement, isNull);
      expect(_view(tester).store.value.session.history.depth, before);
    });
  });

  group('★★★ 8.4.13 が参照するのは移動実績である（決定 D25 の訂正）★★★', () {
    /// 8.4.13 の直前（8.4.12 は宣言が要る分岐なのでその手前から進める）。
    const beforeSwap = StepCursor(PhaseId.liveJudgement, StepId.s8_4_12);

    testWidgets('★★ 一方だけが移動していると先攻が入れ替わる ★★', (tester) async {
      await _pumpBoard(tester, cursor: beforeSwap);
      expect(_view(tester).state.firstPlayerId, kSelfPlayerId, reason: '★前提');

      await _openDialog(tester);
      // ★勝者は両者にしておく（8.4.7.1 の「両者勝利」の形）。
      await tester.tap(find.byKey(const ValueKey('winner-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('winner-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      // ★移動したのは相手だけ。
      await tester.tap(find.byKey(const ValueKey('mover-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      // ★押す前に効きが読める。
      expect(find.textContaining('先攻が相手になります'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      await _advancePast(tester, StepId.s8_4_13);

      expect(_view(tester).state.firstPlayerId, kOpponentPlayerId,
          reason: '★★8.4.13「一方のプレイヤーのみが移動していた場合」★★');
    });

    testWidgets('★★対: 両者が移動していれば入れ替わらない ★★', (tester) async {
      await _pumpBoard(tester, cursor: beforeSwap);

      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('mover-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mover-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      expect(find.textContaining('入れ替えは起きません'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      await _advancePast(tester, StepId.s8_4_13);

      expect(_view(tester).state.firstPlayerId, kSelfPlayerId);
    });

    testWidgets('★★★対: 勝者だけを入れても入れ替わらない（欄を分けている理由）★★★',
        (tester) async {
      // ★★ 1 つの欄にまとめた実装ならここで入れ替わってしまう ★★
      await _pumpBoard(tester, cursor: beforeSwap);

      await _openDialog(tester);
      await tester.tap(find.byKey(const ValueKey('winner-$kOpponentPlayerId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('live-judgement-apply')));
      await tester.pumpAndSettle();

      await _advancePast(tester, StepId.s8_4_13);

      expect(_view(tester).state.firstPlayerId, kSelfPlayerId,
          reason: '★8.4.13 は 8.4.6 の勝敗を読まない');
    });
  });
}

/// [target] のステップを**実行する**まで進める。
///
/// ★★ 分岐（8.4.12）では**前へ進む**側を選ぶ ★★
/// 8.4.12 は「処理がある → 8.4.9 へ戻る」というループを持つので、
/// 最初の候補を選ぶと戻り続けて着かない。
/// ★どちらが前かは `PhaseId.steps` の並びから導く（テストに条番号を書かない）。
///
/// ★★ M-B7 で条件を「着いたか」から「実行したか」へ変えた（決定 D92）★★
/// 「次へ」は**次の停止点まで**進むので、目的のステップを 1 押下で
/// **通り過ぎる**ことがある。カーソル位置で見ると永久に着かない。
/// → **1 押下で実行したステップ**（`BoardOperationLog.steps`）で見る。
Future<void> _advancePast(WidgetTester tester, StepId target) async {
  for (var i = 0; i < 12; i++) {
    final cursor = _view(tester).state.cursor;

    if (find.byKey(const ValueKey('advance-choice')).evaluate().isNotEmpty) {
      final steps = cursor.phase.steps;
      final forward = steps[steps.indexOf(cursor.step) + 1];
      final transition = _view(tester)
          .store
          .transitions
          .firstWhere((t) => t.target == forward);
      await tester
          .tap(find.byKey(ValueKey('advance-choice-${transition.label}')));
    } else {
      await tester.tap(find.byKey(const ValueKey('advance-step')));
    }
    await tester.pumpAndSettle();

    final executed = _view(tester).store.value.operation?.steps ?? const [];
    if (executed.any((step) => step.cursor.step == target)) return;
  }
  fail('${target.ruleRef} を実行しなかった');
}
