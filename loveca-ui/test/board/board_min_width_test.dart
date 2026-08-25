/// 盤面の最小ウィンドウ幅（未決 **U16** の検算 / 決定 D83）.
///
/// ★★ 根拠の格を分けて書く（U8 / D61 と同じ手順）★★
///
/// | # | 根拠 | 格 |
/// |---|---|---|
/// | (a) | 外部標準 | ★**存在しない。** Material 3 の 840dp は「ペインを何枚出すか」の境界であり、D75 が盤面のペイン縮退を禁じている以上、この盤面に当てられる外部標準が無い。★**「無い」ことを書く**のが格を分けるということ |
/// | (b-1) | 構造の下限 = **溢れない最小幅**（このファイルが二分探索する） | 実測（テスト用フォント） |
/// | (b-2) | 使える下限 = **6.2.1.5 の初期手札が同時に見える幅**（同上） | ★**条文由来**の基準 |
/// | (b-3) | 可読性 = 実機での物理px と目視 | 実測（実機 / `docs/決定事項一覧.md` D83） |
///
/// ★★ 「溢れない」は「使える」ではない ★★
/// U8 と同じ注意。文字は ellipsis で潰れるので、幅を削っても溢れずに
/// **読めなくなるだけ**である。(b-1) は溢れの下限であって使える幅ではない。
/// → 使える下限は**条文から取る**（(b-2)）。「見た目の好み」で決めない。
///
/// ★★ 札の大きさはウィンドウ幅で変わらない ★★
/// スロットは `kBoardSlotWidth` の固定値なので、窓を広げても札は大きくならない。
/// **(b-3) の可読性は `kBoardSlotWidth` の話であって `kBoardMinWidth` の話ではない。**
/// 窓幅が決めるのは「同時に何が見えるか」だけである。
///
/// ★★ 2 つの下限がある ★★
/// 盤面（`BoardLayout`）は最小幅を下回ると**横スクロールする**ので溢れない。
/// 溢れうるのは進行バー・帯・`AppBar` のほうである。**両方測る。**
///
/// | # | 何の下限か | 測り方 |
/// |---|---|---|
/// | 1 | 置き場 11 + 共有 1 が**横スクロールなしで**収まる幅 | `BoardLayout(minWidth: 0)` を幅で挟む |
/// | 2 | 盤面以外（`AppBar` / 進行バー / 帯）が溢れない幅 | `BoardPage` を窓幅で挟む |
///
/// ★★ 測る前に「削らないもの」を決めてある ★★
/// 置き場 11 + 共有 1 + ルール外 2（盤面設計メモ §4-1）。
/// **収まるよう表示を削ってから測ると検算にならない。**
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/state/board_notice.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_layout.dart';
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

const _fullHand = <String>[_live, _member, _energy, _live, _member, _energy];
const _fullZones = <Zone, List<String>>{
  Zone.hand: _fullHand,
  Zone.mainDeck: [_member, _member],
  Zone.energyDeck: [_energy, _energy],
  Zone.energyField: [_energy, _energy, _energy],
  Zone.liveStage: [_live, _member],
  Zone.successLive: [_live, _live],
  Zone.waitingRoom: [_member, _energy],
  Zone.exile: [_live, _member],
};
const _fullMembers = <MemberAreaSlot, List<String>>{
  MemberAreaSlot.leftSide: [_member, _member],
  MemberAreaSlot.center: [_member, _member],
  MemberAreaSlot.rightSide: [_member, _member],
};

/// ★★ 最も混んだ盤面 ★★
/// 両者のメンバーエリアに 2 人（10.4 待ち）+ 下のカード（4.5.5.1）+ 孤児
/// （4.5.5.4.1）、全領域に札、解決領域に両者のカード、フリーエリアにも札。
GameState _crowded() => handcraftedBoard(
      selfZones: _fullZones,
      opponentZones: _fullZones,
      selfMembers: _fullMembers,
      opponentMembers: _fullMembers,
      selfBeneath: const {
        MemberAreaSlot.leftSide: [_energy, _member],
        MemberAreaSlot.center: [_energy],
        MemberAreaSlot.rightSide: [_energy],
      },
      selfOrphans: const {
        MemberAreaSlot.center: [_energy, _member],
      },
      selfResolution: const [_live, _member],
      selfFreeArea: const [_energy, _live],
    );

