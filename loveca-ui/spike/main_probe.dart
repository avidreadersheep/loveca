/// Step 1: sqlite3 の Flutter 経路の疎通確認.
///
/// ★ここが通らなければ以降の試作は成立しない★
/// 確かめるのは 4 点。
///   1. ビルドフック（native assets）で調達した sqlite3 が Flutter の Windows
///      ビルドにバンドルされ、FTS5 / trigram が使えるか
///   2. `NativeDatabase.createInBackground` が生む**別 isolate**からも同じ
///      ネイティブライブラリを解決できるか
///   3. 実 dist を取り込んで 1,708 種 / 2,527 刷りになるか
///   4. dist の thumb（WebP）が Windows でデコードできるか
///
/// ```bash
/// flutter run -d windows -t spike/main_probe.dart
/// ```
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:loveca_db/loveca_db.dart';

import 'common/metrics.dart';
import 'common/spike_db.dart';

void main() {
  runApp(const ProbeApp());
}

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / probe',
        theme: ThemeData(useMaterial3: true),
        home: const ProbePage(),
      );
}

typedef ProbeLine = (String label, String value, bool? pass);

class ProbeResult {
  ProbeResult(this.lines, this.sampleThumb, this.ok);

  final List<ProbeLine> lines;
  final String? sampleThumb;
  final bool ok;
}

class ProbePage extends StatefulWidget {
  const ProbePage({super.key});

  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  late final Future<ProbeResult> _future = _run();

