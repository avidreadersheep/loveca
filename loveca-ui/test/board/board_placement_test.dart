/// 領域に置かれるカードの配置状態を**画面で**見る。
///
/// 総合ルール 4.3.1「配置状態には、**向きを示す状態**と、**表示面を表す状態**が
/// あります」→ 2 つの軸をそれぞれ別の条文が決める。
///
///   表示面 … 4.1.2.1（領域の公開 / 非公開から導く）
///   向き   … 4.3.1（持つのは 4.5.4 と 4.7.3 だけ）/ 4.3.2.3（既定はアクティブ）
///
/// ★★ 表示面の条文の系は 2 段である ★★
///   4.1.2.1「公開領域にカードが置かれる場合、そのカードは公開状態 (4.2.2) で
///   置かれます。非公開領域にカードが置かれる場合、そのカードは非公開状態 (4.2.3)
///   で置かれます」
///   → 4.2.2 公開状態 = 4.3.3.1 表向き / 4.2.3 非公開状態 = 4.3.3.2 裏向き
///
/// ★★ 「表向きになる」だけを見ても何も証明しない ★★
///   `docs/...` D-10 の教訓。**裏向きのままであるべきものが裏向きのまま**を対で置く。
///   とくに 4.6 ライブカード置き場（8.2.2 / 8.2.4 のブラフ）が表向きになったら、
///   それは新しい不具合である。
///
/// ★写像そのものは `loveca-core/test/zone_placement_test.dart` が全組を回している。
///   ここは**画面から通した経路**で、実際に絵が出る／裏面が出ることを見る。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_slot.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

const _live = drawLivePrinting;
const _energy = energyPrinting;

/// 札の絵そのもの（枠）。★裏向きの札には存在しない。
Finder _art(String instanceId) => find.descendant(
      of: find.byKey(ValueKey('board-card-$instanceId')),
      matching: find.byType(CardThumb),
    );

Finder _slotOf(String instanceId) => find
    .ancestor(
      of: find.byKey(ValueKey('board-card-$instanceId')),
      matching: find.byType(BoardSlot),
    )
    .first;

Finder _zone(Zone zone, [String playerId = kSelfPlayerId]) =>
    find.byKey(ValueKey('zone-${zone.name}-$playerId'));

/// 4.3.2.2 のウェイト状態として**実際に回して描かれている**札。
///
/// ★状態ではなく描画を見る。`board_slot.dart` は `orientation == wait` の
///   ときだけこの key を持つ `Transform` を挟む。
Finder _rotated(String instanceId) =>
    find.byKey(ValueKey('board-card-wait-$instanceId'));

/// [zone] の中に裏面が何枚出ているか。★画面で見えているものだけを数える。
Finder _faceDownIn(Zone zone) =>
    find.descendant(of: _zone(zone), matching: find.byType(BoardFaceDown));

Rect _box(WidgetTester tester, Finder slot) => tester.getRect(
      find.descendant(of: slot, matching: find.byType(SizedBox)).first,
    );

/// ★★ 絵の外・箱の中（＝ D72 が作った帯）の 1 点 ★★
Offset _bandPoint(WidgetTester tester, String instanceId) {
  final box = _box(tester, _slotOf(instanceId));
  final art = tester.getRect(_art(instanceId));
  final band = art.top - box.top;

  expect(band, greaterThan(10),
      reason: '★帯が実際にある（枠線と余白ではない）ことを先に確かめる');
  return Offset(box.center.dx, box.top + band / 2);
}