/// 溢れを拾う。★溢れは paint 時に `FlutterError` として上がる。
///
/// ★★ `takeException` を使わない ★★
/// 溢れは複数箇所で同時に起きる。`takeException` は 1 つしか保持せず、
/// 2 つ目からは「Multiple exceptions」に化けて中身が読めない
/// （`test/ui/deck_pane_width_test.dart` と同じ手当て）。
///
/// ★★★ 溢れは **`RenderObject` ごとに 1 回しか**報告されない ★★★
/// `DebugOverflowIndicatorMixin._overflowReportNeeded` は一度報告すると false になり、
/// **`reassemble`（ホットリロード）でしか戻らない。**
/// 幅を変えて同じツリーを `pumpWidget` し直しても `RenderObject` は使い回されるので、
/// **2 回目以降の溢れが黙って落ちる。**
/// → 二分探索は「1 回目だけ真、あとは全部偽」になり、**下限のすぐ上に収束する。**
/// 実際、この手当てを入れる前の測定は (1) 376 / (2) 201（= 探索の下限 200 + 1）と出た。
///
/// ★これは D-10（検知手段自身が同じ罠を踏む）の実例である。
/// **手当て: 毎回ツリーを捨ててから組み直す。** `RenderObject` が作り直され、
/// `_overflowReportNeeded` が true に戻る。
Future<bool> _overflows(WidgetTester tester, Future<void> Function() pump) async {
  // ★★ ここが要（上の doc を参照）★★
  await tester.pumpWidget(const SizedBox.shrink());

  var overflowed = false;
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) {
      overflowed = true;
    } else {
      previous?.call(details);
    }
  };
  await pump();
  FlutterError.onError = previous;
  return overflowed;
}

