/// 試作3-B: 最小盤面モック（Phase 3b への転用可否）.
///
/// ★ここで確かめるのは物理操作の表現力だけ★
/// カード効果の自動処理は一切しない（CLAUDE.md §1 / 決定 D-A）。
/// 置く・動かす・重ねるという操作が `Draggable` / `DragTarget` で
/// 表現しきれるかどうかだけを見る。ルール上の可否は判定しない。
///
/// ★核心は重ね置き（総合ルール 4.5.5）★
/// 「メンバーの下にカードを差し込む」操作は、通常のドロップと意味が違う。
/// 同じメンバーに落としても「上に重ねる」と「下に差し込む」を
/// 撃ち分けられなければ、盤面 UI が成立しない。
/// `DragTarget` は落ちた場所の座標を渡してくれるので、
/// カードの上半分／下半分で意味を変えられるかを実測する。
///
/// ```bash
/// flutter build windows --profile -t spike/main_board.dart
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

void main() => runApp(const BoardSpikeApp());

class BoardSpikeApp extends StatelessWidget {
  const BoardSpikeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / board',
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const BoardSpikePage(),
      );
}

/// 盤面の領域。★実プレイヤー ID を埋めない★
/// フェイズをロールで定義するのと同じ理由で、ここも位置だけを持つ。
enum BoardZone { hand, member1, member2, member3, waitingRoom }

extension BoardZoneLabel on BoardZone {
  String get label => switch (this) {
        BoardZone.hand => '手札',
        BoardZone.member1 => 'メンバーエリア 1',
        BoardZone.member2 => 'メンバーエリア 2',
        BoardZone.member3 => 'メンバーエリア 3',
        BoardZone.waitingRoom => '控え室',
      };

  bool get isMemberArea =>
      this == BoardZone.member1 ||
      this == BoardZone.member2 ||
      this == BoardZone.member3;
}

/// 重なりの単位。`cards.first` が一番上。
///
/// 4.5.5 の重ね置きを表現するために、スロットは 1 枚ではなく列で持つ。
class CardStack {
  CardStack(this.cards);

  final List<CardGridRow> cards;

  CardGridRow get top => cards.first;
  int get depth => cards.length;
  String get topId => cards.first.printingId;
}

/// ドラッグで運ぶもの。
class BoardDrag {
  const BoardDrag({
    required this.zone,
    required this.slotIndex,
    required this.card,
  });

  final BoardZone zone;
  final int slotIndex;
  final CardGridRow card;
}

/// 同じスロットに落としたときの意味。
enum DropIntent {
  /// スロットの上半分。上に重ねる。
  onTop,

  /// スロットの下半分。★下に差し込む（4.5.5）。
  beneath,
}

class BoardSpikePage extends StatefulWidget {
  const BoardSpikePage({super.key});

  @override
  State<BoardSpikePage> createState() => _BoardSpikePageState();
}

class _BoardSpikePageState extends State<BoardSpikePage> {
  final List<String> _log = [];
  final StringBuffer _report = StringBuffer();

  SpikePaths? _paths;
  List<CardGridRow> _pool = const [];

  final Map<BoardZone, List<CardStack>> _zones = {
    for (final z in BoardZone.values) z: <CardStack>[],
  };

  /// スロットの位置を測るための鍵。zone と index で引く。
  final Map<String, GlobalKey> _slotKeys = {};
  final Map<BoardZone, GlobalKey> _zoneKeys = {
    for (final z in BoardZone.values) z: GlobalKey(),
  };

  /// ドラッグ中のインジケータ。どこへどう落ちるかを出す。
  (BoardZone, int, DropIntent)? _hover;

  String _status = '起動中…';
  bool _benchRunning = false;
  int _dragStarts = 0;
  int _drops = 0;

  String get _dropTrace => '掴んだ $_dragStarts / 落ちた $_drops';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  void _note(String line) {
    _log.add(line);
    stdout.writeln('[board] $line');
  }

  GlobalKey _slotKey(BoardZone zone, int index) =>
      _slotKeys.putIfAbsent('${zone.name}-$index', GlobalKey.new);

