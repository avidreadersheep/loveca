/// ステップ進行.
///
/// 総合ルール 7 章・8 章に対応。
///
/// ★★ 遷移の権威は `step.dart` の [stepGraph] だけ ★★
///   このファイルに条番号による遷移先の再記述をしない。
///   グラフを読み、分岐だけを解決する。
///
/// ★★ 実行するのは「盤面の観測だけで決まる機械的な処理」に限る ★★
///   CLAUDE.md §1 (D-A)「実装してよいのは物理操作の補助のみ」。
///
///   実行する: 7.4.1 / 7.5.2 / 7.6.2 / 8.3.4 / 8.3.11 / 8.3.12 /
///             8.4.8 / 8.4.13 / 8.4.14、およびチェックタイミングでの整理
///   素通り  : 誘発ステップ、7.7.2 のプレイタイミング、8.2.2 / 8.2.4 の
///             ライブカードセット、8.3.7 / 8.3.8、8.3.15 / 8.3.16 (D18)、
///             8.4.2〜8.4.7 (D10 / D18)
///
///   素通りするステップでは盤面を触らない。プレイヤーが手動で操作してから
///   「次へ」を押す、というサンドボックスの流儀に従う。

library;

import '../entities/card.dart';
import 'aggregation.dart';
import 'card_instance.dart';
import 'card_move.dart';
import 'energy_deck.dart';
import 'game_state.dart';
import 'member_area.dart';
import 'refresh.dart';
import 'rng.dart';
import 'rule_process.dart';
import 'step.dart';
import 'turn_order.dart';
import 'zone.dart';

/// [StepEngine.advance] の結果。
class AdvanceResult {
  const AdvanceResult({
    required this.state,
    required this.executed,
    required this.taken,
    this.tidy,
    this.refreshCount = 0,
    this.skipped = const [],
  });

  final GameState state;

  /// 実行したステップ（進む前のカーソル位置）。
  final StepId executed;

  /// たどった遷移。[StepTransition.endsPhase] ならフェイズが終わった。
  final StepTransition taken;

  /// チェックタイミングで回した整理の結果。CT でないステップでは null。
  final RuleProcessResult? tidy;

  /// このステップの実行中に割り込んだリフレッシュの回数 (10.2.1)。
  final int refreshCount;

  /// ★★ 実行せずに通り越したカーソル (決定 D88) ★★
  ///
  ///   [ProgressionMode.soloFirstPlayer] でのみ空でなくなる。
  ///   ★**黙って飛ばさない。** 1 回の [advance] で 4 フェイズを跨ぐことがあるので、
  ///   何を通らなかったかを出さないと「勝手に飛んだ」ように見える。
  ///   8.3.6 の早期終了で既に学んだ形である (決定 D86)。
  final List<StepCursor> skipped;
}

/// ステップ進行の実行。
class StepEngine {
  const StepEngine({
    required this.cards,
    required this.rng,
    this.mode = ProgressionMode.twoPlayer,
  });

  /// cardNumber -> Card。集計と種別判定に要る。
  final Map<String, Card> cards;

  /// シャッフル (10.2.3) に使う乱数源。
  final DeterministicRng rng;

  /// 進行のしかた (決定 D88)。★既定は 2 名 (1.1.1)。
  ///
  /// ★カーソルを**飛ばす**だけで、実行するものは 1 つも変えない。
  ///   飛ばす規則は `step.dart` の [skipsCursor] が持つ。ここに条番号を書かない。
  final ProgressionMode mode;

  Refresher get _refresher => Refresher(rng: rng);
  RuleProcessor get _processor => RuleProcessor(cards: cards);
  LiveAggregator get _aggregator => LiveAggregator(cards: cards);

  /// 現在のステップの後続候補。★[stepGraph] が唯一の権威。
  List<StepTransition> transitionsFrom(GameState state) =>
      stepGraph[state.cursor.step]!;

  /// 次へ進むのにプレイヤーの選択が要るか。
  ///
  /// ★true になるのは 8.4.12 だけ。8.3.6 は盤面の観測で決まる。
  bool requiresChoice(GameState state) =>
      state.cursor.step.decision == StepDecision.playerDeclared &&
      transitionsFrom(state).length > 1;