/// 下限は溢れる幅、上限は溢れない幅であることを先に確かめてから挟む。
Future<double> _search(
  Future<bool> Function(double width) overflowsAt, {
  required double low,
  required double high,
}) async {
  expect(await overflowsAt(low), isTrue, reason: '★狭すぎれば溢れるはず');
  expect(await overflowsAt(high), isFalse, reason: '★広ければ溢れないはず');

  var lo = low;
  var hi = high;
  while (hi - lo > 1) {
    final mid = ((lo + hi) / 2).roundToDouble();
    if (await overflowsAt(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return hi;
}

void main() {
  testWidgets('★★ U16 (1): 置き場が横スクロールなしで収まる最小幅 ★★',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(tester.view.reset);

    final state = _crowded();
    final store = GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );
    addTearDown(store.dispose);

    Future<bool> overflowsAt(double width) => _overflows(tester, () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    height: 2200,
                    child: BoardView(
                      state: state,
                      viewerId: kSelfPlayerId,
                      catalog: realShapedCatalog(),
                      imageSource: const LocalDirectoryCardImageSource(null),
                      store: store,
                      // ★★ クランプを外して測る（本番では渡さない）★★
                      child: const BoardLayout(
                        onDrawEnergy: null,
                        minWidth: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        });

    final measured = await _search(overflowsAt, low: 200, high: 1600);

    // ignore: avoid_print
    print('★U16 測定 (1)（テスト用フォント）: '
        '置き場が横スクロールなしで収まる最小幅 = $measured 論理px');

    expect(measured, lessThanOrEqualTo(kBoardMinWidth),
        reason: '★採用している kBoardMinWidth では横スクロールが要る');
    // ★★ 探索が「下限 +1」に落ちていないこと ★★
    //   落ちていたら溢れの取りこぼし（`_overflows` の doc）が再発している。
    expect(measured, greaterThan(201),
        reason: '★下限のすぐ上に収束している = 溢れが報告されていない');
  });

  testWidgets('★★ U16 (2): 盤面以外（AppBar / 進行バー / 帯）が溢れない最小幅 ★★',
      (tester) async {
    // ★盤面そのものは最小幅を下回ると横スクロールするので溢れない。
    //   溢れうるのはスクロールしない部分である。
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<bool> overflowsAt(double width) => _overflows(tester, () async {
          tester.view.physicalSize = Size(width, 1400);
          await pumpInAppScope(
            tester,
            BoardPage(
              initialState: _crowded(),
              viewerId: kSelfPlayerId,
              seed: 1234567890,
              // ★帯 2 本（最も混む状態）。
              notices: const [
                MulliganNotImplemented(),
                DeckNotValid(playerLabel: '自分', issues: []),
              ],
            ),
            decks: FakeDeckRepository(),
            catalog: realShapedCatalog(),
          );
        });

    final measured = await _search(overflowsAt, low: 200, high: 1600);

    // ignore: avoid_print
    print('★U16 測定 (2)（テスト用フォント）: '
        '盤面以外が溢れない最小幅 = $measured 論理px');

    expect(measured, lessThanOrEqualTo(kBoardMinWidth));
    expect(measured, greaterThan(201),
        reason: '★下限のすぐ上に収束している = 溢れが報告されていない');
  });

  testWidgets('★採用値 kBoardMinWidth では溢れない（最も混んだ盤面で）',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final overflowed = await _overflows(tester, () async {
      tester.view.physicalSize = const Size(kBoardMinWidth, 1400);
      await pumpInAppScope(
        tester,
        BoardPage(
          initialState: _crowded(),
          viewerId: kSelfPlayerId,
          seed: 1,
          notices: const [MulliganNotImplemented()],
        ),
        decks: FakeDeckRepository(),
        catalog: realShapedCatalog(),
      );
    });

    expect(overflowed, isFalse);

    // ★11 の置き場 + 共有 1 がすべて存在する（4.4 は実体を持たないので数えない）。
    for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
      for (final slot in MemberAreaSlot.values) {
        expect(find.byKey(ValueKey('member-$playerId-${slot.name}')),
            findsOneWidget);
      }
      for (final zone in [
        Zone.liveStage,
        Zone.successLive,
        Zone.energyField,
        Zone.waitingRoom,
        Zone.exile,
      ]) {
        expect(find.byKey(ValueKey('zone-${zone.name}-$playerId')),
            findsOneWidget);
      }
      expect(find.byKey(ValueKey('pile-main-$playerId')), findsOneWidget);
      expect(find.byKey(ValueKey('pile-energy-$playerId')), findsOneWidget);
      expect(find.byKey(ValueKey('hand-$playerId')), findsOneWidget);
      // ★ルール外の 2 つ（4 章の領域と同じ見た目にしない / 3a-1）。
      expect(find.byKey(ValueKey('free-area-$playerId')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('resolution-shared')), findsOneWidget);
    expect(find.textContaining('脇置き 6.2.1.6'), findsOneWidget);
  });

  testWidgets('★★ U16 (3): 6.2.1.5 の初期手札 6 枚が同時に見える最小幅 ★★',
      (tester) async {
    // ★★ 「溢れない」は「使える」ではない ★★
    //   (1)(2) は**溢れの下限**であって、その幅で回せるという意味ではない。
    //   使えるかどうかの下限は**条文から取る** —— 6.2.1.5 は初期手札を
    //   `RuleConfig.initialHandSize` 枚と定めており、それが同時に見えなければ
    //   毎ターン横スクロールしながら回すことになる。
    //   ★これは「見た目の好み」ではなく条文由来の基準である。
    //
    //   ★盤面のクランプ（`kBoardMinWidth`）を外して測る。外さないと
    //   窓をいくら狭めても中身は 1100 のまま横スクロールになり、**常に見える**。
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(3000, 2400);
    addTearDown(tester.view.reset);

    // ★★ 探索の途中では当然溢れる。ここで見たいのは溢れではない ★★
    //   溢れ以外の例外は握らず元のハンドラへ流す（決定 D53 と同じ考え方）。
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.exceptionAsString().contains('overflowed')) {
        previous?.call(details);
      }
    };
    addTearDown(() => FlutterError.onError = previous);

    final state = handcraftedBoard(selfZones: const {Zone.hand: _fullHand});
    expect(state.playerOf(kSelfPlayerId).hand,
        hasLength(RuleConfig.standard.initialHandSize),
        reason: '★前提: 6.2.1.5 の枚数');

    final store = GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );
    addTearDown(store.dispose);

    Future<bool> allVisibleAt(double width) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 2200,
                child: BoardView(
                  state: state,
                  viewerId: kSelfPlayerId,
                  catalog: realShapedCatalog(),
                  imageSource: const LocalDirectoryCardImageSource(null),
                  store: store,
                  child: const BoardLayout(onDrawEnergy: null, minWidth: 0),
                ),
              ),
            ),
          ),
        ),
      );

      final strip =
          tester.getRect(find.byKey(const ValueKey('hand-$kSelfPlayerId')));
      // ★★ `ListView` は画面外を作らない ★★
      //   末尾の札が組まれていなければ見えていない（D-10 と同じ形）。
      final last = state.playerOf(kSelfPlayerId).hand.last;
      final finder = find.byKey(ValueKey('board-card-${last.instanceId}'));
      if (finder.evaluate().isEmpty) return false;
      return tester.getRect(finder).right <= strip.right + 0.5;
    }

    expect(await allVisibleAt(400), isFalse, reason: '★狭ければ見えないはず');
    expect(await allVisibleAt(1600), isTrue);

    var lo = 400.0;
    var hi = 1600.0;
    while (hi - lo > 1) {
      final mid = ((lo + hi) / 2).roundToDouble();
      if (await allVisibleAt(mid)) {
        hi = mid;
      } else {
        lo = mid;
      }
    }

    // ignore: avoid_print
    print('★U16 測定 (3): 6.2.1.5 の初期手札 6 枚が同時に見える最小幅 = $hi 論理px');

    expect(hi, lessThanOrEqualTo(kBoardMinWidth),
        reason: '★採用値では初期手札が全部見えない');
  });
}
