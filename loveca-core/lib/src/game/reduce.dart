/// リデューサ.
///
/// `reduce(GameState, GameAction) -> GameState`。
/// CLAUDE.md §1 (D-D)「Phase 6 の権威サーバが同じ `reduce` / `redact` を
/// コピーゼロで再利用する」を満たすための関数。
///
/// ★★ 既存の実装を作り直さない ★★
///   このファイルは 3a-1〜3a-3 で実装済みの関数への**ディスパッチャ**である。
///   移動は `card_move.dart`、リフレッシュは `refresh.dart`、
///   整理は `rule_process.dart`、進行は `step_engine.dart` が持つ。
///   ここにルールの再実装を書かないこと。
///
/// ★★ 「純関数」の意味 ★★
///   このファイルが保証するのは次の 2 点であって、参照透過性ではない。
///
///   1. **環境非依存** — `DateTime.now()` / seed なし `Random()` / IO を含まない
///   2. **同一 seed + 同一アクション列 → 同一結果** — リプレイ再現性
///
///   [DeterministicRng] は内部状態を持つため、**同じ `rng` インスタンスで
///   同じ `reduce` を 2 回呼ぶと結果が違う**。これは
///   「乱数を [GameAction] の外から注入する」という設計の必然であり、
///   リプレイは `SeededRng(seed)` を張り直して同じアクション列を流すことで再現する。
///
///   ★参照透過でないのは乱数を消費する 6 つだけ。
///     [ShuffleZone] … 5.5.1 のシャッフル
///     [Refresh]     … 10.2.3 のシャッフル
///     [DrawCards]   … 10.2.1 の割り込みリフレッシュが起きた場合のみ
///     [AdvanceStep] … ★同上。7.6.2 (`_draw`) と 8.3.11 (`_yell`) が
///                     `Refresher.takeFromMainDeck` を通るため
///     [DrawEnergy]  … ★4.9.2 の無作為抽出（決定 D73 / `energy_deck.dart`）
///     [LookAtTop]   … ★**条件つき**。10.2.2.2 で枚数が足りないときだけ
///                     `refreshPlayer` を通り 10.2.3 のシャッフルを消費する
///                     （`ルール整合性チェック_v1.06.md` D-19）
///   他のアクションはすべて完全に純粋。
///
///   ★★ この列挙は 3 つと書かれていた。書かれた時点で既に誤っていた ★★
///     [AdvanceStep] が乱数を消費する経路 (`step_engine.dart` の 7.6.2 / 8.3.11 と
///     `refresh.dart`) は **3a-3** で存在しており、この断定は **3a-4** で書かれた。
///     すなわち**断定のほうが後に書かれ、書いた時点で実装と食い違っていた**。
///     `ルール整合性チェック_v1.06.md` D-15 (a)。///
///   ★★ この列挙はまた古くなる。次に足す人はここでは済まない ★★
///     4 → 5 に直した作業（D-15 (b)）が 6 を見落とし、
///     5 → 6 に直したこの作業も **7 つ目で同じことが起きる**
///     （`ルール整合性チェック_v1.06.md` D-15 → D-16 → **D-19**）。
///     ★**「ここを直せば済む」と読まないこと。**列挙は消費経路が増えるたびに
///     人手で追わなければならず、`dart analyze` も `dart test` も検知しない。
///
///     ★★ 判定が要るなら列挙ではなく**観測**を使うこと ★★
///       UI 側は列挙をやめ、`nextInt` の呼び出し回数を数えて
///       **dispatch の前後で増えたかどうか**で判定している
///       （決定 D90-1 / `loveca-ui/lib/src/state/counting_rng.dart`）。
///       [DeterministicRng] はメソッドが `nextInt` 1 つだけで `shuffled` は
///       extension なので、包めば全経路が数に入る。
///       ★[AdvanceStep] は**消費したりしなかったりする**ので、
///       そもそも列挙では精度が足りない。
///
///     ★ここに残しているのは「参照透過でない理由の説明」としてであって、
///     判定の根拠として使うためではない。
///
/// ★★ seed も RNG の状態も [GameState] / [GameAction] に持たせない ★★
///   seed はサーバ側だけが保持する（権威サーバ設計）。
///
/// ★★ undo / undoStep はここに無い ★★
///   履歴を要するため `GameSession` 層（`history.dart`）が持つ。

