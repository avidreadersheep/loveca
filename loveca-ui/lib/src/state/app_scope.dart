/// 画面へ道具を配る（決定 D53 / D55）.
///
/// ★`AppEnvironment` は起動ゲートで 1 回だけ作られ、以降**不変**である
/// （取り込みは起動ゲートでしか走らない / 決定 D56）。
/// したがって [updateShouldNotify] は「別のインスタンスに差し替わったとき」だけ真。
///
/// ★`MasterCatalog` や `GameState` を直接 `InheritedWidget` に載せない
/// （`docs/UI設計メモ.md` §3-2）。更新のたびに全依存が走る形になり、絞る手段が消える。
/// ここが配るのは**寿命の長い道具**だけで、変化する状態は `Store` が持つ。
library;

import 'package:flutter/widgets.dart';

import '../boot/boot_steps.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.environment,
    required this.notices,
    required this.timings,
    required super.child,
  });

  final AppEnvironment environment;

  /// 起動時に出た「エラーではないが伝えるべきこと」（`docs/UI設計メモ.md` §3-4(3)）。
  /// ★決定 D39 / D60: 記録するだけで誰も見ない状態にしない。
  final List<BootNotice> notices;

  final BootTimings timings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope が上に無い。BootGate の内側で使うこと。');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      !identical(oldWidget.environment, environment) ||
      !identical(oldWidget.notices, notices);
}
