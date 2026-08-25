/// ゲームアクション.
///
/// `reduce(GameState, GameAction) -> GameState` の入力。
/// CLAUDE.md §1 (D-D)「Phase 6 の権威サーバが同じ `reduce` / `redact` を
/// コピーゼロで再利用する」を満たすための型。
///
/// ★★ カード効果の解釈を伴うアクションを作らない ★★
///   D-A（CLAUDE.md §1）。実装してよいのは**物理操作の補助のみ**で、
///   「引く / シャッフル / 移動 / 上から見る / 表裏の反転 / 横向き / 重ね置き / 選択」。
///   効果の発動・解決、8.3.15 / 8.3.16 の必要ハート判定 (D18)、
///   10.3 の勝利処理 (D10) はアクションにしない。
///
///   「選択」は独立したアクションではなく、各アクションの
///   `instanceId` / `slot` などの**引数**として表現する。
///
/// ★★ RNG の seed も状態も持たせない ★★
///   乱数は `reduce` の引数として外から注入する。
///   seed はサーバ側だけが保持する（権威サーバ設計）。
///   このファイルに `Rng` / `seed` を持つフィールドを足さないこと。
///
/// ★★ undo / undoStep はここに入れない ★★
///   履歴 (`GameHistory`) を要するため `reduce` では表現できない。
///   権威サーバでは他プレイヤーの観測を巻き戻せないので undo は成立せず、
///   `GameState` に履歴を持たせると Phase 6 の負債になる。
///   `GameSession` 層が持つ（決定 D36 / `history.dart`）。

library;

import 'card_instance.dart';
import 'card_move.dart';
import 'game_state.dart';
import 'step.dart';
import 'member_area.dart';
import 'zone.dart';

/// ゲームを進める 1 操作。
sealed class GameAction {
  const GameAction();
}

// ===========================================================================
// A. 手動の物理操作（D-A の許す範囲）
// ===========================================================================

/// 領域間の移動。総合ルール 5.4.1「カードを指定領域に'置く'指示がある場合、
/// そのカードをその領域に移動します」
///
/// ★[Zone] だけを受ける。ルール外の置き場は [MoveOutOfRule] / [MoveFromOutOfRule]。
/// ★メンバーエリア (4.5.5 の構造を持つ) と解決領域 (4.14.1 の共有) は扱わない。
///   それぞれ専用のアクションがある。
///
/// ★4.1.7「あるカードがメンバーエリアやライブカード置き場以外の領域に移動する場合、
///   そのカードのオーナーに属する領域に移動します」
///   [toPlayerId] にオーナー以外を指定できるのはライブカード置き場だけ。
final class MoveCard extends GameAction {
  const MoveCard({
    required this.instanceId,
    required this.fromPlayerId,
    required this.from,
    required this.toPlayerId,
    required this.to,
    this.position = ZonePosition.top,
  });

  final String instanceId;
  final String fromPlayerId;
  final Zone from;
  final String toPlayerId;
  final Zone to;

  /// 順番が管理される領域 (4.8.2 / 4.10.2) でのみ意味を持つ。
  final ZonePosition position;
}

/// 共有の解決領域へ移す。総合ルール 4.14.1。
///
/// ★解決領域は両プレイヤー共有で 1 つだけなので、[MoveCard] とは別にする。
final class MoveToResolution extends GameAction {
  const MoveToResolution({
    required this.instanceId,
    required this.fromPlayerId,
    required this.from,
  });

  final String instanceId;
  final String fromPlayerId;
  final Zone from;
}

/// 共有の解決領域から移す。総合ルール 4.14.1 / 4.1.7。
final class MoveFromResolution extends GameAction {
  const MoveFromResolution({
    required this.instanceId,
    required this.toPlayerId,
    required this.to,
    this.position = ZonePosition.top,
  });

  final String instanceId;
  final String toPlayerId;
  final Zone to;
  final ZonePosition position;
}

/// 総合ルール 4 章の領域からルール外の置き場へ移す。
///
/// ★[Zone] と [OutOfRuleZone] を同じアクションに混ぜない（3a-1 の拘束）。
final class MoveOutOfRule extends GameAction {
  const MoveOutOfRule({
    required this.instanceId,
    required this.playerId,
    required this.from,
    required this.to,
  });

