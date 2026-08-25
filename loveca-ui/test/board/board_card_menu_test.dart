/// 反転 / 向き / 剥がす のメニュー（M-B2 / 決定 D85）.
///
/// ★★ 見るのは「その居場所で合法な操作だけが出ること」である ★★
/// 4.3.1 は配置状態が指定されるのを「**一部の領域において**」と限定しており、
/// 表示面も向きもどの領域でも持てるわけではない。
/// **出る側だけを見ると「全部の札に全部の操作を出す」実装でも通る**ので、
/// 出ない側と理由を必ず対で固定する。
///
/// ★★ 操作したら画面が変わることまで見る ★★
/// 反転も向きも `GameState` が変わるだけでは意味が無い。
/// **描かなければ「黙って何も起きない操作」になる。**
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_slot.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _live = drawLivePrinting;
const _member = trioMemberPrinting;
const _energy = energyPrinting;

Future<void> _pump(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(1600, 1300);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(initialState: state, viewerId: kSelfPlayerId, seed: 1),
    decks: FakeDeckRepository(),
    catalog: realShapedCatalog(),
  );
}

BoardView _view(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView).first);

GameState _state(WidgetTester tester) => _view(tester).state;

int _depth(WidgetTester tester) =>
    _view(tester).store.value.session.history.depth;

Finder _slotOf(String instanceId) => find
    .ancestor(
      of: find.byKey(ValueKey('board-card-$instanceId')),
      matching: find.byType(BoardSlot),
    )
    .first;

Rect _box(WidgetTester tester, Finder slot) => tester.getRect(
      find.descendant(of: slot, matching: find.byType(SizedBox)).first,
    );

/// 札を叩いてメニューを開く。
Future<void> _openMenu(WidgetTester tester, String instanceId) async {
  await tester.tap(_slotOf(instanceId));
  await tester.pumpAndSettle();
}

MemberArea _area(WidgetTester tester, MemberAreaSlot slot) => _state(tester)
    .playerOf(kSelfPlayerId)
    .memberAreas
    .firstWhere((a) => a.slot == slot);

