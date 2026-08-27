/// 盤面セッションの再生（M-B5 / 決定 D78 / 盤面設計メモ §8-3）.
///
/// ★★ この 2 件は「実測したのに再現手段がリポジトリに無い」状態だった ★★
/// 決定 D78 の根拠 —— **巻き戻しを含むログを同じ seed で再生すると最終状態が一致する /
/// 巻き戻しを落とすと一致しない** —— は、設計セッションで
/// **リポジトリの外の使い捨てスクリプト**を走らせて確かめたまま置かれていた。
/// 決定 D51 が戒めている「判断根拠が検証不能な主張になる」状態そのものである。
/// → M-B5 でここに置き直す。
///
/// ★★ 再生は本番の口を通す ★★
/// `dispatchAll` / `undo` / `undoStep` をそのまま呼ぶ。再生専用の経路を書くと、
/// **再生できることと本番が動くことが別々になる。**
///
/// ★★ 対を必ず置く ★★
/// 「一致する」だけを見ると、**何もしない再生でも通る。**
/// 落とすと一致しないこと・モードが違うと一致しないことを対で固定する。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart' hide Card;
import 'package:loveca_ui/src/state/board_mode.dart';
import 'package:loveca_ui/src/state/board_session.dart';
import 'package:loveca_ui/src/state/game_store.dart';
import 'package:loveca_ui/src/ui/board/board_start_dialog.dart';

import '../support/board_fixture.dart';
import '../support/board_signature.dart';
import '../support/real_shaped_catalog.dart';

const _seed = 20260825;

// ===========================================================================
// 材料
// ===========================================================================

/// 乱数を消費する経路を**全部**通せる盤面。
///
/// ★★ 控え室を空にしない ★★
/// 10.2.3 のシャッフルは控え室が空だと**何もせずに戻る**（`refresh.dart`）。
/// 空の盤面で試すと「消費したはず」の検査が全部すり抜ける（D-10 と同じ形）。
///
/// ★メインデッキを控え室より薄くしてある。10.2.1 の割り込みリフレッシュと
/// 10.2.2.2（上から見るときの不足）を**本当に**起こすため。
GameState _board() => handcraftedBoard(
      selfZones: {
        Zone.mainDeck: [
          trioMemberPrinting,
          parallelMemberNormal,
          drawLivePrinting,
        ],
        Zone.waitingRoom: [
          scoreLivePrinting,
          allBladeLivePrinting,
          multiNormalFirst,
          multiNormalSecond,
        ],
        Zone.hand: [trioMemberPrinting, drawLivePrinting],
        Zone.energyDeck: [
          energyPrinting,
          energyPrinting,
          energyPrinting,
          energyPrinting,
        ],
        Zone.energyField: [energyPrinting],
      },
      opponentZones: {
        Zone.mainDeck: [trioMemberPrinting, scoreLivePrinting],
        Zone.waitingRoom: [drawLivePrinting, multiNormalParallel],
        Zone.energyDeck: [energyPrinting, energyPrinting, energyPrinting],
        Zone.hand: [parallelMemberOtherProduct],
      },
      selfMembers: {
        MemberAreaSlot.center: [trioMemberPrinting],
      },
    );

GameStore _store(GameState initial, {BoardMode mode = BoardMode.localVersus}) =>
    GameStore(
      initialState: initial,
      viewerId: kSelfPlayerId,
      mode: mode,
      seed: _seed,
      cards: realShapedCatalog().cards,
      // ★★ 再生のたびに seed から張り直す ★★
      //   `SeededRng` は内部状態を持つので、使い回すと 2 回目が別の列になる。
      rng: SeededRng(_seed),
    );