  Future<ProbeResult> _run() async {
    final lines = <ProbeLine>[];
    String? thumb;
    var ok = true;

    void add(String k, String v, [bool? pass]) {
      lines.add((k, v, pass));
      if (pass == false) ok = false;
    }

    add('Directory.current', Directory.current.path);
    add('resolvedExecutable', Platform.resolvedExecutable);

    final opened = await openSpikeDatabase();
    final paths = opened.paths;
    final db = opened.db;

    add('repoRoot', paths.repoRoot.path, paths.repoRoot.existsSync());
    add('dist', paths.distDir.path, paths.distExists);
    add('cache(DB)', paths.dbFile.path);

    // --- 1. ネイティブ sqlite3 の能力 ---
    final caps = opened.capabilities;
    add('sqlite3 version', caps.version);
    add('FTS5', caps.hasFts5.toString(), caps.hasFts5);
    add('trigram', caps.hasTrigram.toString(), caps.hasTrigram);

    // --- 2. 別 isolate から同じライブラリが引けるか ---
    add(
      'executor',
      opened.usedBackgroundIsolate
          ? 'NativeDatabase.createInBackground (別 isolate)'
          : 'openFileExecutor (UI isolate)',
    );
    try {
      // このクエリは executor 経由なので、背景 isolate 側で FTS5 の
      // 仮想テーブルに触ることになる。通れば DLL がそちらでも解決できている。
      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM card_search')
          .getSingle();
      add('card_search への問い合わせ', '成功 (${row.read<int>('c')} 行)', true);
    } catch (e) {
      add('card_search への問い合わせ', '失敗: $e', false);
    }

    // --- 3. 実データの取り込み ---
    add('この起動で取り込んだか', opened.didImport ? 'はい (コールド)' : 'いいえ (既存 DB を再利用)');
    add('DB を開くまで', '${opened.openMillis} ms');
    if (opened.didImport) {
      add('取り込み', '${opened.importMillis} ms');
    }
    if (opened.importError != null) {
      add('取り込みエラー', opened.importError.toString(), false);
    }
    final r = opened.importResult;
    if (r != null) {
      add('decision', r.decision.toString());
      add('dataVersion', '${r.dataVersion} (advanced=${r.dataVersionAdvanced})');
      add('failedPaths', r.failedPaths.toString(), r.failedPaths.isEmpty);
      add('unhandledPaths', r.unhandledPaths.toString(),
          r.unhandledPaths.isEmpty);
    }

    final cardDao = CardDao(db);
    final cardCount = await cardDao.cardCount();
    final printings = await cardDao.printingsById();
    add('cards (cardNumber の種類)', '$cardCount / 期待 1708', cardCount == 1708);
    add('printings (刷り)', '${printings.length} / 期待 2527',
        printings.length == 2527);

    final indexed = await CardSearchDao(db).indexedCount();
    add('検索索引', '$indexed / 期待 1708', indexed == 1708);

    // --- 4. thumb (WebP) が読めるか ---
    final withImage =
        printings.values.where((p) => p.imageHash.isNotEmpty).toList();
    add('imageHash を持つ刷り', '${withImage.length} / ${printings.length}',
        withImage.isNotEmpty);
    if (withImage.isNotEmpty) {
      final candidate = paths.thumbPath(withImage.first.imageHash);
      final exists = File(candidate).existsSync();
      add('thumb の実ファイル', candidate, exists);
      if (exists) {
        thumb = candidate;
        // ★画面表示だけだと非対話実行で真偽を確認できない★
        //   実際にデコードして寸法を取り、WebP が Windows で扱えることを数値で残す。
        try {
          final bytes = await File(candidate).readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final img = frame.image;
          add(
            'thumb の WebP デコード',
            '${img.width}x${img.height} / ファイル ${bytes.length} B / '
                'デコード後 約 ${(img.width * img.height * 4 / 1024).round()} KiB',
            true,
          );
          img.dispose();
          codec.dispose();
        } catch (e) {
          add('thumb の WebP デコード', '失敗: $e', false);
        }
      }
    }

    // --- 検索が実際に引けるか (trigram / LIKE 両経路) ---
    for (final q in ['スクール', '花帆']) {
      final res = await CardSearchDao(db).search(q);
      add('検索 $q', '${res.length} 件 / mode=${res.mode.name}', !res.isEmpty);
    }

    final report = StringBuffer()
      ..writeln('# spike / probe — sqlite3 の Flutter 経路')
      ..writeln()
      ..writeln(environmentHeading())
      ..writeln()
      ..writeln('判定: ${ok ? "全項目 OK" : "★不合格の項目がある★"}')
      ..writeln()
      ..writeln('| | 項目 | 値 |')
      ..writeln('|---|---|---|');
    for (final (label, value, pass) in lines) {
      final mark = pass == null ? '' : (pass ? 'OK' : '**NG**');
      report.writeln('| $mark | $label | `$value` |');
    }
    writeSpikeReport('01_probe', report.toString());

    if (spikeAutoExit) {
      Future<void>.delayed(const Duration(milliseconds: 300),
          () => exit(ok ? 0 : 1));
    }
    return ProbeResult(lines, thumb, ok);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: const Text('spike / probe - sqlite3 の Flutter 経路')),
        body: FutureBuilder<ProbeResult>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  '★致命的な失敗★\n\n${snap.error}\n\n${snap.stackTrace}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final result = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  color: result.ok ? Colors.green.shade100 : Colors.red.shade100,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    result.ok ? '全項目 OK' : '★不合格の項目がある★',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final line in result.lines)
                              _ProbeRow(line: line),
                          ],
                        ),
                      ),
                      if (result.sampleThumb != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              const Text('thumb (WebP)'),
                              const SizedBox(height: 8),
                              Image.file(
                                File(result.sampleThumb!),
                                width: 200,
                                errorBuilder: (_, e, _) => Text(
                                  'デコード失敗\n$e',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
}

class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.line});

  final ProbeLine line;

  @override
  Widget build(BuildContext context) {
    final (label, value, pass) = line;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: pass == null
                ? const Text('・')
                : Icon(
                    pass ? Icons.check : Icons.close,
                    size: 16,
                    color: pass ? Colors.green : Colors.red,
                  ),
          ),
          SizedBox(
            width: 230,
            child:
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
