/// 写像の答えを**本番の口**（`GameStore.dispatchAll`）へ流す（決定 D90-2 / D93）.
///
/// ## ★★ なぜ要るのか —— 写像テストは `reduce` を通していない ★★
///
/// `board_move_test.dart` は `reduce` も `ReduceContext` も `GameStore` も
/// **1 つも import していない。**見ているのは
/// **掴んだ場所 × 落とした場所 → `GameAction`** の写像だけである。
///
/// M-B5 が合成にした 7 経路のうち、**画面から通せるのは 6 経路**で、
/// 7 つ目（盤の外 → 盤の外 / `freeArea` → `mulliganAside`）は
/// **画面に落とし先が無い。** ★★決定 D93-2 で「今後も置かない」と確定した★★ ——
/// `zone.dart` が「脇置きは 6.2.1.6 の手順内にのみ存在する」と定めており、
/// 恒久の落とし先を置くと条文が定めていない状態を作れてしまう（D-B）。
///
/// ★★ したがって 7 つ目は、写像だけを見ていると次が未検証のまま残る ★★
///
/// | # | 未検証だったもの |
/// |---|---|
/// | 1 | その 2 アクションが**実際に `reduce` を通るか**（中継先の手札で札を見つけられるか） |
/// | 2 | 中継で `placedIn(card, Zone.hand)` が効くので、**フリーエリアで表向きだった札が脇置きで裏向きになる** —— この観測差を誰も一度も走らせていない |
/// | 3 | 合成が**履歴 1 件**に収まるか（他の 6 経路は画面テストが通しているが 7 つ目は通っていない） |
///
/// → ★**「テストがあるから大丈夫」で終わらせない。**画面から通せないままにするが、
/// **写像の答えを本番の口へ流して**穴を塞ぐ。
///
/// ★このファイルは写像の**表**を再掲しない（`board_move_test.dart` が正）。
/// ここが見るのは「その答えが `reduce` を通り、履歴 1 件で収まる」ことだけである。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_drag.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';

import '../support/board_fixture.dart';
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

/// 写像の答えを本番の口へ流す。★[MoveActions] も [MoveAction] も同じ扱い。
void _apply(GameStore store, BoardMove move) {
  switch (move) {
    case MoveAction(:final action):
      store.dispatch(action);
    case MoveActions(:final actions):
      store.dispatchAll(actions);
    case NeedsMemberChoice() || MoveRefused() || MoveIgnored():
      fail('この経路は合成の答えを返すはずである: $move');
  }
}

/// 最も混んだ盤面（全経路の出どころが揃っている）。
GameState _board() => handcraftedBoard(
      selfZones: const {
        Zone.hand: [_member],
        Zone.waitingRoom: [_live],
      },
      selfMembers: const {
        MemberAreaSlot.center: [_member],
      },
      selfResolution: const [_live],
      selfFreeArea: const [_energy],
    );

CardInstance _only(List<CardInstance> cards) => cards.single;

