/// 合成ポインタでドラッグを再現する.
///
/// ★手で操作した印象だけでは記録に残せない★
/// `docs/UI技術検証メモ.md` に「なめらかだった」としか書けないと、
/// Phase 3b でやり直すときに比較できない。`GestureBinding` へ直接
/// ポインタ列を流し込み、同じ操作を毎回同じ速度で再現して測る。
///
/// テスト用のヘルパ（`WidgetTester.drag`）は `flutter_test` のもので
/// 実アプリからは使えないため、最小限を自前で持つ。
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class SyntheticPointer {
  SyntheticPointer({this.pointer = 7001, this.kind = PointerDeviceKind.mouse});

  final int pointer;
  final PointerDeviceKind kind;

  Offset _position = Offset.zero;
  Offset get position => _position;

  void down(Offset at) {
    _position = at;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        kind: kind,
        position: at,
        buttons: kPrimaryButton,
      ),
    );
  }

  void moveBy(Offset delta) {
    final next = _position + delta;
    GestureBinding.instance.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        kind: kind,
        position: next,
        delta: delta,
        buttons: kPrimaryButton,
      ),
    );
    _position = next;
  }

  /// [target] まで [steps] 回に分けて動かす。1 ステップごとに 1 フレーム待つ。
  Future<void> moveTo(Offset target, {int steps = 40}) async {
    final start = _position;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final next = Offset.lerp(start, target, t)!;
      moveBy(next - _position);
      await SchedulerBinding.instance.endOfFrame;
    }
  }

  void up() {
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: pointer, kind: kind, position: _position),
    );
  }

  void cancel() {
    GestureBinding.instance.handlePointerEvent(
      PointerCancelEvent(pointer: pointer, kind: kind, position: _position),
    );
  }

  /// 押す → 動かす → 離す、を 1 回。
  ///
  /// `Draggable` は既定で `ImmediateMultiDragGestureRecognizer` を使うので、
  /// 押した直後に少し動かすとドラッグが始まる。
  /// [holdMs] は押した位置で止まっている時間。
  /// `LongPressDraggable` は既定 500 ms 押し続けないと始まらないので、
  /// これを 0 のままにすると「長押し方式は動かない」という誤った結論が出る。
  Future<void> dragFromTo(
    Offset from,
    Offset to, {
    int steps = 40,
    int settleFrames = 6,
    int holdMs = 0,
  }) async {
    down(from);
    await SchedulerBinding.instance.endOfFrame;
    if (holdMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: holdMs));
    }
    await moveTo(to, steps: steps);
    up();
    for (var i = 0; i < settleFrames; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
  }
}

/// ある画面座標の真下にある RenderObject を並べる。
///
/// ★「ドラッグが始まらない」の原因切り分けに要る★
/// 掴めていないのか落とせていないのかは、押した点に何があるかを見ないと分からない。
List<String> hitTestAt(Offset position) {
  final result = HitTestResult();
  GestureBinding.instance.hitTestInView(
    result,
    position,
    WidgetsBinding.instance.platformDispatcher.views.first.viewId,
  );
  return [
    for (final entry in result.path)
      entry.target.runtimeType.toString(),
  ];
}

/// ウィジェットの画面上の中心座標を求める。合成ポインタの行き先に使う。
Offset? centerOfKey(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final box = ctx.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// ウィジェットの画面上の矩形。
Rect? rectOfKey(GlobalKey key) {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final box = ctx.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