  final String instanceId;
  final String playerId;
  final Zone from;
  final OutOfRuleZone to;
}

/// ルール外の置き場から総合ルール 4 章の領域へ戻す。
///
/// 6.2.1.6 のマリガンは、脇に置いたカードをメインデッキ置き場へ戻す。
final class MoveFromOutOfRule extends GameAction {
  const MoveFromOutOfRule({
    required this.instanceId,
    required this.playerId,
    required this.from,
    required this.to,
    this.position = ZonePosition.top,
  });

  final String instanceId;
  final String playerId;
  final OutOfRuleZone from;
  final Zone to;
  final ZonePosition position;
}

/// 表裏の反転。総合ルール 5.3.1 / 4.3.3。
final class FlipCard extends GameAction {
  const FlipCard({
    required this.instanceId,
    required this.playerId,
    required this.zone,
    required this.face,
  });

  final String instanceId;
  final String playerId;
  final Zone zone;
  final FaceState face;
}

/// 向きの変更。総合ルール 5.2.1 / 4.3.2。
///
/// ★向きを示す配置状態を持つのはエネルギー置き場 (4.7.3) と
///   メンバーエリアのメンバーカード (4.5.4) だけ。
///   メンバーは [SetMemberOrientation] を使う。
final class SetOrientation extends GameAction {
  const SetOrientation({
    required this.instanceId,
    required this.playerId,
    required this.zone,
    required this.orientation,
  });

  final String instanceId;
  final String playerId;
  final Zone zone;
  final CardOrientation orientation;
}

/// シャッフル。総合ルール 5.5.1。
///
/// ★★ 乱数を消費するアクションは 6 つある ★★
///   [ShuffleZone] … 5.5.1 のシャッフル（直接）
///   [DrawCards]   … 10.2.1 の割り込みリフレッシュ（10.2.3 のシャッフル）
///   [Refresh]     … 同上
///   [AdvanceStep] … ★同上。7.6.2 (`_draw`) と 8.3.11 (`_yell`) が
///                   `Refresher.takeFromMainDeck` を通るため
///   [DrawEnergy]  … ★4.9.2 の無作為抽出（決定 D73）。7.5.2 は [AdvanceStep] 経由で
///                   同じ抽出を通るので、この列挙では [AdvanceStep] に含まれる
///   [LookAtTop]   … ★**条件つき**。10.2.2.2「メインデッキ置き場を上から見る指示が
///                   あり、枚数が指示された数値未満である」ときだけ `refreshPlayer`
///                   を通る（`ルール整合性チェック_v1.06.md` D-19）
///
///   ★★ ここは「このアクションだけが乱数を消費する」と書かれていた ★★
///     書かれた時点で既に誤っていた。[AdvanceStep] の消費経路
///     (`step_engine.dart` の 7.6.2 / 8.3.11 と `refresh.dart`) は **3a-3** で存在し、
///     この断定は **3a-4** で書かれている。**断定のほうが後である**。
///     `ルール整合性チェック_v1.06.md` D-15 (b) / `reduce.dart` 冒頭も同じ列挙を持つ。
///
///   ★★ この列挙はまた古くなる。次に足す人はここでは済まない ★★
///     3 → 5 に直した作業（D-15 (b)）が [LookAtTop] を見落とし、
///     5 → 6 に直したこの作業も **7 つ目で同じことが起きる**
///     （D-15 → D-16 → **D-19**。3 度数え直して 3 度とも漏れた）。
///     ★**「ここを直せば済む」と読まないこと。**
///
///     ★★ 判定が要るなら列挙ではなく**観測**を使うこと ★★
///       UI 側は列挙をやめ、`nextInt` の呼び出し回数を数えて
///       **dispatch の前後で増えたかどうか**で判定している
///       （決定 D90-1 / `loveca-ui/lib/src/state/counting_rng.dart`）。
///       ★[AdvanceStep] と [LookAtTop] は**消費したりしなかったりする**ので、
///       そもそも列挙では精度が足りない。
///
///   5.5.1.2: 0 枚・1 枚でもシャッフルは行われたものとして扱う。
final class ShuffleZone extends GameAction {
  const ShuffleZone({required this.playerId, required this.zone});

