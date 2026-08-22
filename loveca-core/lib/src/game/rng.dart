/// 決定性のある乱数.
///
/// ★★ loveca_core に乱数実装を埋め込まない ★★
///   CLAUDE.md §1 (D-D)。抽象だけを置き、実装は呼び出し側が注入する。
///   理由は 2 つ。
///     1. seed 再現性。同じ seed で同じ盤面を再現できないと不具合を追えない
///     2. Phase 6 の権威サーバがシャッフル結果の権威を持つ必要がある
///
///   ★`Random()` を引数なしで使わないこと。再現性が失われる。

library;

import 'dart:math' show Random;

/// 決定性のある乱数源。
///
/// [nextInt] だけを要求する。シャッフルは [RngShuffle.shuffled] が
/// この 1 つの操作から組み立てるため、実装が違っても
/// 同じ [nextInt] 列なら同じ結果になる。
abstract interface class DeterministicRng {
  /// 0 以上 [max] 未満の整数を返す。[max] は 1 以上。
  int nextInt(int max);
}

/// seed から決まる乱数源。
///
/// `dart:math` の `Random` を使う。IO も日時も参照しない。
class SeededRng implements DeterministicRng {
  SeededRng(this.seed) : _random = Random(seed);

  /// 再現に必要な seed。盤面の保存・共有時にこれを添える。
  final int seed;

  final Random _random;

  @override
  int nextInt(int max) => _random.nextInt(max);
}

extension RngShuffle on DeterministicRng {
  /// [source] をシャッフルした**新しいリスト**を返す。総合ルール 5.5.1。
  ///
  /// ★元のリストを破壊しない。GameState はイミュータブルに保つ。
  ///
  /// ★`List.shuffle` を使わずフィッシャー・イェーツを自前で回す。
  ///   標準実装に依存すると、Dart のバージョンや Phase 6 のサーバ実装で
  ///   同じ seed から違う並びが出うるため。
  ///
  /// 5.5.1.2: カードが 0 枚または 1 枚でもシャッフルは行われたものとして扱う。
  List<T> shuffled<T>(List<T> source) {
    final result = List<T>.of(source);
    for (var i = result.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
    }
    return result;
  }
}