void main() {
  group('★★ 表裏の反転（5.3.1 / 4.3.3）★★', () {
    testWidgets('4.6 ライブカード置き場では出る。裏返すと絵が消える',
        (tester) async {
      // ★8.2.2 / 8.2.4 のブラフ（ライブ以外を裏向きに置く）はここで起こる。
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.liveStage: [_live],
        }),
      );

      final id =
          _state(tester).playerOf(kSelfPlayerId).liveStage.single.instanceId;
      expect(find.byKey(ValueKey('board-card-$id')), findsOneWidget);

      await _openMenu(tester, id);
      await tester.tap(find.text('裏向きにする 5.3.1 / 4.3.3.2'));
      await tester.pumpAndSettle();

      expect(_state(tester).playerOf(kSelfPlayerId).liveStage.single.face,
          FaceState.faceDown);
      // ★★ 描かれていなければ「黙って何も起きない操作」である ★★
      expect(find.byKey(ValueKey('board-card-$id')), findsNothing,
          reason: '★4.3.3.2: 情報が書かれている面が見えない');
      expect(_depth(tester), 1);
    });

    testWidgets('★裏向きの札には「表向きにする」が出る（往復できる）', (tester) async {
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.exile: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).exile.single.instanceId;
      await _openMenu(tester, id);
      await tester.tap(find.text('裏向きにする 5.3.1 / 4.3.3.2'));
      await tester.pumpAndSettle();

      // ★裏になったので `board-card-` のキーは消えている。箱から叩く。
      await tester.tap(find.byKey(const ValueKey('zone-exile-$kSelfPlayerId')));
      await tester.pumpAndSettle();
      expect(find.text('表向きにする 5.3.1 / 4.3.3.1'), findsOneWidget);
    });

    testWidgets('★★ 対: 4.11 手札には出ない（理由も出る）★★', (tester) async {
      // ★4.11 に表示面の規定が無く、盤面は 4.11.2 に従って常に中身を出す。
      //   反転しても観測差が出ないので、口を出さない。
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      await _openMenu(tester, id);

      expect(find.textContaining('裏向きにする'), findsNothing);
      expect(find.textContaining('4.11.2'), findsOneWidget,
          reason: '★黙って空のメニューにしない');
    });

    testWidgets('★★ 対: メンバーエリアには出ない（未決 U14）★★', (tester) async {
      // ★`FlipCard` が `Zone.memberArea` を弾く（`card_move.dart`）ので構造的に無理。
      await _pump(
        tester,
        handcraftedBoard(selfMembers: const {
          MemberAreaSlot.center: [_member],
        }),
      );

      final id = _area(tester, MemberAreaSlot.center).stacks.single.member
          .instanceId;
      await _openMenu(tester, id);

      expect(find.textContaining('裏向きにする'), findsNothing);
      expect(find.textContaining('4.5 に表示面の規定がありません'), findsOneWidget);
    });
  });

  group('★★ 向き（5.2.1）★★', () {
    testWidgets('4.7 エネルギー置き場では出る。横向きにすると絵が回る',
        (tester) async {
      // ★4.7.3 が向きを与える唯一の Zone。
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.energyField: [_energy],
        }),
      );

      final id =
          _state(tester).playerOf(kSelfPlayerId).energyField.single.instanceId;
      final before = _box(tester, _slotOf(id));
      expect(find.byKey(ValueKey('board-card-wait-$id')), findsNothing);

      await _openMenu(tester, id);
      await tester.tap(find.text('横向き（ウェイト）にする 5.2.1 / 4.7.3'));
      await tester.pumpAndSettle();

      expect(_state(tester).playerOf(kSelfPlayerId).energyField.single.orientation,
          CardOrientation.wait);
      // ★★ 描かれていなければ「黙って何も起きない操作」である ★★
      expect(find.byKey(ValueKey('board-card-wait-$id')), findsOneWidget);

      // ★★ 箱の寸法は変わらない（D76 / D47 の前提）★★
      //   変わると「上半分 / 下半分」の帯の高さが場所ごとに違ってしまう。
      expect(_box(tester, _slotOf(id)).size, before.size);
    });

    testWidgets('★横向きの札には「縦向きにする」が出る（4.3.2.1 へ戻せる）',
        (tester) async {
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.energyField: [_energy],
        }),
      );

      final id =
          _state(tester).playerOf(kSelfPlayerId).energyField.single.instanceId;
      await _openMenu(tester, id);
      await tester.tap(find.text('横向き（ウェイト）にする 5.2.1 / 4.7.3'));
      await tester.pumpAndSettle();

      await _openMenu(tester, id);
      expect(find.text('縦向き（アクティブ）にする 5.2.1 / 4.7.3'), findsOneWidget);
    });

    testWidgets('メンバーにも出る（4.5.4）。★条番号が 4.7.3 と違う', (tester) async {
      await _pump(
        tester,
        handcraftedBoard(selfMembers: const {
          MemberAreaSlot.center: [_member],
        }),
      );

      final id = _area(tester, MemberAreaSlot.center).stacks.single.member
          .instanceId;
      await _openMenu(tester, id);
      await tester.tap(find.text('横向き（ウェイト）にする 5.2.1 / 4.5.4'));
      await tester.pumpAndSettle();

      expect(_area(tester, MemberAreaSlot.center).stacks.single.member.orientation,
          CardOrientation.wait);
      expect(find.byKey(ValueKey('board-card-wait-$id')), findsOneWidget);
    });

    testWidgets('★★ 対: 4.12 控え室には向きが出ない（4.3.1 の「一部の領域」）★★',
        (tester) async {
      // ★出る側だけ見ると「全部の札に向きを出す」実装でも通る。
      await _pump(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.waitingRoom: [_energy],
        }),
      );

      final id =
          _state(tester).playerOf(kSelfPlayerId).waitingRoom.single.instanceId;
      await _openMenu(tester, id);

      expect(find.textContaining('横向き'), findsNothing);
      // ★対: 反転は出る（メニューそのものが出ていないわけではない）。
      expect(find.textContaining('裏向きにする'), findsOneWidget);
    });
  });

  group('★★ 下に重ねられたカード（4.5.5.1）★★', () {
    GameState stacked() => handcraftedBoard(
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
          selfBeneath: const {
            MemberAreaSlot.center: [_energy],
          },
        );

    testWidgets('剥がすと孤児になる（4.5.5.4.1 / 10.1.2）', (tester) async {
      await _pump(tester, stacked());

      final id = _area(tester, MemberAreaSlot.center)
          .stacks
          .single
          .beneath
          .single
          .instanceId;
      await _openMenu(tester, id);
      await tester.tap(find.text('下から剥がす 4.5.5.4.1'));
      await tester.pumpAndSettle();

      final area = _area(tester, MemberAreaSlot.center);
      expect(area.stacks.single.beneath, isEmpty);
      // ★ここで控え室へ送ってはいけない。行き先を決めるのはルール処理（10.1.2）。
      expect(area.orphans.single.instanceId, id);
      expect(_state(tester).playerOf(kSelfPlayerId).waitingRoom, isEmpty);
      expect(_depth(tester), 1);
    });

    testWidgets('★★ 対: 向きは出ない（4.5.5.2）★★', (tester) async {
      await _pump(tester, stacked());

      final id = _area(tester, MemberAreaSlot.center)
          .stacks
          .single
          .beneath
          .single
          .instanceId;
      await _openMenu(tester, id);

      expect(find.textContaining('横向き（ウェイト）にする'), findsNothing);
      expect(find.textContaining('4.5.5.2'), findsOneWidget,
          reason: '★出せない理由が読めること');
    });

    testWidgets('★孤児にも口はある（できることが無い理由を出す）', (tester) async {
      await _pump(
        tester,
        handcraftedBoard(
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
          selfOrphans: const {
            MemberAreaSlot.center: [_energy],
          },
        ),
      );

      final id =
          _area(tester, MemberAreaSlot.center).orphans.single.instanceId;
      await _openMenu(tester, id);

      // ★M-B3 で盤面の帯にも「正規の中間状態」と出るようになった（孤児の注記）。
      //   メニューの中に絞って見る。★どちらにも出ることが正しい。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-menu-0')),
          matching: find.textContaining('正規の中間状態'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('整理（10.4 / 10.5）'), findsOneWidget);
      // ★押せる行が 1 つも無いので盤面は動かない。
      expect(_depth(tester), 0);
    });
  });
}