library;

import '../entities/card.dart';
import 'card_instance.dart';
import 'card_move.dart';
import 'energy_deck.dart';
import 'game_action.dart';
import 'game_state.dart';
import 'history.dart';
import 'member_area.dart';
import 'refresh.dart';
import 'rng.dart';
import 'rule_process.dart';
import 'step.dart';
import 'step_engine.dart';
import 'zone.dart';

/// [reduce] に外から注入する環境。
///
/// ★[GameState] にも [GameAction] にも入れないもの。
class ReduceContext {
  const ReduceContext({
    required this.cards,
    required this.rng,
    this.mode = ProgressionMode.twoPlayer,
  });

  /// cardNumber -> Card。種別判定と集計に要る。
  final Map<String, Card> cards;

  /// 乱数源。★seed はここにだけあり、[GameState] には無い。
  final DeterministicRng rng;

  /// ★★ 進行のしかた (決定 D88)。[GameState] には置かない ★★
  ///   1.1.1 が「原則 2 名」とし、それ以外のプレイヤー数のルールは
  ///   「現在の総合ルールでは対応していません」と書いている。
  ///   条文が対応しないと書いた区分を [GameState] に置くと
  ///   **条文に無いものが盤面の状態になる**。
  ///   ★[GameHistory] は [GameState] のスナップショット (D36) なので、
  ///   状態に置くと **undo でモードが戻る**という意味の無い操作が型の上で可能になる。
  ///   ★先例は seed / 乱数 (D79) —— 再現性の入力が `context` であることは既に設計に入っている。
  ///
  /// ★★ 代償を書いておく ★★
  ///   同じログを**違うモードの `context` で再生すると結果が食い違う**。
  ///   これは seed について既に成立している性質と同じである。
  final ProgressionMode mode;

  Refresher get refresher => Refresher(rng: rng);
  RuleProcessor get processor => RuleProcessor(cards: cards);
  StepEngine get engine => StepEngine(cards: cards, rng: rng, mode: mode);
}

/// [reduce] の副次情報。
///
/// [reduce] は [GameState] だけを返すため、整理の警告 (10.3 / 10.6) や
/// 割り込みリフレッシュの回数が失われる。UI がそれらを要るときはこちらを使う。
class ReduceReport {
  const ReduceReport({
    required this.state,
    this.tidy,
    this.advance,
    this.refreshCount = 0,
  });

  final GameState state;

  /// 整理の結果。[Tidy] と、チェックタイミングを含む [AdvanceStep] で非 null。
  final RuleProcessResult? tidy;

  /// 進行の結果。[AdvanceStep] で非 null。
  final AdvanceResult? advance;

  /// このアクションの中で割り込んだリフレッシュの回数 (10.2.1)。
  final int refreshCount;

  /// ★★ 実行せずに通り越したカーソル (決定 D88) ★★
  ///
  ///   [AdvanceStep] 以外では常に空。★**黙って飛ばさない**ための口である。
  ///
  /// ★★ フィールドにしない ★★
  ///   同じ値を [advance] とここの 2 箇所に持つと必ず食い違う
  ///   (`ルール整合性チェック_v1.06.md` D-15)。導出だけを置く。
  List<StepCursor> get skipped => advance?.skipped ?? const [];
}

/// アクションを適用した新しい [GameState] を返す。
///
/// ★入力の [state] は変更しない。[GameState] は完全にイミュータブル。
GameState reduce(
  GameState state,
  GameAction action, {
  required ReduceContext context,
}) =>
    reduceWithReport(state, action, context: context).state;

