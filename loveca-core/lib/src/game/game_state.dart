/// ゲーム状態の型.
///
/// 総合ルール 4 章・8.4 に対応。確定の根拠は `docs/PhaseEngine設計メモ.md`。
///
/// ★★ このパッケージは Flutter に一切依存させないこと ★★
///   Phase 6 の権威サーバが同じ型を再利用する。日時・乱数・IO を持ち込まない。

library;

import '../entities/deck.dart';
import 'card_instance.dart';
import 'member_area.dart';
import 'step.dart';

/// ライブ勝敗判定フェイズ 8.4 の 1 回分の記録。
///
/// ★★ 勝敗と移動実績は別物 ★★
///   8.4.13 が参照するのは 8.4.6 で決まる勝敗ではなく、
///   8.4.7 で実際に成功ライブカード置き場へカードを移動したかどうかである。
///
///   8.4.7.1 により「両者がライブに勝利し、かつライブカード置き場に 2 枚ある
///   プレイヤー」はカードを移動しない。したがって両者は一致しない。
///
///   ずれる例: 同点で A はライブ置き場に 1 枚、B は 2 枚。
///     8.4.6  → 8.4.6.2 により**両者勝利**
///     8.4.7  → B は 8.4.7.1 で移動しないので **A のみ移動**
///     8.4.13 → 一方のみが移動しているので **A が先攻になる**
///
///   勝敗で判定すると「両者勝利＝勝者が 1 人に定まらない」として
///   先攻据え置きと誤る。
class LiveJudgementRecord {
  const LiveJudgementRecord({
    this.winnerIds = const {},
    this.movedToSuccessIds = const {},
  });

  /// 8.4.6 で確定したライブの勝者。
  ///
  /// - 8.4.6.1 両者ともライブカード置き場にカードが無い場合は勝者なし (空)
  /// - 8.4.6.2 同点の場合は**両者勝利** (2 人)
  ///
  /// 決定 D10 によりこの確定は手動ボタンで行う。
  /// ★1.2.1.2 の引き分け (両者同時に成功ライブカード 3 枚以上) とは別の概念。
  final Set<String> winnerIds;

  /// ★8.4.7 で実際に成功ライブカード置き場へカードを移動したプレイヤー。
  ///
  /// ★★ 8.4.13 が参照するのはこちら ★★
  ///   8.4.13「8.4.7 において、一方のプレイヤーのみが成功ライブカード置き場に
  ///   カードを移動していた場合、そのプレイヤーが先攻プレイヤーとなり、
  ///   その相手が後攻プレイヤーとなります」
  final Set<String> movedToSuccessIds;

  /// 8.4.13 の条件「一方のプレイヤーのみが移動していた」を満たすか。
  ///
  /// ★判定そのもの (誰が先攻になるか) は行わない。条件の観測のみ。
  bool get hasSoleMover => movedToSuccessIds.length == 1;

  LiveJudgementRecord copyWith({
    Set<String>? winnerIds,
    Set<String>? movedToSuccessIds,
  }) =>
      LiveJudgementRecord(
        winnerIds: winnerIds ?? this.winnerIds,
        movedToSuccessIds: movedToSuccessIds ?? this.movedToSuccessIds,
      );
}

/// 1 人のプレイヤーに属する領域。総合ルール 4.1.1。
///
/// ★解決領域 (4.14) はここに無い。両プレイヤー共有で 1 つだけ存在するため
///   [GameState.resolution] が持つ (4.14.1)。
class PlayerState {
  const PlayerState({
    required this.playerId,
    this.memberAreas = const [],
    this.hand = const [],
    this.mainDeck = const [],
    this.energyDeck = const [],
    this.energyField = const [],
    this.liveStage = const [],
    this.successLive = const [],
    this.waitingRoom = const [],
    this.exile = const [],
    this.mulliganAside = const [],
    this.freeArea = const [],
  });

  final String playerId;

  /// メンバーエリア。総合ルール 4.5。
  ///
  /// ステージ (4.4) はこれを統合した領域であり、別の実体を持たない (4.4.1)。
  /// 枚数は `RuleConfig.stageAreaCount` (4.5.2 により 3)。
  final List<MemberArea> memberAreas;

  /// 手札。総合ルール 4.11。非公開領域 (4.11.2)。
  final List<CardInstance> hand;

  /// メインデッキ置き場。総合ルール 4.8。
  /// ★非公開で**順番が管理される** (4.8.2)。先頭を「一番上」とする。
  final List<CardInstance> mainDeck;

  /// エネルギーデッキ置き場。総合ルール 4.9。
  /// ★非公開で順番は管理されない (4.9.2)。
  final List<CardInstance> energyDeck;

  /// エネルギー置き場。総合ルール 4.7。向きを示す配置状態を持つ (4.7.3)。
  /// ★5.9.1 のコスト支払いはウェイトにするだけで、カードはこの領域から動かない。
  final List<CardInstance> energyField;

  /// ライブカード置き場。総合ルール 4.6。
  /// 8.2.2 / 8.2.4 で裏向きに置き、8.3.4 で表向きにする。
  final List<CardInstance> liveStage;

  /// 成功ライブカード置き場。総合ルール 4.10。
  /// ★順番が管理され、これまでに置かれているカードの**上**に置く (4.10.2)。
  /// 1.2.1.1 の勝利条件 (3 枚) が数える領域。
  final List<CardInstance> successLive;