  final String playerId;
  final Zone zone;
}

/// カードを引く。総合ルール 5.6.1 / 5.6.2。
///
/// ★途中でメインデッキが尽きたらリフレッシュして続行する (10.2.1)。
final class DrawCards extends GameAction {
  const DrawCards({required this.playerId, this.count = 1});

  final String playerId;
  final int count;
}

/// エネルギーデッキ置き場から**無作為に** [count] 枚をエネルギー置き場へ移す。
///
/// 総合ルール 4.9.2（順番は管理されない）/ 4.9.3（複数枚なら 1 枚ずつ）。
/// 決定 D73（整合性チェック B-2 の解消）。根拠は `energy_deck.dart`。
///
/// ★★ [MoveCard]（instanceId 指定）と畳まない ★★
///   効果が「エネルギーデッキを**見て** 1 枚選ぶ」場合は [MoveCard] を使う。
///   **無作為と指定は別の操作**である（決定 D73 の変更 #3）。
///
/// ★★ このアクションが要る理由 ★★
///   UI で組もうとすると [MoveCard] に instanceId を渡すことになり、
///   **どれを選ぶかを UI が決める＝乱数が UI へ漏れる**。
///   乱数は `reduce` の外から注入する設計（このファイル冒頭）に触れる。
///
/// ★6.2.1.7（開始時の 3 枚）もこれと同じ抽出を通る（`GameSetup`）。
/// ★エネルギーデッキが尽きたら**引けた分で止まる**。UI がボタンを無効にして理由を出す。
final class DrawEnergy extends GameAction {
  const DrawEnergy({required this.playerId, this.count = 1});

  final String playerId;
  final int count;
}

/// メインデッキ置き場を上から見る。総合ルール 10.2.2.2。
///
/// ★見る行為自体は盤面を変えない。
///   このアクションが行うのは 10.2.2.2 の判定と、必要ならリフレッシュだけ。
///   「見た結果どうするか」はプレイヤーが別のアクションで行う。
final class LookAtTop extends GameAction {
  const LookAtTop({required this.playerId, required this.count});

  final String playerId;
  final int count;
}

// ===========================================================================
// A-2. メンバーエリアの操作（4.5.5 の構造を持つため専用）
// ===========================================================================

/// メンバーカードをメンバーエリアに置く。総合ルール 4.5.1。
///
/// ★新しい [MemberStack] として**末尾**に積む。
///   `MemberArea.stacks` のリスト順が配置順であり、末尾が
///   10.4.1 の「最も後から置かれたメンバー」になる。
/// ★4.3.2.3: 配置状態が指定される領域なので、既定はアクティブ状態。
final class PlaceMemberInArea extends GameAction {
  const PlaceMemberInArea({
    required this.instanceId,
    required this.playerId,
    required this.from,
    required this.slot,
    this.orientation = CardOrientation.active,
  });

  final String instanceId;
  final String playerId;
  final Zone from;
  final MemberAreaSlot slot;
  final CardOrientation orientation;
}

/// メンバーを他のメンバーエリアへ移す。総合ルール 4.5.5.3。
///
/// ★「その下に重ねて置かれているメンバーカードやエネルギーカードも同時に
///   新たなメンバーエリアに、移動したメンバーの下に重なっている状態で移動します」
///   → スタックごと動く。解消は起きない。
final class MoveMemberBetweenAreas extends GameAction {
  const MoveMemberBetweenAreas({
    required this.instanceId,
    required this.playerId,
    required this.fromSlot,
    required this.toSlot,
  });

  final String instanceId;
  final String playerId;
  final MemberAreaSlot fromSlot;
  final MemberAreaSlot toSlot;
}

