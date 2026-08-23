/// 試作1: 仮想リスト.
///
/// 実データ 2,527 刷りをグリッド表示し、thumb をローカルファイルから読む。
/// ネットワーク取得は実装しない。
///
/// ★測るのは 5 つ★
///   1. 初回表示までの時間（取得経路 leanJoin / daoFull の差を含む）
///   2. スクロール時のフレーム落ち
///   3. メモリ（RSS）のピーク
///   4. 画像キャッシュの上限設定の要否
///   5. フィルタ適用時の再構築コスト（SQL 再クエリ / メモリ上フィルタ）
///
/// ```bash
/// flutter build windows --profile -t spike/main_grid.dart
/// SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:loveca_db/loveca_db.dart';

import 'common/card_grid_data.dart';
import 'common/metrics.dart';
import 'common/paths.dart';
import 'common/spike_db.dart';

/// アプリ起動から最初のデータ入りフレームまでを測るための基準時刻。
///
/// ★トップレベルの final は遅延初期化される★
/// 宣言時に `..start()` しても、最初に触った時刻が 0 になって
/// 「初回表示 0 ms」という嘘の値が出る。main() で明示的に始める。
final Stopwatch bootStopwatch = Stopwatch();

/// 1 パスの間に画像が何枚描かれたかを数える。
///
/// ★「フレーム落ちが無い」だけでは足りない★
/// スクロールが速すぎてデコードが 1 枚も間に合っていなくても
/// フレーム統計は綺麗に出る。実際に絵が出た枚数を併記しないと、
/// 「空白を高速で流しただけ」を「快適」と読み違える。
class DecodeCounter {
  static final Set<String> _async = {};
  static final Set<String> _sync = {};

  /// 非同期にデコードが完了して初めて描けた枚数。
  static int get decodedNow => _async.length;

  /// キャッシュから即座に描けた枚数。
  static int get fromCache => _sync.length;

  static void reset() {
    _async.clear();
    _sync.clear();
  }

  static void record(String id, bool wasSync) {
    if (wasSync) {
      if (!_async.contains(id)) _sync.add(id);
    } else {
      _sync.remove(id);
      _async.add(id);
    }
  }
}

void main() {
  bootStopwatch.start();
  runApp(const GridSpikeApp());
}

/// 1 回のスクロール計測の条件。
class GridConfig {
  const GridConfig({
    required this.label,
    this.showImage = true,
    this.resizeToCell = false,
    this.imageCacheMiB,
    this.placeholder = false,
    this.precacheAhead = 0,
  });

  final String label;
  final bool showImage;

  /// `ResizeImage` でセル実寸に合わせてデコードする。
  final bool resizeToCell;

  /// `imageCache.maximumSizeBytes` の明示設定。null は Flutter 既定（100MiB）。
  final int? imageCacheMiB;

  final bool placeholder;

  /// 可視範囲の何セル先まで `precacheImage` するか。0 で無効。
  final int precacheAhead;
}

/// ★計測する条件の一覧★
/// 画像なしを基準に置いて、グリッド自体のコストと画像のコストを切り分ける。
const benchConfigs = <GridConfig>[
  GridConfig(label: '画像なし（グリッド自体のコスト）', showImage: false),
  GridConfig(label: 'Image.file 既定（200px でデコード / 上限 100MiB）'),
  GridConfig(label: '+ ResizeImage（セル実寸でデコード）', resizeToCell: true),
  GridConfig(
    label: '+ ResizeImage + imageCache 256MiB',
    resizeToCell: true,
    imageCacheMiB: 256,
  ),
  GridConfig(
    label: '+ ResizeImage + プレースホルダ',
    resizeToCell: true,
    placeholder: true,
  ),
  GridConfig(
    label: '+ ResizeImage + precacheImage 先読み 60 セル',
    resizeToCell: true,
    placeholder: true,
    precacheAhead: 60,
  ),
];

class GridSpikeApp extends StatelessWidget {
  const GridSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / grid',
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const GridSpikePage(),
      );
}