  /// 控え室。総合ルール 4.12。
  final List<CardInstance> waitingRoom;

  /// 除外領域。総合ルール 4.13。
  final List<CardInstance> exile;

  // ---- ★ここから下は総合ルール 4 章の領域ではない (OutOfRuleZone) ----

  /// 6.2.1.6 のマリガンで「裏向きに脇に置く」カードの一時置き場。
  ///
  /// ★条文は 4 章の領域名を与えていない。6.2.1.6 の手順内でメインデッキ置き場へ戻る。
  final List<CardInstance> mulliganAside;

  /// 盤外の自由置き場。ルールには存在しない。
  ///
  /// 効果を手動で処理する際の一時退避先 (CLAUDE.md §1)。
  final List<CardInstance> freeArea;

  PlayerState copyWith({
    List<MemberArea>? memberAreas,
    List<CardInstance>? hand,
    List<CardInstance>? mainDeck,
    List<CardInstance>? energyDeck,
    List<CardInstance>? energyField,
    List<CardInstance>? liveStage,
    List<CardInstance>? successLive,
    List<CardInstance>? waitingRoom,
    List<CardInstance>? exile,
    List<CardInstance>? mulliganAside,
    List<CardInstance>? freeArea,
  }) =>
      PlayerState(
        playerId: playerId,
        memberAreas: memberAreas ?? this.memberAreas,
        hand: hand ?? this.hand,
        mainDeck: mainDeck ?? this.mainDeck,
        energyDeck: energyDeck ?? this.energyDeck,
        energyField: energyField ?? this.energyField,
        liveStage: liveStage ?? this.liveStage,
        successLive: successLive ?? this.successLive,
        waitingRoom: waitingRoom ?? this.waitingRoom,
        exile: exile ?? this.exile,
        mulliganAside: mulliganAside ?? this.mulliganAside,
        freeArea: freeArea ?? this.freeArea,
      );
}

/// ゲーム全体の状態。
class GameState {
  const GameState({
    required this.players,
    required this.firstPlayerId,
    required this.cursor,
    this.turnNumber = 1,
    this.resolution = const [],
    this.liveJudgement,
    this.config = RuleConfig.standard,
  });

  /// 参加プレイヤー。
  final List<PlayerState> players;

  /// ★★ 現ターンの先攻プレイヤー ★★
  ///
  /// フェイズはロール (`PhaseRole`) で定義され実プレイヤー ID を持たないため、
  /// 手番プレイヤーとアクティブプレイヤーはここから実行時に解決する
  /// (7.2.1.1 / 7.2.1.2)。
  ///
  /// ★★ これを書き換えるのはステップ 8.4.13 の 1 箇所だけ ★★
  ///   参照するのは 8.4.6 の勝敗ではなく [liveJudgement] の
  ///   [LiveJudgementRecord.movedToSuccessIds] (8.4.7 の移動実績)。
  ///
  /// 他に `firstPlayerId` に依存する規定:
  ///   1.3.4 / 1.3.4.2  複数プレイヤーの同時選択はアクティブプレイヤーから先に
  ///   9.5.3.2 / 9.5.3.3 チェックタイミングでの待機自動能力のプレイ順
  ///   10.2.4            両者同時リフレッシュは現ターンの先攻が先
  final String firstPlayerId;

  /// 進行の現在地。(PhaseId, StepId) の組。
  final StepCursor cursor;

  final int turnNumber;

  /// 解決領域。総合ルール 4.14。
  ///
  /// ★★ 両プレイヤーで共有され、ゲーム中に 1 つだけ存在する (4.14.1) ★★
  ///   プレイヤーごとに持たせてはいけない。
  ///
  ///   先攻パフォーマンスフェイズの後も先攻のエールカードが残ったまま
  ///   後攻パフォーマンスフェイズに入るため、8.3.14 のハート合計は
  ///   `CardInstance.ownerId` での絞り込みが必須になる。
  ///   マスターの定義 (3.1.2「その領域が属しているプレイヤー」) が共有領域では定まらない。
  final List<CardInstance> resolution;

  /// 現在のライブ勝敗判定フェイズの記録。8.4 の外では null。
  ///
  /// ★8.4.13 はここの [LiveJudgementRecord.movedToSuccessIds] を参照する。
  final LiveJudgementRecord? liveJudgement;

  /// デッキ構築ルール。総合ルール 6.1。
  ///
  /// ★6.1.2 により構築条件を置換する効果が存在しうるため定数にしない。
  final RuleConfig config;

  GameState copyWith({
    List<PlayerState>? players,
    String? firstPlayerId,
    StepCursor? cursor,
    int? turnNumber,
    List<CardInstance>? resolution,
    LiveJudgementRecord? liveJudgement,
    bool clearLiveJudgement = false,
  }) =>
      GameState(
        players: players ?? this.players,
        firstPlayerId: firstPlayerId ?? this.firstPlayerId,
        cursor: cursor ?? this.cursor,
        turnNumber: turnNumber ?? this.turnNumber,
        resolution: resolution ?? this.resolution,
        liveJudgement:
            clearLiveJudgement ? null : (liveJudgement ?? this.liveJudgement),
        config: config,
      );
}
