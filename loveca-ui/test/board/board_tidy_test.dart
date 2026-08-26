/// 整理を手で回す口（M-B6 / 決定 D93 / 総合ルール 10.4 / 10.5）.
///
/// ★★ 実行するものと実行しないものを対で固定する ★★
/// 10.4 / 10.5 は**アプリが自動で実行してよい**。
/// 10.3（勝利処理 / D10）と 10.6（不正解決領域処理 / D-A）は**実行しない**。
/// ★実行する側だけを見ると「全部実行する実装」でも通る。
///
/// ★★ 押して何も当たらなかったことも黙らない ★★
/// 「黙って効かないボタンを作らない」の裏返し。★対で「当たったときは別の行が出る」
/// と「自動（チェックタイミング）の整理では出さない」を置く。
///
/// ★★ 整理ログの器は複数件である（盤面設計メモ §14-7 の持ち越し 4 つ目 / D-21）★★
/// 手で押した [Tidy] は 1 件しか出さないが、**M-B7 の自動進行は 1 押下で
/// 複数のチェックタイミングを通る**ので N 件出る。
/// ★M-B6 の完成条件ではないが、単数で作り込むと M-B7 で作り直しになる。
/// → `dispatchAll` に 2 件渡して**本当に 2 グループ出ること**を固定する。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/board_notice.dart';
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
const _energy = energyPrinting;

GameStore _storeFor(GameState state) => GameStore(
      initialState: state,
      viewerId: kSelfPlayerId,
      mode: BoardMode.localVersus,
      seed: 1,
      cards: realShapedCatalog().cards,
      rng: SeededRng(1),
    );

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

GameState _stateOf(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView).first).state;

/// 1 つのエリアにメンバーが 2 人（10.4 待ちの正規の中間状態）。
GameState _duplicateMembers() => handcraftedBoard(selfMembers: const {
      MemberAreaSlot.leftSide: [_member, _member],
    });

