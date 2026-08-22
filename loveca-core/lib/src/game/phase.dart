/// フェイズの型.
///
/// 総合ルール 7 章・8 章に対応。確定の根拠は `docs/PhaseEngine設計メモ.md` の B-1。
///
/// ★★ リーフフェイズは 12 個 ★★
///   7.1.2 / 7.3.3 / 8.1.2 が過不足なく列挙しており、解釈の余地は無い。
///   過去のドキュメントにあった「13 フェイズ」は誤記。
///   「フェイズ」と名の付く語を数えるとリーフ 12 + コンテナ 3 = 15 になる。
///   12 と 15 はありえるが、13 はありえない。
///
/// ★★ フェイズに実プレイヤー ID を埋めない ★★
///   8.4.13 で先攻・後攻が入れ替わるため。詳細は [PhaseRole]。

library;

/// フェイズを担うロール。
///
/// ★★ 実プレイヤー ID の代わりにこれを持つ ★★
///   総合ルール 8.4.13 により、先攻プレイヤーはゲーム中に入れ替わる。
///   「先攻通常フェイズ」であることはターンを跨いで不変だが、
///   そこに座る実プレイヤーはターンごとに変わりうる。
///   両者を混ぜると、入れ替えの起きたターンで全フェイズの手番が誤る。
///
///   実プレイヤーは `GameState.firstPlayerId` から実行時に解決する。
///   `firstPlayerId` を書き換える場所はステップ 8.4.13 の 1 箇所だけ。
enum PhaseRole {
  /// 先攻プレイヤー。
  first,

  /// 後攻プレイヤー。
  second,

  /// 手番プレイヤーが存在しないフェイズ。総合ルール 7.2.1.2。
  ///
  /// このとき**アクティブプレイヤーは先攻プレイヤー**になる。
  /// 該当するのは [PhaseId.liveCardSet] と [PhaseId.liveJudgement] の 2 つだけ。
  none,
}

/// フェイズのコンテナ。総合ルール 7.1.2。
///
/// ★リーフではない。総合的なフェイズであることは 7.3.1 が明示している
///   「通常フェイズとは、いずれかのプレイヤーが一連のフェイズを実行する総合的なフェイズです」。
enum PhaseGroup {
  /// 先攻通常フェイズ。7.1.2 / 7.3。
  firstNormal('7.3'),

  /// 後攻通常フェイズ。7.1.2 / 7.3。
  secondNormal('7.3'),

  /// ライブフェイズ。7.1.2 / 7.8 / 8.1。
  live('8.1');

  const PhaseGroup(this.ruleRef);

  final String ruleRef;
}

/// リーフフェイズ。★12 個ちょうど★
///
/// 総合ルール 7.1.2 / 7.3.3 / 8.1.2。
///
/// ★8.4.13 (先攻入れ替え) と 8.4.14 (ターン終了) をフェイズに昇格させないこと。
///   これらはライブ勝敗判定フェイズ 8.4 の第 13・第 14 手順であり、`StepId` として持つ。
///   8.1.2 がライブフェイズの中身を 4 つと明示しているため、5 つ目を足すと
///   条番号とフェイズの 1 対 1 対応が崩れる。
///   また 8.4.12 は 8.4.9 へ戻るループを持つため、切り出すとループ範囲と
///   フェイズ境界が交差する。
///
/// ★条文はターン境界の誘発を意図的に既存フェイズへ畳み込んでいる。
///   「ターンの始めに」は 7.4.2 (アクティブフェイズ)、
///   「ターンの終わりに」は 8.4.10 (ライブ勝敗判定フェイズ)。
enum PhaseId {
  // ---- 先攻通常フェイズ (7.1.2 / 7.3.3) ----
  firstActive(PhaseGroup.firstNormal, PhaseRole.first, '7.4'),
  firstEnergy(PhaseGroup.firstNormal, PhaseRole.first, '7.5'),
  firstDraw(PhaseGroup.firstNormal, PhaseRole.first, '7.6'),
  firstMain(PhaseGroup.firstNormal, PhaseRole.first, '7.7'),

  // ---- 後攻通常フェイズ (7.1.2 / 7.3.3) ----
  secondActive(PhaseGroup.secondNormal, PhaseRole.second, '7.4'),
  secondEnergy(PhaseGroup.secondNormal, PhaseRole.second, '7.5'),
  secondDraw(PhaseGroup.secondNormal, PhaseRole.second, '7.6'),
  secondMain(PhaseGroup.secondNormal, PhaseRole.second, '7.7'),

  // ---- ライブフェイズ (8.1.2) ----

  /// ライブカードセットフェイズ。総合ルール 8.2。
  ///
  /// ★手番プレイヤーが存在しない。8.2.2 が先攻、8.2.4 が後攻と両者を動かすため。
  ///   7.2.1.2 によりアクティブプレイヤーは先攻プレイヤー。
  liveCardSet(PhaseGroup.live, PhaseRole.none, '8.2'),

  /// 先攻パフォーマンスフェイズ。総合ルール 8.3。
  ///
  /// ★リーフである。8.3.1 は「一連の**処理**を実行するフェイズ」と書き、
  ///   7.3.1 の「総合的な」に当たる語が無い。8.3.3〜8.3.17 は手順であって下位フェイズではない。
  firstPerformance(PhaseGroup.live, PhaseRole.first, '8.3'),

  /// 後攻パフォーマンスフェイズ。総合ルール 8.3。
  ///
  /// ★8.3.2.1 により先攻パフォーマンスフェイズと同じ 8.3 の手続きの 2 インスタンス目。
  ///   8.1.2 も後攻パフォーマンスフェイズにだけ節番号を振らず、8.3 の再利用を示している。
  secondPerformance(PhaseGroup.live, PhaseRole.second, '8.3'),

  /// ライブ勝敗判定フェイズ。総合ルール 8.4。
  ///
  /// ★手番プレイヤーが存在しない。8.4.2 以降が両者を動かすため。
  ///   7.2.1.2 によりアクティブプレイヤーは先攻プレイヤー。
  liveJudgement(PhaseGroup.live, PhaseRole.none, '8.4');

  const PhaseId(this.group, this.turnPlayerRole, this.ruleRef);

  /// このフェイズが属するコンテナ。総合ルール 7.1.2。
  final PhaseGroup group;

  /// 手番プレイヤーのロール。総合ルール 7.3.2 / 8.3.2。
  ///
  /// ★[PhaseRole.none] は手番プレイヤーが存在しないことを表す (7.2.1.2)。
  ///   手番あり 10 個 / なし 2 個。
  ///
  /// ★★ アクティブプレイヤーの解決をここに書かないこと ★★
  ///   7.2.1.1 (手番プレイヤーがアクティブプレイヤー) と
  ///   7.2.1.2 (手番プレイヤーが居ない場合は先攻プレイヤー) の適用には
  ///   `GameState.firstPlayerId` が要る。ロールだけでは実プレイヤーは決まらない。
  final PhaseRole turnPlayerRole;

  /// このフェイズを定義する条番号。
  ///
  /// ★一意ではない。[firstActive] と [secondActive] はどちらも 7.4、
  ///   [firstPerformance] と [secondPerformance] はどちらも 8.3。
  final String ruleRef;

  /// 手番プレイヤーが存在するか。総合ルール 7.2.1.1 / 7.2.1.2。
  bool get hasTurnPlayer => turnPlayerRole != PhaseRole.none;
}