class GridSpikePage extends StatefulWidget {
  const GridSpikePage({super.key});

  @override
  State<GridSpikePage> createState() => _GridSpikePageState();
}

class _GridSpikePageState extends State<GridSpikePage> {
  final ScrollController _scroll = ScrollController();
  final MemorySampler _memory = MemorySampler();
  final List<String> _log = [];

  LovecaDatabase? _db;
  CardGridRepository? _repo;
  SpikePaths? _paths;

  List<CardGridRow> _allRows = const [];
  List<CardGridRow> _rows = const [];
  List<String> _expansions = const [];

  GridConfig _config = benchConfigs.first;
  CardGridFilter _filter = const CardGridFilter();

  int? _firstPaintMillis;
  bool _benchRunning = false;
  String _status = '起動中…';

  // セル幅（論理 px / 物理 px）。ResizeImage の cacheWidth に使う。
  double _cellLogicalWidth = 0;
  int _cellPhysicalWidth = 0;

  // 先読み用。
  int _precachedUpTo = -1;

  final StringBuffer _report = StringBuffer();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _memory.stop();
    _db?.close();
    super.dispose();
  }

  void _note(String line) {
    _log.add(line);
    stdout.writeln('[grid] $line');
  }

  Future<void> _boot() async {
    final opened = await openSpikeDatabase();
    _db = opened.db;
    _paths = opened.paths;
    _repo = CardGridRepository(opened.db);

    if (opened.importError != null) {
      setState(() => _status = '★${opened.importError}');
      return;
    }
    _note('DB open ${opened.openMillis} ms / '
        'import ${opened.didImport ? "${opened.importMillis} ms" : "なし"} / '
        'executor=${opened.usedBackgroundIsolate ? "background" : "ui"}');

    // --- 取得経路の比較 ---
    final lean = await _repo!.load(GridLoadStrategy.leanJoin);
    final dao = await _repo!.load(GridLoadStrategy.daoFull);
    _note('leanJoin ${lean.rows.length} 行 / ${lean.millis} ms');
    _note('daoFull  ${dao.rows.length} 行 / ${dao.millis} ms');

    _expansions = await _repo!.expansions();

    setState(() {
      _allRows = lean.rows;
      _rows = lean.rows;
      _status = '${_rows.length} 刷り';
    });

    // データ入りの最初のフレームが出た時点を「初回表示」とする。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstPaintMillis ??= bootStopwatch.elapsedMilliseconds;
      _note('初回表示まで $_firstPaintMillis ms（DB 起動 + 取得 + 初回フレーム）');

      _report
        ..writeln('# 試作1 — 仮想リスト')
        ..writeln()
        ..writeln(environmentHeading())
        ..writeln()
        ..writeln('## 起動と取得')
        ..writeln()
        ..writeln('| 項目 | 値 |')
        ..writeln('|---|---:|')
        ..writeln('| DB を開く | ${opened.openMillis} ms |')
        ..writeln('| executor | '
            '${opened.usedBackgroundIsolate ? "別 isolate" : "UI isolate"} |')
        ..writeln('| 取得 leanJoin（表示列だけの JOIN） | '
            '${lean.millis} ms / ${lean.rows.length} 行 |')
        ..writeln('| 取得 daoFull（既存 DAO で全件実体化） | '
            '${dao.millis} ms / ${dao.rows.length} 行 |')
        ..writeln('| 初回表示まで | $_firstPaintMillis ms |')
        ..writeln('| 起動直後の RSS | ${MemorySampler.currentRssMb} MiB |')
        ..writeln();

      if (spikeAutoExit) {
        unawaited(_runBenchmarks());
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 計測
  // ---------------------------------------------------------------------------

  Future<void> _settle([int frames = 12]) async {
    for (var i = 0; i < frames; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _runBenchmarks() async {
    if (_benchRunning) return;
    _benchRunning = true;

    // 2 つの速度で測る。
    //   fling: 端から端まで 8 秒。実際の指ではじいた勢いに近い。
    //   browse: 端から端まで 40 秒。眺めながら送る速度。
    for (final (passLabel, duration) in [
      ('fling（全域 8 秒）', const Duration(seconds: 8)),
      ('browse（全域 40 秒）', const Duration(seconds: 40)),
    ]) {
      final extent = _scroll.position.maxScrollExtent;
      _report
        ..writeln('## スクロール計測 — $passLabel')
        ..writeln()
        ..writeln('全 ${_rows.length} セル / スクロール量 '
            '${extent.round()} px / 速度 '
            '${(extent / duration.inMilliseconds * 1000).round()} px/s')
        ..writeln()
        ..writeln('セル幅 ${_cellLogicalWidth.toStringAsFixed(1)} 論理 px '
            '= $_cellPhysicalWidth 物理 px'
            '（thumb の原寸は 200x279。ResizeImage の cacheWidth に使う値）')
        ..writeln()
        ..writeln('${FrameSummary.markdownHeader.split('\n')[0]} '
            '絵が出た | キャッシュ命中 |')
        ..writeln('${FrameSummary.markdownHeader.split('\n')[1]}---:|---:|');

      final detail = <String>[];

      for (final config in benchConfigs) {
        final summary = await _benchOne(config, duration);
        final decoded = DecodeCounter.decodedNow;
        final cached = DecodeCounter.fromCache;
        _report.writeln('${summary.toMarkdownRow()} $decoded | $cached |');

        final cache = PaintingBinding.instance.imageCache;
        detail.add(
          '| ${config.label} | ${cache.currentSize} | '
          '${(cache.currentSizeBytes / 1024 / 1024).toStringAsFixed(1)} MiB | '
          '${cache.liveImageCount} | ${_memory.peakMb} MiB |',
        );
        _note('[$passLabel] ${config.label} → 予算超え '
            '${summary.overBudget}/${summary.frames} / 絵が出た $decoded 枚');
      }

      _report
        ..writeln()
        ..writeln('### 画像キャッシュと RSS（各パス終了時点） — $passLabel')
        ..writeln()
        ..writeln('| 条件 | キャッシュ枚数 | キャッシュ量 | live | RSS ピーク |')
        ..writeln('|---|---:|---:|---:|---:|');
      for (final line in detail) {
        _report.writeln(line);
      }
      _report.writeln();
    }

    await _benchFilters();

    writeSpikeReport('02_grid', _report.toString());
    if (spikeAutoExit) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
    _benchRunning = false;
  }

  Future<FrameSummary> _benchOne(GridConfig config, Duration duration) async {
    // ★毎回キャッシュを空にしてから測る★
    //   前の条件のデコード済み画像が残っていると、後の条件ほど有利になる。
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    cache.maximumSizeBytes = (config.imageCacheMiB ?? 100) * 1024 * 1024;

    setState(() {
      _config = config;
      _precachedUpTo = -1;
      _status = '計測中: ${config.label}';
    });
    _scroll.jumpTo(0);
    await _settle(20);

    DecodeCounter.reset();
    _memory.reset();
    _memory.start();
    final stats = FrameStats(config.label)..start();

    await _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: duration,
      curve: Curves.linear,
    );

    stats.stop();
    _memory.stop();
    await _settle(4);
    return stats.summary();
  }

  /// フィルタ適用時の再構築コスト。SQL 再クエリとメモリ上フィルタを比べる。
  Future<void> _benchFilters() async {
    _report
      ..writeln('## フィルタ適用のコスト')
      ..writeln()
      ..writeln('| 条件 | SQL 再クエリ | メモリ上フィルタ | 件数 |')
      ..writeln('|---|---:|---:|---:|');

    final expansion =
        _expansions.firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final cases = <(String, CardGridFilter)>[
      ('商品 $expansion のみ', CardGridFilter(expansion: expansion)),
      ('コスト 2 以下', const CardGridFilter(maxCost: 2)),
      ('パラレル表示 OFF', const CardGridFilter(showParallel: false)),
      ('商品 $expansion + コスト 3 以下',
          CardGridFilter(expansion: expansion, maxCost: 3)),
    ];

    for (final (label, filter) in cases) {
      final sqlResult = await _repo!.load(GridLoadStrategy.leanJoin,
          filter: filter);

      final sw = Stopwatch()..start();
      final inMemory = _allRows.where(filter.matches).toList();
      sw.stop();

      // 実際に描き直して、再構築が 1 フレームに収まるかも見る。
      setState(() {
        _filter = filter;
        _rows = inMemory;
      });
      _scroll.jumpTo(0);
      await _settle(6);

      _report.writeln('| $label | ${sqlResult.millis} ms | '
          '${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms | '
          '${inMemory.length} |');
      _note('$label: SQL ${sqlResult.millis} ms / '
          'memory ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms / '
          '${inMemory.length} 件（SQL 側 ${sqlResult.rows.length} 件）');
    }

    setState(() {
      _filter = const CardGridFilter();
      _rows = _allRows;
    });
    await _settle(6);
    _report.writeln();
  }

  // ---------------------------------------------------------------------------
  // 先読み
  // ---------------------------------------------------------------------------

  void _maybePrecache(int lastVisibleIndex) {
    final ahead = _config.precacheAhead;
    if (ahead == 0 || _paths == null) return;
    final target = (lastVisibleIndex + ahead).clamp(0, _rows.length - 1);
    if (target <= _precachedUpTo) return;
    final from = (_precachedUpTo + 1).clamp(0, _rows.length - 1);
    _precachedUpTo = target;
    for (var i = from; i <= target; i++) {
      final hash = _rows[i].imageHash;
      if (hash.isEmpty) continue;
      unawaited(precacheImage(_imageProvider(hash), context)
          .catchError((_) {}));
    }
  }

  ImageProvider _imageProvider(String hash) {
    final base = FileImage(File(_paths!.thumbPath(hash)));
    if (!_config.resizeToCell || _cellPhysicalWidth <= 0) return base;
    // ★物理ピクセルで指定する★ 論理 px を渡すと DPR 倍だけ小さくデコードされ、
    //   拡大表示になってぼやける。
    return ResizeImage(base, width: _cellPhysicalWidth);
  }

  // ---------------------------------------------------------------------------
  // 画面
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('spike / grid — $_status'),
          actions: [
            if (!_benchRunning)
              TextButton(
                onPressed: _rows.isEmpty ? null : _runBenchmarks,
                child: const Text('計測を実行'),
              ),
          ],
        ),
        body: Column(
          children: [
            _ControlBar(
              configs: benchConfigs,
              current: _config,
              onChanged: (c) => setState(() {
                PaintingBinding.instance.imageCache
                  ..clear()
                  ..clearLiveImages();
                _config = c;
                _precachedUpTo = -1;
              }),
              expansions: _expansions,
              filter: _filter,
              onFilter: (f) async {
                final sw = Stopwatch()..start();
                final rows = _allRows.where(f.matches).toList();
                sw.stop();
                setState(() {
                  _filter = f;
                  _rows = rows;
                });
                _note('フィルタ: ${rows.length} 件 / '
                    '${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2)} ms');
              },
            ),
            Expanded(child: _buildGrid()),
            _LogPane(lines: _log),
          ],
        ),
      );

  Widget _buildGrid() {
    if (_rows.isEmpty) {
      return Center(child: Text(_status));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxExtent = 140.0;
        const spacing = 6.0;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final crossAxisCount =
            (constraints.maxWidth / maxExtent).ceil().clamp(1, 100);
        _cellLogicalWidth =
            (constraints.maxWidth - spacing * (crossAxisCount + 1)) /
                crossAxisCount;
        _cellPhysicalWidth = (_cellLogicalWidth * dpr).round();

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (_config.precacheAhead > 0 && n is ScrollUpdateNotification) {
              // セル高さから可視末尾のおおよその index を出す。
              final rowHeight = _cellLogicalWidth * 279 / 200 + spacing;
              final lastRow =
                  ((n.metrics.pixels + n.metrics.viewportDimension) / rowHeight)
                      .ceil();
              _maybePrecache(lastRow * crossAxisCount);
            }
            return false;
          },
          child: GridView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(spacing),
            // ★2,527 セルでも GridView.builder は可視分しか作らない（仮想化）。
            //   問題になるのはセルの中身、特に画像のデコード。
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: 200 / 279,
            ),
            itemCount: _rows.length,
            itemBuilder: (context, i) => _CardCell(
              row: _rows[i],
              config: _config,
              provider: _config.showImage && _rows[i].imageHash.isNotEmpty
                  ? _imageProvider(_rows[i].imageHash)
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class _CardCell extends StatelessWidget {
  const _CardCell({
    required this.row,
    required this.config,
    required this.provider,
  });

  final CardGridRow row;
  final GridConfig config;
  final ImageProvider? provider;

  @override
  Widget build(BuildContext context) {
    final label = Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          row.cardNumber,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 9),
        ),
      ),
    );

    Widget image;
    if (provider == null) {
      image = Container(
        color: Colors.blueGrey.shade100,
        alignment: Alignment.center,
        child: Text(row.name,
            maxLines: 3,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10)),
      );
    } else {
      // ★デコードが追いつかない間に何が見えるかを切り替えて比べる★
      // プレースホルダ無しは「絵が出るまで何も無い」状態になる。
      image = Image(
        image: provider!,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || frame != null) {
            DecodeCounter.record(row.printingId, wasSync);
            return child;
          }
          return config.placeholder
              ? Container(color: Colors.blueGrey.shade50)
              : const SizedBox.shrink();
        },
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        if (row.isParallel)
          const Positioned(
            right: 2,
            top: 2,
            child: Icon(Icons.star, size: 12, color: Colors.amber),
          ),
        label,
      ],
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.configs,
    required this.current,
    required this.onChanged,
    required this.expansions,
    required this.filter,
    required this.onFilter,
  });

  final List<GridConfig> configs;
  final GridConfig current;
  final ValueChanged<GridConfig> onChanged;
  final List<String> expansions;
  final CardGridFilter filter;
  final ValueChanged<CardGridFilter> onFilter;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<GridConfig>(
                value: current,
                onChanged: (c) => c == null ? null : onChanged(c),
                items: [
                  for (final c in configs)
                    DropdownMenuItem(value: c, child: Text(c.label)),
                ],
              ),
              DropdownButton<String?>(
                value: filter.expansion,
                hint: const Text('商品'),
                onChanged: (v) => onFilter(CardGridFilter(
                  expansion: v,
                  maxCost: filter.maxCost,
                  showParallel: filter.showParallel,
                )),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('商品（すべて）')),
                  for (final e in expansions)
                    DropdownMenuItem<String?>(value: e, child: Text(e)),
                ],
              ),
              DropdownButton<int?>(
                value: filter.maxCost,
                hint: const Text('コスト'),
                onChanged: (v) => onFilter(CardGridFilter(
                  expansion: filter.expansion,
                  maxCost: v,
                  showParallel: filter.showParallel,
                )),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('コスト（すべて）')),
                  for (final c in [0, 1, 2, 3, 4, 5])
                    DropdownMenuItem<int?>(value: c, child: Text('$c 以下')),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: filter.showParallel,
                    onChanged: (v) => onFilter(CardGridFilter(
                      expansion: filter.expansion,
                      maxCost: filter.maxCost,
                      showParallel: v ?? true,
                    )),
                  ),
                  const Text('パラレルを表示'),
                ],
              ),
            ],
          ),
        ),
      );
}

class _LogPane extends StatelessWidget {
  const _LogPane({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
        height: 110,
        width: double.infinity,
        color: Colors.black87,
        padding: const EdgeInsets.all(6),
        child: ListView(
          reverse: true,
          children: [
            for (final line in lines.reversed)
              Text(line,
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
          ],
        ),
      );
}