/// [reduce] と同じだが副次情報も返す。
ReduceReport reduceWithReport(
  GameState state,
  GameAction action, {
  required ReduceContext context,
}) {
  return switch (action) {
    // ---- A. 手動の物理操作 ----
    MoveCard() => ReduceReport(state: _moveCard(state, action)),
    MoveToResolution() => ReduceReport(state: _moveToResolution(state, action)),
    MoveFromResolution() =>
      ReduceReport(state: _moveFromResolution(state, action)),
    MoveOutOfRule() => ReduceReport(state: _moveOutOfRule(state, action)),
    MoveFromOutOfRule() =>
      ReduceReport(state: _moveFromOutOfRule(state, action)),
    FlipCard() => ReduceReport(state: _flipCard(state, action)),
    SetOrientation() => ReduceReport(state: _setOrientation(state, action)),
    ShuffleZone() => ReduceReport(state: _shuffle(state, action, context)),
    DrawCards() => _draw(state, action, context),
    // ★4.9.2 / 4.9.3 の無作為抽出（決定 D73）。実装は `energy_deck.dart` 1 つ。
    DrawEnergy() => ReduceReport(
        state: drawEnergyRandomly(
            state, action.playerId, action.count, context.rng),
      ),
    LookAtTop() => _lookAtTop(state, action, context),

    // ---- A-2. メンバーエリアの操作 ----
    PlaceMemberInArea() => ReduceReport(state: _placeMember(state, action)),
    MoveMemberBetweenAreas() =>
      ReduceReport(state: _moveMemberBetweenAreas(state, action)),
    MoveMemberOut() => ReduceReport(state: _moveMemberOut(state, action)),
    SetMemberOrientation() =>
      ReduceReport(state: _setMemberOrientation(state, action)),
    StackUnderMember() => ReduceReport(state: _stackUnder(state, action)),
    DetachFromMember() => ReduceReport(state: _detach(state, action)),

    // ---- B. 進行・ルール処理 ----
    AdvanceStep() => _advance(state, action, context),
    Refresh() => ReduceReport(state: _refresh(state, action, context)),
    Tidy() => _tidy(state, context),
    SetLiveJudgement() => ReduceReport(
        state: action.record == null
            ? state.copyWith(clearLiveJudgement: true)
            : state.copyWith(liveJudgement: action.record),
      ),
  };
}

/// [GameSession] にアクションを適用する。
///
/// ★現在の状態を履歴に積んでから [reduce] する。
///   これにより `undo` / `undoStep` がそのまま効く（決定 D36）。
extension SessionReduce on GameSession {
  GameSession apply(GameAction action, {required ReduceContext context}) =>
      record(reduce(state, action, context: context));
}

// ===========================================================================
// 物理操作
// ===========================================================================

/// 領域から 1 枚取り出す。見つからなければ例外（呼び出し側のバグ）。
({List<CardInstance> rest, CardInstance card}) _takeOut(
  List<CardInstance> zone,
  String instanceId,
  String what,
) {
  final index = zone.indexWhere((c) => c.instanceId == instanceId);
  if (index < 0) {
    throw ArgumentError('$what に instanceId "$instanceId" が無い');
  }
  return (
    rest: [...zone.sublist(0, index), ...zone.sublist(index + 1)],
    card: zone[index],
  );
}

GameState _moveCard(GameState state, MoveCard a) {
  final from = cardsIn(state, a.fromPlayerId, a.from);
  final taken = _takeOut(from, a.instanceId, a.from.name);

  final next = replaceZone(state, a.fromPlayerId, a.from, taken.rest);
  return replaceZone(
    next,
    a.toPlayerId,
    a.to,
    insertInto(cardsIn(next, a.toPlayerId, a.to),
        // 4.1.2.1: 移動先の領域の規定に合わせる。
        [placedIn(taken.card, a.to)],
        // 4.10.2: 領域が置き場所を定めているならそちらが優先する。
        positionIn(a.to, a.position)),
  );
}

GameState _moveToResolution(GameState state, MoveToResolution a) {
  final from = cardsIn(state, a.fromPlayerId, a.from);
  final taken = _takeOut(from, a.instanceId, a.from.name);
  final next = replaceZone(state, a.fromPlayerId, a.from, taken.rest);
  // 4.14.2: 解決領域は公開領域。→ 4.1.2.1 により公開状態 = 表向き。
  return replaceResolution(
      next, [...next.resolution, placedIn(taken.card, Zone.resolution)]);
}