/// ★★ 乱数を消費する経路を 1 つ残らず含み、巻き戻しも混ぜたログ ★★
///
/// 含めてあるもの: `ShuffleZone`（5.5.1）/ `DrawCards`（10.2.1 の割り込み）/
/// `Refresh`（10.2.3）/ `DrawEnergy`（4.9.2 / 決定 D73）/ `AdvanceStep`（7.5.2）/
/// ★**`LookAtTop`（10.2.2.2）** —— **6 つ目**である（`ルール整合性チェック_v1.06.md` D-19）。
///
/// ★★ 純粋なアクションも混ぜてある ★★
/// 乱数を消費するものだけだと「常に消費する」実装でも通る。
/// ★★ instanceId は盤面から引く（手で書かない）★★
/// `handcraftedBoard` の採番は組み立て順に依存するので、写しを置くと
/// fixture を触った瞬間に黙って別のカードを指す（D-15 と同じ形）。
List<BoardLogEntry> _script(GameState initial) {
  final handLive = cardsIn(initial, kSelfPlayerId, Zone.hand)
      .firstWhere((c) => c.printingId == drawLivePrinting);
  final member = initial
      .playerOf(kSelfPlayerId)
      .memberAreas
      .firstWhere((a) => a.slot == MemberAreaSlot.center)
      .stacks
      .single
      .member;

  return [
    const Act([ShuffleZone(playerId: kSelfPlayerId, zone: Zone.mainDeck)]),
    // ★メインデッキ 3 枚に対して 4 枚引く → 10.2.1 の割り込みリフレッシュ。
    const Act([DrawCards(playerId: kSelfPlayerId, count: 4)]),
    const Undo(),
    const Act([DrawEnergy(playerId: kSelfPlayerId)]),
    // ★純粋なアクション（乱数を消費しない）。
    Act([
      FlipCard(
        instanceId: handLive.instanceId,
        playerId: kSelfPlayerId,
        zone: Zone.hand,
        face: FaceState.faceDown,
      ),
    ]),
    const Act([LookAtTop(playerId: kSelfPlayerId, count: 6)]),
    const UndoStep(),
    const Act([Refresh(playerId: kOpponentPlayerId)]),
    // ★合成（M-B5）。★履歴 1 件なので 1 回の巻き戻しで両方戻る。
    Act([
      MoveMemberOut(
        instanceId: member.instanceId,
        playerId: kSelfPlayerId,
        slot: MemberAreaSlot.center,
        toPlayerId: kSelfPlayerId,
        to: Zone.hand,
      ),
      MoveOutOfRule(
        instanceId: member.instanceId,
        playerId: kSelfPlayerId,
        from: Zone.hand,
        to: OutOfRuleZone.freeArea,
      ),
    ]),
    const Act([AdvanceStep()]),
    const Act([AdvanceStep()]),
    const Undo(),
    const Act([AdvanceStep()]),
    const Act([ShuffleZone(playerId: kOpponentPlayerId, zone: Zone.mainDeck)]),
    const UndoStep(),
    const Act([DrawCards(playerId: kSelfPlayerId, count: 2)]),
  ];
}

/// 手札にある実在のライブ 1 枚（純粋なアクションの的）。
CardInstance _handLive(GameState state) =>
    cardsIn(state, kSelfPlayerId, Zone.hand)
        .firstWhere((c) => c.printingId == drawLivePrinting);

void _replay(GameStore store, List<BoardLogEntry> log) {
  for (final entry in log) {
    switch (entry) {
      case Act(:final actions):
        store.dispatchAll(actions);
      case Undo():
        store.undo();
      case UndoStep():
        store.undoStep();
    }
  }
}

// ===========================================================================

