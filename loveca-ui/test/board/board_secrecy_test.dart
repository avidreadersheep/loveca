/// ★★ 4.8 / 4.9 の秘匿は盤面 UI の責務である（決定 D77）★★
///
/// 一人回しでは `redact` を掛けない（掛けると相手側を操作できなくなる）。
/// しかし 4.8.2 / 4.9.2 は**オーナーからも非公開**なので、`GameState` が中身を
/// 持っていても盤面が出してはいけない。
///
/// ★★ 「たまたま描いていない」では守れないので、対で固定する（D-10）★★
///
/// | 見るもの | なぜ対が要るか |
/// |---|---|
/// | 山のカードの printingId がツリーに無い | ★**空の盤面なら常に通る** |
/// | ★対: 枚数は出る（4.1.2.2） | 秘匿と混同して枚数まで消していないこと |
/// | 山の imageHash で `provider` が呼ばれない | 文字列検査では「絵として出ている」を拾えない |
/// | ★対: 手札の imageHash では呼ばれる | ★**検査自体が生きていること**。`provider` が常に null を返す実装でも「呼ばれない」は通る |
///
/// ## ★★ 対照実験で分かったこと（2026-08-24）★★
///
/// `board_layout.dart` の `HiddenPile` を普通の領域（`_ZoneStack`）に差し替えて
/// **わざと山を描く**間違いを入れ、どのテストが落ちるかを見た。
///
/// | テスト | 落ちたか |
/// |---|---|
/// | 山の imageHash で `provider` が呼ばれない | ○ |
/// | 4.1.2.2 の枚数が出る | ○ |
/// | 山のウィジェットに絵が無い | ○ |
/// | ★**山の札の printingId がツリーに無い** | ★**落ちなかった** |
///
/// ★★ キーによる検査だけでは漏れを捕まえられない ★★
///   `GameSetup` が置く山の札は**裏向き**（4.8.2 / 4.9.2 の既定）で、
///   `BoardCard` は裏向きなら `printingId` を含むキーを作らない。
///   **つまりキー検査は「裏向きだから通った」のであって、
///   盤面が山を渡していないことを確かめてはいない。**
///
/// → だから `provider` の検査は **`face` を既定（表向き）にした手組みの盤面**で行う。
///   表向きの中身を渡しても出ないことが確かめられて、はじめて
///   「盤面 UI が構造的に出さない」と言える。
///   ★**裏向きフラグを秘匿の手段にしていない**ことの確認でもある
///   （`FlipCard` の不具合ひとつで全部見えてしまう形にしない）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/ui/board/board_page.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';
import '../support/real_shaped_catalog.dart';
import '../support/recording_image_source.dart';

