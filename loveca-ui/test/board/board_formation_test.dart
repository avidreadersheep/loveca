/// ポジションチェンジ 11.10 / フォーメーションチェンジ 11.11（決定 D74 / D93 / M-B6）.
///
/// ★★ いちばん大事なのは「素のドラッグには課さない」を対で置くこと（§3-4）★★
/// 11.10.2 / 11.11.2 は**その効果の中での制約**であって盤面の不変条件ではない。
/// コマンド側だけを見ると、**盤全体に課した実装**でも通ってしまう。
/// → 同じ盤面で**ドラッグなら 1 エリアに 2 人並べられる**ことを固定する。
///
/// ★★ 合成の途中に `Tidy` を挟んでいないことも見る（§3-3）★★
/// 挟むと 10.4 が走って中間状態が壊れる。★入れ替えの直後に控え室が増えていないこと。
///
/// ★★ 1 押下 = 履歴 1 件（M-B5 の合成 / §8-2）★★
/// 入れ替えは 2 アクションだが **1 回の `undo` で両方戻る**。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_formation.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _member = parallelMemberNormal;
const _other = trioMemberPrinting;
const _energy = energyPrinting;

Future<void> _pumpBoard(
  WidgetTester tester,
  GameState state, {
  BoardMode mode = BoardMode.localVersus,
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(
      initialState: state,
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

GameState _state(WidgetTester tester) => _view(tester).state;

PlayerState _self(WidgetTester tester) =>
    _state(tester).playerOf(kSelfPlayerId);

int _historyDepth(WidgetTester tester) =>
    _view(tester).store.value.session.history.depth;

/// そのエリアのメンバーの printingId 列。
List<String> _membersIn(WidgetTester tester, MemberAreaSlot slot) => _self(tester)
    .memberAreas
    .firstWhere((area) => area.slot == slot)
    .stacks
    .map((stack) => stack.member.printingId)
    .toList();

/// 左とセンターに 1 人ずつ。
GameState _twoMembers() => handcraftedBoard(selfMembers: const {
      MemberAreaSlot.leftSide: [_member],
      MemberAreaSlot.center: [_other],
    });

/// メンバーの札のメニューを開く。
Future<void> _openMemberMenu(
  WidgetTester tester,
  MemberAreaSlot slot,
) async {
  await tester.tap(find.byKey(ValueKey('member-$kSelfPlayerId-${slot.name}')));
  await tester.pumpAndSettle();
}

void main() {
  group('★★ ポジションチェンジ 11.10 ★★', () {
    testWidgets('★ 移動先が空なら 1 件だけ動く（11.10.1）', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfMembers: const {
          MemberAreaSlot.leftSide: [_member],
        }),
      );
      final before = _historyDepth(tester);

      await _openMemberMenu(tester, MemberAreaSlot.leftSide);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('position-change')), findsOneWidget);
      // ★今いるエリアは選べない（11.10.1「今いるエリア以外のエリアに」）。
      expect(find.byKey(const ValueKey('position-change-leftSide')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('position-change-center')));
      await tester.pumpAndSettle();

      expect(_membersIn(tester, MemberAreaSlot.leftSide), isEmpty);
      expect(_membersIn(tester, MemberAreaSlot.center), [_member]);
      expect(_historyDepth(tester), before + 1);
    });

    testWidgets('★★ 移動先にメンバーがいると入れ替わる（11.10.2）★★', (tester) async {
      await _pumpBoard(tester, _twoMembers());
      final before = _historyDepth(tester);
      final waitingRoomBefore = _self(tester).waitingRoom.length;

      await _openMemberMenu(tester, MemberAreaSlot.leftSide);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();
      // ★押す前に「入れ替わる」と読める。
      expect(find.textContaining('11.10.2 により入れ替わります'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('position-change-center')));
      await tester.pumpAndSettle();

      expect(_membersIn(tester, MemberAreaSlot.center), [_member]);
      expect(_membersIn(tester, MemberAreaSlot.leftSide), [_other]);

      // ★★ 2 アクションだが履歴は 1 件（1 undo で戻る / §8-2）★★
      expect(_historyDepth(tester), before + 1);
      // ★★ 合成の途中に `Tidy` を挟んでいない（§3-3）★★
      //   挟むと 10.4 が走って片方が控え室へ行く。
      expect(_self(tester).waitingRoom, hasLength(waitingRoomBefore));
    });

    testWidgets('★ 1 回の undo で両方戻る', (tester) async {
      await _pumpBoard(tester, _twoMembers());

      await _openMemberMenu(tester, MemberAreaSlot.leftSide);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('position-change-center')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();

      expect(_membersIn(tester, MemberAreaSlot.leftSide), [_member]);
      expect(_membersIn(tester, MemberAreaSlot.center), [_other]);
    });

    testWidgets('★ やめると何も起きない（履歴が増えない）', (tester) async {
      await _pumpBoard(tester, _twoMembers());
      final before = _historyDepth(tester);

      await _openMemberMenu(tester, MemberAreaSlot.leftSide);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('position-change-cancel')));
      await tester.pumpAndSettle();

      expect(_historyDepth(tester), before);
      expect(_membersIn(tester, MemberAreaSlot.leftSide), [_member]);
    });

    testWidgets('★★ 4.5.5.3: 下に重ねたカードも一緒に移る ★★', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(
          selfMembers: const {
            MemberAreaSlot.leftSide: [_member],
          },
          selfBeneath: const {
            MemberAreaSlot.leftSide: [_energy],
          },
        ),
      );

      await _openMemberMenu(tester, MemberAreaSlot.leftSide);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('position-change-center')));
      await tester.pumpAndSettle();

      final center = _self(tester)
          .memberAreas
          .firstWhere((area) => area.slot == MemberAreaSlot.center);
      expect(center.stacks.single.beneath.map((c) => c.printingId), [_energy]);
    });
  });

  group('★★ フォーメーションチェンジ 11.11 ★★', () {
    testWidgets('★ 袖のボタンは両プレイヤーぶん出る（D87 と揃える）', (tester) async {
      await _pumpBoard(tester, _twoMembers());

      expect(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('formation-change-$kOpponentPlayerId')),
          findsOneWidget);
    });

    testWidgets('★対: ソロは袖が 1 つなので 1 つだけ', (tester) async {
      await _pumpBoard(tester, _twoMembers(), mode: BoardMode.solo);

      expect(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('formation-change-$kOpponentPlayerId')),
          findsNothing);
    });

    testWidgets('★★ N 人まとめて動いて履歴は 1 件 ★★', (tester) async {
      await _pumpBoard(tester, _twoMembers());
      final before = _historyDepth(tester);

      await tester
          .tap(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formation-change')), findsOneWidget);

      // ★左サイドの人 → 右サイド、センターの人 → 左サイド。
      final rows = tester
          .widgetList(find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>)
                  .value
                  .startsWith('formation-target-')))
          .toList();
      expect(rows, hasLength(2));

      Future<void> assign(int index, String label) async {
        await tester.tap(find.byKey(rows[index].key!));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      await assign(0, '右サイドエリア');
      await assign(1, '左サイドエリア');

      await tester
          .tap(find.byKey(const ValueKey('formation-change-apply')));
      await tester.pumpAndSettle();

      expect(_membersIn(tester, MemberAreaSlot.rightSide), [_member]);
      expect(_membersIn(tester, MemberAreaSlot.leftSide), [_other]);
      expect(_membersIn(tester, MemberAreaSlot.center), isEmpty);
      // ★★ 2 アクションでも履歴は 1 件 ★★
      expect(_historyDepth(tester), before + 1);
    });

    testWidgets('★★ 11.11.2: 同じエリアに 2 人は割り当てられない ★★', (tester) async {
      await _pumpBoard(tester, _twoMembers());

      await tester
          .tap(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')));
      await tester.pumpAndSettle();

      // ★既定は現状のままなので、まだ衝突していない（前提）。
      expect(find.byKey(const ValueKey('formation-change-conflict')),
          findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('formation-change-apply')))
              .onPressed,
          isNotNull);

      // ★左サイドの人をセンターへ → センターが 2 人になる。
      final first = tester
          .widgetList(find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>)
                  .value
                  .startsWith('formation-target-')))
          .first;
      await tester.tap(find.byKey(first.key!));
      await tester.pumpAndSettle();
      await tester.tap(find.text('センターエリア').last);
      await tester.pumpAndSettle();

      // ★★ 黙って弾かない。理由が出て、決定が無効になる ★★
      expect(find.byKey(const ValueKey('formation-change-conflict')),
          findsOneWidget);
      expect(find.textContaining('11.11.2'), findsWidgets);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('formation-change-apply')))
              .onPressed,
          isNull);
    });
  });

  group('★★★【要確認】1 エリアに 2 人以上いるときは無効にして理由を出す（D74 / §3-5）★★★',
      () {
    /// 左サイドに 2 人（10.4 待ちの正規の中間状態）。
    GameState crowded() => handcraftedBoard(selfMembers: const {
          MemberAreaSlot.leftSide: [_member, _other],
          MemberAreaSlot.center: [_other],
        });

    test('★ 判定は関数 1 つ（11.10 と 11.11 で分けない）', () {
      final ok = handcraftedBoard(selfMembers: const {
        MemberAreaSlot.leftSide: [_member],
      }).playerOf(kSelfPlayerId);
      expect(formationRefusal(ok), isNull);

      final ng = crowded().playerOf(kSelfPlayerId);
      expect(formationRefusal(ng), contains('左サイドエリア'));
      expect(formationRefusal(ng), contains('11.10.2'));
      expect(formationRefusal(ng), contains('整理する'));
    });

    testWidgets('★ 11.10 のダイアログが移動先を出さず、理由を出す', (tester) async {
      await _pumpBoard(tester, crowded());

      await _openMemberMenu(tester, MemberAreaSlot.center);
      await tester.tap(find.text('ポジションチェンジする 11.10'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('position-change-refusal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('position-change-leftSide')), findsNothing);
      expect(find.byKey(const ValueKey('position-change-rightSide')), findsNothing);
    });

    testWidgets('★ 11.11 のダイアログが決定を無効にし、理由を出す', (tester) async {
      await _pumpBoard(tester, crowded());

      await tester
          .tap(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('formation-change-refusal')),
          findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.byKey(const ValueKey('formation-change-apply')))
              .onPressed,
          isNull);
    });

    testWidgets('★ 整理すると使えるようになる（永久に無効ではない）', (tester) async {
      await _pumpBoard(tester, crowded());

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('formation-change-$kSelfPlayerId')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('formation-change-refusal')), findsNothing);
    });

    testWidgets(
        '★★★対照実験: 素のドラッグには課さない（1 エリアに 2 人並べられる）★★★',
        (tester) async {
      // ★★ これが無いと「盤全体に課した実装」でも上の 3 件は通る ★★
      //   4.5.5 / 10.4 の中間状態を手で再現できることが、
      //   `MemberArea` が型で表現できるようにした状態そのものである（§3-4）。
      await _pumpBoard(tester, _twoMembers());
      expect(_membersIn(tester, MemberAreaSlot.center), hasLength(1), reason: '★前提');

      final from = tester.getCenter(
          find.byKey(ValueKey('member-$kSelfPlayerId-leftSide')));
      // ★上半分に落とす（4.5.1「置く」。下半分は 4.5.5「下に置く」）。
      final target =
          tester.getRect(find.byKey(ValueKey('member-$kSelfPlayerId-center')));
      final to = Offset(target.center.dx, target.top + target.height * 0.25);

      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_membersIn(tester, MemberAreaSlot.center), hasLength(2),
          reason: '★★ドラッグは 11.11.2 に縛られない（コマンドの中だけの制約）★★');
      expect(_membersIn(tester, MemberAreaSlot.leftSide), isEmpty);
    });
  });
}