  /// 1 ステップ進める。
  ///
  /// [choice] は [requiresChoice] が true のときだけ必要。
  /// 渡さずに呼ぶと例外を投げる（呼び出し側のバグ）。
  AdvanceResult advance(GameState state, {StepTransition? choice}) {
    final step = state.cursor.step;

    // ---- 1. このステップの機械的な処理を実行する ----
    final executed = _execute(state);
    var next = executed.state;

    // ---- 2. チェックタイミングなら整理を回す (9.5.3.1) ----
    RuleProcessResult? tidy;
    if (step.checkTiming) {
      tidy = _processor.tidy(next);
      next = tidy.state;
    }

    // ---- 3. 遷移を決める ----
    final taken = _resolveTransition(next, choice: choice);

    // ---- 4. カーソルを進める ----
    next = _moveCursor(next, taken);

    // ---- 5. ★飛ばすカーソルの間は**実行せずに**進める (決定 D88) ----
    //   ここを advance の末尾に置くので、カーソルは飛ばすステップの上に
    //   **留まらない**。次の advance は必ず通るステップから始まる。
    final forward = skipForward(next.cursor, (c) => skipsCursor(c, mode));
    if (forward.skipped.isNotEmpty) {
      next = next.copyWith(cursor: forward.cursor);
    }

    return AdvanceResult(
      state: next,
      executed: step,
      taken: taken,
      tidy: tidy,
      refreshCount: executed.refreshCount,
      skipped: forward.skipped,
    );
  }

  /// 後続候補から 1 つ選ぶ。
  StepTransition _resolveTransition(GameState state,
      {StepTransition? choice}) {
    // ★state.cursor はまだ進んでいないので、実行したステップの候補を読む。
    final candidates = stepGraph[state.cursor.step]!;
    if (candidates.length == 1) return candidates.single;

    return switch (state.cursor.step.decision) {
      // 8.3.6: 盤面の観測のみ。アプリが自動判定してよい。
      StepDecision.automatic => _resolveAutomatic(state, candidates),

      // 8.4.12: 自動能力の誘発有無を含むためプレイヤーが宣言する (D-A)。
      StepDecision.playerDeclared => choice ??
          (throw ArgumentError(
              '${state.cursor.step.ruleRef} はプレイヤーの宣言が要る。choice を渡すこと')),

      null => throw StateError(
          '${state.cursor.step.ruleRef} に分岐があるのに判定主体が無い'),
    };
  }

  /// 総合ルール 8.3.6 の自動判定。
  ///
  /// 「ライブカード置き場にカードが無ければパフォーマンスフェイズを終了」。
  /// ★手番プレイヤーのライブカード置き場を見る。
  StepTransition _resolveAutomatic(
      GameState state, List<StepTransition> candidates) {
    final turnPlayer = turnPlayerOf(state, state.cursor.phase);
    if (turnPlayer == null) {
      throw StateError('${state.cursor.step.ruleRef} は手番プレイヤーを要する');
    }
    final isEmpty = cardsIn(state, turnPlayer, Zone.liveStage).isEmpty;

    // 空ならフェイズ終了 (target == null)、あれば 8.3.7 へ。
    // ★8.3.17 へジャンプさせない。8.3.17 の CT が余分に走る。
    return candidates.firstWhere((t) => t.endsPhase == isEmpty);
  }

  /// カーソルを進める。
  GameState _moveCursor(GameState state, StepTransition taken) {
    final target = taken.target;
    if (target != null) {
      // 同じフェイズ内の遷移。8.4.12 → 8.4.9 のループもここ。
      return state.copyWith(cursor: StepCursor(state.cursor.phase, target));
    }

    // ★フェイズ終了。次のフェイズの先頭ステップへ (7.1.2 / 7.3.3 / 8.1.2)。
    final nextPhase = state.cursor.phase.next;
    return state.copyWith(
      cursor: StepCursor(nextPhase, nextPhase.steps.first),
    );
  }

