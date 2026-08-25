/// 盤面の物理操作（M-B2 / 決定 D46 / D47 / D72 / D85）.
///
/// ★★ M-B2 が確認するのはこれである ★★
/// D72 のあと**絵はスロットを埋めない**。ライブの札（200:143）は縦長の箱（200:279）の
/// 上下に**透明な帯**を残す。掴める矩形を作るのは絵ではなく
/// `CardDragSource.background` の `ColoredBox` である（D46）。
/// 怠ると「**ライブだけ帯を掴めない**」という種別依存の、例外も出ない不具合になる。
///
/// ★★ 掴む点が絵の外であることを先に検査する ★★
/// そうしないと絵の上を掴んで通ってしまう（`test/ui/card_art_test.dart` と同じ形）。
/// 帯の厚みに `> 10` を要求するのは、枠線 1 + 余白 2 では満たせない値だから。
///
/// ★★ 対照実験は 2 段ある ★★
///
/// | # | 何を見るか | どこ |
/// |---|---|---|
/// | 1 | **常設** —— 同じ寸法・同じ絵の形を素の `Draggable` で包むと帯で掴めない | このファイル |
/// | 2 | **手作業（1 回）** —— `card_drag.dart` の `ColoredBox` を外すと**このファイルが落ちる** | `docs/決定事項一覧.md` D85 に結果を記録 |
///
/// 1 が落ちたら「ウィジェットテストでは D46 が再現しない」という意味であり、
/// **成功側のテストが何も証明していない**ことを示す（D-10）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_slot.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/board/board_view.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

/// ★実在のライブ（200×143 / 横長）と実在のメンバー（200×279 / 縦長）。
const _live = drawLivePrinting;
const _member = trioMemberPrinting;

/// 札の絵そのもの（枠）。
///
/// ★★ `CardArt` ではなく中の `CardThumb` を測る ★★
///   `CardArt` は `Center(AspectRatio(...))` なので**箱と同じ矩形**を持つ。
///   これを測ると帯の厚みが常に 0 になり、**帯を叩いていないのに通る**
///   （`test/ui/card_art_test.dart` が `CardThumb` を測っているのと同じ理由）。
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

Finder _memberSlot(MemberAreaSlot slot, [String playerId = kSelfPlayerId]) =>
    find.byKey(ValueKey('member-$playerId-${slot.name}'));

/// 箱（[BoardSlot] の中の寸法つき `SizedBox`）。
Rect _box(WidgetTester tester, Finder slot) => tester.getRect(
      find.descendant(of: slot, matching: find.byType(SizedBox)).first,
    );

/// ★★ 絵の外・箱の中（＝ D72 が作った帯）の 1 点 ★★
Offset _bandPoint(WidgetTester tester, String instanceId) {
  final box = _box(tester, _slotOf(instanceId));
  final art = tester.getRect(_art(instanceId));
  final band = art.top - box.top;

  // ★★ ここを緩めると、帯を叩いていないのに通る（D-10 の形）★★
  expect(band, greaterThan(10),
      reason: '★帯が実際にある（枠線と余白ではない）ことを先に確かめる');
  return Offset(box.center.dx, box.top + band / 2);
}

/// 札の箱の中心。★帯を持たない札（メンバー / エネルギー）を掴むときはこちら。
///
/// ★[_bandPoint] は**ライブ専用**である。メンバーの絵は箱を埋めるので帯が 0 になる。
Offset _cardPoint(WidgetTester tester, String instanceId) =>
    _box(tester, _slotOf(instanceId)).center;

Future<void> _drag(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  bool longPress = false,
}) async {
  final gesture = await tester.startGesture(from, kind: kind);
  if (longPress) {
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  }
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// 落とさずに「乗っている」状態まで持っていく。★呼び出し側が `up()` すること。
Future<TestGesture> _hover(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
}) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  return gesture;
}

