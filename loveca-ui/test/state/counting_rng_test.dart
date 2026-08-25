/// `CountingRng` が `DeterministicRng` の契約を壊していないこと（M-B5）.
///
/// ★★ なぜ要るのか ★★
/// M-B5 は「乱数を消費したか」を**列挙ではなく実測**で判定する（`counting_rng.dart`）。
/// そのために乱数源を包むが、**包んだせいで乱数列が変われば**
/// 「同じ seed なら同じ盤面」（決定 D79）が崩れ、
/// `board_session_test.dart` の再生の前提ごと壊れる。
///
/// → **素通しであること**をここで固定する。数えることの検査より先に来る。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/state/counting_rng.dart';

void main() {
  group('★★ 素通しであること（決定 D79 の前提）★★', () {
    test('★ 包んだものと素のものが同じ列を返す', () {
      final bare = SeededRng(20260825);
      final wrapped = CountingRng(SeededRng(20260825));

      final fromBare = [for (var i = 0; i < 200; i++) bare.nextInt(97)];
      final fromWrapped = [for (var i = 0; i < 200; i++) wrapped.nextInt(97)];

      expect(fromWrapped, fromBare);
    });

    test('★ `shuffled`（extension）の結果も一致する', () {
      // ★`shuffled` は extension なので `nextInt` だけを包めば自動的に一致するはず。
      //   「はず」で済ませない（D-10）。
      final source = [for (var i = 0; i < 40; i++) 'c$i'];

      final bare = SeededRng(7);
      final wrapped = CountingRng(SeededRng(7));

      expect(wrapped.shuffled(source), bare.shuffled(source));
      // ★2 回目も一致する = 内部状態の進み方まで同じ。
      expect(wrapped.shuffled(source), bare.shuffled(source));
    });

    test('★★ 陽性対照: seed が違えば列も違う ★★', () {
      // ★これが落ちたら、上の 2 件は「何を比べても一致する」検査になっている。
      final a = CountingRng(SeededRng(1));
      final b = CountingRng(SeededRng(2));

      final fromA = [for (var i = 0; i < 50; i++) a.nextInt(1000)];
      final fromB = [for (var i = 0; i < 50; i++) b.nextInt(1000)];

      expect(fromA, isNot(fromB));
    });
  });

  group('★★ 数えていること ★★', () {
    test('作った直後は 0', () {
      expect(CountingRng(SeededRng(1)).count, 0);
    });

    test('`nextInt` の回数がそのまま入る', () {
      final rng = CountingRng(SeededRng(1));
      for (var i = 0; i < 13; i++) {
        rng.nextInt(5);
      }
      expect(rng.count, 13);
    });

    test('★★ `shuffled` 経由も入る（ここが本題）★★', () {
      // ★★ シャッフルは `nextInt` を直接呼ばない経路である ★★
      //   数えられていないと、`ShuffleZone` を undo しても注記が出ない。
      final rng = CountingRng(SeededRng(1));
      rng.shuffled([for (var i = 0; i < 10; i++) i]);

      // Fisher-Yates は要素数 n に対して n-1 回引く（`rng.dart`）。
      expect(rng.count, 9);
    });

    test('★ 1 枚以下のシャッフルは 1 つも消費しない', () {
      // ★「シャッフルしたから消費した」と決め打ちできないことの根拠。
      //   ★列挙方式だとここで嘘の注記が出る。
      final rng = CountingRng(SeededRng(1));
      rng.shuffled(<int>[]);
      rng.shuffled(<int>[1]);

      expect(rng.count, 0);
    });
  });
}
