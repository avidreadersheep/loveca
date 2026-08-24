/// ドラッグのラッパ（決定 D46 / D47 / D58）.
///
/// ★★ 「掴めること」だけを見るテストは、`ColoredBox` を外しても通る ★★
/// D46 が実際に踏んだのは「**行の余白**を押すと掴めない」であり、
/// 掴める側だけを固定しても手当てが効いているかは分からない。
/// → **対照実験**を置く。色を持たない素の `Draggable` を同じ形で並べ、
/// **同じ相対位置で掴めないこと**を固定する。
/// これが通らなくなったら、それは「ウィジェットテストでは D46 が再現しない」という
/// 意味であり、上の成功側のテストが**何も証明していない**ことを示す
/// （D-10:「0 件は『無い』と『見えていない』の区別がつかない」の適用）。
///
/// ★★ 2 つの手当ては「外すと落ちる」ことを実際に確かめてある（2026-08-24）★★
///
/// | 外したもの | 結果 |
/// |---|---|
/// | `CardDragSource` の `ColoredBox` | ——（対照実験がその役目。素の `Draggable` で落ちることを常時固定） |
/// | `dragAnchorStrategy: pointerDragAnchorStrategy` | 「掴んだ位置が違っても判定は変わらない」が **trailing / leading に割れて落ちた** |
///
/// ★★ 落とす点を端にすると、外しても通ってしまう ★★
/// 最初その形で書いていて**外しても通った**。掴んだ位置の差が中央をまたぐ点で
/// 落とさないと差が出ない。D-10（検知手段自身が同じ罠を踏む）の実例。
///
/// ★★ `DragStartMode` の両方を通す（決定 D52 (d) / D58）★★
/// `longPress` は PC では使われない。**使われない経路は D51 の `spike/` と
/// 同じ性質で静かに腐る**（`flutter analyze` は通るので気づけない）。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/ui/common/card_drag.dart';

/// 掴む側の矩形。★中身は「余白の広い行」——D46 が踏んだ形そのもの。
const _sourceKey = Key('source');
const _targetKey = Key('target');
const _controlSourceKey = Key('controlSource');

/// 行の中の**文字が無いところ**。ここを押せるかが D46 の論点。
Offset _padding(WidgetTester tester, Key key) {
  final rect = tester.getRect(find.byKey(key));
  // 右端寄り・上下中央。文字（左端）から外れている。
  return Offset(rect.right - 8, rect.center.dy);
}