Future<void> _drag(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final gesture = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _pumpBoard(WidgetTester tester, GameState state) async {
  tester.view.physicalSize = const Size(1600, 1300);
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

BoardView _view(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView).first);

GameState _state(WidgetTester tester) => _view(tester).state;

/// ★盤面が実際に配っている `GameStore`（＝ `reduce` へ届く唯一の口 / D53 / D85）。
GameStore _store(WidgetTester tester) => _view(tester).store;

String _first(WidgetTester tester, Zone zone) =>
    cardsIn(_state(tester), kSelfPlayerId, zone).first.instanceId;

FaceState _faceOf(WidgetTester tester, Zone zone, String instanceId) =>
    cardsIn(_state(tester), kSelfPlayerId, zone)
        .firstWhere((c) => c.instanceId == instanceId)
        .face;

void main() {
  group('★★ 4.1.2.1 — 領域に置かれるカードの表示面 ★★', () {
    testWidgets('★★ 前提（陽性対照）: 手札の札は盤面の状態では裏向きである ★★',
        (tester) async {
      // ★★ これが表向きだと、下の「表向きになった」試験は素通しで緑になる ★★
      //   4.11.2 は非公開領域。`handcraftedBoard` も 4.1.2.1 を通してある。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _first(tester, Zone.hand);
      expect(_faceOf(tester, Zone.hand, id), FaceState.faceDown,
          reason: '★4.11.2 は非公開領域 → 4.1.2.1 → 4.2.3 → 4.3.3.2');

      // ★対: 画面では表として出る（D37 / D77。持ち主は見られる）。
      expect(_art(id), findsOneWidget,
          reason: '★盤面は 4.11.2 に従って持ち主に中身を出す');
    });

    testWidgets('★報告された不具合: 手札 → 控え室で表向きになる（4.12.2）',
        (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _first(tester, Zone.hand);
      expect(_faceDownIn(Zone.waitingRoom), findsNothing, reason: '★動かす前');

      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.waitingRoom)),
      );

      expect(_faceOf(tester, Zone.waitingRoom, id), FaceState.faceUp);
      expect(_faceDownIn(Zone.waitingRoom), findsNothing,
          reason: '★控え室に裏面が出ている = 4.1.2.1 が効いていない');
      expect(_art(id), findsOneWidget, reason: '★絵が出ていること');
    });

    testWidgets('4.13.2: 手札 → 除外領域も表向きで置かれる', (tester) async {
      // 4.13.2「特に指示がないかぎり、取り除かれたカードは表向きに置かれます」
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _first(tester, Zone.hand);
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.exile)),
      );

      expect(_faceOf(tester, Zone.exile, id), FaceState.faceUp);
      expect(_faceDownIn(Zone.exile), findsNothing);
    });
  });

  group('★★ 対: 4.6.2 の例外を潰していない ★★', () {
    testWidgets('★★ 手札 → ライブカード置き場は裏向きのまま（8.2.2 / 8.2.4）★★',
        (tester) async {
      // ★★ ここが表向きになったら、それは新しい不具合である ★★
      //   4.6.2「公開領域ですが、カードが一時的に裏向きに置かれることがあります」
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _first(tester, Zone.hand);
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.liveStage)),
      );

      expect(_faceOf(tester, Zone.liveStage, id), FaceState.faceDown);
      expect(_faceDownIn(Zone.liveStage), findsOneWidget,
          reason: '★ブラフが成立しない = 相手に種別まで見えている');
      expect(_art(id), findsNothing);
    });

    testWidgets('★★ 対の対: 控え室 → ライブカード置き場は表向きのまま ★★',
        (tester) async {
      // ★「4.6 は常に裏向き」という実装だとここで落ちる。
      //   4.6.2 は裏向きを**許す**のであって強制しない（8.3.4 で表にした札が戻る）。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.waitingRoom: [_live],
        }),
      );

      final id = _first(tester, Zone.waitingRoom);
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.liveStage)),
      );

      expect(_faceOf(tester, Zone.liveStage, id), FaceState.faceUp);
      expect(_faceDownIn(Zone.liveStage), findsNothing);
    });

    testWidgets('★今日踏める経路: 控え室 → 手札 → ライブカード置き場が裏向きになる',
        (tester) async {
      // ★4.11.2 の非公開が復元されないと、ここが表向きのままライブに入る。
      //   修正前に実際に踏めた経路である。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.waitingRoom: [_live],
          Zone.hand: [_live],
        }),
      );

      final anchor = _first(tester, Zone.hand);
      final id = _first(tester, Zone.waitingRoom);

      // (1) 控え室 → 手札。★手札の帯には key が無いので既存の札の上へ落とす。
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_slotOf(anchor)),
      );
      expect(_faceOf(tester, Zone.hand, id), FaceState.faceDown,
          reason: '★4.11.2 は非公開領域');

      // (2) 手札 → ライブカード置き場。
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.liveStage)),
      );
      expect(_faceOf(tester, Zone.liveStage, id), FaceState.faceDown);
      expect(_faceDownIn(Zone.liveStage), findsOneWidget);
    });
  });

  group('★★ 4.3.1 / 4.3.2.3 — 領域に置かれるカードの向き ★★', () {
    /// エネルギーを 1 枚置いて、5.2.1 でウェイト状態にした盤面。
    ///
    /// ★★ 向きは `SetOrientation` で立てる ★★
    ///   `handcraftedBoard` は 4.1.2.1 / 4.3.2.3 を通すので、
    ///   4.7 の札は必ずアクティブ状態で生まれる（条文どおり）。
    ///   横向きの札は**盤面のメニュー（5.2.1）と同じ経路**で作る。
    Future<String> waitingEnergy(WidgetTester tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.energyField: [_energy],
        }),
      );

      final id = _first(tester, Zone.energyField);
      expect(_rotated(id), findsNothing,
          reason: '★前提: 4.3.2.3 により置いた直後はアクティブ状態');

      _store(tester).dispatch(SetOrientation(
        instanceId: id,
        playerId: kSelfPlayerId,
        zone: Zone.energyField,
        orientation: CardOrientation.wait,
      ));
      await tester.pumpAndSettle();
      return id;
    }

    testWidgets('★対: エネルギー置き場では横向きに描かれる（4.7.3 は向きを持つ）',
        (tester) async {
      // ★「常に向きを落とす」実装だとここで落ちる。
      final id = await waitingEnergy(tester);

      expect(_rotated(id), findsOneWidget);
      expect(
          cardsIn(_state(tester), kSelfPlayerId, Zone.energyField)
              .single
              .orientation,
          CardOrientation.wait);
    });

    testWidgets('★実害の再現: ウェイトのエネルギーを控え室へ移すと縦向きに戻る',
        (tester) async {
      // ★★ `BoardCard` は `orientation == wait` のときだけ中身を 90 度回す ★★
      //   4.12 に向きの規定は無い (4.3.1) のに、引き継ぐと控え室で横向きのまま残る。
      final id = await waitingEnergy(tester);
      expect(_rotated(id), findsOneWidget, reason: '★動かす前は横向き');

      await _drag(
        tester,
        from: tester.getCenter(_slotOf(id)),
        to: tester.getCenter(_zone(Zone.waitingRoom)),
      );

      expect(
          cardsIn(_state(tester), kSelfPlayerId, Zone.waitingRoom)
              .single
              .orientation,
          isNull,
          reason: '★4.12 に向きの規定は無い（4.3.1）');
      expect(_rotated(id), findsNothing, reason: '★控え室で横向きのまま残っている');
    });
  });
}