GameState _moveFromResolution(GameState state, MoveFromResolution a) {
  final taken = _takeOut(state.resolution, a.instanceId, '解決領域');
  final next = replaceResolution(state, taken.rest);
  return replaceZone(
    next,
    a.toPlayerId,
    a.to,
    // 4.1.2.1: 移動先の領域の規定に合わせる。
    insertInto(cardsIn(next, a.toPlayerId, a.to), [placedIn(taken.card, a.to)],
        // 4.10.2: 領域が置き場所を定めているならそちらが優先する。
        positionIn(a.to, a.position)),
  );
}

GameState _moveOutOfRule(GameState state, MoveOutOfRule a) {
  final taken =
      _takeOut(cardsIn(state, a.playerId, a.from), a.instanceId, a.from.name);
  final next = replaceZone(state, a.playerId, a.from, taken.rest);
  return replaceOutOfRuleZone(next, a.playerId, a.to,
      [...cardsInOutOfRule(next, a.playerId, a.to), taken.card]);
}

GameState _moveFromOutOfRule(GameState state, MoveFromOutOfRule a) {
  final taken = _takeOut(
      cardsInOutOfRule(state, a.playerId, a.from), a.instanceId, a.from.name);
  final next = replaceOutOfRuleZone(state, a.playerId, a.from, taken.rest);
  return replaceZone(
    next,
    a.playerId,
    a.to,
    // ★4.1.2.1: 出どころはルール外の置き場だが、**着地先は 4 章の領域**なので効く。
    insertInto(cardsIn(next, a.playerId, a.to), [placedIn(taken.card, a.to)],
        // 4.10.2: 領域が置き場所を定めているならそちらが優先する。
        positionIn(a.to, a.position)),
  );
}

GameState _flipCard(GameState state, FlipCard a) => _mapCardInZone(
      state,
      a.playerId,
      a.zone,
      a.instanceId,
      (card) => card.copyWith(face: a.face),
    );

GameState _setOrientation(GameState state, SetOrientation a) => _mapCardInZone(
      state,
      a.playerId,
      a.zone,
      a.instanceId,
      (card) => card.copyWith(orientation: a.orientation),
    );

GameState _mapCardInZone(
  GameState state,
  String playerId,
  Zone zone,
  String instanceId,
  CardInstance Function(CardInstance) f,
) {
  final cards = cardsIn(state, playerId, zone);
  final index = cards.indexWhere((c) => c.instanceId == instanceId);
  if (index < 0) {
    throw ArgumentError('${zone.name} に instanceId "$instanceId" が無い');
  }
  return replaceZone(state, playerId, zone, [
    for (var i = 0; i < cards.length; i++)
      if (i == index) f(cards[i]) else cards[i],
  ]);
}

/// 総合ルール 5.5.1 シャッフル。★乱数を消費する。
GameState _shuffle(GameState state, ShuffleZone a, ReduceContext ctx) =>
    replaceZone(state, a.playerId, a.zone,
        ctx.rng.shuffled(cardsIn(state, a.playerId, a.zone)));

/// 総合ルール 5.6.1 / 5.6.2 引く。★10.2.1 の割り込みリフレッシュを含む。
ReduceReport _draw(GameState state, DrawCards a, ReduceContext ctx) {
  final taken = ctx.refresher.takeFromMainDeck(state, a.playerId, a.count);
  return ReduceReport(
    state: replaceZone(
      taken.state,
      a.playerId,
      Zone.hand,
      insertInto(
          cardsIn(taken.state, a.playerId, Zone.hand),
          // 4.1.2.1: 4.11.2 により手札は非公開領域。
          [for (final c in taken.drawn) placedIn(c, Zone.hand)],
          ZonePosition.bottom),
    ),
    refreshCount: taken.refreshCount,
  );
}

/// 総合ルール 10.2.2.2 上から見る。
///
/// ★見る行為そのものは盤面を変えない。枚数が足りない場合のリフレッシュだけ行う。
ReduceReport _lookAtTop(GameState state, LookAtTop a, ReduceContext ctx) {
  if (!ctx.refresher.needsRefreshForLook(state, a.playerId, a.count)) {
    return ReduceReport(state: state);
  }
  return ReduceReport(
    state: ctx.refresher.refreshPlayer(state, a.playerId),
    refreshCount: 1,
  );
}

// ===========================================================================
// メンバーエリアの操作
// ===========================================================================