void main() {
  group('★★ 巻き戻しを含むログの再生（決定 D78 / §8-3）★★', () {
    test('★★ (1) 同じ seed・同じモードで再生すると最終状態が一致する ★★', () {
      final initial = _board();
      final log = _script(initial);

      final live = _store(initial);
      _replay(live, log);

      // ★★ セッションが自分で積んだログを使う（手で書いた列ではない）★★
      //   本番が積むログで再生できなければ意味が無い。
      expect(live.value.log, hasLength(log.length));

      final replayed = _store(initial);
      _replay(replayed, live.value.log);

      expect(boardSignature(replayed.value.state), boardSignature(live.value.state));
      // ★履歴の深さも一致する（巻き戻しの着地先が同じであることの裏づけ）。
      expect(replayed.value.session.history.depth,
          live.value.session.history.depth);

      live.dispose();
      replayed.dispose();
    });

    test('★★ (2) 対: 巻き戻しを落とすと一致しない ★★', () {
      // ★★ これが落ちたら (1) は「何を再生しても通る」検査である ★★
      //   取り消したアクションの**乱数消費は残るのに状態効果は消える**という
      //   非対称があるので、アクション列だけでは再現できない。
      final initial = _board();

      final live = _store(initial);
      _replay(live, _script(initial));

      final actionsOnly = [
        for (final entry in live.value.log)
          if (entry is Act) entry,
      ];
      expect(actionsOnly.length, lessThan(live.value.log.length),
          reason: '★ログに巻き戻しが入っていなければ検査になっていない');

      final replayed = _store(initial);
      _replay(replayed, actionsOnly);

      expect(boardSignature(replayed.value.state),
          isNot(boardSignature(live.value.state)));

      live.dispose();
      replayed.dispose();
    });

    test('★★ (3) 対: モードが違うと一致しない（決定 D88 / §14-3）★★', () {
      // ★ソロは相手を要求するステップ（8.2.4 ほか）と後攻フェイズを飛ばすので、
      //   同じログでも進行が変わる。
      //   ★「同じ seed なら同じ盤面」はモードを固定して初めて成立する。
      //   ★★ モードが効くカーソルから始める ★★ ——
      //     7.4.1 の周りには飛ぶステップが無く、そこだけ再生しても差が出ない。
      final initial = handcraftedBoard(
        selfZones: {
          Zone.mainDeck: [trioMemberPrinting, drawLivePrinting],
          Zone.waitingRoom: [scoreLivePrinting],
          Zone.hand: [drawLivePrinting],
        },
        opponentZones: {
          Zone.mainDeck: [trioMemberPrinting, scoreLivePrinting],
          Zone.hand: [drawLivePrinting],
        },
        cursor: const StepCursor(PhaseId.liveCardSet, StepId.s8_2_3),
      );
      final log = <BoardLogEntry>[
        const Act([AdvanceStep()]),
        const Act([DrawCards(playerId: kSelfPlayerId, count: 1)]),
        const Undo(),
        const Act([AdvanceStep()]),
      ];

      final versus = _store(initial);
      _replay(versus, log);
      // ★飛ばしたことが記録されている＝モードが効いた経路を通っている。
      expect(versus.value.operation!.skipped, isEmpty);

      final solo = _store(initial, mode: BoardMode.solo);
      _replay(solo, log);

      expect(boardSignature(solo.value.state), isNot(boardSignature(versus.value.state)));

      versus.dispose();
      solo.dispose();
    });

    test('★ 同じログを 2 回再生しても毎回同じところへ着く', () {
      // ★再生そのものが決定的であることの確認。片方だけ再生して比べていると
      //   「たまたま 1 回一致した」を見分けられない。
      final initial = _board();
      final log = _script(initial);

      final a = _store(initial)..let(_replay, log);
      final b = _store(initial)..let(_replay, log);

      expect(boardSignature(b.value.state), boardSignature(a.value.state));

      a.dispose();
      b.dispose();
    });
  });

  group('★★ 戻らないはずのものが戻らない ★★', () {
    test('★★ 2 周目の 8.4.9 から 1 ステップ戻ると 1 周目の 8.4.12 に着く ★★', () {
      // ★★ 静的グラフの逆辺なら 8.4.8 に着地して落ちる ★★
      //   8.4.12 → 8.4.9 のループがあるため 8.4.9 の前任は 2 つある。
      //   着地先は**実際に通った履歴**からしか決まらない（決定 D36）。
      final store = _store(handcraftedBoard(
        selfZones: {
          Zone.mainDeck: [trioMemberPrinting, drawLivePrinting],
          Zone.waitingRoom: [scoreLivePrinting],
        },
        opponentZones: {
          Zone.mainDeck: [trioMemberPrinting, scoreLivePrinting],
          Zone.waitingRoom: [drawLivePrinting],
        },
        cursor: const StepCursor(PhaseId.liveJudgement, StepId.s8_4_9),
      ));

      // 8.4.9 → 8.4.10 → 8.4.11 → 8.4.12 まで進める。
      while (store.value.state.cursor.step != StepId.s8_4_12) {
        store.dispatch(const AdvanceStep());
      }

      // ★8.4.12 は宣言が要る分岐。8.4.9 へ戻る側（ループ）を選ぶ。
      expect(store.requiresChoice, isTrue);
      final loop = store.transitions
          .firstWhere((t) => t.target == StepId.s8_4_9);
      store.dispatch(AdvanceStep(choice: loop));
      expect(store.value.state.cursor.step, StepId.s8_4_9, reason: '★2 周目');

      store.undoStep();

      expect(store.value.state.cursor.step, StepId.s8_4_12,
          reason: '★静的グラフの逆辺なら 8.4.8 に着地して誤る');
      expect(store.value.rewind!.landedOnSameStep, isFalse);

      store.dispose();
    });

    test('★★ 対: ステップ内で操作していたら、そのステップの入口に着く ★★', () {
      // ★着地点は 2 通りある。片方だけ見ると `undoStep` が
      //   「常に 1 つ前のステップへ行く」実装でも通る。
      final store = _store(_board());
      final start = store.value.state.cursor;

      store.dispatch(const ShuffleZone(
          playerId: kSelfPlayerId, zone: Zone.mainDeck));
      store.dispatch(const DrawCards(playerId: kSelfPlayerId, count: 1));

      store.undoStep();

      expect(store.value.state.cursor, start, reason: '★カーソルは動かない');
      expect(store.value.rewind!.landedOnSameStep, isTrue);
      // ★2 件まとめて戻る（そのステップの入口まで）。
      expect(store.value.rewind!.entriesPopped, 2);
      expect(store.value.session.canUndo, isFalse);

      store.dispose();
    });

    test('★ 戻せるものが無ければ何も起きない', () {
      final store = _store(_board());
      final before = store.value;

      store.undo();
      store.undoStep();

      expect(identical(store.value, before), isTrue);
      expect(store.value.log, isEmpty, reason: '★空振りをログに載せない');

      store.dispose();
    });
  });

  group('★★ 乱数を消費したかの判定（決定 D78 / 列挙しない）★★', () {
    /// 1 アクションを適用して即座に戻し、注記が立つかを見る。
    bool consumed(GameState initial, GameAction action) {
      final store = _store(initial);
      store.dispatch(action);
      store.undo();
      final result = store.value.rewind!.rngConsumed;
      store.dispose();
      return result;
    }

    test('★ 5.5.1 シャッフル / 10.2.3 リフレッシュ / 4.9.2 エネルギー', () {
      final initial = _board();
      expect(
          consumed(initial,
              const ShuffleZone(playerId: kSelfPlayerId, zone: Zone.mainDeck)),
          isTrue);
      expect(consumed(initial, const Refresh(playerId: kSelfPlayerId)), isTrue);
      expect(consumed(initial, const DrawEnergy(playerId: kSelfPlayerId)),
          isTrue);
    });

    test('★ 10.2.1 の割り込みが起きた引きだけ真になる', () {
      final initial = _board();
      // メインデッキ 3 枚。3 枚までは割り込まない。
      expect(
          consumed(
              initial, const DrawCards(playerId: kSelfPlayerId, count: 3)),
          isFalse);
      // 4 枚目で控え室からリフレッシュする。
      expect(
          consumed(
              initial, const DrawCards(playerId: kSelfPlayerId, count: 4)),
          isTrue);
    });

    test('★★ 10.2.2.2「上から見る」も消費する（★6 つ目 / D-19）★★', () {
      // ★★ 決定 D78 と core のコメントは「5 つ」と列挙しており、これが漏れている ★★
      //   列挙で実装していたら、この undo で注記が出ない。
      final initial = _board();
      // 足りていれば見るだけ。
      expect(
          consumed(initial, const LookAtTop(playerId: kSelfPlayerId, count: 3)),
          isFalse);
      // 足りなければ 10.2.2.2 でリフレッシュする＝シャッフルする。
      expect(
          consumed(initial, const LookAtTop(playerId: kSelfPlayerId, count: 6)),
          isTrue);
    });

    test('★★ 対: 純粋なアクションでは立たない ★★', () {
      final initial = _board();
      expect(
        consumed(
          initial,
          FlipCard(
            instanceId: _handLive(initial).instanceId,
            playerId: kSelfPlayerId,
            zone: Zone.hand,
            face: FaceState.faceDown,
          ),
        ),
        isFalse,
      );
    });

    test('★★ 7.5.2 を通る「次へ」だけが真になる（★列挙では書けない）★★', () {
      // ★★ `AdvanceStep` は消費したりしなかったりする ★★
      //   アクションの型で列挙すると常に真にせざるを得ず、
      //   「次へ」を戻すたびに注記が出て意味が消える（M3 の縮退と同じ）。
      final store = _store(_board());

      // 7.4.1 から 7.5.2 の手前まで。★消費しないことを 1 度は通る。
      store.dispatch(const AdvanceStep());
      store.undo();
      expect(store.value.rewind!.rngConsumed, isFalse,
          reason: '★アクティブフェイズの「次へ」は乱数を引かない');

      while (store.value.state.cursor.step.ruleRef != '7.5.2') {
        store.dispatch(const AdvanceStep());
      }
      store.dispatch(const AdvanceStep());
      store.undo();
      expect(store.value.rewind!.rngConsumed, isTrue,
          reason: '★7.5.2 は 4.9.2 の無作為抽出を通る（決定 D73）');

      store.dispose();
    });

    test('★ 合成のうち 1 つでも消費していれば立つ', () {
      final initial = _board();
      final store = _store(initial);
      store.dispatchAll([
        FlipCard(
          instanceId: _handLive(initial).instanceId,
          playerId: kSelfPlayerId,
          zone: Zone.hand,
          face: FaceState.faceDown,
        ),
        const ShuffleZone(playerId: kSelfPlayerId, zone: Zone.mainDeck),
      ]);
      store.undo();

      expect(store.value.rewind!.rngConsumed, isTrue);
      expect(store.value.rewind!.entriesPopped, 1, reason: '★合成は履歴 1 件');

      store.dispose();
    });
  });
}

/// テストの読みやすさのためだけの小さな道具。
extension _Let on GameStore {
  void let(void Function(GameStore, List<BoardLogEntry>) f,
          List<BoardLogEntry> log) =>
      f(this, log);
}
