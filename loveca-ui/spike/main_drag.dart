/// 試作3-A: デッキ編集のドラッグ&ドロップ.
///
/// リスト → デッキ / デッキ内の並べ替え / デッキ → 削除 の 3 操作を
/// `Draggable` / `DragTarget` で組み、合成ポインタで再現して測る。
///
/// ★デッキは printingId 単位で持つ（決定 D11）★
/// 4 枚制限は cardNumber 単位（総合ルール 6.1.1.2）だが、それは検証の話であり
/// この試作では扱わない。ここで確かめるのは物理操作が成立するかだけ。
///
/// ★メイン / エネルギーの区分は列に持たない（決定 D41）★
/// `cards.card_type` から導出する。この試作でも導出して表示する。
///
/// ★並べ替えの 2 方式は等価ではない★
/// `ReorderableListView` は行のドラッグを自分で握るため、同じ行を
/// 「掴んでゴミ箱へ落とす」ことができない。並べ替えと領域外への持ち出しを
/// 両立させるには行ごとの `DragTarget` 方式が要る。これは実装の好みではなく
/// 機能の差なので、両方を組んで確かめる。
///
/// ```bash
/// flutter build windows --profile -t spike/main_drag.dart
/// SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'common/card_grid_data.dart';
import 'common/metrics.dart';
import 'common/paths.dart';
import 'common/pointer_driver.dart';
import 'common/spike_db.dart';

void main() => runApp(const DragSpikeApp());

class DragSpikeApp extends StatelessWidget {
  const DragSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / drag',
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const DragSpikePage(),
      );
}

/// ドラッグ中に運ぶもの。
class CardDrag {
  const CardDrag(this.row, {this.fromDeckIndex});

  final CardGridRow row;

  /// デッキ内から掴んだ場合の元の位置。リストから掴んだ場合は null。
  final int? fromDeckIndex;
}

class DeckEntry {
  DeckEntry(this.row, this.count);

  final CardGridRow row;
  int count;
}

/// 並べ替えの実装方式。
enum ReorderStyle {
  /// Flutter 標準の `ReorderableListView`。
  reorderableListView,

  /// 行ごとに `DragTarget` を置いて差し込み位置を自前で決める。
  dragTargetPerIndex,
}

/// feedback（ドラッグ中についてくる絵）の作り方。
enum FeedbackStyle { cardImage, simpleBox }

/// ★ドラッグの始め方★
/// `Draggable` の既定は `ImmediateMultiDragGestureRecognizer` で、
/// 押した直後の移動でドラッグが始まる。スクロールできる領域の内側では
/// これがスクロールとジェスチャアリーナを奪い合い、
/// **スクロール軸と同じ向きに引くとスクロール側が勝ってドラッグが始まらない。**
/// 逃げ道は 3 つあり、どれを採るかで操作感が変わるので実測で比べる。
enum DragStartStyle {
  /// 既定。押してすぐ動かすと始まる。
  immediate,

  /// 長押ししてから動かすと始まる（`LongPressDraggable`）。
  longPress,

  /// 横方向の移動でだけ始まる（`Draggable(affinity: Axis.horizontal)`）。
  horizontalAffinity,
}

class DragSpikePage extends StatefulWidget {
  const DragSpikePage({super.key});

  @override
  State<DragSpikePage> createState() => _DragSpikePageState();
}

class _DragSpikePageState extends State<DragSpikePage> {
  final ScrollController _gridScroll = ScrollController();
  final List<String> _log = [];
  final StringBuffer _report = StringBuffer();

  final GlobalKey _deckPanelKey = GlobalKey();
  final GlobalKey _trashKey = GlobalKey();
  final List<GlobalKey> _cellKeys = [];

  /// 行の位置を測るための鍵。★index ではなく printingId で持つ★
  /// 並べ替えで行が動くため、index を鍵にすると GlobalKey が重複する。
  final Map<String, GlobalKey> _deckRowKeys = {};

  SpikePaths? _paths;
  List<CardGridRow> _rows = const [];
  final List<DeckEntry> _deck = [];