/// [slot] のメンバーエリアを書き換える。無ければ作る（ステージは 4.5.2 で常に 3 つ）。
GameState _withArea(
  GameState state,
  String playerId,
  MemberAreaSlot slot,
  MemberArea Function(MemberArea) f,
) {
  final areas = state.playerOf(playerId).memberAreas;
  final index = areas.indexWhere((area) => area.slot == slot);
  final updated = index < 0
      ? [...areas, f(MemberArea(slot: slot))]
      : [
          for (var i = 0; i < areas.length; i++)
            if (i == index) f(areas[i]) else areas[i],
        ];

  return state.copyWith(players: [
    for (final p in state.players)
      p.playerId == playerId ? p.copyWith(memberAreas: updated) : p,
  ]);
}

MemberArea _areaOf(GameState state, String playerId, MemberAreaSlot slot) =>
    state.playerOf(playerId).memberAreas.firstWhere(
          (area) => area.slot == slot,
          orElse: () => MemberArea(slot: slot),
        );

GameState _placeMember(GameState state, PlaceMemberInArea a) {
  final taken =
      _takeOut(cardsIn(state, a.playerId, a.from), a.instanceId, a.from.name);
  final next = replaceZone(state, a.playerId, a.from, taken.rest);

  // ★末尾に積む。リスト順が配置順で、末尾が 10.4.1 の
  //   「最も後から置かれたメンバー」になる。
  return _withArea(
    next,
    a.playerId,
    a.slot,
    (area) => area.copyWith(stacks: [
      ...area.stacks,
      MemberStack(
        // 4.3.2.3: 配置状態が指定される領域なので既定はアクティブ状態。
        // ★4.1.2.1 / 4.5.3: メンバーエリアは公開領域なので表向きで置かれる。
        //   4.5 に表示面の条文は無く、根拠は 4.5.3 の「公開領域」である。
        member: taken.card
            .copyWith(orientation: a.orientation, face: FaceState.faceUp),
      ),
    ]),
  );
}

/// 総合ルール 4.5.5.3: 下のカードも重なったまま同時に移動する。
GameState _moveMemberBetweenAreas(GameState state, MoveMemberBetweenAreas a) {
  final from = _areaOf(state, a.playerId, a.fromSlot);
  final index =
      from.stacks.indexWhere((s) => s.member.instanceId == a.instanceId);
  if (index < 0) {
    throw ArgumentError(
        '${a.fromSlot.label} に instanceId "${a.instanceId}" のメンバーが無い');
  }
  final stack = from.stacks[index];

  final next = _withArea(
    state,
    a.playerId,
    a.fromSlot,
    (area) => area.copyWith(stacks: [
      for (var i = 0; i < area.stacks.length; i++)
        if (i != index) area.stacks[i],
    ]),
  );

  // ★スタックごと移す。解消は起きない。
  return _withArea(
    next,
    a.playerId,
    a.toSlot,
    (area) => area.copyWith(stacks: [...area.stacks, stack]),
  );
}

/// 総合ルール 4.5.5.4: メンバーカードのみが移動し、下のカードは残る。
GameState _moveMemberOut(GameState state, MoveMemberOut a) {
  final area = _areaOf(state, a.playerId, a.slot);
  final index =
      area.stacks.indexWhere((s) => s.member.instanceId == a.instanceId);
  if (index < 0) {
    throw ArgumentError(
        '${a.slot.label} に instanceId "${a.instanceId}" のメンバーが無い');
  }
  final stack = area.stacks[index];

  // ★4.5.5.4.1 / 4.5.5.4.2: 下のカードはそのままメンバーエリアに残る。
  //   ここで控え室へ送ってはいけない。10.1.2 によりそれはチェックタイミングでの
  //   ルール処理 (10.5.3 / 10.5.4) の仕事。
  final next = _withArea(
    state,
    a.playerId,
    a.slot,
    (target) => target.copyWith(
      stacks: [
        for (var i = 0; i < target.stacks.length; i++)
          if (i != index) target.stacks[i],
      ],
      orphans: [...target.orphans, ...stack.beneath],
    ),
  );

  return replaceZone(
    next,
    a.toPlayerId,
    a.to,
    insertInto(
      cardsIn(next, a.toPlayerId, a.to),
      // 4.3.1 / 4.1.2.1: 移動先の領域の規定に向きと表示面を合わせる。
      // ★4.5.4 の向きは移動先には引き継がれない（4.7 以外は向きを持たない）。
      [placedIn(stack.member, a.to)],
      // 4.10.2: 領域が置き場所を定めているならそちらが優先する。
      positionIn(a.to, a.position),
    ),
  );
}

