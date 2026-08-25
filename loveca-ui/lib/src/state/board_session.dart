/// 盤面セッションのログ（M-B5 / 決定 D78 / D90）.
///
/// ★★ ログには巻き戻しも発生順に載せる ★★
/// 盤面設計メモ §8-3 が実測で示したとおり、**アクション列だけを再生しても
/// 同じ盤面にならない** —— 取り消したアクションの**乱数消費は残るのに
/// 状態効果は消える**という非対称があるためである。
///
/// ```
/// 実セッション:     s0 に a1 → s1 に a2 → 巻き戻して s1 → s1 に a3   ⇒ s3
/// アクション列だけ:  s0 に a1 → t1 に a2 → t2 に a3                  ⇒ t3    （s3 ≠ t3）
/// ```
///
/// ★a2 は取り消されているのに、**a2 が引いた乱数だけは進んだまま**である。
///   だから a3 に渡る乱数の位置が食い違う。
///
/// → **[Act] / [Undo] / [UndoStep] を同じ列に、発生順に載せる。**
///   `test/state/board_session_test.dart` が、同じ seed・同じモードで再生すると
///   最終状態が一致すること、★**巻き戻しを落とすと一致しないこと**を対で固定している。
///
/// ★★ [Act] が `List<GameAction>` を持つ理由 ★★
/// 合成コマンド（決定 D78 / 盤面設計メモ §8-2）は N 個のアクションを
/// **履歴 1 件**として積む。ログもそれに合わせて 1 件にしないと、
/// 再生したとき履歴の件数が食い違い、巻き戻しの着地先がずれる。
///
/// ★★ この列は上限を持たない ★★
/// 履歴（`GameHistory`）は 512 件で古いものを捨てるが、
/// **ログは捨てない。**seed から最初まで再生できることが存在意義なので、
/// 途中を捨てると再現できなくなる。1 件はアクションへの参照だけで軽い。
///
/// ★★ このファイルに `Game`+`Session` という語を書かない ★★
/// `test/board/reduce_call_site_test.dart` が、その語に触れるファイルを
/// **`game_store.dart` と `store.dart` ちょうど**に固定している
/// （「盤面の状態を進める場所が増えている。Phase 6 の差し替え点が割れる」）。
/// ★このログ型は**状態を進めない**ので、その不変を弱めずに済ませられる。
/// **型を参照したくなったら、それは責務がずれた合図である。**
library;

import 'package:loveca_core/loveca_core.dart';

/// 盤面セッションのログ 1 件。
///
/// ★`sealed` にしてあるので、種類を足すと**すべての `switch` がコンパイルで落ちる**。
sealed class BoardLogEntry {
  const BoardLogEntry();
}

/// アクションを適用した。
///
/// ★合成コマンドは 1 件にまとまる（[actions] が 2 つ以上になる）。
final class Act extends BoardLogEntry {
  const Act(this.actions);

  final List<GameAction> actions;
}

/// 1 操作戻した。
///
/// ★★ これは [GameAction] ではない ★★
/// `game_action.dart` が「undo / undoStep はここに入れない。履歴を要するため
/// `reduce` では表現できない」と定めている。**だからログの型を分けてある。**
final class Undo extends BoardLogEntry {
  const Undo();
}

/// 1 ステップ戻した。
final class UndoStep extends BoardLogEntry {
  const UndoStep();
}