  ReorderStyle _reorderStyle = ReorderStyle.reorderableListView;
  FeedbackStyle _feedbackStyle = FeedbackStyle.cardImage;
  DragStartStyle _dragStartStyle = DragStartStyle.immediate;
  String _status = '起動中…';
  bool _benchRunning = false;

  // ★ドラッグがどこで止まったのかを数える★
  // 「0 回動いた」だけでは、掴めていないのか、落とせていないのかが分からない。
  int _dragStarts = 0;
  int _dragEnds = 0;
  int _willAccept = 0;
  int _accepted = 0;

  void _resetDragCounters() {
    _dragStarts = 0;
    _dragEnds = 0;
    _willAccept = 0;
    _accepted = 0;
  }

  String get _dragTrace =>
      '開始 $_dragStarts / 終了 $_dragEnds / 判定 $_willAccept / 受理 $_accepted';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _gridScroll.dispose();
    super.dispose();
  }

  void _note(String line) {
    _log.add(line);
    stdout.writeln('[drag] $line');
  }

  Future<void> _boot() async {
    final opened = await openSpikeDatabase();
    _paths = opened.paths;
    if (opened.importError != null) {
      setState(() => _status = '★${opened.importError}');
      return;
    }
    final loaded =
        await CardGridRepository(opened.db).load(GridLoadStrategy.leanJoin);
    setState(() {
      _rows = loaded.rows;
      _cellKeys
        ..clear()
        ..addAll(List.generate(_rows.length, (_) => GlobalKey()));
      _status = '${_rows.length} 刷り';
    });

    _report
      ..writeln('# 試作3-A — デッキ編集のドラッグ&ドロップ')
      ..writeln()
      ..writeln(environmentHeading())
      ..writeln();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (spikeAutoExit) unawaited(_runBenchmarks());
    });
  }

  // ---------------------------------------------------------------------------
  // デッキ操作（物理操作だけ。検証はしない）
  // ---------------------------------------------------------------------------

  void _addToDeck(CardGridRow row) {
    final i = _deck.indexWhere((e) => e.row.printingId == row.printingId);
    setState(() {
      if (i >= 0) {
        _deck[i].count++;
      } else {
        _deck.add(DeckEntry(row, 1));
      }
    });
  }

  void _moveInDeck(int from, int to) {
    if (from == to || from < 0 || from >= _deck.length) return;
    setState(() {
      final e = _deck.removeAt(from);
      _deck.insert(to.clamp(0, _deck.length), e);
    });
  }

  void _removeFromDeck(int index) {
    if (index < 0 || index >= _deck.length) return;
    setState(() => _deck.removeAt(index));
  }

  GlobalKey _deckRowKey(String printingId) =>
      _deckRowKeys.putIfAbsent(printingId, GlobalKey.new);

  Rect? _deckRowRect(int index) => index < _deck.length
      ? rectOfKey(_deckRowKey(_deck[index].row.printingId))
      : null;

  // ---------------------------------------------------------------------------
  // 計測
  // ---------------------------------------------------------------------------

  Future<void> _settle([int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  Future<void> _runBenchmarks() async {
    if (_benchRunning) return;
    _benchRunning = true;

    _report
      ..writeln('## 操作ごとの成否とフレーム統計')
      ..writeln()
      ..writeln('合成ポインタで同じ操作を 40 ステップ（1 ステップ 1 フレーム）に'
          '分けて再現する。長押し方式は押した位置で 600 ms 止まってから動かす。')
      ..writeln()
      ..writeln('★「成否」が本題★ フレーム統計が綺麗でも、'
          'ドラッグがそもそも始まっていなければ意味がない。')
      ..writeln()
      ..writeln('${FrameSummary.markdownHeader.split('\n')[0]} 成否 |')
      ..writeln('${FrameSummary.markdownHeader.split('\n')[1]}---|');

    // --- (1) リスト → デッキ。グリッドから横向きに引き出す ---
    for (final start in DragStartStyle.values) {
      setState(() {
        _dragStartStyle = start;
        _feedbackStyle = FeedbackStyle.cardImage;
      });
      await _settle(10);
      final before = _deckCards;
      final summary = await _benchListToDeck(start, repeats: 6);
      _report.writeln('${summary.toMarkdownRow()} '
          '6 回中 ${_deckCards - before} 枚入った（$_dragTrace） |');
      _note('リスト→デッキ / ${start.name} → '
          '${_deckCards - before} 枚 / $_dragTrace');
    }

    // --- (2) feedback の作り方。成立する組み合わせで比べる ---
    for (final fb in FeedbackStyle.values) {
      setState(() {
        _dragStartStyle = DragStartStyle.immediate;
        _feedbackStyle = fb;
      });
      await _settle(10);
      final before = _deckCards;
      final summary = await _benchListToDeck(
        DragStartStyle.immediate,
        repeats: 6,
        label: 'feedback=${fb.name}',
      );
      _report.writeln('${summary.toMarkdownRow()} '
          '6 回中 ${_deckCards - before} 枚入った |');
      _note('feedback=${fb.name} → 予算超え ${summary.overBudget}');
    }

    // --- (3) デッキ内の並べ替え。縦スクロールと同じ向きに引く ---
    setState(() => _reorderStyle = ReorderStyle.reorderableListView);
    await _settle(12);
    final (rlvSummary, rlvMoved) = await _benchReorder(
        ReorderStyle.reorderableListView, DragStartStyle.immediate, repeats: 5);
    _report.writeln('${rlvSummary.toMarkdownRow()} '
        '5 回中 $rlvMoved 回動いた（$_dragTrace） |');
    _note('並べ替え / ReorderableListView → $rlvMoved 回');

    for (final start in DragStartStyle.values) {
      setState(() {
        _reorderStyle = ReorderStyle.dragTargetPerIndex;
        _dragStartStyle = start;
      });
      await _settle(12);
      final (summary, moved) = await _benchReorder(
          ReorderStyle.dragTargetPerIndex, start, repeats: 5);
      _report.writeln('${summary.toMarkdownRow()} '
          '5 回中 $moved 回動いた（$_dragTrace） |');
      _note('並べ替え / DragTarget+${start.name} → $moved 回 / $_dragTrace');
    }

    // --- (4) デッキ → 削除。リストの外へ縦に持ち出す ---
    for (final start in DragStartStyle.values) {
      setState(() {
        _reorderStyle = ReorderStyle.dragTargetPerIndex;
        _dragStartStyle = start;
      });
      await _settle(12);
      final (summary, removed) = await _benchDeckToTrash(start, repeats: 3);
      _report.writeln('${summary.toMarkdownRow()} '
          '3 回中 $removed 行消えた（$_dragTrace） |');
      _note('デッキ→削除 / ${start.name} → $removed 行 / $_dragTrace');
    }

    _report
      ..writeln()
      ..writeln('計測終了時のデッキ: ${_deck.length} 行 / $_deckCards 枚')
      ..writeln();

    writeSpikeReport('04_drag', _report.toString());
    if (spikeAutoExit) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
    _benchRunning = false;
  }

  int get _deckCards => _deck.fold<int>(0, (a, e) => a + e.count);

  int _holdMsFor(DragStartStyle style) =>
      style == DragStartStyle.longPress ? 600 : 0;

  Future<FrameSummary> _benchListToDeck(
    DragStartStyle start, {
    required int repeats,
    String? label,
  }) async {
    _resetDragCounters();
    final stats = FrameStats(label ?? 'リスト→デッキ / ${start.name}')..start();
    final deckRect = rectOfKey(_deckPanelKey);

    for (var i = 0; i < repeats; i++) {
      final from = centerOfKey(_cellKeys[i]);
      if (from == null || deckRect == null) continue;
      final pointer = SyntheticPointer(pointer: 7000 + i);
      await pointer.dragFromTo(from, deckRect.center,
          steps: 40, holdMs: _holdMsFor(start));
      await _settle(3);
    }
    stats.stop();
    await _settle();
    return stats.summary();
  }

  Future<(FrameSummary, int)> _benchReorder(
    ReorderStyle style,
    DragStartStyle start, {
    required int repeats,
  }) async {
    // 並べ替えるには行が要る。足りなければ足す。
    var seed = 30;
    while (_deck.length < 8 && seed < _rows.length) {
      _addToDeck(_rows[seed++]);
      await _settle(2);
    }

    final label = style == ReorderStyle.reorderableListView
        ? '並べ替え / ReorderableListView'
        : '並べ替え / DragTarget + ${start.name}';
    _resetDragCounters();
    final stats = FrameStats(label)..start();
    var moved = 0;
    for (var i = 0; i < repeats; i++) {
      final fromRect = _deckRowRect(0);
      final toRect = _deckRowRect(4);
      if (fromRect == null || toRect == null) break;
      if (i == 0) {
        // 掴む点の真下に何があるかを 1 度だけ残す。
        // 「掴めない」ときはここに Draggable の Listener が出てこない。
        _note('  ${style.name} 掴む点の真下: '
            '${hitTestAt(fromRect.center).take(4).join(" < ")}');
      }
      final movingId = _deck[0].row.printingId;

      // ★掴む場所が方式で違う★
      //   ReorderableListView はデスクトップだと行末のドラッグハンドルからしか
      //   掴めない。自前 DragTarget 方式は行のどこからでも掴める。
      final from = style == ReorderStyle.reorderableListView
          ? Offset(fromRect.right - 20, fromRect.center.dy)
          : fromRect.center;

      final pointer = SyntheticPointer(pointer: 7100 + i);
      await pointer.dragFromTo(
        from,
        Offset(from.dx, toRect.center.dy),
        steps: 40,
        holdMs:
            style == ReorderStyle.reorderableListView ? 0 : _holdMsFor(start),
        settleFrames: 12,
      );

      if (_deck.isNotEmpty && _deck[0].row.printingId != movingId) moved++;
    }
    stats.stop();
    return (stats.summary(), moved);
  }

  Future<(FrameSummary, int)> _benchDeckToTrash(
    DragStartStyle start, {
    required int repeats,
  }) async {
    // ★毎回同じ行数から始める★
    // 前の条件で消した分だけ行が減ると、後の条件ほど試行回数が減って
    // 「成功率が低い」ように見えてしまう。
    var seed = 60;
    while (_deck.length < repeats + 2 && seed < _rows.length) {
      _addToDeck(_rows[seed++]);
      await _settle(2);
    }

    _resetDragCounters();
    // ★行数は補充のあとに数える★
    // 補充より前の値と比べると、消えた行数を取り違える。
    final before = _deck.length;
    final stats = FrameStats('デッキ→削除 / ${start.name}')..start();
    final trash = centerOfKey(_trashKey);
    for (var i = 0; i < repeats && _deck.isNotEmpty; i++) {
      final rect = _deckRowRect(0);
      if (rect == null || trash == null) break;
      final pointer = SyntheticPointer(pointer: 7200 + i);
      await pointer.dragFromTo(rect.center, trash,
          steps: 40, holdMs: _holdMsFor(start), settleFrames: 8);
      await _settle(6);
    }
    stats.stop();
    return (stats.summary(), before - _deck.length);
  }

  // ---------------------------------------------------------------------------
  // 画面
  // ---------------------------------------------------------------------------

  Widget _thumb(CardGridRow row, {double width = 120}) {
    if (_paths == null || row.imageHash.isEmpty) {
      return Container(color: Colors.blueGrey.shade100);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: ResizeImage(
        FileImage(File(_paths!.thumbPath(row.imageHash))),
        width: (width * dpr).round(),
      ),
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) =>
          (wasSync || frame != null)
              ? child
              : Container(color: Colors.blueGrey.shade50),
    );
  }

  /// 選ばれた方式で `Draggable` を組む。
  ///
  /// ★同じ `DragTarget` に対して始め方だけを差し替えられる形にしてある★
  /// 受け側を変えずに始め方だけ比べないと、どちらが効いたのか分からない。
  Widget _draggable({
    required CardGridRow row,
    required CardDrag data,
    required Widget child,
    Key? key,
  }) {
    final feedback = _feedback(row);
    final whenDragging = Opacity(opacity: 0.3, child: child);
    void started() => _dragStarts++;
    void ended(DraggableDetails _) => _dragEnds++;
    return switch (_dragStartStyle) {
      DragStartStyle.immediate => Draggable<CardDrag>(
          key: key,
          data: data,
          feedback: feedback,
          childWhenDragging: whenDragging,
          onDragStarted: started,
          onDragEnd: ended,
          child: child,
        ),
      DragStartStyle.longPress => LongPressDraggable<CardDrag>(
          key: key,
          data: data,
          feedback: feedback,
          childWhenDragging: whenDragging,
          onDragStarted: started,
          onDragEnd: ended,
          child: child,
        ),
      // ★affinity: horizontal は「横に引いたときだけドラッグ」という意味★
      //   縦スクロールする一覧の中では、縦の動きをスクロールに譲れる。
      //   逆に縦方向へ持ち出す操作は始められなくなる。
      DragStartStyle.horizontalAffinity => Draggable<CardDrag>(
          key: key,
          data: data,
          affinity: Axis.horizontal,
          feedback: feedback,
          childWhenDragging: whenDragging,
          onDragStarted: started,
          onDragEnd: ended,
          child: child,
        ),
    };
  }

  Widget _feedback(CardGridRow row) {
    // ★feedback は Overlay に載る。親の Material が効かないので自分で包む。
    final child = switch (_feedbackStyle) {
      FeedbackStyle.cardImage => SizedBox(
          width: 110,
          height: 153,
          child: Opacity(opacity: 0.85, child: _thumb(row, width: 110)),
        ),
      FeedbackStyle.simpleBox => Container(
          width: 110,
          height: 153,
          color: Colors.indigo.withValues(alpha: 0.7),
          alignment: Alignment.center,
          child: Text(row.cardNumber,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
    };
    return Material(color: Colors.transparent, child: child);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('spike / drag — $_status'),
          actions: [
            DropdownButton<ReorderStyle>(
              value: _reorderStyle,
              onChanged: (v) =>
                  setState(() => _reorderStyle = v ?? _reorderStyle),
              items: const [
                DropdownMenuItem(
                    value: ReorderStyle.reorderableListView,
                    child: Text('ReorderableListView')),
                DropdownMenuItem(
                    value: ReorderStyle.dragTargetPerIndex,
                    child: Text('DragTarget を行ごとに')),
              ],
            ),
            const SizedBox(width: 12),
            DropdownButton<DragStartStyle>(
              value: _dragStartStyle,
              onChanged: (v) =>
                  setState(() => _dragStartStyle = v ?? _dragStartStyle),
              items: const [
                DropdownMenuItem(
                    value: DragStartStyle.immediate, child: Text('即時')),
                DropdownMenuItem(
                    value: DragStartStyle.longPress, child: Text('長押し')),
                DropdownMenuItem(
                    value: DragStartStyle.horizontalAffinity,
                    child: Text('横方向のみ')),
              ],
            ),
            const SizedBox(width: 12),
            DropdownButton<FeedbackStyle>(
              value: _feedbackStyle,
              onChanged: (v) =>
                  setState(() => _feedbackStyle = v ?? _feedbackStyle),
              items: const [
                DropdownMenuItem(
                    value: FeedbackStyle.cardImage, child: Text('feedback: 画像')),
                DropdownMenuItem(
                    value: FeedbackStyle.simpleBox, child: Text('feedback: 単色')),
              ],
            ),
            TextButton(
              onPressed: _benchRunning ? null : _runBenchmarks,
              child: const Text('計測を実行'),
            ),
          ],
        ),
        body: Row(
          children: [
            Expanded(flex: 3, child: _buildGrid()),
            const VerticalDivider(width: 1),
            SizedBox(width: 340, child: _buildDeckPanel()),
          ],
        ),
        bottomNavigationBar: Container(
          height: 96,
          color: Colors.black87,
          padding: const EdgeInsets.all(6),
          child: ListView(
            reverse: true,
            children: [
              for (final line in _log.reversed)
                Text(line,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 11)),
            ],
          ),
        ),
      );

  Widget _buildGrid() {
    if (_rows.isEmpty) return Center(child: Text(_status));
    return GridView.builder(
      controller: _gridScroll,
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 200 / 279,
      ),
      itemCount: _rows.length,
      itemBuilder: (context, i) {
        final row = _rows[i];
        return _draggable(
          key: i < _cellKeys.length ? _cellKeys[i] : null,
          row: row,
          data: CardDrag(row),
          child: _thumb(row),
        );
      },
    );
  }

  Widget _buildDeckPanel() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text('デッキ ${_deck.length} 行 / '
                '${_deck.fold<int>(0, (a, e) => a + e.count)} 枚'),
          ),
          Expanded(
            child: DragTarget<CardDrag>(
              key: _deckPanelKey,
              onWillAcceptWithDetails: (d) => d.data.fromDeckIndex == null,
              onAcceptWithDetails: (d) => _addToDeck(d.data.row),
              builder: (context, candidate, rejected) => Container(
                color: candidate.isEmpty
                    ? null
                    : Colors.green.withValues(alpha: 0.12),
                child: _reorderStyle == ReorderStyle.reorderableListView
                    ? _buildReorderableList()
                    : _buildDragTargetList(),
              ),
            ),
          ),
          DragTarget<CardDrag>(
            key: _trashKey,
            onWillAcceptWithDetails: (d) {
              _willAccept++;
              return d.data.fromDeckIndex != null;
            },
            onAcceptWithDetails: (d) {
              _accepted++;
              _removeFromDeck(d.data.fromDeckIndex!);
            },
            builder: (context, candidate, rejected) => Container(
              height: 64,
              width: double.infinity,
              color:
                  candidate.isEmpty ? Colors.red.shade50 : Colors.red.shade200,
              alignment: Alignment.center,
              child: const Text('ここへ落として削除'),
            ),
          ),
        ],
      );

  /// ★この方式では行を `Draggable` にできない★
  /// `ReorderableListView` が行のドラッグを握っているため、
  /// 行を掴んでゴミ箱へ持ち出す操作が作れない。
  Widget _buildReorderableList() => ReorderableListView.builder(
        itemCount: _deck.length,
        onReorder: (from, to) => _moveInDeck(from, to > from ? to - 1 : to),
        itemBuilder: (context, i) => KeyedSubtree(
          key: ValueKey('reorder-${_deck[i].row.printingId}'),
          child: _deckRow(i, draggable: false),
        ),
      );

  /// 行ごとに `DragTarget` を置いて差し込み位置を自前で決める方式。
  /// 行は `Draggable` のままなので、ゴミ箱への持ち出しも同居できる。
  Widget _buildDragTargetList() => ListView.builder(
        itemCount: _deck.length,
        itemBuilder: (context, i) => DragTarget<CardDrag>(
          onWillAcceptWithDetails: (d) {
            _willAccept++;
            return d.data.fromDeckIndex != null;
          },
          onAcceptWithDetails: (d) {
            _accepted++;
            _moveInDeck(d.data.fromDeckIndex!, i);
          },
          builder: (context, candidate, rejected) => Container(
            decoration: candidate.isEmpty
                ? null
                : const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: Colors.indigo, width: 3)),
                  ),
            child: _deckRow(i, draggable: true),
          ),
        ),
      );

  Widget _deckRow(int i, {required bool draggable}) {
    final entry = _deck[i];
    // ★区分は card_type から導出する。行に保存しない（決定 D41）。
    final section = entry.row.cardType == 'energy' ? 'エネルギー' : 'メイン';
    // ★★ 掴める領域は「実際に描かれているもの」の上にしかない ★★
    // 色も装飾も持たない Container / Row / Column は自分の矩形を
    // ヒットテストしないため、行の中の余白（テキスト行の隙間など）を押しても
    // Draggable まで届かず、ドラッグが始まらない。
    // 実測: 行の中央 x+170 を押すと DragTarget の RenderMetaData までしか
    // 届かず onDragStarted が 1 度も呼ばれなかった。
    // color を与えると ColoredBox（HitTestBehavior.opaque）になって矩形全体が
    // 掴めるようになる。Phase 3b の盤面でも同じ手当てが要る。
    final content = Container(
      key: _deckRowKey(entry.row.printingId),
      color: i.isEven ? Colors.grey.shade50 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 34, height: 47, child: _thumb(entry.row, width: 34)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                Text('${entry.row.printingId} · $section',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Text('×${entry.count}'),
        ],
      ),
    );

    if (!draggable) return content;
    return _draggable(
      row: entry.row,
      data: CardDrag(entry.row, fromDeckIndex: i),
      child: content,
    );
  }
}