void main() {
  group('★★ 10.4 / 10.5 は手で回せる ★★', () {
    testWidgets('★ 重複メンバーが控え室へ移り、10.4.1 が帯に出る', (tester) async {
      await _pumpBoard(tester, _duplicateMembers());

      final before = _stateOf(tester).playerOf(kSelfPlayerId);
      expect(before.memberAreas.first.stacks, hasLength(2), reason: '★前提');
      expect(before.waitingRoom, isEmpty);

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      final after = _stateOf(tester).playerOf(kSelfPlayerId);
      expect(after.memberAreas.first.stacks, hasLength(1),
          reason: '★10.4.1「最も後から置かれたメンバーを 1 枚選び」');
      expect(after.waitingRoom, hasLength(1));
      expect(find.textContaining('同じエリアの重複メンバー 10.4.1'), findsOneWidget);
    });

    testWidgets('★ 孤児カード（4.5.5.4.1 / 4.5.5.4.2）も解消する', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfOrphans: const {
          MemberAreaSlot.center: [_member, _energy],
        }),
      );

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      final after = _stateOf(tester).playerOf(kSelfPlayerId);
      expect(after.memberAreas[1].orphans, isEmpty);
      // ★行き先は種別で分かれる（10.5.3 控え室 / 10.5.4 エネルギーデッキ）。
      expect(after.waitingRoom, hasLength(1));
      expect(after.energyDeck, hasLength(1));
      expect(find.textContaining('上にメンバーが居ないメンバーカード 10.5.3'),
          findsOneWidget);
      expect(find.textContaining('上にメンバーが居ないエネルギーカード 10.5.4'),
          findsOneWidget);
    });

    testWidgets('★★ 1 操作につき履歴がちょうど 1 件（直接 GameState を書いていない）★★',
        (tester) async {
      await _pumpBoard(tester, _duplicateMembers());
      final store = tester
          .widget<BoardView>(find.byType(BoardView).first)
          .store;
      final before = store.value.session.history.depth;

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(store.value.session.history.depth, before + 1);
      // ★★ 1 回戻せば元に戻る ★★
      await tester.tap(find.byKey(const ValueKey('undo-button')));
      await tester.pumpAndSettle();
      expect(_stateOf(tester).playerOf(kSelfPlayerId).memberAreas.first.stacks,
          hasLength(2));
    });
  });

  group('★★★ 10.3 / 10.6 は実行しない。警告だけ（D10 / D-A）★★★', () {
    testWidgets('★ 10.3: 成功ライブが 3 枚でも盤面が動かない', (tester) async {
      expect(RuleConfig.standard.winCondition, 3, reason: '★前提: 1.2.1.1 の枚数');

      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.successLive: [_live, _live, _live],
        }),
      );

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('勝利処理 10.3'), findsOneWidget);
      // ★★ 実行していない ★★ 成功ライブが減っていない。
      expect(_stateOf(tester).playerOf(kSelfPlayerId).successLive, hasLength(3));
    });

    testWidgets('★ 10.6: 解決領域のカードが控え室へ行かない', (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfResolution: const [_live]),
      );

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('不正解決領域処理 10.6'), findsOneWidget);
      // ★★ 実行していない ★★ 解決領域が空になっていない。
      expect(_stateOf(tester).resolution, hasLength(1));
      expect(_stateOf(tester).playerOf(kSelfPlayerId).waitingRoom, isEmpty);
    });

    testWidgets('★対: 条件を満たさなければ警告は出ない', (tester) async {
      // ★出る側だけを見ると「常に警告する実装」でも通る。
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.successLive: [_live, _live],
        }),
      );

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('勝利処理 10.3'), findsNothing);
      expect(find.textContaining('不正解決領域処理 10.6'), findsNothing);
    });
  });

  group('★★ 当たるものが無くても黙らない ★★', () {
    testWidgets('★ 手で押したときは「ありませんでした」が出る', (tester) async {
      await _pumpBoard(tester, handcraftedBoard());

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('tidy-notices')), findsOneWidget);
      expect(find.textContaining('当たるルール処理がありませんでした'), findsOneWidget);
    });

    testWidgets('★対: 当たるものがあれば別の行が出る（常に同じ行ではない）',
        (tester) async {
      await _pumpBoard(tester, _duplicateMembers());

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('当たるルール処理がありませんでした'), findsNothing);
      expect(find.textContaining('整理しました'), findsOneWidget);
    });

    testWidgets('★★対: 自動（チェックタイミング）の整理では出さない ★★',
        (tester) async {
      // ★出すと帯が出っぱなしになり、本当に何か起きたときに気づけなくなる。
      await _pumpBoard(
        tester,
        // 7.4.2 → 7.4.3（チェックタイミング）へ進めると 9.5.3.1 の整理が回る。
        handcraftedBoard(),
      );

      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('advance-step')));
      await tester.pumpAndSettle();

      expect(find.textContaining('当たるルール処理がありませんでした'), findsNothing);
    });

    // ★★ ここから下は 2026-08-26 の実機確認で見つかった穴（決定 D94-2）★★
    //   `BoardTidyLog` の畳み込みが warnings を条件に含んでいたため、
    //   10.3 / 10.6 の警告が立っていると「ありませんでした」が消えていた。
    //   ★上の「手で押したときは出る」は**警告が無い盤面でしか見ていない**ので、
    //     この穴を素通しした（D-10「起きない条件で見ると常に通る」）。

    testWidgets('★★ 10.3 の警告が出ていても、空振りなら 2 行とも出る ★★',
        (tester) async {
      await _pumpBoard(
        tester,
        handcraftedBoard(selfZones: const {
          Zone.successLive: [_live, _live, _live],
        }),
      );

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      // ★警告は押す前から成立している盤面の条件であって、押した結果ではない。
      //   押した 10.4 / 10.5 の答えを隠してはいけない。
      expect(find.textContaining('当たるルール処理がありませんでした'), findsOneWidget);
      expect(find.textContaining('勝利処理 10.3'), findsOneWidget);
    });

    testWidgets('★★ 10.6 の警告でも同じ ★★', (tester) async {
      await _pumpBoard(tester, handcraftedBoard(selfResolution: const [_live]));

      await tester.tap(find.byKey(const ValueKey('tidy-button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('当たるルール処理がありませんでした'), findsOneWidget);
      expect(find.textContaining('不正解決領域処理 10.6'), findsOneWidget);
    });

    // ★★ ここから下は器の規則そのものを直接見る（決定 D94-2）★★
    //   撃ち分けの規則は「抑止できるのはその押下が生んだ事実だけ」（盤面設計メモ §10-2）。
    //   ★画面から通せない組み合わせがあるので、器を直接組んで固定する。

    test('★★ 警告は抑止しない（10.3 / 10.6 は押した結果ではない）★★', () {
      const log = BoardTidyLog(
        cursor: StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        warnings: [RuleProcessWarningKind.victory],
        manual: true,
      );

      expect(log.notices.whereType<TidyFoundNothing>(), hasLength(1));
      // ★対: 警告の行も消えない（片方を出すためにもう片方を畳まない）。
      expect(log.notices.whereType<RuleProcessNotAutomatic>(), hasLength(1));
    });

    test('★★ 判定できない札があるときは出さない（言い切れない）★★', () {
      // ★★ 警告とは扱いが違う ★★
      //   excludedCount は**この押下の中で起きた**事実で、種別を判定できていない以上
      //   「当たるものは無かった」と言い切れない（D-10 の「無い」と「見えていない」）。
      //
      // ★★ 画面からは通せないので器を直接組む ★★
      //   `loveca_core` の `RuleProcessor` は孤児を除外するときも
      //   `applied` に 10.5.3 を積むので（`rule_process.dart` の 10.5.3 / 10.5.4 の枝）、
      //   **`applied` が空のまま `excludedCount` だけが立つ盤面は現在の core では作れない。**
      //   ★作れないからと条件を落とすと、core が分けた瞬間に黙って壊れる。
      //   ★下の「前提」テストがこの不可能性そのものを見張る。
      const log = BoardTidyLog(
        cursor: StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        excludedCount: 1,
        unknownCardNumbers: [ghostCardNumber],
        manual: true,
      );

      expect(log.notices.whereType<TidyFoundNothing>(), isEmpty);
      // ★対: 黙ってはいない。押下の結果は別の行で出る。
      expect(log.notices.whereType<TidyExcluded>(), hasLength(1));
    });

    test('★対: 除外も警告も無ければ同じ形で「ありませんでした」が出る', () {
      const log = BoardTidyLog(
        cursor: StepCursor(PhaseId.firstActive, StepId.s7_4_3),
        manual: true,
      );

      expect(log.notices.single, isA<TidyFoundNothing>());
    });

    test('★★ 前提: いまの core では applied が空のまま除外だけが立つことは無い ★★', () {
      // ★★ 上のテストが「画面から通せない」と書いている根拠を機械で見る ★★
      //   これが落ちたら core が両者を分けたということ。そのときは画面から通せる。
      final store = _storeFor(withGhostOrphan(
          handcraftedBoard(), kSelfPlayerId, MemberAreaSlot.center));
      addTearDown(store.dispose);

      store.dispatch(const Tidy());
      final log = store.value.tidies.single;

      expect(log.excludedCount, 1);
      expect(log.applied, isNotEmpty,
          reason: '★core は除外した孤児にも 10.5.3 を積む（rule_process.dart）');
    });
  });

  group('★★ 整理ログの器は複数件（§14-7 の持ち越し 4 つ目 / 新所見 D-21 の器）★★', () {
    test('★ 1 件なら 1 件', () {
      final store = _storeFor(_duplicateMembers());
      addTearDown(store.dispose);

      store.dispatch(const Tidy());

      expect(store.value.tidies, hasLength(1));
      expect(store.value.tidies.single.applied,
          contains(RuleProcessKind.duplicateMember));
    });

    test('★★ 2 件渡すと 2 件とも残る（最後の 1 件で上書きしない）★★', () {
      // ★★ M-B7 の自動進行が 1 押下で複数の CT を通る形の先取りである ★★
      //   単数で作り込むとそこで作り直しになる（盤面設計メモ §15-12 の根拠 3）。
      final store = _storeFor(_duplicateMembers());
      addTearDown(store.dispose);

      store.dispatchAll(const [Tidy(), Tidy()]);

      expect(store.value.tidies, hasLength(2));
      // ★1 回目で 10.4.1 が当たり、2 回目は当たるものが無い。
      expect(store.value.tidies.first.applied,
          contains(RuleProcessKind.duplicateMember));
      // ★内部の述語ではなく**画面に出る行**で見る（決定 D94-2）。
      //   `isEmpty` は消した —— 3 つの独立した事実を 1 つに畳んでいたのが
      //   「警告があると空振りを黙る」の出どころで、直すと `lib` の消費者が
      //   0 人になる（**D-20** の形そのもの）。
      expect(store.value.tidies.last.applied, isEmpty);
      expect(store.value.tidies.last.notices.single, isA<TidyFoundNothing>());
      // ★合成なので履歴は 1 件（1 undo で戻る）。
      expect(store.value.session.history.depth, 1);
    });

    testWidgets('★★ 2 件が画面でも 2 行として読める ★★', (tester) async {
      await _pumpBoard(tester, _duplicateMembers());
      final store = tester
          .widget<BoardView>(find.byType(BoardView).first)
          .store;

      store.dispatchAll(const [Tidy(), Tidy()]);
      await tester.pumpAndSettle();

      // ★当たった行と、当たらなかった行が**同時に**出る。
      expect(find.textContaining('整理しました'), findsOneWidget);
      expect(find.textContaining('当たるルール処理がありませんでした'), findsOneWidget);
    });

    test('★ 整理が 1 件も起きない操作では前の整理が残る（黙って落とさない）', () {
      final store = _storeFor(handcraftedBoard(
        selfZones: const {
          Zone.successLive: [_live, _live, _live],
          Zone.hand: [_member],
        },
      ));
      addTearDown(store.dispose);

      store.dispatch(const Tidy());
      expect(store.value.tidies.single.warnings,
          contains(RuleProcessWarningKind.victory));

      // ★整理を起こさない操作（手札 → 控え室）。
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
          reason: '★ドラッグ 1 回で 10.3 の警告が消えると黙って落としたのと同じ');
    });

    test('★ 巻き戻すと整理の行も戻る', () {
      final store = _storeFor(_duplicateMembers());
      addTearDown(store.dispose);

      store.dispatch(const Tidy());
      expect(store.value.tidies, hasLength(1));

      store.undo();

      expect(store.value.tidies, isEmpty,
          reason: '★戻した先は「まだ整理していない」状態');
    });
  });
}