void main() {
  group('★★ 合成 7 経路が `reduce` を通り、履歴 1 件で収まる ★★', () {
    /// 出どころ → 落とし先 の 7 経路。★写像は `board_drag.dart` が持つ。
    final routes = <String, BoardMove Function(GameState state)>{
      'メンバー 4.5 → 盤の外': (state) => moveToOutOfRule(
            MemberCardDrag(
              playerId: kSelfPlayerId,
              slot: MemberAreaSlot.center,
              card: state
                  .playerOf(kSelfPlayerId)
                  .memberAreas[1]
                  .stacks
                  .single
                  .member,
            ),
            playerId: kSelfPlayerId,
            to: OutOfRuleZone.freeArea,
          ),
      'メンバー 4.5 → 解決領域 4.14': (state) => moveToResolution(
            MemberCardDrag(
              playerId: kSelfPlayerId,
              slot: MemberAreaSlot.center,
              card: state
                  .playerOf(kSelfPlayerId)
                  .memberAreas[1]
                  .stacks
                  .single
                  .member,
            ),
          ),
      '解決領域 4.14 → メンバーエリア 4.5': (state) => moveToMemberSlot(
            ResolutionCardDrag(card: state.resolution.single),
            playerId: kSelfPlayerId,
            slot: MemberAreaSlot.leftSide,
            edge: DropEdge.leading,
            area: state.playerOf(kSelfPlayerId).memberAreas.first,
          ),
      '解決領域 4.14 → 盤の外': (state) => moveToOutOfRule(
            ResolutionCardDrag(card: state.resolution.single),
            playerId: kSelfPlayerId,
            to: OutOfRuleZone.freeArea,
          ),
      '盤の外 → メンバーエリア 4.5': (state) => moveToMemberSlot(
            OutOfRuleCardDrag(
              playerId: kSelfPlayerId,
              zone: OutOfRuleZone.freeArea,
              card: _only(state.playerOf(kSelfPlayerId).freeArea),
            ),
            playerId: kSelfPlayerId,
            slot: MemberAreaSlot.leftSide,
            edge: DropEdge.leading,
            area: state.playerOf(kSelfPlayerId).memberAreas.first,
          ),
      '盤の外 → 解決領域 4.14': (state) => moveToResolution(
            OutOfRuleCardDrag(
              playerId: kSelfPlayerId,
              zone: OutOfRuleZone.freeArea,
              card: _only(state.playerOf(kSelfPlayerId).freeArea),
            ),
          ),
      // ★★ 7 つ目 —— 画面に落とし先が無い（決定 D93-2）★★
      '★盤の外 → 盤の外（脇置き 6.2.1.6）': (state) => moveToOutOfRule(
            OutOfRuleCardDrag(
              playerId: kSelfPlayerId,
              zone: OutOfRuleZone.freeArea,
              card: _only(state.playerOf(kSelfPlayerId).freeArea),
            ),
            playerId: kSelfPlayerId,
            to: OutOfRuleZone.mulliganAside,
          ),
    };

    routes.forEach((name, resolve) {
      test('$name — 投げず、履歴がちょうど 1 件増える', () {
        final store = _storeFor(_board());
        addTearDown(store.dispose);
        final before = store.value.session.history.depth;

        _apply(store, resolve(store.value.state));

        expect(store.value.session.history.depth, before + 1,
            reason: '★★中継を含めても 1 操作 = 1 undo（決定 D78 / §8-2）★★');
      });
    });

    test('★ 7 経路すべてを見ている（数え落としの番人）', () {
      expect(routes, hasLength(7),
          reason: '★決定 D90-2 が定めた「手札を中継する 7 経路」');
    });
  });

  group('★★ 7 つ目だけが持っていた穴（決定 D93-2）★★', () {
    test('★ 札が脇置きに着き、フリーエリアから消える', () {
      final store = _storeFor(_board());
      addTearDown(store.dispose);
      final card = _only(store.value.state.playerOf(kSelfPlayerId).freeArea);

      _apply(
        store,
        moveToOutOfRule(
          OutOfRuleCardDrag(
            playerId: kSelfPlayerId,
            zone: OutOfRuleZone.freeArea,
            card: card,
          ),
          playerId: kSelfPlayerId,
          to: OutOfRuleZone.mulliganAside,
        ),
      );

      final player = store.value.state.playerOf(kSelfPlayerId);
      expect(player.freeArea, isEmpty);
      expect(player.mulliganAside.single.instanceId, card.instanceId);
      // ★★ 中継は履歴にも盤面にも残らない ★★
      expect(player.hand.map((c) => c.instanceId), isNot(contains(card.instanceId)));
    });

    test('★★ 中継で表示面が変わる —— 誰も走らせていなかった観測差 ★★', () {
      // ★4.1.7 により中継先はオーナー自身の手札で、4.11.2 は非公開領域なので
      //   `placedIn` が裏向きにする（4.1.2.1 / 決定 D91）。
      //   ★盤の外は 4 章の領域ではないので表示面の規定を持たず、引き継がれる。
      final state = _board();
      final free = _only(state.playerOf(kSelfPlayerId).freeArea);
      expect(free.face, FaceState.faceUp,
          reason: '★前提: フリーエリアの札は表向きで生まれている');

      final store = _storeFor(state);
      addTearDown(store.dispose);

      _apply(
        store,
        moveToOutOfRule(
          OutOfRuleCardDrag(
            playerId: kSelfPlayerId,
            zone: OutOfRuleZone.freeArea,
            card: free,
          ),
          playerId: kSelfPlayerId,
          to: OutOfRuleZone.mulliganAside,
        ),
      );

      expect(
          store.value.state.playerOf(kSelfPlayerId).mulliganAside.single.face,
          FaceState.faceDown,
          reason: '★★手札を中継するので 4.11.2 の裏向きが残る★★');
    });

    test('★ 1 回の undo で丸ごと戻る', () {
      final store = _storeFor(_board());
      addTearDown(store.dispose);
      final card = _only(store.value.state.playerOf(kSelfPlayerId).freeArea);

      _apply(
        store,
        moveToOutOfRule(
          OutOfRuleCardDrag(
            playerId: kSelfPlayerId,
            zone: OutOfRuleZone.freeArea,
            card: card,
          ),
          playerId: kSelfPlayerId,
          to: OutOfRuleZone.mulliganAside,
        ),
      );
      store.undo();

      final player = store.value.state.playerOf(kSelfPlayerId);
      expect(player.mulliganAside, isEmpty);
      expect(player.freeArea.single.instanceId, card.instanceId);
    });
  });
}
