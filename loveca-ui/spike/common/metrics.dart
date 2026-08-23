/// 試作の計測ユーティリティ.
///
/// ★数値を再現可能な形で残すことを優先する★
/// DevTools のスクリーンショットだけだと `docs/UI技術検証メモ.md` に
/// 「速かった / 遅かった」しか書けない。フレーム統計と RSS を
/// プログラム側で集計し、そのまま貼れる markdown を吐く。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'paths.dart';

/// `SPIKE_AUTOEXIT=1` を環境変数で渡すと、計測を終えた時点で自己終了する。
/// （非対話で走らせて結果ファイルだけ回収するため。再ビルドは要らない）
bool get spikeAutoExit => Platform.environment['SPIKE_AUTOEXIT'] == '1';

/// 実測したモニタのリフレッシュレートから 1 フレームの予算を出す。
///
/// ★60Hz 決め打ちにしない★
/// 120Hz のモニタなら予算は 8.3ms で、16.7ms を閾値にすると
/// 実際には落ちているフレームを「問題なし」と数えてしまう。
Duration frameBudget() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  final hz = views.isEmpty ? 60.0 : views.first.display.refreshRate;
  final safe = (hz.isFinite && hz > 1) ? hz : 60.0;
  return Duration(microseconds: (1000000 / safe).round());
}

double refreshRateHz() {
  final views = WidgetsBinding.instance.platformDispatcher.views;
  if (views.isEmpty) return 60;
  final hz = views.first.display.refreshRate;
  return (hz.isFinite && hz > 1) ? hz : 60;
}

/// `FrameTiming` を溜めて分位数を出す。
class FrameStats {
  FrameStats(this.label);

  final String label;
  final List<FrameTiming> _timings = [];
  TimingsCallback? _callback;

  bool get isRecording => _callback != null;
  int get frameCount => _timings.length;

  void start() {
    if (_callback != null) return;
    _timings.clear();
    _callback = (List<FrameTiming> t) => _timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  void stop() {
    final cb = _callback;
    if (cb == null) return;
    SchedulerBinding.instance.removeTimingsCallback(cb);
    _callback = null;
  }

  void reset() => _timings.clear();

  List<int> _microsOf(Duration Function(FrameTiming) pick) =>
      _timings.map((t) => pick(t).inMicroseconds).toList()..sort();

  static double _percentile(List<int> sorted, double q) {
    if (sorted.isEmpty) return 0;
    final idx = ((sorted.length - 1) * q).round();
    return sorted[idx] / 1000.0;
  }

  FrameSummary summary() {
    final build = _microsOf((t) => t.buildDuration);
    final raster = _microsOf((t) => t.rasterDuration);
    final total = _microsOf((t) => t.totalSpan);
    final budget = frameBudget().inMicroseconds;
    final over = _timings
        .where((t) =>
            t.buildDuration.inMicroseconds + t.rasterDuration.inMicroseconds >
            budget)
        .length;
    return FrameSummary(
      label: label,
      frames: _timings.length,
      refreshHz: refreshRateHz(),
      budgetMs: budget / 1000.0,
      buildP50: _percentile(build, 0.50),
      buildP95: _percentile(build, 0.95),
      buildMax: _percentile(build, 1.0),
      rasterP50: _percentile(raster, 0.50),
      rasterP95: _percentile(raster, 0.95),
      rasterMax: _percentile(raster, 1.0),
      totalP95: _percentile(total, 0.95),
      overBudget: over,
    );
  }
}

class FrameSummary {
  const FrameSummary({
    required this.label,
    required this.frames,
    required this.refreshHz,
    required this.budgetMs,
    required this.buildP50,
    required this.buildP95,
    required this.buildMax,
    required this.rasterP50,
    required this.rasterP95,
    required this.rasterMax,
    required this.totalP95,
    required this.overBudget,
  });

  final String label;
  final int frames;
  final double refreshHz;
  final double budgetMs;
  final double buildP50;
  final double buildP95;
  final double buildMax;
  final double rasterP50;
  final double rasterP95;
  final double rasterMax;
  final double totalP95;

  /// build + raster が 1 フレームの予算を超えた回数。
  final int overBudget;

  double get overBudgetRatio => frames == 0 ? 0 : overBudget / frames;

  static String get markdownHeader =>
      '| 条件 | frames | build p50 | build p95 | build max | '
      'raster p50 | raster p95 | raster max | 予算超え |\n'
      '|---|---:|---:|---:|---:|---:|---:|---:|---:|';

  String toMarkdownRow() => '| $label | $frames | ${_f(buildP50)} | '
      '${_f(buildP95)} | ${_f(buildMax)} | ${_f(rasterP50)} | '
      '${_f(rasterP95)} | ${_f(rasterMax)} | '
      '$overBudget (${(overBudgetRatio * 100).toStringAsFixed(1)}%) |';

  static String _f(double v) => v.toStringAsFixed(1);

  @override
  String toString() => toMarkdownRow();
}

/// RSS のピークを取る。
///
/// `ProcessInfo.maxRss` は OS が報告するピーク値だが、Windows では
/// プロセス開始からの最大なので「区間ごとのピーク」には使えない。
/// 区間ごとの値は [currentRssMb] のサンプリングで取る。
class MemorySampler {
  Timer? _timer;
  int _peakBytes = 0;

  static int get currentRssMb => ProcessInfo.currentRss ~/ (1024 * 1024);
  static int get maxRssMb => ProcessInfo.maxRss ~/ (1024 * 1024);

  int get peakMb => _peakBytes ~/ (1024 * 1024);

  void start({Duration interval = const Duration(milliseconds: 200)}) {
    stop();
    _peakBytes = ProcessInfo.currentRss;
    _timer = Timer.periodic(interval, (_) {
      final rss = ProcessInfo.currentRss;
      if (rss > _peakBytes) _peakBytes = rss;
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() => _peakBytes = ProcessInfo.currentRss;
}

/// 計測結果を `spike/.cache/measurements/<name>.md` に書く。
File writeSpikeReport(String name, String markdown) {
  final dir = SpikePaths.resolve().measurementsDir;
  dir.createSync(recursive: true);
  final file = File('${dir.path}${Platform.pathSeparator}$name.md');
  file.writeAsStringSync(markdown);
  // stdout にも出す。flutter run のログから拾えるようにするため。
  stdout.writeln('=== spike report: ${file.path} ===');
  stdout.writeln(markdown);
  stdout.writeln('=== end report ===');
  return file;
}

/// 環境の見出し。どのレポートにも同じ形で入れる。
String environmentHeading() {
  final paths = SpikePaths.resolve();
  return [
    '- OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
    '- Dart: ${Platform.version}',
    '- リフレッシュレート: ${refreshRateHz().toStringAsFixed(1)} Hz '
        '(1 フレーム予算 ${frameBudget().inMicroseconds / 1000} ms)',
    '- dist: ${paths.distDir.path}',
    '- DB: ${paths.dbFile.path}',
  ].join('\n');
}