  /// このステップの機械的な処理を実行する。
  ///
  /// ★素通りするステップでは盤面を触らない。
  _Executed _execute(GameState state) {
    final phase = state.cursor.phase;
    final turnPlayer = turnPlayerOf(state, phase);

    return switch (state.cursor.step) {
      // 7.4.1「手番プレイヤーは、自身のエネルギー置き場とメンバーエリアの
      //        ウェイトのカードをすべてアクティブにします」
      // ★7.4 だけ誘発 (7.4.2) より前にこれが来る。
      StepId.s7_4_1 => _Executed(_activateAll(state, turnPlayer!)),

      // 7.5.2「手番プレイヤーは、自身のエネルギーデッキの一番上のカードを、
      //        自身のエネルギー置き場に移動します」
      StepId.s7_5_2 => _Executed(_drawEnergy(state, turnPlayer!)),

      // 7.6.2「手番プレイヤーはカードを 1 枚引きます」(5.6.1)
      StepId.s7_6_2 => _draw(state, turnPlayer!, 1),

      // 8.3.4「ライブカード置き場のカードをすべて表向きにし、
      //        ライブカードでないカードを控え室へ」
      // ★8.3.4.1（「ライブできない」なら全部控え室へ）は実装しない。
      //   「ライブできない」は効果由来であり D-A に抵触する。
      StepId.s8_3_4 => _Executed(_revealLiveStage(state, turnPlayer!)),

      // 8.3.11 エール。★途中でデッキが尽きたらリフレッシュして続行 (10.2.1)。
      StepId.s8_3_11 => _yell(state, turnPlayer!),

      // 8.3.12.1 解決領域のドローアイコンの数だけ引く。★所有者で絞らない。
      StepId.s8_3_12 => _draw(
          state, turnPlayer!, _aggregator.yellDrawCount(state).count),

      // 8.4.8「各プレイヤーは、自身のライブ置き場に残っているカード、
      //        解決領域にあるエールによって公開したカードそれぞれをすべて
      //        自身の控え室に移動します」
      StepId.s8_4_8 => _Executed(_clearAfterLive(state)),

      // 8.4.13 先攻入れ替え。★参照するのは 8.4.7 の移動実績。
      StepId.s8_4_13 => _Executed(_swapFirstPlayer(state)),

      // 8.4.14「このターンを終了する」
      StepId.s8_4_14 => _Executed(_endTurn(state)),

      // それ以外は素通り。盤面を触らない。
      _ => _Executed(state),
    };
  }

  /// 7.4.1: 手番プレイヤーのエネルギー置き場とメンバーエリアをアクティブにする。
  ///
  /// ★メンバーエリアで向きを持つのは [MemberStack.member] だけ (4.5.4)。
  ///   下に重ねられたカードは向きを持たない (4.5.5.2) ので触らない。
  GameState _activateAll(GameState state, String playerId) {
    final energyField = [
      for (final card in cardsIn(state, playerId, Zone.energyField))
        card.copyWith(orientation: CardOrientation.active),
    ];
    var next = replaceZone(state, playerId, Zone.energyField, energyField);

    final areas = [
      for (final area in next.playerOf(playerId).memberAreas)
        area.copyWith(stacks: [
          for (final stack in area.stacks)
            stack.copyWith(
              member: stack.member.copyWith(orientation: CardOrientation.active),
            ),
        ]),
    ];
    return _withMemberAreas(next, playerId, areas);
  }

  /// 7.5.2: エネルギーデッキ置き場から 1 枚をエネルギー置き場へ。
  ///
  /// ★★ 「一番上」ではなく**無作為に 1 枚**（決定 D73 / 整合性チェック B-2 の解消）★★
  ///   4.9.2 がエネルギーデッキ置き場を「カードの順番は管理されません」と定めており、
  ///   6.2.1.3 がシャッフルを指示しない以上、index 0 は
  ///   **プレイヤーが構築時に決めた順**になってしまう。根拠は `energy_deck.dart`。
  ///
  /// ★実装は `drawEnergyRandomly` 1 つ。ここと `DrawEnergy` と 6.2.1.7 が同じものを通る。
  GameState _drawEnergy(GameState state, String playerId) =>
      drawEnergyRandomly(state, playerId, 1, rng);

  /// カードを [count] 枚引く (5.6.1 / 5.6.2)。
  ///
  /// ★途中でデッキが尽きたらリフレッシュして続行する (10.2.1)。
  _Executed _draw(GameState state, String playerId, int count) {
    if (count <= 0) return _Executed(state);

    final taken = _refresher.takeFromMainDeck(state, playerId, count);
    final hand = cardsIn(taken.state, playerId, Zone.hand);
    return _Executed(
      replaceZone(
          taken.state,
          playerId,
          Zone.hand,
          // 4.1.2.1: 4.11.2 により手札は非公開領域。
          insertInto(hand, [for (final c in taken.drawn) placedIn(c, Zone.hand)],
              ZonePosition.bottom)),
      refreshCount: taken.refreshCount,
    );
  }

