/// 盤面セッションが使う乱数（決定 D79 / D81）.
///
/// ★★ UI 層で乱数を引く場所を 2 箇所に留める ★★
/// もう 1 つは `data/deck_id.dart`（`deckId` の UUID v4）。
/// 引く場所を増やすと「どの乱数が盤面の再現に効くのか」が追えなくなる。
///
/// ★★ `Random()`（seed なし）は使わない ★★
/// CLAUDE.md §1 が禁じているのは **seed なしの `Random()`** で、
/// `Random.secure()` は別（`deck_id.dart` の doc と同じ理由）。
/// ここが作るのは **`SeededRng` に渡す seed そのもの**であって、
/// 盤面の乱数は必ず `SeededRng(seed)` を通る。
///
/// ★★ ここで引いた結果は必ず「値」として `GameSetup` に渡す ★★
/// 6.2.1.4 の無作為は**開始ダイアログでその場で引き、結果を画面に出してから**
/// `firstPlayerId` として渡す。`GameSetup` の中で引かない。
/// そうしないと「seed を控えたのに先攻が再現しない」が起きる
/// （seed は `SeededRng` の乱数列を決めるだけで、ダイアログの選択は決めない）。
library;

import 'dart:math';

/// ★UI 層で乱数を引く 2 箇所目（1 つ目は `deck_id.dart`）。
final Random _secureRandom = Random.secure();

/// `SeededRng` に渡す seed を新しく作る（決定 D79）。
///
/// ★★ 画面に出せる大きさに収める ★★
/// 利用者が**読んで書き写せる**ことがこの seed の存在理由（CLAUDE.md §1
/// 「同じ seed で盤面を再現できないと不具合を追えない」）なので、
/// 64bit の全域を使わず 9 桁までに収める。
///
/// ★衝突しても困らない。`deckId`（P1）と違って同期も識別もしない。
int newBoardSeed() => _secureRandom.nextInt(1000000000);

/// 総合ルール 6.2.1.4 の 1 段目「無作為にどちらかのプレイヤーを選択し」。
///
/// ★★ 2 段目（選ばれた人が先攻を選ぶ）はここでやらない ★★
/// 条文は「無作為にどちらかのプレイヤーを選択し、**そのプレイヤーが
/// どちらが先攻プレイヤーとなるかを選びます**」の 2 段である。
/// ローカル対戦では形骸化するが、**UI が 2 段を 1 段に潰すと Phase 6 で組み直しになる**。
/// ★ソロでは 6.2.1.4 そのものを出さない（1 人では手順が成立しない / 決定 D88）。
T pickAtRandom<T>(List<T> candidates) =>
    candidates[_secureRandom.nextInt(candidates.length)];
