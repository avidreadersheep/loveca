/// 集計の表示（M-B3 / 決定 D18 / D86 / CLAUDE.md §6）.
///
/// ★★ ここで見たいのは「参照範囲を取り違えていないこと」である ★★
/// 数値そのものの正しさは `loveca-core/test/aggregation_test.dart` が固定している。
/// 画面側で起きうる失敗は**別**で、次の 2 つが本命。
///
/// 1. 8.3.12（所有者で**絞らない**）に playerId を渡して絞ってしまう
/// 2. 8.3.10（アクティブのみ）と 8.3.14（ウェイトを含む全員）を同じ範囲だと思い込む
///
/// → **同じ盤面で 2 つの答えが違うこと**を見る。片方だけ見ても取り違えは出ない。
///
/// ★★ 8.4.2 の null は「—」であって 0 ではない ★★
/// 8.4.3.2 が「片方だけカードがあるならそちらが大きい」と定めているので、
/// 0 で代用すると**スコア 0 のライブと同点になる**（実在する）。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/board_summary.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';

/// ブレード 5 / ハート 桃3 緑3 紫3。
const _bigMember = trioMemberPrinting;

/// ブレード 2 / ハート 桃1 緑1 青2。
const _smallMember = parallelMemberNormal;

/// ライブ。スコア 5 / ブレードハート 青1 / ★ドロー 1。
const _drawLive = drawLivePrinting;

/// ライブ。スコア 1 / ★スコアアイコン 1。
const _scoreLive = scoreLivePrinting;

/// ライブ。スコア 2 / ★ブレードハート ALL 1。
const _allLive = allBladeLivePrinting;

BoardSummary _summaryOf(GameState state, String playerId) =>
    BoardSummary.of(state, realShapedCatalog().cards, playerId: playerId);

