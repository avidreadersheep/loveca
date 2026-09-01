/// ★★ 分母を測り直す手順そのもの（★★運転指示【0】(1)★★ / 2026-09-02）★★
///
/// ★★ なぜ★道具にしたか ★★
/// ★**`docs/同期設計メモ.md` §63-7 は「★動かす機械で測り直し、★60000 ÷ 測った値を
/// 上限として引き直すこと」と★★書いた★★。★しかし★★測り直す手段が★リポジトリに 1 つも無かった★★。**
/// → ★**手順を★文章で書くと★★次に測る人が★別のやり方で測る★★**（★回数 / ★ウォームアップ / ★統計が揃わない）。
/// ★**先例は `loveca-db/tool/probe_sqlite.dart`**（★★機械ごとに答えが変わるものを★道具で測る★★）。
///
/// ★★ 何を測るか ★★
/// ★**[passwordHashIterations] 回の PBKDF2 を★★1 回走らせる費用★★**（★保存する側と★照合する側）。
/// ★**これが★上限の★★分母★★である**（`loveca-server/lib/src/rate_limit.dart` の
/// [measuredPasswordHashCostMs]）。
///
/// ★★ 走らせ方 ★★
/// ```
/// cd loveca-server
/// dart run tool/measure_hash_cost.dart            # ★既定 12 標本
/// dart run tool/measure_hash_cost.dart 20         # ★標本の数を変える
/// ```
///
/// ★★ 何を★どう写すか（★★これが手順の本体である★★）★★
/// | # | ★段 |
/// |---|---|
/// | ★**1** | ★**下の出力の★★「採る値」★★を [measuredPasswordHashCostMs] に写す** |
/// | ★★**2**★★ | ★★**それ以外は 1 つも書き換えない**★★ —— ★38 も 33 も★★定数から導かれる★★ |
/// | ★**3** | ★**`dart test` を走らせる**。★★`rate_limit_test.dart` の「今日の分母での値」の群が落ちる★★ |
/// | ★**4** | ★**落ちた件の期待値を★新しい値に直す**（★★それが「分母が動いた」の合図である★★ / ★先例は **D-24** / §57） |
///
/// ★★ 「採る値」は★平均でも中央でもない。★★最大である★★ ★★
/// ★**上限は「窓に入りきること」なので、★★1 回の費用を小さく見積もると★上限が大きくなりすぎる★★。**
/// ★**大きい側に振れた標本を採ると★上限が小さくなる ＝ ★★安全側である★★。**
/// → ★**この道具は★★最大★★を「採る値」として出す。★平均と中央とばらつきも★併せて出す**（**D-28** の作法）。
library;

import 'dart:io';

import 'package:loveca_server/src/password_hash.dart';
import 'package:loveca_server/src/rate_limit.dart';

void main(List<String> args) {
  final samples = args.isEmpty ? 12 : int.tryParse(args.first) ?? 12;
  if (samples < 3) {
    stderr.writeln('★標本は 3 以上であること（★ばらつきが出ない）');
    exitCode = 2;
    return;
  }

  stdout.writeln('★ 繰り返し回数: $passwordHashIterations');
  stdout.writeln('★ 標本の数: $samples（★ウォームアップ 2 回は勘定に入れない）');
  stdout.writeln('');

  // ★ウォームアップ —— ★★1 回目だけ突出することを勘定に入れないため★★。
  for (var i = 0; i < 2; i++) {
    final stored = encodePasswordHash('warmup', salt: newSalt());
    verifyPassword('warmup', stored);
  }

  final save = <int>[];
  final verify = <int>[];
  for (var i = 0; i < samples; i++) {
    final salt = newSalt();
    final sw = Stopwatch()..start();
    final stored = encodePasswordHash('measure-$i', salt: salt);
    sw.stop();
    save.add(sw.elapsedMilliseconds);

    final sw2 = Stopwatch()..start();
    final ok = verifyPassword('measure-$i', stored);
    sw2.stop();
    if (!ok) throw StateError('★照合が失敗した（★測定の前提が崩れている）');
    verify.add(sw2.elapsedMilliseconds);
  }

  final saveStat = _Stat(save);
  final verifyStat = _Stat(verify);
  _print('保存する側（/accounts）', saveStat);
  _print('照合する側（★名乗るたびに走る）', verifyStat);

  final take = saveStat.max > verifyStat.max ? saveStat.max : verifyStat.max;
  final total = rateLimitWindowMs ~/ take;
  stdout.writeln('');
  stdout.writeln('★★ 採る値 = $take ms ★★'
      '（★両側の最大のうち大きいほう ＝ ★★安全側★★）');
  stdout.writeln('  → measuredPasswordHashCostMs = $take');
  stdout.writeln('  → 合計の枠 = $rateLimitWindowMs ~/ $take = $total');
  stdout.writeln('  → 人が押す枠 = $humanRateLimitBudget（★据え置き）');
  stdout.writeln('  → 同期の枠 = ${total - humanRateLimitBudget}');
  stdout.writeln('  → 1 台が同期できるデッキの数 '
      '= ${total - humanRateLimitBudget - 1}');
  if (total - humanRateLimitBudget <= 0) {
    stdout.writeln('');
    stdout.writeln('★★ この機械では★同期の枠が 0 以下になる ★★');
    stdout.writeln('  → ★人が押す枠を下げるか、★繰り返し回数を下げること。');
    stdout.writeln('  → ★★そのまま写すと★コンパイルが通らない★★'
        '（`RateLimitPolicy.perWindow` の assert）。');
  }
  stdout.writeln('');
  stdout.writeln('★ いま書かれている分母: $measuredPasswordHashCostMs ms'
      '（★合計 $totalRateLimitBudget / ★同期 $syncRateLimitBudget）');
}

void _print(String name, _Stat s) {
  stdout.writeln('$name: 全件=${s.xs}');
  stdout.writeln('  最小=${s.min} 最大=${s.max} 中央=${s.median.toStringAsFixed(1)} '
      '平均=${s.mean.toStringAsFixed(1)} 標準偏差=${s.sd.toStringAsFixed(1)} '
      '幅=${s.max - s.min}');
}

class _Stat {
  _Stat(List<int> raw) : xs = List<int>.unmodifiable(raw) {
    final sorted = [...raw]..sort();
    min = sorted.first;
    max = sorted.last;
    median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2].toDouble()
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
    mean = raw.fold<int>(0, (a, b) => a + b) / raw.length;
    final v =
        raw.fold<double>(0, (a, b) => a + (b - mean) * (b - mean)) / raw.length;
    sd = _sqrt(v);
  }

  final List<int> xs;
  late final int min;
  late final int max;
  late final double median;
  late final double mean;
  late final double sd;

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    var g = x;
    for (var i = 0; i < 60; i++) {
      g = (g + x / g) / 2;
    }
    return g;
  }
}
