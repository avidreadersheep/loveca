/// ★★ 画像キャッシュの見積りを★★実データで測り直す★★（★**W-34** / `docs/UI技術検証メモ.md` §3-3）★★
///
/// ★★ なぜ `main_grid.dart` では足りないか ★★
/// ★**あちらは★★リポジトリの現物を★ファイルシステムから探す★★**（`common/paths.dart` の `_findRepoRoot`）。
/// → ★**Windows の開発機でしか走らない。★★Android では★根が無い★★**（`main_sqlite_caps.dart` と同じ理由）。
/// ★**あちらは★DB も開く**（`common/spike_db.dart`）。★**この試作は★DB を 1 バイトも触らない。**
///
/// ★★ 何を測るか —— ★★1 枚あたりのバイト数と、★何枚載るか★★ ★★
/// ★`docs/UI技術検証メモ.md` §3-3 は★**PC で「1 枚 約 74 KB / 1000 枚」**と測った。
/// ★**その測定条件は★★セル 120 物理px★★である**（`docs/UI設計メモ.md` §9-7）。
/// ★**モバイルでは★セルの物理幅が違う**（**W-24** の実測 —— ★★339 物理px★★）。
/// → ★**同じ規則で★もう一度測る。**
///
/// ★★ スクロールしない。★★解決を数える★★ ★★
/// ★**§3-3 は★スクロールして測った。★★この試作は `ImageProvider.resolve` を 1 枚ずつ待つ★★。**
/// ★**理由**: ★★スクロールの速さは★デコードが間に合うかを測る道具であって★（§3-4）、
///   ★★1 枚あたりのバイト数を測る道具ではない★★。★待てば★★機械の速さに依らない★★。
/// ★**同じ `imageCache` に載る** —— ★`resolve` は `imageCache.putIfAbsent` を通る（★実読）。
///
/// ★★ 本番の口を通す（**D-27** の (甲)）★★
/// ★`LocalDirectoryCardImageSource.provider` と `CardGrid` の寸法の規則を★★呼ぶ★★。
/// ★**写し取らない** —— ★写すと★★本番が変わっても測定だけが古いまま残る★★（★`spike/` は静かに腐る / **D51**）。
///
/// ★★ 走らせ方（★★dist を置く経路そのものが **W-34** の中身である★★）★★
///
/// ```bash
/// # ★Windows —— ★★陽性対照。★§3-3 の値を再現できるかを見る★★
/// flutter build windows --debug -t spike/main_image_cache.dart \
///   --dart-define=LOVECA_DIST_DIR=C:/Users/hiimo/loveca/loveca-data/data/dist \
///   --dart-define=SPIKE_AUTOEXIT=1
/// ./build/windows/x64/runner/Debug/loveca_ui.exe > cache.txt 2>&1
///
/// # ★Android —— ★★dist を先に置く★★
/// #   ★★`/sdcard/Android/data/<pkg>/files/` は★★アプリから読めない★★（Permission denied / errno 13。
/// #     ★2026-09-02 実測 / API 36）。★★アプリ専有の内部領域へ `run-as` で写すこと★★。
/// adb push <dist の各段> /data/local/tmp/lovecadist/...
/// adb shell chmod -R a+rX /data/local/tmp/lovecadist
/// adb shell run-as com.example.loveca_ui cp -r /data/local/tmp/lovecadist /data/data/com.example.loveca_ui/files/dist
/// adb shell rm -rf /data/local/tmp/lovecadist
/// flutter build apk --debug -t spike/main_image_cache.dart \
///   --dart-define=LOVECA_DIST_DIR=/data/data/com.example.loveca_ui/files/dist \
///   --dart-define=SPIKE_AUTOEXIT=1
/// adb install -r build/app/outputs/flutter-apk/app-debug.apk
/// adb logcat -c && adb shell am start -n com.example.loveca_ui/.MainActivity
/// adb logcat -d | grep IMAGE_CACHE
/// ```
///
/// ★★ 出力の前置は `IMAGE_CACHE` である ★★
/// ★`adb logcat` は★他の行を大量に混ぜるので、★★1 つの語で抜けること★★が要る。
///
/// ★★ 実測は★ここに書かない。★正は `docs/UI技術検証メモ.md` §3-3-2 である ★★
/// ★**同じ数を 2 か所に書けば必ず食い違う**（**D-15** の規約 3）。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loveca_ui/src/data/card_image_source.dart';
import 'package:loveca_ui/src/ui/browse/card_grid.dart';
import 'package:path/path.dart' as p;

const String _distDefine = String.fromEnvironment('LOVECA_DIST_DIR');
const String _autoExit = String.fromEnvironment('SPIKE_AUTOEXIT');

/// ★どこで区切って報告するか。★**追い出しが始まる点を跨ぐように取る。**
const List<int> _checkpoints = <int>[100, 200, 400, 800, 1200, 1600, 2000, 2527];

void _say(String line) => debugPrint('IMAGE_CACHE $line');

void main() {
  // ★★ 既定の `debugPrint` は★★流量を絞る★★（`debugPrintThrottled`）★★
  //   ★**絞られた行は★★キューに残り、★`exit(0)` で失われる★★**（★2026-09-02 実測 ——
  //     ★Windows で★10 行しか出ず、★測定の後半が丸ごと消えた —— ★★実測★★）。
  //   → ★**同期に出す。★★測定の出力を落とさない★★**（**D-34** の作法 —— ★出力を切らない）。
  debugPrint = debugPrintSynchronously;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _App());
}