void main() {
  group('★★ 8.3.10 と 8.3.14 は参照範囲が違う ★★', () {
    // 同じ盤面に、アクティブ 1 人（ブレード 5）とウェイト 1 人（ブレード 2）。
    final state = handcraftedBoard(
      selfMembers: const {
        MemberAreaSlot.center: [_bigMember],
      },
      selfWaitMembers: const {
        MemberAreaSlot.leftSide: [_smallMember],
      },
    );

    test('8.3.10 はアクティブ状態のメンバーだけを数える', () {
      expect(_summaryOf(state, kSelfPlayerId).blade.total, 5,
          reason: '★ウェイトの 2 を足さない');
    });

    test('★対: 8.3.14 はウェイトのメンバーのハートも数える', () {
      final hearts = _summaryOf(state, kSelfPlayerId).hearts.hearts;
      // アクティブ: 桃3 緑3 紫3 / ウェイト: 桃1 緑1 青2
      expect(hearts[HeartColor.pink], 4);
      expect(hearts[HeartColor.green], 4);
      expect(hearts[HeartColor.purple], 3);
      expect(hearts[HeartColor.blue], 2, reason: '★ウェイトのメンバーぶん');
    });
  });

  group('★★★ 8.3.12 と 8.3.14 の対比（同じ解決領域で片方は絞らない）★★★', () {
    // ★解決領域は共有 1 つ（4.14.1）。自分と相手のカードを 1 枚ずつ置く。
    //   どちらも `drawLive`（ドロー 1 / ブレードハート 青 1）。
    final state = handcraftedBoard(
      selfResolution: const [_drawLive],
      opponentResolution: const [_drawLive],
    );

    test('8.3.12 は解決領域のすべてのカードを数える（絞らない）', () {
      expect(state.resolution, hasLength(2), reason: '★前提: 共有領域に 2 枚');
      expect(_summaryOf(state, kSelfPlayerId).draw.count, 2);
      // ★どちらの視点でも同じ数（＝ 絞っていないことの裏取り）。
      expect(_summaryOf(state, kOpponentPlayerId).draw.count, 2);
    });

    test('★★ 対: 8.3.14 は自分のカードだけを数える ★★', () {
      final mine = _summaryOf(state, kSelfPlayerId).hearts.hearts;
      expect(mine[HeartColor.blue], 1, reason: '★相手の 1 枚を足さない');

      final theirs = _summaryOf(state, kOpponentPlayerId).hearts.hearts;
      expect(theirs[HeartColor.blue], 1);
    });

    test('★8.4.2.1 も自分のエールだけを数える', () {
      // 自分のライブ置き場にスコア 1 のライブ、解決領域に自分と相手のスコアアイコン。
      final scored = handcraftedBoard(
        selfZones: const {
          Zone.liveStage: [_scoreLive],
        },
        selfResolution: const [_scoreLive],
        opponentResolution: const [_scoreLive],
      );

      // ライブ置き場のスコア 1 ＋ 自分のエールのスコアアイコン 1 = 2
      expect(_summaryOf(scored, kSelfPlayerId).score.total, 2,
          reason: '★相手のエールのスコアアイコンを足さない');
    });
  });

  group('★★ 8.4.2 は空のとき null（0 ではない）★★', () {
    test('ライブカード置き場が空なら null', () {
      final state = handcraftedBoard();
      expect(_summaryOf(state, kSelfPlayerId).score.total, isNull);
      expect(_summaryOf(state, kSelfPlayerId).score.hasLiveCards, isFalse);
    });

    test('★対: カードがあれば数値', () {
      final state = handcraftedBoard(selfZones: const {
        Zone.liveStage: [_scoreLive],
      });
      expect(_summaryOf(state, kSelfPlayerId).score.total, 1);
    });
  });

  group('★★ ALL / GRAY を色に変換しない（8.3.15.1.1 は手動 / D18）★★', () {
    test('ALL は ALL のまま残る', () {
      final state = handcraftedBoard(selfResolution: const [_allLive]);
      final hearts = _summaryOf(state, kSelfPlayerId).hearts.hearts;

      expect(hearts[HeartColor.all], 1);
      // ★6 色のどれにも化けていない。
      for (final color in HeartColor.sixColors) {
        expect(hearts[color], isNull, reason: '★${color.name} に変換されている');
      }
    });

    test('★対: 色のブレードハートは色として出る', () {
      final state = handcraftedBoard(selfResolution: const [_drawLive]);
      final hearts = _summaryOf(state, kSelfPlayerId).hearts.hearts;
      expect(hearts[HeartColor.blue], 1);
      expect(hearts[HeartColor.all], isNull);
    });
  });

  group('★ 画面に出る（実物の経路）', () {
    Future<void> pumpBoard(WidgetTester tester, GameState state) async {
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
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    }

    testWidgets('4 種が条番号と参照範囲つきで出る', (tester) async {
      await pumpBoard(
        tester,
        handcraftedBoard(
          selfMembers: const {
            MemberAreaSlot.center: [_bigMember],
          },
          selfZones: const {
            Zone.liveStage: [_scoreLive],
          },
          selfResolution: const [_drawLive],
        ),
      );

      expect(find.byKey(const ValueKey('summary-panel')), findsOneWidget);
      // ★★ 範囲をツールチップだけにしていない（並べた 2 つを取り違えるため）★★
      expect(find.textContaining('ブレード合計 8.3.10'), findsWidgets);
      expect(find.textContaining('（アクティブ状態のメンバーのみ）'), findsWidgets);
      expect(find.textContaining('ライブ所有ハート 8.3.14'), findsWidgets);
      expect(find.textContaining('全メンバー（ウェイトを含む）'), findsWidgets);
      // ★8.3.12 は「共有」の行に 1 つだけ。
      expect(find.byKey(const ValueKey('summary-shared')), findsOneWidget);
      expect(find.textContaining('どちらのカードかで絞りません'), findsOneWidget);
      // ★出していないものを明示している（D18）。
      expect(find.textContaining('8.3.15'), findsOneWidget);
    });

    testWidgets('★★ 8.4.2 が空のとき「—」で、0 と出ない ★★', (tester) async {
      await pumpBoard(tester, handcraftedBoard());

      final score = find.descendant(
        of: find.byKey(const ValueKey('summary-score-$kSelfPlayerId')),
        matching: find.byType(Text),
      );
      final texts = tester.widgetList<Text>(score).map((t) => t.data).toList();

      expect(texts, contains('—'));
      expect(texts, isNot(contains('0')), reason: '★空を 0 で代用しない（8.4.3.2）');
      expect(texts.join(), contains('ライブカード置き場が空'));
    });

    testWidgets('★ALL が画面にも ALL として出る', (tester) async {
      await pumpBoard(tester, handcraftedBoard(selfResolution: const [_allLive]));

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('summary-hearts-$kSelfPlayerId')),
          matching: find.text('ALL 1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('★★ 畳んでも警告の帯は消えない ★★', (tester) async {
      // ★孤児（4.5.5.4.1）を作る。集計を畳んでも警告は残らなければならない。
      await pumpBoard(
        tester,
        handcraftedBoard(selfOrphans: const {
          MemberAreaSlot.center: [_smallMember],
        }),
      );

      expect(find.textContaining('上にメンバーが居なくなったカード'), findsOneWidget);
      expect(find.textContaining('ブレード合計 8.3.10'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('summary-toggle')));
      await tester.pumpAndSettle();

      expect(find.textContaining('ブレード合計 8.3.10'), findsNothing,
          reason: '★集計は畳めた');
      expect(find.textContaining('上にメンバーが居なくなったカード'), findsOneWidget,
          reason: '★★警告は畳めない（黙って落とさない）★★');
    });
  });
}