/// メンバーをメンバーエリア以外の領域へ移す。総合ルール 4.5.5.4。
///
/// ★「そのメンバーカードのみが移動します」
///   下に重ねられていたカードは**そのままメンバーエリアに残る**（孤児カード）。
///   4.5.5.4.1 / 4.5.5.4.2 により、その後のルール処理 (10.5.3 / 10.5.4) で移動する。
///   10.1.2 によりルール処理はチェックタイミングでのみ実行されるため、
///   **ここで下のカードを消してはいけない**。
final class MoveMemberOut extends GameAction {
  const MoveMemberOut({
    required this.instanceId,
    required this.playerId,
    required this.slot,
    required this.toPlayerId,
    required this.to,
    this.position = ZonePosition.top,
  });

  final String instanceId;
  final String playerId;
  final MemberAreaSlot slot;
  final String toPlayerId;
  final Zone to;
  final ZonePosition position;
}

/// メンバーの向きを変える。総合ルール 5.2.1 / 4.5.4。
final class SetMemberOrientation extends GameAction {
  const SetMemberOrientation({
    required this.instanceId,
    required this.playerId,
    required this.slot,
    required this.orientation,
  });

  final String instanceId;
  final String playerId;
  final MemberAreaSlot slot;
  final CardOrientation orientation;
}

/// カードをメンバーの下に重ねる。総合ルール 4.5.5 / 5.10.1。
///
/// ★4.5.5.2 により下に重ねられたカードは**向きを示す配置状態を持たない**。
///   重ねる際に向きを落とす。
final class StackUnderMember extends GameAction {
  const StackUnderMember({
    required this.instanceId,
    required this.playerId,
    required this.from,
    required this.slot,
    required this.memberInstanceId,
  });

  final String instanceId;
  final String playerId;

  /// 重ねる前にカードがあった領域。5.10.1 のエネルギーならエネルギー置き場。
  final Zone from;

  final MemberAreaSlot slot;

  /// どのメンバーの下に置くか。
  final String memberInstanceId;
}

/// メンバーの下からカードを取り出し、メンバーエリアに残す（孤児化）。
///
/// ★行き先は指定しない。4.5.5.4.1 / 4.5.5.4.2 により、その後のルール処理で
///   種別ごとの行き先へ移動する。10.1.2 によりそれはチェックタイミング。
final class DetachFromMember extends GameAction {
  const DetachFromMember({
    required this.instanceId,
    required this.playerId,
    required this.slot,
  });

  final String instanceId;
  final String playerId;
  final MemberAreaSlot slot;
}

// ===========================================================================
// B. 進行・ルール処理
// ===========================================================================

/// 1 ステップ進める。総合ルール 7 章・8 章。
///
/// ★8.4.13 の先攻入れ替えもこの中で起きる。独立したアクションにしない。
///   `firstPlayerId` を書き換えるのは 8.4.13 の 1 箇所だけ、という不変条件を
///   保つため。入力となる勝敗と移動実績は [SetLiveJudgement] で置く。
///
/// [choice] は 8.4.12 のようにプレイヤーの宣言が要る分岐でのみ必要。
final class AdvanceStep extends GameAction {
  const AdvanceStep({this.choice});

  final StepTransition? choice;
}

/// リフレッシュ。総合ルール 10.2。
///
/// [playerId] を省略すると、条件を満たす全プレイヤーを
/// 10.2.4 の順（現ターンの先攻が先）で処理する。
final class Refresh extends GameAction {
  const Refresh({this.playerId});

  final String? playerId;
}

/// 整理（ルール処理 10.4 / 10.5）。
///
/// ★10.3（勝利処理）と 10.6（不正解決領域処理）は実行しない。
///   D10 と D-A により警告に留まる。
final class Tidy extends GameAction {
  const Tidy();
}

/// ライブ勝敗判定の記録を置く。総合ルール 8.4.6 / 8.4.7。
///
/// ★決定 D10 により勝敗確定は手動。アプリが判定しない。
/// ★8.4.13 が参照するのは [LiveJudgementRecord.movedToSuccessIds]
///   （8.4.7 の移動実績）であって `winnerIds` ではない (8.4.7.1)。
final class SetLiveJudgement extends GameAction {
  const SetLiveJudgement(this.record);

  final LiveJudgementRecord? record;
}
