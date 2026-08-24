/// 盤面のレイアウト（決定 D75 / D76 / D46）.
///
/// ★★ 鏡像は見た目の都合ではなく条文の要求である ★★
/// 4.5.7.1「左サイドエリアの正面は他プレイヤーの**右サイドエリア**が、
/// センターエリアは他プレイヤーのセンターエリアが、
/// 右サイドエリアは他プレイヤーの**左サイドエリア**がそれぞれ該当します」
///
/// → **正面同士が縦に揃っていること**を中心 x で見る。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_slot.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/common/card_thumb.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

void main() {
  Future<void> pumpBoard(
    WidgetTester tester, {
    String viewerId = kSelfPlayerId,
    GameState? state,
    Size size = const Size(1600, 1200),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      BoardPage(
        initialState: state ?? boardFixtureState(),
        viewerId: viewerId,
        seed: 1,
      ),
      decks: FakeDeckRepository(),
      catalog: realShapedCatalog(),
    );
  }

  Finder memberSlot(String playerId, MemberAreaSlot slot) =>
      find.byKey(ValueKey('member-$playerId-${slot.name}'));

  group('★★ 4.5.7.1 の鏡像配置（決定 D75）★★', () {
    testWidgets('自分の左サイドの正面に相手の右サイドが来る', (tester) async {
      await pumpBoard(tester);

      final mine = tester.getCenter(
          memberSlot(kSelfPlayerId, MemberAreaSlot.leftSide));
      final facing = tester.getCenter(
          memberSlot(kOpponentPlayerId, MemberAreaSlot.rightSide));

      expect(facing.dx, closeTo(mine.dx, 0.5),
          reason: '★正面同士が縦に揃っていない');
      expect(facing.dy, lessThan(mine.dy), reason: '★相手は上段');
    });

    testWidgets('自分の右サイドの正面に相手の左サイドが来る', (tester) async {
      await pumpBoard(tester);

      expect(
        tester
            .getCenter(memberSlot(kOpponentPlayerId, MemberAreaSlot.leftSide))
            .dx,
        closeTo(
          tester
              .getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.rightSide))
              .dx,
          0.5,
        ),
      );
    });

    testWidgets('センターの正面はセンター', (tester) async {
      await pumpBoard(tester);

      expect(
        tester
            .getCenter(memberSlot(kOpponentPlayerId, MemberAreaSlot.center))
            .dx,
        closeTo(
          tester
              .getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.center))
              .dx,
          0.5,
        ),
      );
    });

    testWidgets('★★ 対: 同じ側どうしは揃っていない ★★', (tester) async {
      // ★これが無いと「全部同じ x に並べる実装」でも上の 3 件が通ってしまう。
      await pumpBoard(tester);

      expect(
        tester
            .getCenter(memberSlot(kOpponentPlayerId, MemberAreaSlot.leftSide))
            .dx,
        isNot(closeTo(
          tester
              .getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.leftSide))
              .dx,
          1,
        )),
        reason: '★鏡像なら左サイドどうしは別の列に来る',
      );
    });

    testWidgets('★自分の行は 4.5.2.2 のとおり 左→中→右', (tester) async {
      await pumpBoard(tester);

      final left =
          tester.getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.leftSide));
      final center =
          tester.getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.center));
      final right =
          tester.getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.rightSide));

      expect(left.dx, lessThan(center.dx));
      expect(center.dx, lessThan(right.dx));
    });
  });

  group('★★ viewerId を切り替えると上下が入れ替わる（決定 D75）★★', () {
    testWidgets('切替の前後で上下が反転する', (tester) async {
      await pumpBoard(tester);

      double centerYOf(String playerId) =>
          tester.getCenter(memberSlot(playerId, MemberAreaSlot.center)).dy;

      expect(centerYOf(kSelfPlayerId), greaterThan(centerYOf(kOpponentPlayerId)),
          reason: '★はじめは自分が下段');

      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      expect(centerYOf(kOpponentPlayerId), greaterThan(centerYOf(kSelfPlayerId)),
          reason: '★切り替えたら相手が下段');
    });

    testWidgets('★鏡像も追随する（切替後も正面が縦に揃う）', (tester) async {
      await pumpBoard(tester);
      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      // ★下段が相手になったので、相手の左サイドの正面は自分の右サイド。
      expect(
        tester
            .getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.rightSide))
            .dx,
        closeTo(
          tester
              .getCenter(memberSlot(kOpponentPlayerId, MemberAreaSlot.leftSide))
              .dx,
          0.5,
        ),
      );
    });

    testWidgets('★手札の帯も追随する（下段の手札が下に来る）', (tester) async {
      await pumpBoard(tester);

      double handYOf(String playerId) =>
          tester.getCenter(find.byKey(ValueKey('hand-$playerId'))).dy;

      expect(handYOf(kSelfPlayerId), lessThan(handYOf(kOpponentPlayerId)));

      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      expect(handYOf(kOpponentPlayerId), lessThan(handYOf(kSelfPlayerId)));
    });

    testWidgets('★視点を替えても盤面の状態は変わらない（GameAction ではない）',
        (tester) async {
      await pumpBoard(tester);

      // 枚数（4.1.2.2）が変わらないことで見る。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
    });
  });

  group('★ 共有解決領域は中央 1 本（4.14.1 / 決定 D75）', () {
    testWidgets('解決領域はプレイヤーごとに 2 本置かれていない', (tester) async {
      await pumpBoard(tester);

      expect(find.byKey(const ValueKey('resolution-shared')), findsOneWidget);
    });

    testWidgets('★ownerId で分けて出す（8.3.14 が絞るため）', (tester) async {
      await pumpBoard(tester);

      expect(find.textContaining('自分のカード'), findsOneWidget);
      expect(find.textContaining('相手のカード'), findsOneWidget);
    });

    testWidgets('★自分と相手のあいだ（上下の中間）に置かれている', (tester) async {
      await pumpBoard(tester);

      final resolution =
          tester.getCenter(find.byKey(const ValueKey('resolution-shared'))).dy;

      expect(
        resolution,
        greaterThan(tester
            .getCenter(memberSlot(kOpponentPlayerId, MemberAreaSlot.center))
            .dy),
      );
      expect(
        resolution,
        lessThan(tester
            .getCenter(memberSlot(kSelfPlayerId, MemberAreaSlot.center))
            .dy),
      );
    });
  });

  group('★★ スロットの箱は例外なく kCardAspectRatio（決定 D76）★★', () {
    /// ★D72 の Phase 3b 節は「4.6 / 4.10 はライブ専用なので横長にできる」と
    /// 書いていたが、4.6 について**誤り**である（8.2.2 / 8.2.4 のブラフ）。
    testWidgets('メンバーエリア / ライブ / 成功ライブ / 控え室 の箱がすべて同じ比',
        (tester) async {
      await pumpBoard(tester);

      final targets = <Finder>[
        memberSlot(kSelfPlayerId, MemberAreaSlot.center),
        find.byKey(const ValueKey('zone-liveStage-$kSelfPlayerId')),
        find.byKey(const ValueKey('zone-successLive-$kSelfPlayerId')),
        find.byKey(const ValueKey('zone-waitingRoom-$kSelfPlayerId')),
        find.byKey(const ValueKey('zone-exile-$kSelfPlayerId')),
        find.byKey(const ValueKey('zone-energyField-$kSelfPlayerId')),
      ];

      for (final target in targets) {
        final box = tester.getSize(
          find.descendant(of: target, matching: find.byType(SizedBox)).first,
        );
        expect(box.width / box.height, closeTo(kCardAspectRatio, 0.01),
            reason: '★種別や領域で箱の比を変えない（D47 の DropEdge が高さ基準）');
      }
    });

    testWidgets('★対: 盤面のすべての BoardSlot が同じ比（大きさは違ってよい）',
        (tester) async {
      // ★手札・解決領域の札は小さく出すが、**比は変えない**（決定 D76）。
      await pumpBoard(tester);

      final slots = find.byType(BoardSlot);
      expect(slots, findsWidgets);

      // ★★ BoardSlot そのものを測らない ★★
      //   `label` を渡した BoardSlot は Column を返すので、
      //   `getSize` が「箱 + 見出し」の寸法になり **0.61 あたりになる**。
      //   測るのは中の箱（最初の SizedBox）である。
      for (var i = 0; i < slots.evaluate().length; i++) {
        final box = tester.getSize(
          find
              .descendant(of: slots.at(i), matching: find.byType(SizedBox))
              .first,
        );
        expect(box.width / box.height, closeTo(kCardAspectRatio, 0.01),
            reason: '★$i 番目の箱の比が違う');
      }
    });

    testWidgets('★小さく出す箱もある（「全部同じ寸法」ではないことの確認）',
        (tester) async {
      await pumpBoard(tester);

      final widths = <double>{
        for (var i = 0; i < find.byType(BoardSlot).evaluate().length; i++)
          tester
              .getSize(find
                  .descendant(
                      of: find.byType(BoardSlot).at(i),
                      matching: find.byType(SizedBox))
                  .first)
              .width,
      };

      expect(widths.length, greaterThan(1),
          reason: '★寸法は場所で変わる。変えないのは**比**である');
    });
  });

  group('★ 空きスロットと背景は描画物である（決定 D46）', () {
    /// [point] を叩いたとき、[finder] の描画オブジェクトが当たり判定に入るか。
    ///
    /// ★★ 「そこに何か描かれている」ことの検査である ★★
    /// D46 が実際に踏んだのは「行の余白を押すと掴めない」——
    /// 透明な領域は `hitTest` に出てこない。M-B2 のドラッグはこの上に載る。
    bool hits(WidgetTester tester, Finder finder, Offset point) {
      final target = tester.renderObject(finder);
      return tester
          .hitTestOnBinding(point)
          .path
          .any((entry) => identical(entry.target, target));
    }

    testWidgets('★空のメンバーエリアは中心で当たる', (tester) async {
      await pumpBoard(tester);

      final slot = memberSlot(kSelfPlayerId, MemberAreaSlot.center);
      // ★★ カードが 1 枚も置かれていないことを先に確かめる ★★
      //   置かれていると絵の上を叩いて通ってしまう（D-10 と同じ形）。
      expect(find.descendant(of: slot, matching: find.byType(CardArt)),
          findsNothing);

      final box = tester.getRect(
          find.descendant(of: slot, matching: find.byType(DecoratedBox)).first);
      expect(hits(tester, find.byType(BoardPage), box.center), isTrue);

      // ★★ 対: 背景そのものが当たっていること ★★
      //   `BoardPage` は Scaffold ごと当たるので、それだけでは何も証明しない。
      final decorated = find
          .descendant(of: slot, matching: find.byType(DecoratedBox))
          .first;
      expect(hits(tester, decorated, box.center), isTrue,
          reason: '★空きスロットの背景が描画物でない = M-B2 で落とせない');
    });

    testWidgets('★★ 対照実験: 塗りを持たない同じ寸法の箱は当たらない ★★', (tester) async {
      // ★これが通らなくなったら「ウィジェットテストでは D46 が再現しない」
      //   という意味であり、**上のテストが何も証明していない**ことを示す。
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              key: const ValueKey('bare-box'),
              width: kBoardSlotWidth,
              height: kBoardSlotWidth / kCardAspectRatio,
            ),
          ),
        ),
      );

      final bare = find.byKey(const ValueKey('bare-box'));
      expect(hits(tester, bare, tester.getCenter(bare)), isFalse,
          reason: '★塗りが無ければ当たらない = D46 がテストで再現している');
    });
  });

  group('★ 最小幅を下回ったら盤面ごとスクロールする（決定 D75 / 未決 U16）', () {
    testWidgets('狭い窓でも落ちず、置き場はすべて残る', (tester) async {
      await pumpBoard(tester, size: const Size(900, 900));

      expect(find.byType(BoardPage), findsOneWidget);
      // ★PaneScaffold を使っていないので 1 ペインに縮退する分岐は無い。
      //   置き場はすべて存在したまま、盤面ごとスクロールする。
      expect(memberSlot(kSelfPlayerId, MemberAreaSlot.center), findsOneWidget);
      expect(memberSlot(kOpponentPlayerId, MemberAreaSlot.center),
          findsOneWidget);
    });

    testWidgets('★★ kBoardMinWidth で溢れない（U16 の暫定値の裏づけ）★★',
        (tester) async {
      // ★★ 暫定値は「置いただけ」にしない ★★
      //   U8 / D61 と同じ手順で、暫定値を置いた時点で**その値で成立すること**を
      //   固定しておく。実測（物理px と可読性）は M-B2 の U16。
      //
      //   ★溢れ（RenderFlex overflow）は `pumpAndSettle` の中で例外になるので、
      //   このテストが通ること自体が「溢れていない」の検査になっている。
      await pumpBoard(tester, size: const Size(kBoardMinWidth, 1200));

      // ★11 の置き場 + 共有 1 がすべて存在する（4.4 は実体を持たないので数えない）。
      for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
        for (final slot in MemberAreaSlot.values) {
          expect(memberSlot(playerId, slot), findsOneWidget);
        }
        for (final zone in ['liveStage', 'successLive', 'energyField',
            'waitingRoom', 'exile']) {
          expect(find.byKey(ValueKey('zone-$zone-$playerId')), findsOneWidget);
        }
        expect(find.byKey(ValueKey('pile-main-$playerId')), findsOneWidget);
        expect(find.byKey(ValueKey('pile-energy-$playerId')), findsOneWidget);
        expect(find.byKey(ValueKey('hand-$playerId')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('resolution-shared')), findsOneWidget);
    });
  });
}