Future<void> _drag(
  WidgetTester tester, {
  required Offset from,
  required Offset to,
  PointerDeviceKind kind = PointerDeviceKind.mouse,
  bool longPress = false,
}) async {
  final gesture = await tester.startGesture(from, kind: kind);
  if (longPress) {
    // ★長押し起点は待たないと始まらない。
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  }
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// ラッパで組んだ「掴む 1 行 + 落とす 1 枠」。
Widget _wrapped({
  required void Function(String data, DropEdge edge) onDrop,
  DragStartMode mode = DragStartMode.immediate,
  bool enabled = true,
  double targetHeight = 120,
  ValueChanged<DropEdge?>? onHover,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              key: _sourceKey,
              width: 300,
              height: 60,
              child: CardDragSource<String>(
                data: 'card',
                background: Colors.white,
                mode: mode,
                enabled: enabled,
                feedback: const SizedBox(width: 40, height: 56),
                // ★色も装飾も持たない中身。ラッパの ColoredBox だけが頼り。
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(children: [Text('行')]),
                ),
              ),
            ),
            SizedBox(
              key: _targetKey,
              width: 300,
              height: targetHeight,
              child: CardDropTarget<String>(
                background: Colors.grey,
                onDrop: onDrop,
                builder: (context, hovering) {
                  onHover?.call(hovering);
                  return Center(
                    child: Text(switch (hovering) {
                      null => 'ここへ',
                      DropEdge.leading => '手前に入る',
                      DropEdge.trailing => '後ろに入る',
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

/// ★対照実験。**素の `Draggable`**（色を持たない中身）で同じ形を組む。
Widget _control({required VoidCallback onDrop}) => MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              key: _controlSourceKey,
              width: 300,
              height: 60,
              child: Draggable<String>(
                data: 'card',
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: const SizedBox(width: 40, height: 56),
                // ★★ ColoredBox で包まない。これが D46 の踏んだ形 ★★
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(children: [Text('行')]),
                ),
              ),
            ),
            SizedBox(
              key: _targetKey,
              width: 300,
              height: 120,
              child: DragTarget<String>(
                onAcceptWithDetails: (_) => onDrop(),
                builder: (context, _, _) =>
                    const ColoredBox(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  group('★★ D46: 掴める領域は描画物の上にしか無い ★★', () {
    testWidgets('★対照実験: 色を持たない素の Draggable は行の余白で掴めない', (tester) async {
      // ★★ このテストが落ちたら、下の成功側は何も証明していない ★★
      //   「ウィジェットテストでは D46 が再現しない」という意味になるため。
      var dropped = false;
      await tester.pumpWidget(_control(onDrop: () => dropped = true));

      await _drag(
        tester,
        from: _padding(tester, _controlSourceKey),
        to: tester.getCenter(find.byKey(_targetKey)),
      );

      expect(
        dropped,
        isFalse,
        reason: '色の無い Padding / Row は自分の矩形をヒットテストしない',
      );
    });

    testWidgets('★CardDragSource は同じ位置（行の余白）で掴める', (tester) async {
      String? droppedData;
      await tester.pumpWidget(
        _wrapped(onDrop: (data, _) => droppedData = data),
      );

      await _drag(
        tester,
        from: _padding(tester, _sourceKey),
        to: tester.getCenter(find.byKey(_targetKey)),
      );

      expect(droppedData, 'card');
    });

    testWidgets('★enabled: false なら掴めない（マスタに無い刷り / 決定 D35）',
        (tester) async {
      var dropped = false;
      await tester.pumpWidget(
        _wrapped(enabled: false, onDrop: (_, _) => dropped = true),
      );

      await _drag(
        tester,
        from: _padding(tester, _sourceKey),
        to: tester.getCenter(find.byKey(_targetKey)),
      );

      expect(dropped, isFalse);
    });
  });

  group('★★ DragStartMode の両方を通す（決定 D52 (d) / D58）★★', () {
    // ★longPress は PC では使われない。使われない経路は静かに腐る。
    for (final mode in DragStartMode.values) {
      for (final kind in [PointerDeviceKind.mouse, PointerDeviceKind.touch]) {
        testWidgets('${mode.name} / ${kind.name} でドラッグが成立する', (tester) async {
          String? droppedData;
          await tester.pumpWidget(
            _wrapped(mode: mode, onDrop: (data, _) => droppedData = data),
          );

          await _drag(
            tester,
            from: _padding(tester, _sourceKey),
            to: tester.getCenter(find.byKey(_targetKey)),
            kind: kind,
            longPress: mode == DragStartMode.longPress,
          );

          expect(droppedData, 'card');
        });
      }
    }

    testWidgets('★longPress は長押ししなければ始まらない（出ない側）', (tester) async {
      var dropped = false;
      await tester.pumpWidget(
        _wrapped(
          mode: DragStartMode.longPress,
          onDrop: (_, _) => dropped = true,
        ),
      );

      await _drag(
        tester,
        from: _padding(tester, _sourceKey),
        to: tester.getCenter(find.byKey(_targetKey)),
        // longPress: false ——待たずに動かす。
      );

      expect(dropped, isFalse);
    });
  });

  group('★★ D47: 落下点の上半分／下半分を撃ち分ける ★★', () {
    testWidgets('上半分なら leading / 下半分なら trailing', (tester) async {
      final edges = <DropEdge>[];
      await tester.pumpWidget(_wrapped(onDrop: (_, edge) => edges.add(edge)));

      final rect = tester.getRect(find.byKey(_targetKey));
      await _drag(
        tester,
        from: _padding(tester, _sourceKey),
        to: Offset(rect.center.dx, rect.top + 10),
      );
      await _drag(
        tester,
        from: _padding(tester, _sourceKey),
        to: Offset(rect.center.dx, rect.bottom - 10),
      );

      expect(edges, [DropEdge.leading, DropEdge.trailing]);
    });

    testWidgets('★★ 掴んだ位置が違っても判定は変わらない（pointerDragAnchorStrategy）★★',
        (tester) async {
      // ★★ これが D47 の手当てそのもの ★★
      // 指定を外すと DragTargetDetails.offset が feedback の左上になり、
      // **札のどこを掴んだかで上下判定が変わる。**
      final edges = <DropEdge>[];
      await tester.pumpWidget(_wrapped(onDrop: (_, edge) => edges.add(edge)));

      final source = tester.getRect(find.byKey(_sourceKey));
      final target = tester.getRect(find.byKey(_targetKey));
      // ★★ 落とす点は中央のすぐ下（局所 dy = 70 / 高さ 120）★★
      //   ここでないと検知できない。dragAnchorStrategy を外すと
      //   details.offset が「ポインタ − 掴んだ位置」になるので、
      //   掴んだ位置の差（6 と 54）が中央 60 をまたぐ点でだけ答えが割れる。
      //   端で落とすと両方とも同じ答えになり、**外しても通るテスト**になる。
      final dropAt = Offset(target.center.dx, target.top + 70);

      // 行の左上寄りを掴む / 右下寄りを掴む。落とす点は同じ。
      await _drag(
        tester,
        from: Offset(source.left + 6, source.top + 6),
        to: dropAt,
      );
      await _drag(
        tester,
        from: Offset(source.right - 6, source.bottom - 6),
        to: dropAt,
      );

      expect(edges, [DropEdge.trailing, DropEdge.trailing]);
    });

    testWidgets('★どちらの意味で落ちるかを乗っている間に出す（出さないと気づけない）',
        (tester) async {
      await tester.pumpWidget(_wrapped(onDrop: (_, _) {}));

      final source = _padding(tester, _sourceKey);
      final target = tester.getRect(find.byKey(_targetKey));

      final gesture = await tester.startGesture(source);
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump();

      await gesture.moveTo(Offset(target.center.dx, target.top + 10));
      await tester.pump();
      expect(find.text('手前に入る'), findsOneWidget);

      await gesture.moveTo(Offset(target.center.dx, target.bottom - 10));
      await tester.pump();
      expect(find.text('後ろに入る'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // ★落としたあとは消える（出しっぱなしにしない）。
      expect(find.text('ここへ'), findsOneWidget);
    });
  });

  testWidgets('★accepts が false のものは受け取らないし、帯も出さない', (tester) async {
    var dropped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                key: _sourceKey,
                width: 300,
                height: 60,
                child: CardDragSource<String>(
                  data: 'card',
                  background: Colors.white,
                  feedback: const SizedBox(width: 40, height: 56),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(children: [Text('行')]),
                  ),
                ),
              ),
              SizedBox(
                key: _targetKey,
                width: 300,
                height: 120,
                child: CardDropTarget<String>(
                  background: Colors.grey,
                  accepts: (_) => false,
                  onDrop: (_, _) => dropped = true,
                  builder: (context, hovering) =>
                      Text(hovering == null ? 'ここへ' : '入る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await _drag(
      tester,
      from: _padding(tester, _sourceKey),
      to: tester.getCenter(find.byKey(_targetKey)),
    );

    expect(dropped, isFalse);
    expect(find.text('ここへ'), findsOneWidget);
  });
}