Future<void> _pumpBoard(
  WidgetTester tester,
  GameState state, {
  DragStartMode mode = DragStartMode.immediate,
  Size size = const Size(1600, 1300),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await pumpInAppScope(
    tester,
    BoardPage(
      initialState: state,
      viewerId: kSelfPlayerId,
      mode: BoardMode.localVersus,
      seed: 1,
      dragStartMode: mode,
    ),
    decks: FakeDeckRepository(),
    catalog: realShapedCatalog(),
  );
}

/// 盤面が実際に配っている視点（＝ 実物の `GameStore` へ届く経路）。
///
/// ★ダイアログが同じ視点を配り直す（`BoardView.provideTo`）ので `.first` を取る。
BoardView _view(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView).first);

GameState _state(WidgetTester tester) => _view(tester).state;

/// ★★ 直接 `GameState` を書き換えていないことの証拠 ★★
/// `GameStore.dispatch` は `GameSession.apply` を通るので、
/// 1 操作につき履歴がちょうど 1 件積まれる（`reduce.dart` の `SessionReduce`）。
int _historyDepth(WidgetTester tester) =>
    _view(tester).store.value.session.history.depth;

void main() {
  group('★★ D46 / D72: 盤面の各所でライブの札の帯を掴める ★★', () {
    /// 5 か所すべてにライブとメンバーを 1 枚ずつ置いた盤面。
    ///
    /// ★★ 落とす先は 4.13 除外領域に統一する ★★
    ///   どの出どころからでも 1 手で届き（4.1.7 のオーナー一致）、
    ///   **どの出どころとも重ならない**ので `MoveIgnored` にならない。
    GameState crowded() => handcraftedBoard(
          selfZones: const {
            Zone.hand: [_live, _member],
            Zone.liveStage: [_live, _member],
            Zone.waitingRoom: [_live, _member],
          },
          selfMembers: const {MemberAreaSlot.center: [_member]},
          selfResolution: const [_live, _member],
        );

    /// メンバーエリアだけはライブを置けない（`PlaceMemberInArea` は 4.5.1）。
    /// ★4.5 の帯は**メンバー**で見る。ライブは残り 4 か所で見る。
    final places = <String, Zone?>{
      '手札 4.11': Zone.hand,
      'ライブカード置き場 4.6': Zone.liveStage,
      '控え室 4.12': Zone.waitingRoom,
      '解決領域 4.14': null,
    };

    for (final entry in places.entries) {
      testWidgets('★ライブの帯（絵の外・箱の中）から掴める — ${entry.key}',
          (tester) async {
        await _pumpBoard(tester, crowded());

        final state = _state(tester);
        final id = entry.value == null
            ? state.resolution.firstWhere((c) => c.printingId == _live).instanceId
            : cardsIn(state, kSelfPlayerId, entry.value!)
                .firstWhere((c) => c.printingId == _live)
                .instanceId;

        await _drag(
          tester,
          from: _bandPoint(tester, id),
          to: tester.getCenter(_zone(Zone.exile)),
        );

        expect(
          [for (final c in _state(tester).playerOf(kSelfPlayerId).exile)
            c.instanceId],
          contains(id),
          reason: '★${entry.key}のライブの帯から掴めていない（D46）',
        );
      });

      testWidgets('★対: メンバーも同じ点で掴める — ${entry.key}', (tester) async {
        // ★★ 出る側だけ見ると「ライブだけ直した」実装でも通る ★★
        //   種別依存の不具合を疑うのだから、必ず対で見る。
        await _pumpBoard(tester, crowded());

        final state = _state(tester);
        final live = entry.value == null
            ? state.resolution.firstWhere((c) => c.printingId == _live)
            : cardsIn(state, kSelfPlayerId, entry.value!)
                .firstWhere((c) => c.printingId == _live);
        final member = entry.value == null
            ? state.resolution.firstWhere((c) => c.printingId == _member)
            : cardsIn(state, kSelfPlayerId, entry.value!)
                .firstWhere((c) => c.printingId == _member);

        // ★★ ライブの帯と**同じ相対位置**を使う ★★
        //   箱の寸法は場所で変わる（山の 1 枚目は大きく、あふれた札は小さい）。
        //   変わらないのは**比**である（決定 D76）。だから割合で合わせる。
        final liveBox = _box(tester, _slotOf(live.instanceId));
        final memberBox = _box(tester, _slotOf(member.instanceId));
        expect(
          memberBox.width / memberBox.height,
          closeTo(liveBox.width / liveBox.height, 0.01),
          reason: '★D76: 箱の比は種別でも場所でも変わらない',
        );

        final fraction =
            (tester.getRect(_art(live.instanceId)).top - liveBox.top) /
                liveBox.height;
        expect(fraction, greaterThan(0.1), reason: '★前提: ライブには帯がある');

        await _drag(
          tester,
          from: Offset(
            memberBox.center.dx,
            memberBox.top + memberBox.height * fraction / 2,
          ),
          to: tester.getCenter(_zone(Zone.exile)),
        );

        expect(
          [for (final c in _state(tester).playerOf(kSelfPlayerId).exile)
            c.instanceId],
          contains(member.instanceId),
        );
      });
    }

    testWidgets('★メンバーエリア 4.5 のメンバーも帯から掴める', (tester) async {
      // ★メンバーの絵は箱を埋めるので「帯」は無い。
      //   代わりに**箱の上端すぐ内側**（絵の中だが D46 の踏んだ「余白」に相当）
      //   ではなく、**ライブと同じ相対位置**で掴めることを見る。
      await _pumpBoard(tester, crowded());

      final id = _state(tester)
          .playerOf(kSelfPlayerId)
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.center)
          .stacks
          .single
          .member
          .instanceId;

      final box = _box(tester, _memberSlot(MemberAreaSlot.center));
      await _drag(
        tester,
        from: Offset(box.center.dx, box.top + 4),
        to: tester.getCenter(_zone(Zone.exile)),
      );

      expect(
        [for (final c in _state(tester).playerOf(kSelfPlayerId).exile)
          c.instanceId],
        contains(id),
      );
    });
  });
  testWidgets('★★ 対照実験: 色を持たない素の Draggable は帯で掴めない ★★',
      (tester) async {
    // ★★ これが落ちたら、上の成功側は何も証明していない ★★
    //   「ウィジェットテストでは D46 が再現しない」という意味になるため。
    //   ★盤面の札と**同じ形**を組む——絵は箱を埋めず、上下に帯が残る（D72）。
    var dropped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BoardSlot(
                key: const ValueKey('control-slot'),
                child: Draggable<String>(
                  data: 'x',
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: const SizedBox(width: 20, height: 20),
                  // ★★ ColoredBox で包まない ★★
                  child: const Center(
                    child: AspectRatio(
                      aspectRatio: kLiveCardAspectRatio,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
              SizedBox(
                key: const ValueKey('control-target'),
                width: 200,
                height: 100,
                child: DragTarget<String>(
                  onAcceptWithDetails: (_) => dropped = true,
                  builder: (_, _, _) => const ColoredBox(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final box = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('control-slot')),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    final art = tester.getRect(find.byType(AspectRatio));
    final band = art.top - box.top;
    expect(band, greaterThan(10), reason: '★前提: 帯がある形になっている');

    final target = tester.getCenter(find.byKey(const ValueKey('control-target')));
    await _drag(
      tester,
      from: Offset(box.center.dx, box.top + band / 2),
      to: target,
    );
    expect(dropped, isFalse,
        reason: '★色の無い Center / AspectRatio は帯をヒットテストしない');

    // ★対: 絵の上からなら掴める（検査そのものが生きている）。
    await _drag(tester, from: art.center, to: target);
    expect(dropped, isTrue, reason: '★掴めないのは帯だけ、が確かめられていない');
  });

  group('★★ DragStartMode の両値でドラッグが成立する（決定 D52 (d) / D58）★★', () {
    // ★longPress は PC では使われない。使われない経路は `spike/` と同じ性質で腐る。
    for (final mode in DragStartMode.values) {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets('${mode.name} / ${kind.name}', (tester) async {
          await _pumpBoard(
            tester,
            handcraftedBoard(selfZones: const {
              Zone.hand: [_live],
            }),
            mode: mode,
          );

          final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
          await _drag(
            tester,
            from: _bandPoint(tester, id),
            to: tester.getCenter(_zone(Zone.exile)),
            kind: kind,
            longPress: mode == DragStartMode.longPress,
          );

          expect(_state(tester).playerOf(kSelfPlayerId).exile, hasLength(1));
        });
      }
    }

    testWidgets('★longPress は長押ししなければ始まらない（出ない側）', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
        mode: DragStartMode.longPress,
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.exile)),
      );

      expect(_state(tester).playerOf(kSelfPlayerId).exile, isEmpty);
    });
  });

  group('★★ D47: 上半分 / 下半分の撃ち分け ★★', () {
    Finder band(DropEdge edge) => find.byKey(ValueKey(
        edge == DropEdge.leading ? 'drop-band-leading' : 'drop-band-trailing'));
    final hover = find.byKey(const ValueKey('drop-hover'));

    testWidgets('メンバーエリア: 上半分 = 置く 4.5.1 / 下半分 = 下に置く 4.5.5',
        (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.hand: [_live],
          },
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
        ),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _memberSlot(MemberAreaSlot.center));

      final gesture = await _hover(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.top + 6),
      );
      expect(band(DropEdge.leading), findsOneWidget);
      expect(find.text('上に置く 4.5.1'), findsOneWidget);

      await gesture.moveTo(Offset(box.center.dx, box.bottom - 6));
      await tester.pump();
      expect(band(DropEdge.trailing), findsOneWidget);
      expect(find.text('下に置く 4.5.5'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      // ★落としたあとは消える（出しっぱなしにしない）。
      expect(band(DropEdge.trailing), findsNothing);
    });

    testWidgets('★上半分に落とすと 2 人並ぶ（10.4 待ちの正規の中間状態）', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.hand: [_member],
          },
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
        ),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _memberSlot(MemberAreaSlot.center));
      await _drag(
        tester,
        // ★掴むのはメンバー（帯を持たない）。ライブの帯は D46 の群が見ている。
        from: _cardPoint(tester, id),
        to: Offset(box.center.dx, box.top + 6),
      );

      final area = _state(tester)
          .playerOf(kSelfPlayerId)
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.center);
      expect(area.stacks, hasLength(2));
      expect(area.stacks.last.member.instanceId, id,
          reason: '★末尾が「最も後から置かれたメンバー」（10.4.1）');
    });

    testWidgets('★下半分に落とすとメンバーの下に入る（4.5.5 / 5.10.1）', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.hand: [_live],
          },
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
        ),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _memberSlot(MemberAreaSlot.center));
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.bottom - 6),
      );

      final area = _state(tester)
          .playerOf(kSelfPlayerId)
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.center);
      expect(area.stacks, hasLength(1));
      expect(area.stacks.single.beneath.single.instanceId, id);
      // ★4.5.5.2: 下に重ねられたカードは向きを示す配置状態を持たない。
      expect(area.stacks.single.beneath.single.orientation, isNull);
    });

    testWidgets('★★ 順番を管理しない領域では帯が出ない（4.1.3）★★', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;

      for (final zone in [Zone.waitingRoom, Zone.exile, Zone.energyField]) {
        expect(zone.isOrdered, isFalse, reason: '★前提: ${zone.ruleRef}');
        final box = _box(tester, _zone(zone));

        final gesture = await _hover(
          tester,
          from: _bandPoint(tester, id),
          to: Offset(box.center.dx, box.bottom - 6),
        );
        expect(band(DropEdge.trailing), findsNothing,
            reason: '★${zone.ruleRef} に帯が出ている = 順番があるように見える');
        expect(band(DropEdge.leading), findsNothing);
        // ★対: 乗っていることは分かる（落とせるかどうかが読めないと困る）。
        expect(hover, findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('★★ メンバーが 0 人のスロットでも帯が出ない ★★', (tester) async {
      // ★「下に置く」先が無いので 2 通りにならない。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_member],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _memberSlot(MemberAreaSlot.center));

      final gesture = await _hover(
        tester,
        from: _cardPoint(tester, id),
        to: Offset(box.center.dx, box.bottom - 6),
      );
      expect(band(DropEdge.trailing), findsNothing);
      expect(hover, findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      // ★落ちた先は 4.5.1 の「置く」。
      expect(
        _state(tester)
            .playerOf(kSelfPlayerId)
            .memberAreas
            .firstWhere((a) => a.slot == MemberAreaSlot.center)
            .stacks,
        hasLength(1),
      );
    });

    testWidgets('★★ メンバーを掴んだときは帯が出ない（意味が 1 つ）★★', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfMembers: const {
          MemberAreaSlot.leftSide: [_member],
          MemberAreaSlot.center: [_member],
        }),
      );

      final from = _box(tester, _memberSlot(MemberAreaSlot.leftSide));
      final to = _box(tester, _memberSlot(MemberAreaSlot.center));

      final gesture = await _hover(
        tester,
        from: Offset(from.center.dx, from.top + 4),
        to: Offset(to.center.dx, to.bottom - 6),
      );
      // ★同じスロットでも、掴んだ札が違えば帯の有無が変わる。
      expect(band(DropEdge.trailing), findsNothing,
          reason: '★メンバーは 4.5.5.3 の移動しかできない。上下に意味が無い');
      expect(hover, findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        _state(tester)
            .playerOf(kSelfPlayerId)
            .memberAreas
            .firstWhere((a) => a.slot == MemberAreaSlot.center)
            .stacks,
        hasLength(2),
      );
    });

    testWidgets('★★ 4.8 メインデッキは順番が管理されるので帯が出る ★★', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
          Zone.mainDeck: [_member, _member],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(
        tester,
        find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
      );

      final gesture = await _hover(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.top + 6),
      );
      expect(find.text('一番上へ 4.8'), findsOneWidget);
      await gesture.moveTo(Offset(box.center.dx, box.bottom - 6));
      await tester.pump();
      expect(find.text('一番下へ 4.8'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();

      // ★下半分に落としたので一番下（末尾）に入る。
      final deck = _state(tester).playerOf(kSelfPlayerId).mainDeck;
      expect(deck, hasLength(3));
      expect(deck.last.instanceId, id);
    });

    testWidgets('★対: 4.8 の上半分に落とすと一番上に入る', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
          Zone.mainDeck: [_member, _member],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(
        tester,
        find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
      );
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.top + 6),
      );

      expect(
          _state(tester).playerOf(kSelfPlayerId).mainDeck.first.instanceId, id);
    });

    testWidgets('★★ 4.10 成功ライブは置き場所が定まっているので帯が出ない ★★',
        (tester) async {
      // ★★ 帯を出す条件はフラグではなく写像の答えである（決定 D85）★★
      //   4.10.2 が「これまでに置かれているカードの上に置かれます」と定めるので
      //   上下で答えが同じになり、帯は**自動的に**消える。
      //   → `board_drop.dart` には領域の一覧を書いていない。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
          Zone.successLive: [_live, _live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _zone(Zone.successLive));

      final gesture = await _hover(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.bottom - 6),
      );
      // ★★ 領域の見出し（「成功ライブ 4.10」）を拾わない文言で見ること ★★
      //   `textContaining('4.10')` にすると見出しが常に当たり、
      //   **帯を見ていないのに落ちる / 通る**。帯の文言は `board_drop.dart` が決める。
      expect(find.text('一番下へ 4.10'), findsNothing,
          reason: '★下半分の帯が出ている = 4.10.2 の 2 文目を無視している');
      await gesture.moveTo(Offset(box.center.dx, box.top + 6));
      await tester.pump();
      expect(find.text('一番上へ 4.10'), findsNothing,
          reason: '★上半分でも帯を出さない（上下で答えが同じだから）');
      await gesture.up();
      await tester.pumpAndSettle();

      // ★下半分に落としたのに一番上に入る（4.10.2）。
      final pile = _state(tester).playerOf(kSelfPlayerId).successLive;
      expect(pile, hasLength(3));
      expect(pile.first.instanceId, id);
    });

    testWidgets('★★ 対: 4.8 では帯が出続ける（4.10.2 は 4.10 だけの規定）★★',
        (tester) async {
      // ★この対が無いと「帯を全部消した」実装でも上の試験が通る。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
          Zone.mainDeck: [_member, _member],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(
        tester,
        find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
      );
      final gesture = await _hover(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.bottom - 6),
      );
      expect(find.text('一番下へ 4.8'), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('★★ メンバーが 2 人以上いるエリアへの「下に置く」（4.5.5 / 5.10.1）★★', () {
    /// センターに 2 人、手札にライブ 1 枚。
    GameState twoMembers() => handcraftedBoard(
          selfZones: const {
            Zone.hand: [_live],
          },
          selfMembers: const {
            MemberAreaSlot.center: [_member, _member],
          },
        );

    Future<void> dropUnder(WidgetTester tester) async {
      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      final box = _box(tester, _memberSlot(MemberAreaSlot.center));
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: Offset(box.center.dx, box.bottom - 6),
      );
    }

    testWidgets('★★ 選択が出る。黙って末尾のメンバーの下に入れない ★★', (tester) async {
      await _pumpBoard(tester, twoMembers());
      await dropUnder(tester);

      expect(find.byKey(const ValueKey('stack-under-choice')), findsOneWidget);
      // ★この時点ではまだ盤面が動いていない。
      expect(_historyDepth(tester), 0);

      final members = _state(tester)
          .playerOf(kSelfPlayerId)
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.center)
          .stacks;
      // ★★ 末尾ではないほう（先頭）を選ぶ ★★
      //   末尾を選ぶと「黙って末尾に入れる実装」でも通ってしまう。
      final chosen = members.first.member.instanceId;
      await tester.tap(find.byKey(ValueKey('stack-under-$chosen')));
      await tester.pumpAndSettle();

      final after = _state(tester)
          .playerOf(kSelfPlayerId)
          .memberAreas
          .firstWhere((a) => a.slot == MemberAreaSlot.center);
      expect(after.stacks.first.beneath, hasLength(1),
          reason: '★選んだメンバーの下に入っていない');
      expect(after.stacks.last.beneath, isEmpty,
          reason: '★末尾のメンバーの下に入っている = 選択が効いていない');
      expect(_historyDepth(tester), 1);
    });

    testWidgets('★やめると盤面が動かない（履歴も増えない）', (tester) async {
      await _pumpBoard(tester, twoMembers());
      await dropUnder(tester);

      await tester.tap(find.byKey(const ValueKey('stack-under-cancel')));
      await tester.pumpAndSettle();

      expect(_state(tester).playerOf(kSelfPlayerId).hand, hasLength(1),
          reason: '★手札から出ていってはいけない');
      expect(_historyDepth(tester), 0);
    });

    testWidgets('★対: メンバーが 1 人なら選択は出ない（選ぶものが無い）',
        (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(
          selfZones: const {
            Zone.hand: [_live],
          },
          selfMembers: const {
            MemberAreaSlot.center: [_member],
          },
        ),
      );
      await dropUnder(tester);

      expect(find.byKey(const ValueKey('stack-under-choice')), findsNothing);
      expect(_historyDepth(tester), 1);
    });
  });

  group('★★ 移動は GameAction を通る（決定 D53）★★', () {
    testWidgets('★1 操作につき履歴がちょうど 1 件増える', (tester) async {
      // ★★ 直接 `GameState` を書き換えていないことの証拠 ★★
      //   `GameStore.dispatch` は `GameSession.apply`（履歴に積んでから reduce）
      //   を通る。書き換えを別経路でやっていれば履歴は増えない。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live, _live],
        }),
      );

      expect(_historyDepth(tester), 0);

      for (var i = 1; i <= 2; i++) {
        final id = _state(tester).playerOf(kSelfPlayerId).hand.first.instanceId;
        await _drag(
          tester,
          from: _bandPoint(tester, id),
          to: tester.getCenter(_zone(Zone.exile)),
        );
        expect(_historyDepth(tester), i, reason: '★$i 回目で履歴が $i 件');
        expect(_state(tester).playerOf(kSelfPlayerId).exile, hasLength(i));
      }
    });

    // ★★ 手札を中継する合成（M-B5 / 決定 D78）★★
    //   写像は 7 経路あるが、**画面から通せるのは 6 経路**（脇置きは M-B6）。
    //   M-B5 以前はどれも「いったん手札などへ戻してから」と拒否していた。
    //   ★**1 経路だけ確かめても足りない** —— 他が 2 件積む実装でも通る。
    //   ★条文は禁じていない（4.5.5.4 / 4.14.1 / 4.5.1）。詳細は `board_drag.dart`。
    testWidgets('★★ 合成の 6 経路すべてで履歴がちょうど 1 件増える ★★', (tester) async {
      // ★★ 中継先の手札に札が残っていたら合成になっていない ★★
      //   1 件だけ積んで中間状態が残る実装を弾く。
      for (final route in _relayRoutes) {
        await _pumpBoard(tester, route.board());

        expect(_historyDepth(tester), 0, reason: '★${route.name}: 前提');
        final id = route.pick(_state(tester));

        await _drag(
          tester,
          // ★ここは D46 の帯の検査ではないので絵の中心を掴む
          //   （メンバーの札に帯は無い / `_bandPoint` は厚み > 10 を要求する）。
          from: tester.getCenter(_art(id)),
          to: tester.getCenter(route.target(tester)),
        );

        expect(_historyDepth(tester), 1,
            reason: '★${route.name}: 履歴が 1 件でなければ 1 回で戻せない');
        expect(route.landed(_state(tester)), contains(id),
            reason: '★${route.name}: 落ちていない（拒否されている）');
        expect(
          [for (final c in _state(tester).playerOf(kSelfPlayerId).hand)
            c.instanceId],
          isNot(contains(id)),
          reason: '★${route.name}: 中継した手札に残っている（合成になっていない）',
        );
      }
    });

    testWidgets('★★ 合成も 1 回の巻き戻しで元へ戻る ★★', (tester) async {
      // ★★ これが M-B5 で合成にした理由そのものである ★★
      //   2 件積んでいれば 1 回では戻り切らず、中継先の手札に残る。
      for (final route in _relayRoutes) {
        await _pumpBoard(tester, route.board());
        final before = _signatureOf(_state(tester));
        final id = route.pick(_state(tester));

        await _drag(
          tester,
          from: tester.getCenter(_art(id)),
          to: tester.getCenter(route.target(tester)),
        );
        _view(tester).store.undo();
        await tester.pumpAndSettle();

        expect(_signatureOf(_state(tester)), before,
            reason: '★${route.name}: 1 回の undo で元に戻っていない');
      }
    });

    testWidgets('★同じ場所へ落としたら履歴が増えない（MoveIgnored）', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.exile: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).exile.single.instanceId;
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.exile)),
      );

      expect(_historyDepth(tester), 0);
    });

    testWidgets('★★ 落とせないときは理由が出る（黙って何も起きない形にしない）★★',
        (tester) async {
      // ★4.1.7: メンバーエリアやライブカード置き場以外はオーナーの領域へ。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(_zone(Zone.waitingRoom, kOpponentPlayerId)),
      );

      expect(find.textContaining('4.1.7'), findsOneWidget);
      expect(_historyDepth(tester), 0);
    });

    testWidgets('★ルール外の置き場は別経路（OutOfRuleZone / 3a-1 §4.1）',
        (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.hand: [_live],
        }),
      );

      final id = _state(tester).playerOf(kSelfPlayerId).hand.single.instanceId;
      await _drag(
        tester,
        from: _bandPoint(tester, id),
        to: tester.getCenter(find.byKey(const ValueKey('free-area-$kSelfPlayerId'))),
      );

      expect(
        cardsInOutOfRule(
            _state(tester), kSelfPlayerId, OutOfRuleZone.freeArea),
        hasLength(1),
      );
      expect(_historyDepth(tester), 1);
    });
  });
}


