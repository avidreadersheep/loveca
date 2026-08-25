/// 乱数の消費を数える包み（M-B5 / 決定 D90）.
///
/// ★★ なぜ数えるのか — 列挙を持たないため ★★
/// 盤面設計メモ §8-3 と決定 D78 は「巻き戻しても乱数は戻らない」ことを
/// **乱数を消費したアクションを undo したときだけ**注記すると定めている。
/// その判定を「どのアクションが乱数を消費するか」の**列挙**で行うと、
/// 消費経路が増えたときに黙って古くなる。
///
/// ★実際に古くなっていた —— D78 / 盤面設計メモ §8-3 / `reduce.dart` 冒頭 /
/// `game_action.dart` の 4 箇所が揃って「5 つ」と書いているが、
/// `LookAtTop` が 6 つ目である（10.2.2.2 の不足時に `refresh.dart` の
/// `refreshPlayer` を通り `rng.shuffled` を消費する）。
/// `ルール整合性チェック_v1.06.md` **D-19**。
///
/// → **列挙を持たない。**`nextInt` が実際に何回呼ばれたかを数え、
///   差が 0 かどうかで判定する。これなら消費経路が増えても自動的に追随する。
///   ★`AdvanceStep` のように「ステップによって消費したりしなかったりする」ものでも
///   **実際に消費したときだけ**真になる（列挙では常に真にせざるを得ない）。
///
/// ★★ `loveca_core` の変更は 1 文字も要らない ★★
/// [DeterministicRng] はメソッドが `nextInt` 1 つだけで、`shuffled` は
/// **extension** として定義されている（`rng.dart`）。したがって `nextInt` を
/// 包めばシャッフル経由の消費も自動的に数に入る。
///
/// ★★ 未決 U15（巻き戻し後に乱数が張り直されない）との関係 ★★
/// **器はここにある。**U15 の退避先は「UI 側で `nextInt` の呼び出し回数を数え、
/// undo 時に `SeededRng(seed)` を作り直して N 回空回しする」であり、
/// 前半（数える）はこのクラスが既に満たしている。
///
/// ★**U15 を採るときに足すのは後半だけ** ——
///   1. `GameStore` が「巻き戻したあとに残るべき消費数」を履歴と並行して持つ
///   2. undo 時に `SeededRng(seed)` を作り直し、その回数だけ `nextInt` を空回しする
///   3. `ReduceContext` を差し替える（`ReduceContext` はイミュータブルなので作り直す）
///
/// ★**いまは実装しない。**D78 が定めた引き金 2 つ（(1) 実際に問題として報告された
/// (2) Phase 6 で undo を成立させる方式が見つかった）を踏んでいない。
/// **そのとき一から検討し直さないために、何が既にあるかをここに書いてある。**
///
/// ★★ ここは「乱数を引く場所」ではない ★★
/// 決定 D81 が定める「UI 層で乱数を引く場所」は `data/deck_id.dart` と
/// `state/board_seed.dart` の 2 箇所である。このクラスは**素通しの包み**であり、
/// 自分では 1 つも乱数を作らない。**あの一覧を増やさない。**
library;

import 'package:loveca_core/loveca_core.dart';

/// [DeterministicRng] を包んで `nextInt` の呼び出し回数を数える。
///
/// ★★ 素通しであること（戻り値を書き換えない）が前提である ★★
/// 包んだせいで乱数列が変われば、同じ seed で同じ盤面が出なくなり
/// 決定 D79 の前提ごと崩れる。`test/state/counting_rng_test.dart` が
/// 「包んだものと素のものが同じ列を返す」を固定している。
class CountingRng implements DeterministicRng {
  CountingRng(this._inner);

  final DeterministicRng _inner;

  int _count = 0;

  /// [nextInt] がこれまでに呼ばれた回数。
  ///
  /// ★`shuffled`（extension）経由の呼び出しも入る。
  int get count => _count;

  @override
  int nextInt(int max) {
    _count++;
    return _inner.nextInt(max);
  }
}