void main() {
  late RecordingImageSource images;

  setUp(() => images = RecordingImageSource());

  Future<GameState> pumpBoard(
    WidgetTester tester, {
    GameState? state,
    String viewerId = kSelfPlayerId,
  }) async {
    final resolved = state ?? boardFixtureState();
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpInAppScope(
      tester,
      BoardPage(
        initialState: resolved,
        viewerId: viewerId,
        mode: BoardMode.localVersus,
        seed: 1,
      ),
      decks: FakeDeckRepository(),
      catalog: realShapedCatalog(),
      imageSource: images,
    );
    return resolved;
  }

  /// ★領域ごとに刷りを指定して盤面を手で組む。
  ///
  /// ★★ `GameSetup` の出力では「隠す側にしか無い絵」を作れない ★★
  ///   シャッフルの結果しだいで同じ刷りが手札にも山にも入るため、
  ///   絵の要求が秘匿の漏れなのか公開領域ぶんなのか区別できない。
  GameState handcraftedState({
    required List<String> hand,
    required List<String> mainDeck,
    required List<String> energyDeck,
  }) {
    var seq = 0;
    List<CardInstance> build(List<String> printingIds, String playerId) => [
          for (final printingId in printingIds)
            CardInstance(
              instanceId: '$playerId:$printingId:${seq++}',
              printingId: printingId,
              cardNumber:
                  realShapedCatalog().printings[printingId]!.cardNumber,
              ownerId: playerId,
            ),
        ];

    PlayerState player(String playerId) => PlayerState(
          playerId: playerId,
          memberAreas: [
            for (final slot in MemberAreaSlot.values) MemberArea(slot: slot),
          ],
          hand: build(hand, playerId),
          mainDeck: build(mainDeck, playerId),
          energyDeck: build(energyDeck, playerId),
        );

    return GameState(
      players: [player(kSelfPlayerId), player(kOpponentPlayerId)],
      firstPlayerId: kSelfPlayerId,
      cursor: const StepCursor(PhaseId.firstActive, StepId.s7_4_1),
    );
  }

  /// [zone] にあるカードの imageHash（★中身が入っていることも確かめる）。
  Set<String> hashesIn(GameState state, String playerId, Zone zone) {
    final catalog = realShapedCatalog();
    final cards = cardsIn(state, playerId, zone);
    expect(cards, isNotEmpty,
        reason: '★中身が入っていないと、秘匿の検査は常に通ってしまう（D-10）');
    return {
      for (final card in cards) catalog.printings[card.printingId]!.imageHash,
    };
  }

  group('★★ 4.8 / 4.9 の中身が盤面のどこにも出ない（決定 D77）★★', () {
    testWidgets('メインデッキの札はツリーに 1 つも無い', (tester) async {
      final state = await pumpBoard(tester);

      for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
        for (final card in cardsIn(state, playerId, Zone.mainDeck)) {
          expect(
            find.byKey(ValueKey('board-card-${card.instanceId}')),
            findsNothing,
            reason: '★4.8.2: すべてのプレイヤーに対して非公開',
          );
        }
      }
    });

    testWidgets('エネルギーデッキの札もツリーに 1 つも無い', (tester) async {
      final state = await pumpBoard(tester);

      for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
        for (final card in cardsIn(state, playerId, Zone.energyDeck)) {
          expect(
            find.byKey(ValueKey('board-card-${card.instanceId}')),
            findsNothing,
            reason: '★4.9.2: 同上',
          );
        }
      }
    });

    testWidgets('★★ 山の imageHash で画像が 1 度も要求されない ★★', (tester) async {
      // ★★ 山にしか無い刷りを置いた盤面で見る ★★
      //   `GameSetup` の出力をそのまま使うと、同じ刷りが公開領域
      //   （4.7 エネルギー置き場 / 手札）にも居るため、その絵の要求が
      //   秘匿の漏れなのか公開領域ぶんなのか**区別がつかない**。
      //   → 隠す側と出す側で**別の刷り**を置く。
      final state = handcraftedState(
        hand: const [drawLivePrinting],
        mainDeck: const [trioMemberPrinting],
        energyDeck: const [energyPrinting],
      );
      await pumpBoard(tester, state: state);

      final catalog = realShapedCatalog();
      String hashOf(String printingId) =>
          catalog.printings[printingId]!.imageHash;

      // ★前提: 隠す側の絵は公開領域のどこにも居ない。
      //   居ると、この検査は秘匿を何も証明しない（D-10）。
      expect(hashOf(trioMemberPrinting), isNot(hashOf(drawLivePrinting)));
      expect(hashOf(energyPrinting), isNot(hashOf(drawLivePrinting)));

      expect(images.requested, isNot(contains(hashOf(trioMemberPrinting))),
          reason: '★4.8.2 メインデッキの絵が要求されている = 秘匿が漏れている');
      expect(images.requested, isNot(contains(hashOf(energyPrinting))),
          reason: '★4.9.2 エネルギーデッキの絵が要求されている = 秘匿が漏れている');

      // ★★ 対: 検査そのものが生きている ★★
      //   同じ盤面で、公開領域に置いた刷りの絵は**来ている**。
      //   来ていなければ「来ない」は何も証明しない。
      expect(images.requested, contains(hashOf(drawLivePrinting)));
    });

    testWidgets('★★ 対: 同じ刷りを手札に置けば絵が要求される ★★', (tester) async {
      // ★上のテストで「来なかった」のが**その刷りだから**ではないことを見る。
      //   置き場所を変えるだけで来るなら、来なかった理由は領域 4.8 / 4.9 である。
      final state = handcraftedState(
        hand: const [trioMemberPrinting, energyPrinting],
        mainDeck: const [drawLivePrinting],
        energyDeck: const [],
      );
      await pumpBoard(tester, state: state);

      final catalog = realShapedCatalog();
      expect(images.requested,
          contains(catalog.printings[trioMemberPrinting]!.imageHash));
      expect(images.requested,
          contains(catalog.printings[energyPrinting]!.imageHash));
    });
  });

  group('★★ 対: 出るはずのものは出る ★★', () {
    testWidgets('4.1.2.2: 枚数はどちらの山も出る', (tester) async {
      final state = await pumpBoard(tester);
      final self = state.playerOf(kSelfPlayerId);

      // ★fixture は メンバー 6 + ライブ 6 = 12 のうち 6 枚が手札 → 山は 6 枚。
      expect(self.mainDeck.length, 6, reason: '★前提の確認');
      expect(self.energyDeck.length, 3, reason: '★6 枚から 3 枚出た');

      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-main-$kSelfPlayerId')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('pile-energy-$kSelfPlayerId')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('★一人回しでは両者の手札の札が出る（4.11 / 決定 D77）', (tester) async {
      final state = await pumpBoard(tester);

      for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
        final hand = cardsIn(state, playerId, Zone.hand);
        expect(hand, isNotEmpty);
        // ★横スクロールの帯なので先頭が必ず可視。
        expect(
          find.byKey(ValueKey('board-card-${hand.first.instanceId}')),
          findsOneWidget,
          reason: '★redact を掛けていれば相手側が消えるはず（掛けていないことの確認）',
        );
      }
    });

    testWidgets('★★ 検査が生きている: 手札の imageHash では要求が来る ★★',
        (tester) async {
      final state = await pumpBoard(tester);
      final handHashes = hashesIn(state, kSelfPlayerId, Zone.hand);

      expect(images.requested, isNotEmpty,
          reason: '★1 度も来ないなら「来ない」という検査は何も証明しない');
      expect(handHashes.any(images.requested.contains), isTrue);
    });
  });

  group('★ 4.8 / 4.9 は枚数しか受け取らない（構造で守る）', () {
    testWidgets('山のウィジェットに CardInstance を渡す口が無い', (tester) async {
      await pumpBoard(tester);

      // ★`HiddenPile` のコンストラクタは count しか取らない。
      //   ここではその帰結（絵が 1 つも無いこと）を見る。
      final pile = find.byKey(const ValueKey('pile-main-$kSelfPlayerId'));
      expect(pile, findsOneWidget);
      expect(
        find.descendant(of: pile, matching: find.byType(Image)),
        findsNothing,
      );
    });
  });

  group('★★ 秘匿は領域で決まる。視点では決まらない（決定 D77 / D84）★★', () {
    /// ★★ この群は U17 の確定（D84）が何に依存しているかを固定する ★★
    /// 「相手の手札を常時出す」が成り立つのは
    /// **一人回しでは `redact` を掛けない**からであって、
    /// `viewerId` が秘匿に関わっていないからである。
    /// D77 が「描画の視点と `redact` の視点を同じ変数にしない」と定めた形が
    /// 実際に守られていることを、**視点を切り替えて**確かめる。
    ///
    /// ★M-B1 の秘匿テストで「キー検査が**裏向きだから**通っていた」という
    /// 発見があった以上、依存関係は明示的に検証する。

    /// 隠す側と出す側で**別の刷り**を置いた盤面。
    GameState split() => handcraftedState(
          hand: const [drawLivePrinting],
          mainDeck: const [trioMemberPrinting],
          energyDeck: const [energyPrinting],
        );

    testWidgets('★視点を切り替えても、どちらの手札も隠れない', (tester) async {
      final state = await pumpBoard(tester, state: split());

      Future<void> expectBothHandsVisible(String label) async {
        for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
          final hand = cardsIn(state, playerId, Zone.hand);
          expect(hand, isNotEmpty, reason: '★前提');
          expect(
            find.byKey(ValueKey('board-card-${hand.first.instanceId}')),
            findsOneWidget,
            reason: '★$label で $playerId の手札が消えた = viewerId が秘匿に使われている',
          );
        }
      }

      await expectBothHandsVisible('切替前');

      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      await expectBothHandsVisible('切替後');
    });

    testWidgets('★★ 対: 視点を切り替えても 4.8 / 4.9 は隠れたまま ★★',
        (tester) async {
      // ★★ 秘匿が「視点で決まっていない」ことの対である ★★
      //   手札が両方見えるだけなら「何でも見える実装」でも通る。
      //   同じ切替で山が**出てこない**ことまで見て、はじめて
      //   「秘匿は領域で決まる」と言える。
      final state = await pumpBoard(tester, state: split());

      Future<void> expectPilesHidden(String label) async {
        for (final playerId in [kSelfPlayerId, kOpponentPlayerId]) {
          for (final zone in [Zone.mainDeck, Zone.energyDeck]) {
            for (final card in cardsIn(state, playerId, zone)) {
              expect(
                find.byKey(ValueKey('board-card-${card.instanceId}')),
                findsNothing,
                reason: '★$label で ${zone.ruleRef} が見えた',
              );
            }
          }
        }
      }

      await expectPilesHidden('切替前');

      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      await expectPilesHidden('切替後');

      final catalog = realShapedCatalog();
      expect(
        images.requested,
        isNot(contains(catalog.printings[trioMemberPrinting]!.imageHash)),
        reason: '★切替後にメインデッキの絵が要求されている',
      );
      expect(
        images.requested,
        isNot(contains(catalog.printings[energyPrinting]!.imageHash)),
      );
    });

    testWidgets('★★ 対: 切替後も手札の絵は要求される（検査が生きている）★★',
        (tester) async {
      // ★上の 2 件が「何も描かれていないから通った」ではないことを見る。
      await pumpBoard(tester, state: split());

      images.requested.clear();
      await tester.tap(find.byKey(const ValueKey('swap-viewer')));
      await tester.pumpAndSettle();

      expect(images.requested, isNotEmpty,
          reason: '★切替後に 1 度も要求が来ないなら「来ない」は何も証明しない');
      expect(
        images.requested,
        contains(realShapedCatalog().printings[drawLivePrinting]!.imageHash),
      );
    });
  });
}