GameState _setMemberOrientation(GameState state, SetMemberOrientation a) =>
    _withArea(
      state,
      a.playerId,
      a.slot,
      (area) => area.copyWith(stacks: [
        for (final stack in area.stacks)
          if (stack.member.instanceId == a.instanceId)
            stack.copyWith(
                member: stack.member.copyWith(orientation: a.orientation))
          else
            stack,
      ]),
    );

/// 総合ルール 4.5.5 / 5.10.1: メンバーの下に重ねる。
GameState _stackUnder(GameState state, StackUnderMember a) {
  final taken =
      _takeOut(cardsIn(state, a.playerId, a.from), a.instanceId, a.from.name);
  final next = replaceZone(state, a.playerId, a.from, taken.rest);

  return _withArea(
    next,
    a.playerId,
    a.slot,
    (area) => area.copyWith(stacks: [
      for (final stack in area.stacks)
        if (stack.member.instanceId == a.memberInstanceId)
          stack.copyWith(beneath: [
            ...stack.beneath,
            // ★4.5.5.2: 下に重ねられたカードは向きを示す配置状態を持たない。
            // ★★ 4.5.5.2 が奪うのは**向きだけ**である ★★
            //   4.1.2.1 / 4.5.3 によりメンバーエリアは公開領域なので、
            //   下に重ねられたカードも表向きで置かれる。
            //   `redact` はメンバーエリアを秘匿しない (4.5.3) ので、
            //   裏向きのまま残すと「見えるはずの札が裏面で見える」ことになる。
            taken.card
                .copyWith(clearOrientation: true, face: FaceState.faceUp),
          ])
        else
          stack,
    ]),
  );
}

/// メンバーの下から取り出して孤児にする。
///
/// ★行き先を指定しない。4.5.5.4.1 / 4.5.5.4.2 により、その後のルール処理で
///   種別ごとの行き先へ移動する（10.1.2 によりチェックタイミング）。
GameState _detach(GameState state, DetachFromMember a) {
  final area = _areaOf(state, a.playerId, a.slot);

  CardInstance? detached;
  final stacks = <MemberStack>[];
  for (final stack in area.stacks) {
    final index =
        stack.beneath.indexWhere((c) => c.instanceId == a.instanceId);
    if (index < 0) {
      stacks.add(stack);
      continue;
    }
    detached = stack.beneath[index];
    stacks.add(stack.copyWith(beneath: [
      ...stack.beneath.sublist(0, index),
      ...stack.beneath.sublist(index + 1),
    ]));
  }

  final found = detached;
  if (found == null) {
    throw ArgumentError('${a.slot.label} の下に instanceId "${a.instanceId}" が無い');
  }

  return _withArea(
    state,
    a.playerId,
    a.slot,
    (target) => target.copyWith(
      stacks: stacks,
      // ★孤児カードとしてメンバーエリアに残す。行き先はルール処理が決める。
      orphans: [...target.orphans, found],
    ),
  );
}

// ===========================================================================
// 進行・ルール処理
// ===========================================================================

ReduceReport _advance(GameState state, AdvanceStep a, ReduceContext ctx) {
  final result = ctx.engine.advance(state, choice: a.choice);
  return ReduceReport(
    state: result.state,
    advance: result,
    tidy: result.tidy,
    refreshCount: result.refreshCount,
  );
}

GameState _refresh(GameState state, Refresh a, ReduceContext ctx) {
  final playerId = a.playerId;
  // ★指定なしなら 10.2.4 の順（現ターンの先攻が先）で条件を満たす全員。
  if (playerId == null) return ctx.refresher.refreshIfNeeded(state);
  return ctx.refresher.refreshPlayer(state, playerId);
}

ReduceReport _tidy(GameState state, ReduceContext ctx) {
  final result = ctx.processor.tidy(state);
  return ReduceReport(state: result.state, tidy: result);
}
