/// 盤面のモード（決定 D88 / `docs/盤面設計メモ.md` §14）.
///
/// ★★ 「一人回し」という語は使わない ★★
/// R7 は「一人回し」という名前で **1 人が両プレイヤーを操作する盤面**を出していたが、
/// 利用者の想定する一人回しは**対戦相手を想定せず自分のデッキの動きだけを見るもの**だった。
/// **名前と実体が食い違っていた**ので、語ごと廃止した（D88-1）。
/// ★D88 以前の文書・コード・コミットメッセージの「一人回し」は**すべてローカル対戦**を指す。
///
/// | モード | 領域 | 秘匿 | 手番 |
/// |---|---|---|---|
/// | [solo] | ★**自分側のみ** | `redact` を掛けない（★**隠す相手が居ない**） | ★**常に先攻**。8.4.13 は起きない |
/// | [localVersus] | 両側 | `redact` を掛けない（★**1 人が両方を操作する**） | 8.4.13 で入れ替わる |
/// | オンライン対戦（Phase 6） | 両側 | ★サーバが `redact` を掛けて配る | 同上 |
///
/// ★★ どちらも `redact` を掛けないが、理由が違う ★★
/// ソロは**隠す相手が居ない**から、ローカル対戦は**1 人が両方を操作する**から
/// である（D77 の訂正 / D88-2）。同じ結論でも根拠を混ぜない。
///
/// ★★ Release 1 では 2 値。`online` を今から足さない ★★
/// 到達しない枝が生えると**網羅性検査の意味が薄れる**（U12 で `childAspectRatio` の案を
/// 「グリッドに寸法の前提が 2 つ生まれる」として退けたのと同じ形）。
/// ★**Phase 6 で `online` を足した瞬間に全 `switch` がコンパイルエラーになるのが正しい** ——
/// 秘匿の分岐を足すときに見落とすと事故になるので、**壊れて止まるほうが安い。**
///
/// ★★ モードは開始時に選ぶ。あとから切り替えない ★★
/// 切り替えると 6.2.1 をやり直すことになり、「同じ seed で同じ盤面」が成立しなくなる。
///
/// ★★ このファイルは `GameState` からプレイヤーを引き直さない ★★
/// `state/board_*.dart` は走査テスト（`test/board/board_player_access_test.dart`）の
/// 対象である。**描くプレイヤーを配るのは `ui/board/board_view.dart` 1 か所**。
library;

import 'package:loveca_core/loveca_core.dart';

enum BoardMode {
  /// ソロ。★相手側の領域を**そもそも参照しない**（`BoardView.opponent` が null）。
  solo,

  /// ローカル対戦。★1 人が両プレイヤーを操作する。
  localVersus;

  /// `loveca_core` に渡す進行のしかた。
  ///
  /// ★★ core は 2 値でよい（§14-2）★★
  /// オンライン対戦とローカル対戦は**進行が同一**で、違うのは
  /// `redact` を誰が掛けるかだけである。core に 3 値目を置くと死んだ枝ができる。
  ProgressionMode get progression => switch (this) {
        BoardMode.solo => ProgressionMode.soloFirstPlayer,
        BoardMode.localVersus => ProgressionMode.twoPlayer,
      };

  /// 画面に出す呼び名。★内部語彙（enum の名前）を出さない。
  String get label => switch (this) {
        BoardMode.solo => 'ソロ',
        BoardMode.localVersus => 'ローカル対戦',
      };

  /// 相手側の領域を描くか。
  ///
  /// ★★ これは「描画の都合」ではない ★★
  /// ソロでは相手を**そもそも参照しない**（§14-5）。この値が false のとき
  /// `BoardView.opponent` は null を返し、**相手を読んでいる箇所は
  /// コンパイルエラーになる。**
  bool get hasOpponent => switch (this) {
        BoardMode.solo => false,
        BoardMode.localVersus => true,
      };
}