class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  String _status = '測っている…';

  bool _started = false;

  /// ★★ 幅は★★レイアウトから受け取る。★`platformDispatcher` から取らない★★ ★★
  /// ★**Android では★最初のフレームの時点で `physicalSize` が★★0x0 である★★**
  ///   （★2026-09-02 実測 —— ★★`columns=1 / cellLogical=-12` という嘘の値が出た★★）。
  /// ★**本番の `CardGrid` も★`LayoutBuilder` の制約から受け取る**（★実読）。
  ///   → ★**同じ受け取り方にする**（**D-27** の (甲)）。
  void _startOnce(double logicalWidth, double dpr) {
    if (_started || logicalWidth <= 0) return;
    _started = true;
    unawaited(_run(logicalWidth, dpr));
  }

  Future<void> _run(double logicalWidth, double dpr) async {
    // ★★ セルの寸法は `CardGrid` の規則を★★呼ぶ★★（★写さない）★★
    final crossAxisCount =
        (logicalWidth / CardGrid.maxCellExtent).ceil().clamp(1, 100);
    final cellLogical =
        (logicalWidth - CardGrid.spacing * (crossAxisCount + 1)) /
            crossAxisCount;
    final cellPhysical = (cellLogical * dpr).round();

    _say('platform=${Platform.operatingSystem} '
        'logicalWidth=${logicalWidth.toStringAsFixed(2)} dpr=$dpr');
    _say('grid columns=$crossAxisCount cellLogical='
        '${cellLogical.toStringAsFixed(2)} cellPhysical=$cellPhysical '
        'maxCellExtent=${CardGrid.maxCellExtent} spacing=${CardGrid.spacing}');

    if (_distDefine.isEmpty) {
      _say('ERROR dist が渡されていない（--dart-define=LOVECA_DIST_DIR=...）');
      _finish('dist が渡されていない');
      return;
    }
    final imagesRoot = Directory(p.join(_distDefine, 'images'));
    if (!imagesRoot.existsSync()) {
      _say('ERROR images が無い: ${imagesRoot.path}');
      _finish('images が無い: ${imagesRoot.path}');
      return;
    }

    final source = LocalDirectoryCardImageSource(imagesRoot);
    final cache = PaintingBinding.instance.imageCache;
    _say('cache maximumSize=${cache.maximumSize} '
        'maximumSizeBytes=${cache.maximumSizeBytes}');

    for (final size in CardImageSize.values) {
      final dir = Directory(p.join(imagesRoot.path, size.directoryName));
      if (!dir.existsSync()) {
        _say('${size.name} SKIP 段が無い: ${dir.path}');
        continue;
      }
      final hashes = <String>[
        for (final f in dir.listSync().whereType<File>())
          if (p.extension(f.path) == '.webp') p.basenameWithoutExtension(f.path),
      ]..sort();
      // ★★ 本番が渡す値そのもの（`CardThumb` は cacheWidthPx = 論理幅 × DPR を渡す）★★
      //   ★段の中で `min(cacheWidthPx, 原寸)` に切られる。★それも本番の中で起きる。
      final decodeWidth =
          cellPhysical < size.sourceWidth ? cellPhysical : size.sourceWidth;
      _say('${size.name} files=${hashes.length} sourceWidth=${size.sourceWidth} '
          'cacheWidthPx=$cellPhysical decodeWidth=$decodeWidth');

      cache.clear();
      cache.clearLiveImages();
      var done = 0;
      for (final hash in hashes) {
        final provider = source.provider(hash, size, cacheWidthPx: cellPhysical);
        if (provider == null) continue;
        await _resolve(provider);
        done++;
        if (_checkpoints.contains(done)) {
          _report(size.name, done);
        }
      }
      _report('${size.name} FINAL', done);
      cache.clear();
      cache.clearLiveImages();
    }

    _say('DONE');
    _finish('終わった');
  }

  void _report(String label, int resolved) {
    final cache = PaintingBinding.instance.imageCache;
    final count = cache.currentSize;
    final bytes = cache.currentSizeBytes;
    final per = count == 0 ? 0 : bytes ~/ count;
    _say('$label resolved=$resolved count=$count bytes=$bytes '
        '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MiB) perImage=$per '
        '(${(per / 1024).toStringAsFixed(1)} KiB) live=${cache.liveImageCount}');
  }

  /// ★1 枚を解決し、★最初のフレームが届くまで待つ。
  ///
  /// ★★ 参照を離す ★★
  /// ★**離さないと★★live に留まって追い出しが起きない★★** ——
  ///   ★`ImageCache` は live の分を `currentSize` の外で持つ（★実読）。
  Future<void> _resolve(ImageProvider provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (image, sync) {
        image.dispose();
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (error, stack) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  void _finish(String status) {
    setState(() => _status = status);
    if (_autoExit == '1') {
      Future<void>.delayed(const Duration(seconds: 2), () => exit(0));
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              // ★★ 本番と同じ受け取り方（`CardGrid` は `LayoutBuilder` の中に居る）★★
              _startOnce(
                constraints.maxWidth,
                MediaQuery.devicePixelRatioOf(context),
              );
              return Center(child: Text(_status));
            },
          ),
        ),
      );
}