// ===========================================================================
// ★★ 手札を中継する合成の経路表（M-B5）★★
// ===========================================================================

/// 掴む場所 → 落とす場所。どれも M-B5 以前は `MoveRefused` だった。
class _RelayRoute {
  const _RelayRoute({
    required this.name,
    required this.board,
    required this.pick,
    required this.target,
    required this.landed,
  });

  final String name;
  final GameState Function() board;

  /// 掴む札。★盤面から引く（instanceId を写さない）。
  final String Function(GameState) pick;
  final Finder Function(WidgetTester) target;

  /// 落ちたはずの場所の instanceId。
  final List<String> Function(GameState) landed;
}

const _relayMember = parallelMemberNormal;

GameState _boardWithMember() => handcraftedBoard(
      selfMembers: const {
        MemberAreaSlot.center: [_relayMember],
      },
    );

GameState _boardWithResolution() =>
    handcraftedBoard(selfResolution: const [_relayMember]);

GameState _boardWithFreeArea() =>
    handcraftedBoard(selfFreeArea: const [_relayMember]);

String _memberIn(GameState s) => s
    .playerOf(kSelfPlayerId)
    .memberAreas
    .firstWhere((a) => a.slot == MemberAreaSlot.center)
    .stacks
    .single
    .member
    .instanceId;