  /// 8.3.4: ライブカード置き場をすべて表向きにし、ライブでないカードを控え室へ。
  GameState _revealLiveStage(GameState state, String playerId) {
    final revealed = [
      for (final card in cardsIn(state, playerId, Zone.liveStage))
        card.copyWith(face: FaceState.faceUp),
    ];

    final live = <CardInstance>[];
    var next = state;
    for (final card in revealed) {
      final master = cards[card.cardNumber];
      if (master != null && master.cardType != CardType.live) {
        // 4.1.7: オーナーの領域へ。
        next = replaceZone(
          next,
          card.ownerId,
          Zone.waitingRoom,
          insertInto(
              cardsIn(next, card.ownerId, Zone.waitingRoom),
              // 4.1.2.1 / 4.12.2: 控え室は公開領域。
              [placedIn(card, Zone.waitingRoom)],
              ZonePosition.top),
        );
      } else {
        live.add(card);
      }
    }
    return replaceZone(next, playerId, Zone.liveStage, live);
  }

  /// 8.3.11 エール。
  ///
  /// 「手番プレイヤーは、自身のメインデッキの一番上のカードを解決領域に移動する処理を、
  /// 前述の合計ブレード数と同じ回数繰り返します」
  ///
  /// ★★ 途中でデッキが尽きたらその場でリフレッシュして残り回数を続行する ★★
  ///   10.2.1。チェックタイミングを待たない。
  _Executed _yell(GameState state, String playerId) {
    // 8.3.10 の合計ブレード数。★アクティブ状態のメンバーのみ。
    final blades = _aggregator.bladeTotal(state, playerId).total;
    if (blades <= 0) return _Executed(state);

    final taken = _refresher.takeFromMainDeck(state, playerId, blades);

    // 4.14.2: 解決領域は公開領域。→ 4.1.2.1 により公開状態 = 表向き。
    final revealed = [
      for (final card in taken.drawn) placedIn(card, Zone.resolution),
    ];

    return _Executed(
      replaceResolution(taken.state, [...taken.state.resolution, ...revealed]),
      refreshCount: taken.refreshCount,
    );
  }

  /// 8.4.8: ライブ置き場の残りと解決領域のエールを、それぞれのオーナーの控え室へ。
  ///
  /// ★解決領域は両プレイヤー共有で 1 つだけ (4.14.1) なので `ownerId` で振り分ける。
  GameState _clearAfterLive(GameState state) {
    var next = state;

    for (final player in state.players) {
      final liveStage = cardsIn(next, player.playerId, Zone.liveStage);
      if (liveStage.isEmpty) continue;
      next = replaceZone(next, player.playerId, Zone.liveStage, const []);
      for (final card in liveStage) {
        next = _toWaitingRoom(next, card);
      }
    }

    for (final card in next.resolution) {
      next = _toWaitingRoom(next, card);
    }
    return replaceResolution(next, const []);
  }

  GameState _toWaitingRoom(GameState state, CardInstance card) => replaceZone(
        state,
        card.ownerId, // 4.1.7
        Zone.waitingRoom,
        insertInto(
            cardsIn(state, card.ownerId, Zone.waitingRoom),
            // 4.1.2.1 / 4.12.2: 控え室は公開領域。4.3.1: 向きは持たない。
            [placedIn(card, Zone.waitingRoom)],
            ZonePosition.top),
      );

  /// 8.4.13: 先攻入れ替え。
  ///
  /// 「8.4.7 において、一方のプレイヤーのみが成功ライブカード置き場にカードを
  /// 移動していた場合、そのプレイヤーが先攻プレイヤーとなり、
  /// その相手が後攻プレイヤーとなります」
  ///
  /// ★★ 参照するのは 8.4.6 の勝敗ではなく 8.4.7 の移動実績 ★★
  ///   8.4.7.1 により「両者勝利かつライブ置き場に 2 枚あるプレイヤー」は移動しない。
  ///   勝敗で判定すると、同点で片方だけが移動したケースを取りこぼす。
  ///
  /// ★`firstPlayerId` を書き換えるのはここだけ。
  GameState _swapFirstPlayer(GameState state) {
    final record = state.liveJudgement;
    if (record == null || !record.hasSoleMover) {
      // そうでなければ現在の先攻が継続する。
      return state;
    }
    return state.copyWith(firstPlayerId: record.movedToSuccessIds.single);
  }

  /// 8.4.14: このターンを終了する。
  GameState _endTurn(GameState state) => state.copyWith(
        turnNumber: state.turnNumber + 1,
        clearLiveJudgement: true,
      );

  GameState _withMemberAreas(
    GameState state,
    String playerId,
    List<MemberArea> areas,
  ) =>
      state.copyWith(
        players: [
          for (final p in state.players)
            p.playerId == playerId ? p.copyWith(memberAreas: areas) : p,
        ],
      );
}

class _Executed {
  const _Executed(this.state, {this.refreshCount = 0});

  final GameState state;
  final int refreshCount;
}
