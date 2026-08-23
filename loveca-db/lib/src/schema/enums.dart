/// スキーマ側でのみ使う区分値.
///
/// `HeartColor` / `BladeHeartEffect` / `CardType` は `loveca_core` の型をそのまま使う。
/// ここに定義するのは「行の種別」を表す、DB の都合で生まれた区分だけ。
library;

/// `card_names` の行が何の名称か。
///
/// `Card` 側は `characterNames` / `groupNames` / `unitNames` の 3 リストで持つ
/// （2.3.2.1 / 2.4.2.1）。DB では 1 テーブルに寄せ、この列で区別する。
enum CardNameKind { character, group, unit }

/// `card_hearts` の行がどのハートか。
///
/// ★参照範囲がそれぞれ違う★
/// - [hearts]        メンバーの所持ハート（2.9）。8.3.14 は**ウェイト含む全メンバー**を見る
/// - [requiredHearts] ライブの必要ハート（2.11）
/// - [bladeHearts]   ブレードハートの**色**（2.7）。8.3.14 のライブ所有ハートに合算する
///
/// 非色アイコン（DRAW / SCORE）は**このテーブルに入らない**。
/// `card_blade_heart_effects` という別テーブル・別 enum 型に分けてある。
enum HeartKind { hearts, requiredHearts, bladeHearts }

/// 取り込みが失敗した理由の分類。
enum ImportIssueKind {
  /// `MasterFileSource.read` が失敗した（ファイルが無い・読めない等）。
  readFailure,

  /// ★`HeartColor.fromKey` / `BladeHeartEffect.fromKey` / `CardType.fromJa` が
  /// 未知のキーで `ArgumentError` を投げた（決定 D-1 / D39）。
  /// 配信側が契約を破った場合にここへ来る。
  unknownKey,

  /// その他のパース失敗（JSON 不正・必須キー欠落・型不一致など）。
  parseFailure,
}