String _inResolution(GameState s) => s.resolution.single.instanceId;

String _inFreeArea(GameState s) =>
    cardsInOutOfRule(s, kSelfPlayerId, OutOfRuleZone.freeArea).single.instanceId;

List<String> _idsInFreeArea(GameState s) => [
      for (final c in cardsInOutOfRule(s, kSelfPlayerId, OutOfRuleZone.freeArea))
        c.instanceId,
    ];

List<String> _idsInResolution(GameState s) =>
    [for (final c in s.resolution) c.instanceId];

List<String> _idsInMemberArea(GameState s) => [
      for (final area in s.playerOf(kSelfPlayerId).memberAreas)
        for (final stack in area.stacks) stack.member.instanceId,
    ];

final _relayRoutes = <_RelayRoute>[
  _RelayRoute(
    name: 'メンバー 4.5 → 盤の外',
    board: _boardWithMember,
    pick: _memberIn,
    target: (t) => find.byKey(const ValueKey('free-area-$kSelfPlayerId')),
    landed: _idsInFreeArea,
  ),
  _RelayRoute(
    name: 'メンバー 4.5 → 解決領域 4.14',
    board: _boardWithMember,
    pick: _memberIn,
    target: (t) => find.byKey(const ValueKey('resolution-shared')),
    landed: _idsInResolution,
  ),
  _RelayRoute(
    name: '解決領域 4.14 → メンバーエリア 4.5',
    board: _boardWithResolution,
    pick: _inResolution,
    target: (t) => _memberSlot(MemberAreaSlot.leftSide),
    landed: _idsInMemberArea,
  ),
  _RelayRoute(
    name: '解決領域 4.14 → 盤の外',
    board: _boardWithResolution,
    pick: _inResolution,
    target: (t) => find.byKey(const ValueKey('free-area-$kSelfPlayerId')),
    landed: _idsInFreeArea,
  ),
  _RelayRoute(
    name: '盤の外 → メンバーエリア 4.5',
    board: _boardWithFreeArea,
    pick: _inFreeArea,
    target: (t) => _memberSlot(MemberAreaSlot.leftSide),
    landed: _idsInMemberArea,
  ),
  _RelayRoute(
    name: '盤の外 → 解決領域 4.14',
    board: _boardWithFreeArea,
    pick: _inFreeArea,
    target: (t) => find.byKey(const ValueKey('resolution-shared')),
    landed: _idsInResolution,
  ),
  // ★★ 「盤の外 → 盤の外（脇置き 6.2.1.6）」は画面に落とし先がまだ無い ★★
  //   脇置きは M-B6（マリガン）で置く。写像は `board_move_test.dart` が持つ。
  //   ★**「7 経路すべて」と書かないこと。**画面から通せるのは 6 経路である。
];

/// 盤面の要点だけの署名（巻き戻しで元へ戻ったことを見る）。
///
/// ★網羅は `test/state/board_session_test.dart` が持つ。ここは 1 枚の行き先だけ。
String _signatureOf(GameState state) => [
      _idsInMemberArea(state).join(','),
      _idsInResolution(state).join(','),
      _idsInFreeArea(state).join(','),
      [for (final c in state.playerOf(kSelfPlayerId).hand) c.instanceId].join(','),
    ].join('|');
