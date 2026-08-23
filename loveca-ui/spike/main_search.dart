/// 試作2: 検索の応答性.
///
/// `CardSearchDao.search` を UI から 1 打鍵ごとに呼ぶ構成で測る。
///
/// ★測るのは 4 つ★
///   1. 語長ごとの実測。3 文字以上（trigram）と 2 文字以下（LIKE 全走査）の両経路
///   2. `search()` の内訳。FTS の MATCH 自体と、cardNumber を元の表記へ戻す処理
///   3. デバウンスの要否と待ち時間
///   4. 結果が数百〜千件を超えたときの描画コストと、上限の要否
///
/// ```bash
/// flutter build windows --profile -t spike/main_search.dart
/// SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:loveca_db/loveca_db.dart';

import 'common/card_grid_data.dart';
import 'common/metrics.dart';
import 'common/paths.dart';
import 'common/spike_db.dart';

void main() => runApp(const SearchSpikeApp());

class SearchSpikeApp extends StatelessWidget {
  const SearchSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / search',
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const SearchSpikePage(),
      );
}

/// 1 回の検索の内訳。
class SearchTiming {
  const SearchTiming({
    required this.query,
    required this.mode,
    required this.hits,
    required this.printings,
    required this.totalUs,
    required this.ftsOnlyUs,
    required this.resolveUs,
    required this.expandUs,
  });

  final String query;
  final CardSearchMode mode;
  final int hits;
  final int printings;

  /// `CardSearchDao.search` の全体。
  final int totalUs;

  /// FTS5 の MATCH だけ（索引を直接引いた時間）。
  final int ftsOnlyUs;

  /// 折りたたみ済み cardNumber を元の表記へ戻す処理の主要部
  /// （`SELECT * FROM cards` の全件読み）。
  final int resolveUs;

  /// cardNumber を刷りへ展開する時間。
  final int expandUs;

  static String ms(int us) => (us / 1000).toStringAsFixed(2);
}

class SearchSpikePage extends StatefulWidget {
  const SearchSpikePage({super.key});

  @override
  State<SearchSpikePage> createState() => _SearchSpikePageState();
}