  Future<void> _boot() async {
    final opened = await openSpikeDatabase();
    _paths = opened.paths;
    if (opened.importError != null) {
      setState(() => _status = '★${opened.importError}');
      return;
    }
    final loaded =
        await CardGridRepository(opened.db).load(GridLoadStrategy.leanJoin);

    // メンバーカードだけ拾って盤面に並べる。
    final members =
        loaded.rows.where((r) => r.cardType == 'member').take(40).toList();
    setState(() {
      _pool = members;
      _resetBoard();
      _status = '${members.length} 枚をプールに用意';
    });

    _report
      ..writeln('# 試作3-B — 最小盤面モック（Phase 3b への転用可否）')
      ..writeln()
      ..writeln(environmentHeading())
      ..writeln();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (spikeAutoExit) unawaited(_runBenchmarks());
    });
  }

  void _resetBoard() {
    for (final z in BoardZone.values) {
      _zones[z]!.clear();
    }
    if (_pool.length < 12) return;
    // 手札 5 枚、各メンバーエリアに 2 枚ずつ。
    for (var i = 0; i < 5; i++) {
      _zones[BoardZone.hand]!.add(CardStack([_pool[i]]));
    }
    var n = 5;
    for (final z in [BoardZone.member1, BoardZone.member2, BoardZone.member3]) {
      for (var i = 0; i < 2; i++) {
        _zones[z]!.add(CardStack([_pool[n++]]));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 物理操作（ルール判定はしない）
  // ---------------------------------------------------------------------------

  /// 掴んだカードを元の場所から取り除く。
  CardGridRow? _take(BoardDrag drag) {
    final list = _zones[drag.zone]!;
    if (drag.slotIndex >= list.length) return null;
    final stack = list[drag.slotIndex];
    final card = stack.cards.removeAt(0);
    if (stack.cards.isEmpty) list.removeAt(drag.slotIndex);
    return card;
  }

  /// 空きスペースへ新しいスロットとして置く。
  void _dropOnZone(BoardDrag drag, BoardZone zone) {
    setState(() {
      final card = _take(drag);
      if (card == null) return;
      _zones[zone]!.add(CardStack([card]));
      _drops++;
    });
  }

  /// 既にあるスロットへ落とす。[intent] で重ね方を撃ち分ける。
  ///
  /// ★これが 4.5.5 の表現に要る分岐★
  void _dropOnSlot(
    BoardDrag drag,
    BoardZone zone,
    int slotIndex,
    DropIntent intent,
  ) {
    setState(() {
      final target = _zones[zone]![slotIndex];
      final card = _take(drag);
      if (card == null) return;
      // 掴んだ位置の削除でスロットがずれることがあるので、対象は参照で持つ。
      switch (intent) {
        case DropIntent.onTop:
          target.cards.insert(0, card);
        case DropIntent.beneath:
          target.cards.add(card);
      }
      _drops++;
    });
  }

  /// ドロップ位置がスロットの上半分か下半分かを判定する。
  ///
  /// ★`DragTargetDetails.offset` は feedback の左上★
  /// 掴んだ位置によってずれるため、`dragAnchorStrategy` を
  /// `pointerDragAnchorStrategy` にして「ポインタ位置＝ feedback の左上」に
  /// 揃えてある。そうしないと同じ操作でも掴んだ場所で結果が変わる。
  DropIntent? _intentFor(GlobalKey slotKey, Offset globalOffset) {
    final ctx = slotKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(globalOffset);
    return local.dy < box.size.height / 2
        ? DropIntent.onTop
        : DropIntent.beneath;
  }

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
      ..writeln('## 操作が成立するか')
      ..writeln()
      ..writeln('合成ポインタで実際に引いて、盤面の状態がどう変わったかで判定する。')
      ..writeln()
      ..writeln('| 操作 | 期待 | 結果 | 判定 |')
      ..writeln('|---|---|---|---|');

    await _caseHandToMemberArea();
    await _caseBetweenMemberAreas();
    await _caseStackOnTop();
    await _caseStackBeneath();
    await _caseToWaitingRoom();

    // フレーム統計は別に取る。
    final stats = FrameStats('盤面のドラッグ 10 回')..start();
    for (var i = 0; i < 10; i++) {
      final from = centerOfKey(_slotKey(BoardZone.hand, 0));
      final to = centerOfKey(_zoneKeys[BoardZone.member1]!);
      if (from == null || to == null) break;
      await SyntheticPointer(pointer: 8300 + i)
          .dragFromTo(from, to, steps: 30, settleFrames: 6);
      await _settle(4);
      if (_zones[BoardZone.hand]!.isEmpty) _refillHand();
    }
    stats.stop();

    _report
      ..writeln()
      ..writeln('## フレーム統計')
      ..writeln()
      ..writeln(FrameSummary.markdownHeader)
      ..writeln(stats.summary().toMarkdownRow())
      ..writeln();

    writeSpikeReport('05_board', _report.toString());
    if (spikeAutoExit) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
    _benchRunning = false;
  }

  void _refillHand() {
    setState(() {
      for (var i = 0; i < 5 && i < _pool.length; i++) {
        _zones[BoardZone.hand]!.add(CardStack([_pool[i]]));
      }
    });
  }

  void _row(String op, String expected, String actual, bool ok) {
    _report.writeln(
        '| $op | $expected | $actual（$_dropTrace） | ${ok ? "○" : "**×**"} |');
    _note('$op → $actual ${ok ? "○" : "×"} / $_dropTrace');
  }

  Future<void> _resetAndSettle() async {
    setState(_resetBoard);
    _dragStarts = 0;
    _drops = 0;
    await _settle(10);
  }

  Future<void> _caseHandToMemberArea() async {
    await _resetAndSettle();
    final before = _zones[BoardZone.member1]!.length;
    final from = centerOfKey(_slotKey(BoardZone.hand, 0));
    // ★空きスペースへ落とす。エリアの右端（スロットの無いところ）を狙う。
    final zoneRect = rectOfKey(_zoneKeys[BoardZone.member1]!);
    if (from == null || zoneRect == null) return;
    final to = Offset(zoneRect.right - 40, zoneRect.center.dy);
    await SyntheticPointer(pointer: 8000).dragFromTo(from, to, steps: 30);
    await _settle(8);
    final after = _zones[BoardZone.member1]!.length;
    _row('手札 → メンバーエリア', 'スロットが 1 つ増える', '$before → $after',
        after == before + 1);
  }

  Future<void> _caseBetweenMemberAreas() async {
    await _resetAndSettle();
    final before1 = _zones[BoardZone.member1]!.length;
    final before2 = _zones[BoardZone.member2]!.length;
    final from = centerOfKey(_slotKey(BoardZone.member1, 0));
    final zoneRect = rectOfKey(_zoneKeys[BoardZone.member2]!);
    if (from == null || zoneRect == null) return;
    final to = Offset(zoneRect.right - 40, zoneRect.center.dy);
    await SyntheticPointer(pointer: 8010).dragFromTo(from, to, steps: 30);
    await _settle(8);
    _row(
      'メンバーエリア間の移動',
      '1 が 1 減り 2 が 1 増える',
      '1: $before1 → ${_zones[BoardZone.member1]!.length} / '
          '2: $before2 → ${_zones[BoardZone.member2]!.length}',
      _zones[BoardZone.member1]!.length == before1 - 1 &&
          _zones[BoardZone.member2]!.length == before2 + 1,
    );
  }

  Future<void> _caseStackOnTop() async {
    await _resetAndSettle();
    final targetKey = _slotKey(BoardZone.member1, 0);
    final targetRect = rectOfKey(targetKey);
    final from = centerOfKey(_slotKey(BoardZone.hand, 0));
    if (targetRect == null || from == null) return;
    final movingId = _zones[BoardZone.hand]![0].topId;
    final wasTop = _zones[BoardZone.member1]![0].topId;

    // ★スロットの上半分へ落とす＝上に重ねる。
    final to = Offset(targetRect.center.dx, targetRect.top + targetRect.height * 0.25);
    await SyntheticPointer(pointer: 8020).dragFromTo(from, to, steps: 30);
    await _settle(8);

    final slot = _zones[BoardZone.member1]![0];
    final ok = slot.depth == 2 &&
        slot.cards[0].printingId == movingId &&
        slot.cards[1].printingId == wasTop;
    _row('重ね置き / 上半分に落とす', '運んだカードが一番上 (深さ 2)',
        '深さ ${slot.depth} / 一番上 ${slot.topId == movingId ? "運んだ方" : "元の方"}', ok);
  }

  Future<void> _caseStackBeneath() async {
    await _resetAndSettle();
    final targetKey = _slotKey(BoardZone.member1, 0);
    final targetRect = rectOfKey(targetKey);
    final from = centerOfKey(_slotKey(BoardZone.hand, 0));
    if (targetRect == null || from == null) return;
    final movingId = _zones[BoardZone.hand]![0].topId;
    final wasTop = _zones[BoardZone.member1]![0].topId;

    // ★スロットの下半分へ落とす＝下に差し込む（4.5.5）。
    final to =
        Offset(targetRect.center.dx, targetRect.bottom - targetRect.height * 0.25);
    await SyntheticPointer(pointer: 8030).dragFromTo(from, to, steps: 30);
    await _settle(8);

    final slot = _zones[BoardZone.member1]![0];
    final ok = slot.depth == 2 &&
        slot.cards[0].printingId == wasTop &&
        slot.cards.last.printingId == movingId;
    _row('重ね置き / 下半分に落とす', '運んだカードが下 (深さ 2・元のカードが上)',
        '深さ ${slot.depth} / 一番上 ${slot.topId == wasTop ? "元の方" : "運んだ方"}', ok);
  }

  Future<void> _caseToWaitingRoom() async {
    await _resetAndSettle();
    final before = _zones[BoardZone.waitingRoom]!.length;
    final from = centerOfKey(_slotKey(BoardZone.member1, 0));
    final to = centerOfKey(_zoneKeys[BoardZone.waitingRoom]!);
    if (from == null || to == null) return;
    await SyntheticPointer(pointer: 8040).dragFromTo(from, to, steps: 30);
    await _settle(8);
    final after = _zones[BoardZone.waitingRoom]!.length;
    _row('メンバーエリア → 控え室', '控え室が 1 増える', '$before → $after',
        after == before + 1);
  }

  // ---------------------------------------------------------------------------
  // 画面
  // ---------------------------------------------------------------------------

  Widget _cardFace(CardGridRow row, {double width = 70}) {
    if (_paths == null || row.imageHash.isEmpty) {
      return Container(color: Colors.blueGrey.shade200);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image(
      image: ResizeImage(
        FileImage(File(_paths!.thumbPath(row.imageHash))),
        width: (width * dpr).round(),
      ),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) =>
          (wasSync || frame != null)
              ? child
              : Container(color: Colors.blueGrey.shade100),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('spike / board — $_status'),
          actions: [
            TextButton(
              onPressed: _benchRunning ? null : _runBenchmarks,
              child: const Text('計測を実行'),
            ),
            TextButton(
              onPressed: () => setState(_resetBoard),
              child: const Text('並べ直す'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final z in [
                    BoardZone.member1,
                    BoardZone.member2,
                    BoardZone.member3,
                  ])
                    Expanded(child: _buildZone(z)),
                  SizedBox(width: 160, child: _buildZone(BoardZone.waitingRoom)),
                ],
              ),
            ),
            SizedBox(height: 150, child: _buildZone(BoardZone.hand)),
            Container(
              height: 92,
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
          ],
        ),
      );

  Widget _buildZone(BoardZone zone) => DragTarget<BoardDrag>(
        key: _zoneKeys[zone],
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (d) => _dropOnZone(d.data, zone),
        builder: (context, candidate, rejected) => Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            // ★色を必ず置く★ 装飾の無い箱は自分の矩形をヒットテストしないので、
            // 空きスペースへのドロップが成立しなくなる（試作3-A で実測）。
            color: candidate.isEmpty
                ? Colors.grey.shade100
                : Colors.green.shade100,
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(zone.label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < _zones[zone]!.length; i++)
                        _buildSlot(zone, i),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildSlot(BoardZone zone, int index) {
    final stack = _zones[zone]![index];
    final key = _slotKey(zone, index);
    final hovering = _hover != null &&
        _hover!.$1 == zone &&
        _hover!.$2 == index;

    return DragTarget<BoardDrag>(
      onWillAcceptWithDetails: (d) =>
          !(d.data.zone == zone && d.data.slotIndex == index),
      onMove: (d) {
        final intent = _intentFor(key, d.offset);
        if (intent == null) return;
        if (_hover?.$1 != zone || _hover?.$2 != index || _hover?.$3 != intent) {
          setState(() => _hover = (zone, index, intent));
        }
      },
      onLeave: (_) {
        if (hovering) setState(() => _hover = null);
      },
      onAcceptWithDetails: (d) {
        final intent = _intentFor(key, d.offset) ?? DropIntent.onTop;
        setState(() => _hover = null);
        _dropOnSlot(d.data, zone, index, intent);
      },
      builder: (context, candidate, rejected) {
        final face = Container(
          key: key,
          width: 78,
          height: 108,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          // ★ここも色が要る（試作3-A の実測）。
          color: Colors.white,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 下に重なっている枚数だけずらして描く。
              for (var d = stack.depth - 1; d >= 1; d--)
                Positioned(
                  left: d * 4.0,
                  top: d * 4.0,
                  right: -d * 0.0,
                  bottom: 0,
                  child: Container(color: Colors.blueGrey.shade300),
                ),
              Positioned.fill(child: _cardFace(stack.top)),
              if (stack.depth > 1)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    color: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text('${stack.depth}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ),
              // ★どちらの意味で落ちるかを出す★
              // 出さないと利用者は上下で挙動が変わることに気づけない。
              if (hovering)
                Positioned(
                  left: 0,
                  right: 0,
                  top: _hover!.$3 == DropIntent.onTop ? 0 : null,
                  bottom: _hover!.$3 == DropIntent.beneath ? 0 : null,
                  child: Container(
                    height: 26,
                    color: _hover!.$3 == DropIntent.onTop
                        ? Colors.blue.withValues(alpha: 0.75)
                        : Colors.deepOrange.withValues(alpha: 0.75),
                    alignment: Alignment.center,
                    child: Text(
                      _hover!.$3 == DropIntent.onTop ? '上に重ねる' : '下に差し込む',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        );

        return Draggable<BoardDrag>(
          data: BoardDrag(zone: zone, slotIndex: index, card: stack.top),
          // ★ポインタ位置と feedback の左上を揃える★
          // 既定だと掴んだ位置の分だけずれ、上半分／下半分の判定が
          // 掴み方によって変わってしまう。
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () => _dragStarts++,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                  width: 78, height: 108, child: _cardFace(stack.top)),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: face),
          child: face,
        );
      },
    );
  }
}