class _SearchSpikePageState extends State<SearchSpikePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<String> _log = [];
  final StringBuffer _report = StringBuffer();

  LovecaDatabase? _db;
  CardSearchDao? _search;
  SpikePaths? _paths;

  Map<String, List<CardGridRow>> _byCardNumber = const {};
  List<CardGridRow> _results = const [];

  int _debounceMs = 120;
  int _limit = 500;
  Timer? _debounce;
  SearchTiming? _last;
  String _status = '起動中…';
  bool _benchRunning = false;

  /// ★常に動き続けるものを 1 つ置く★
  /// 何も動いていないと 1 秒間に数フレームしか生まれず、
  /// 「UI スレッドが検索で止まったか」がフレーム統計に出てこない。
  /// 回り続ける印を置いて、毎 vsync フレームが出る状態で測る。
  late final AnimationController _spinner = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _spinner.dispose();
    _debounce?.cancel();
    _input.dispose();
    _scroll.dispose();
    _db?.close();
    super.dispose();
  }

  void _note(String line) {
    _log.add(line);
    stdout.writeln('[search] $line');
  }

  Future<void> _boot() async {
    // ★起動中もフレームは出続けている（_spinner が回っている）★
    //   executor が UI isolate だと、取り込みの間ここが止まる。
    //   D45 を判断するのに一番効く区間なので、この間のフレームを別に数える。
    final bootStats = FrameStats('起動')..start();
    final opened = await openSpikeDatabase();
    bootStats.stop();
    final bootSummary = bootStats.summary();
    _db = opened.db;
    _paths = opened.paths;
    _search = CardSearchDao(opened.db);

    if (opened.importError != null) {
      setState(() => _status = '★${opened.importError}');
      return;
    }

    final loaded =
        await CardGridRepository(opened.db).load(GridLoadStrategy.leanJoin);
    final byNumber = <String, List<CardGridRow>>{};
    for (final r in loaded.rows) {
      (byNumber[r.cardNumber] ??= []).add(r);
    }

    setState(() {
      _byCardNumber = byNumber;
      _results = const [];
      _status = '${loaded.rows.length} 刷り / ${byNumber.length} 種';
    });

    _report
      ..writeln('# 試作2 — 検索の応答性')
      ..writeln()
      ..writeln(environmentHeading())
      ..writeln()
      ..writeln('- executor: '
          '${opened.usedBackgroundIsolate ? "NativeDatabase.createInBackground（別 isolate）" : "openFileExecutor（UI isolate）"}')
      ..writeln('- カード ${byNumber.length} 種 / 刷り ${loaded.rows.length}')
      ..writeln()
      ..writeln('## 起動（DB を開く + 必要なら取り込み）')
      ..writeln()
      ..writeln('| 項目 | 値 |')
      ..writeln('|---|---:|')
      ..writeln('| DB を開く | ${opened.openMillis} ms |')
      ..writeln('| 取り込み | '
          '${opened.didImport ? "${opened.importMillis} ms（コールド）" : "なし（既存 DB）"} |')
      ..writeln('| この間のフレーム | ${bootSummary.frames} |')
      ..writeln('| 予算超え | ${bootSummary.overBudget} |')
      ..writeln('| 最悪フレーム build | ${bootSummary.buildMax} ms |')
      ..writeln('| 最悪フレーム raster | ${bootSummary.rasterMax} ms |')
      ..writeln();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (spikeAutoExit) unawaited(_runBenchmarks());
    });
  }

  // ---------------------------------------------------------------------------
  // 検索 1 回とその内訳
  // ---------------------------------------------------------------------------

  Future<SearchTiming> _searchOnce(String query, {int? limit}) async {
    final effectiveLimit = limit ?? _limit;
    final total = Stopwatch()..start();
    final result = await _search!.search(query, limit: effectiveLimit);
    total.stop();

    // --- 内訳: FTS5 の MATCH だけを直接引く ---
    // ★loveca_db は変更しない。同じ SQL をこちらから投げて時間を比べるだけ。
    final folded = fold(query.trim());
    var ftsUs = 0;
    if (folded.isNotEmpty && isTrigramSearchable(folded)) {
      final sw = Stopwatch()..start();
      await _db!.customSelect(
        'SELECT card_number FROM card_search WHERE card_search MATCH ? '
        'ORDER BY rank LIMIT ?',
        variables: [
          Variable<String>('"${folded.replaceAll('"', '""')}"'),
          Variable<int>(effectiveLimit),
        ],
      ).get();
      ftsUs = sw.elapsedMicroseconds;
    }

    // --- 参考値: かつて復元に使われていた全件読み ---
    // ★決定 D49 でこの処理は search() から消えた★
    //   索引が生の cardNumber を持つようになったため、cards を読む必要が無い。
    //   ここは「以前どれだけ掛かっていたか」を並べて見るためだけに残してある。
    //   search() の実測値にはもう含まれない。
    var resolveUs = 0;
    if (result.mode == CardSearchMode.trigram && !result.isEmpty) {
      final sw = Stopwatch()..start();
      await _db!.select(_db!.cards).get();
      resolveUs = sw.elapsedMicroseconds;
    }

    // --- cardNumber を刷りへ展開する ---
    final expand = Stopwatch()..start();
    final rows = <CardGridRow>[];
    for (final n in result.cardNumbers) {
      final list = _byCardNumber[n];
      if (list != null) rows.addAll(list);
    }
    expand.stop();

    _results = rows;
    return SearchTiming(
      query: query,
      mode: result.mode,
      hits: result.length,
      printings: rows.length,
      totalUs: total.elapsedMicroseconds,
      ftsOnlyUs: ftsUs,
      resolveUs: resolveUs,
      expandUs: expand.elapsedMicroseconds,
    );
  }

  // ---------------------------------------------------------------------------
  // 対話操作
  // ---------------------------------------------------------------------------

  void _onChanged(String value) {
    _debounce?.cancel();
    if (_debounceMs == 0) {
      unawaited(_runQuery(value));
      return;
    }
    _debounce = Timer(Duration(milliseconds: _debounceMs), () {
      unawaited(_runQuery(value));
    });
  }

  Future<void> _runQuery(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _last = null;
      });
      return;
    }
    final t = await _searchOnce(value);
    if (!mounted) return;
    setState(() => _last = t);
  }

  // ---------------------------------------------------------------------------
  // 計測
  // ---------------------------------------------------------------------------

  Future<void> _settle([int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _runBenchmarks() async {
    if (_benchRunning) return;
    _benchRunning = true;

    await _benchQueryLengths();
    await _benchDebounce();
    await _benchResultCounts();

    writeSpikeReport(
      useBackgroundIsolate ? '03_search' : '03_search_ui_isolate',
      _report.toString(),
    );
    if (spikeAutoExit) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
    _benchRunning = false;
  }

  /// 語長ごとの実測。両経路と内訳。
  Future<void> _benchQueryLengths() async {
    const queries = [
      'ラ', '花', '夢',
      '花帆', 'スク', 'かの',
      'スクー', 'ドロー', 'ハート',
      'スクール', 'ブレード', 'ライブ',
      'スクールアイドル',
      'アクティブ状態',
    ];

    _report
      ..writeln('## 語長ごとの実測')
      ..writeln()
      ..writeln('各クエリ 5 回の中央値。`search()` は 1 回の呼び出しで '
          'FTS の MATCH と cardNumber の復元の両方を行う。')
      ..writeln()
      ..writeln('| 語 | 文字数 | 経路 | 種 | 刷り | search() 全体 | '
          'うち FTS MATCH | 参考: 旧復元処理 (D49 で廃止) | 刷りへの展開 |')
      ..writeln('|---|---:|---|---:|---:|---:|---:|---:|---:|');

    for (final q in queries) {
      final samples = <SearchTiming>[];
      for (var i = 0; i < 5; i++) {
        samples.add(await _searchOnce(q, limit: 500));
      }
      samples.sort((a, b) => a.totalUs.compareTo(b.totalUs));
      final m = samples[samples.length ~/ 2];
      final ftsSorted = samples.map((s) => s.ftsOnlyUs).toList()..sort();
      final resolveSorted = samples.map((s) => s.resolveUs).toList()..sort();

      _report.writeln('| $q | ${q.length} | ${m.mode.name} | ${m.hits} | '
          '${m.printings} | ${SearchTiming.ms(m.totalUs)} ms | '
          '${SearchTiming.ms(ftsSorted[2])} ms | '
          '${SearchTiming.ms(resolveSorted[2])} ms | '
          '${SearchTiming.ms(m.expandUs)} ms |');
      _note('$q: ${m.mode.name} ${m.hits} 種 / '
          '${SearchTiming.ms(m.totalUs)} ms');
    }
    _report.writeln();
  }

  /// インクリメンタル入力。デバウンスの値を振って比べる。
  Future<void> _benchDebounce() async {
    _report
      ..writeln('## インクリメンタル入力とデバウンス')
      ..writeln()
      ..writeln('「スクールアイドル」を一定間隔で 1 文字ずつ入力した場合。')
      ..writeln('「最後の打鍵から結果まで」が利用者の待ち時間、'
          '「うち無駄」は結果が捨てられた検索の回数。')
      ..writeln();

    for (final keystrokeMs in [60, 120]) {
      _report
        ..writeln('### 打鍵間隔 $keystrokeMs ms')
        ..writeln()
        ..writeln('| デバウンス | 実行された検索 | うち無駄 | DB に使った合計 | '
            '最後の打鍵から結果まで | 予算超えフレーム |')
        ..writeln('|---:|---:|---:|---:|---:|---:|');
      await _benchDebounceAt(keystrokeMs);
      _report.writeln();
    }
  }

  Future<void> _benchDebounceAt(int keystrokeMs) async {
    const typed = 'スクールアイドル';

    for (final debounceMs in [0, 50, 100, 150, 250]) {
      final stats = FrameStats('debounce $debounceMs')..start();
      var issued = 0;
      var searchUs = 0;
      Timer? pending;
      // ★固定の待ち時間を測定に混ぜない★
      //   打鍵の間隔やデバウンスの待ちまで数えると、どのデバウンス値でも
      //   「待ち時間そのもの」が結果になってしまう。
      //   測るのは「最後の打鍵から、最後の語の結果が出るまで」。
      final done = Completer<int>();
      Stopwatch? sinceLastKeystroke;

      Future<void> fire(String value) async {
        issued++;
        final sw = Stopwatch()..start();
        await _searchOnce(value, limit: 500);
        searchUs += sw.elapsedMicroseconds;
        if (value == typed && !done.isCompleted) {
          done.complete(sinceLastKeystroke?.elapsedMilliseconds ?? -1);
        }
      }

      for (var i = 1; i <= typed.length; i++) {
        final value = typed.substring(0, i);
        pending?.cancel();
        if (i == typed.length) sinceLastKeystroke = Stopwatch()..start();
        if (debounceMs == 0) {
          unawaited(fire(value));
        } else {
          pending = Timer(
              Duration(milliseconds: debounceMs), () => unawaited(fire(value)));
        }
        if (i < typed.length) {
          await Future<void>.delayed(Duration(milliseconds: keystrokeMs));
        }
      }

      final latency = await done.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => -1,
      );
      stats.stop();
      final summary = stats.summary();
      final wasted = issued - 1;

      _report.writeln('| $debounceMs ms | $issued 回 | 捨てた $wasted 回 | '
          '${SearchTiming.ms(searchUs)} ms | $latency ms | '
          '${summary.overBudget}/${summary.frames} |');
      _note('debounce $debounceMs: $issued 回（無駄 $wasted）/ '
          'DB 合計 ${SearchTiming.ms(searchUs)} ms / '
          '最後の打鍵から $latency ms');
      await _settle();
    }
  }

  /// 結果件数と描画コスト。上限を設けるべきかの判断材料。
  Future<void> _benchResultCounts() async {
    // ★広くヒットする語を選ぶ★
    //   数百件で止まる語だけだと「上限が要るか」の判断材料にならない。
    //   'ー' は長音記号でほぼ全件に当たる（LIKE 経路）。
    const broad = 'ー';
    const broad2 = 'ライブ';

    _report
      ..writeln('## 結果件数と描画コスト')
      ..writeln()
      ..writeln('`limit` を振って、検索そのものと結果の描画を分けて測る。')
      ..writeln('検索結果は cardNumber なので、刷りへ展開すると件数が増える。')
      ..writeln()
      ..writeln('| 語 | limit | 種 | 刷り | 検索 | 結果を描くまで | 予算超え |')
      ..writeln('|---|---:|---:|---:|---:|---:|---:|');

    for (final q in [broad, broad2]) {
      for (final limit in [200, 500, 1000, 1708]) {
        final t = await _searchOnce(q, limit: limit);

        // 結果を実際に描き直して、最初のフレームが出るまでを測る。
        final stats = FrameStats('$q/$limit')..start();
        final paint = Stopwatch()..start();
        setState(() {
          _limit = limit;
          _last = t;
        });
        await SchedulerBinding.instance.endOfFrame;
        paint.stop();
        await _settle(6);
        stats.stop();
        final summary = stats.summary();

        _report.writeln('| $q | $limit | ${t.hits} | ${t.printings} | '
            '${SearchTiming.ms(t.totalUs)} ms | '
            '${paint.elapsedMilliseconds} ms | '
            '${summary.overBudget}/${summary.frames} |');
        _note('$q limit=$limit: ${t.hits} 種 → ${t.printings} 刷り / '
            '検索 ${SearchTiming.ms(t.totalUs)} ms / '
            '描画 ${paint.elapsedMilliseconds} ms');
      }
    }
    _report.writeln();
  }

  // ---------------------------------------------------------------------------
  // 画面
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: Bar(
          status: _status,
          onBench: _benchRunning ? null : _runBenchmarks,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      autofocus: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'カード名 / 効果 / グループ / ユニット / カード番号',
                        isDense: true,
                      ),
                      onChanged: _onChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('デバウンス'),
                  DropdownButton<int>(
                    value: _debounceMs,
                    onChanged: (v) => setState(() => _debounceMs = v ?? 0),
                    items: [
                      for (final v in [0, 50, 100, 120, 150, 250])
                        DropdownMenuItem(value: v, child: Text('$v ms')),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Text('上限'),
                  DropdownButton<int>(
                    value: _limit,
                    onChanged: (v) => setState(() => _limit = v ?? 500),
                    items: [
                      for (final v in [200, 500, 1000, 1708])
                        DropdownMenuItem(value: v, child: Text('$v')),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _TimingBar(timing: _last, results: _results.length),
                ),
                RepaintBoundary(
                  child: RotationTransition(
                    turns: _spinner,
                    child: const Icon(Icons.autorenew, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            Expanded(child: _buildResults()),
            _LogPane(lines: _log),
          ],
        ),
      );

  Widget _buildResults() {
    if (_results.isEmpty) {
      return const Center(child: Text('検索語を入力する'));
    }
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 200 / 279,
      ),
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final row = _results[i];
        // ★試作1 の結論に合わせ、ResizeImage でセル実寸にしてデコードする。
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (row.imageHash.isEmpty)
              Container(color: Colors.blueGrey.shade100)
            else
              Image(
                image: ResizeImage(
                  FileImage(File(_paths!.thumbPath(row.imageHash))),
                  width: (120 * dpr).round(),
                ),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, wasSync) =>
                    (wasSync || frame != null)
                        ? child
                        : Container(color: Colors.blueGrey.shade50),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(row.cardNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class Bar extends StatelessWidget implements PreferredSizeWidget {
  const Bar({super.key, required this.status, required this.onBench});

  final String status;
  final VoidCallback? onBench;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        title: Text('spike / search — $status'),
        actions: [
          TextButton(onPressed: onBench, child: const Text('計測を実行')),
        ],
      );
}

class _TimingBar extends StatelessWidget {
  const _TimingBar({required this.timing, required this.results});

  final SearchTiming? timing;
  final int results;

  @override
  Widget build(BuildContext context) {
    final t = timing;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        t == null
            ? '—'
            : '経路 ${t.mode.name} / ${t.hits} 種 → $results 刷り / '
                'search() ${SearchTiming.ms(t.totalUs)} ms '
                '(FTS ${SearchTiming.ms(t.ftsOnlyUs)} / '
                '旧復元 ${SearchTiming.ms(t.resolveUs)} / '
                '展開 ${SearchTiming.ms(t.expandUs)})',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _LogPane extends StatelessWidget {
  const _LogPane({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        height: 100,
        width: double.infinity,
        color: Colors.black87,
        padding: const EdgeInsets.all(6),
        child: ListView(
          reverse: true,
          children: [
            for (final line in lines.reversed)
              Text(line,
                  style:
                      const TextStyle(color: Colors.greenAccent, fontSize: 11)),
          ],
        ),
      );
}
