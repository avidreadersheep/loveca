/// 検索コストの改善案 3 つを、実装せずに比較するための計測.
///
/// ★`loveca_db` は一切変更していない★
/// 現行の索引と DB はそのまま使い、
///   - 現行と同じ SQL をこちら側から投げて内訳を測る
///   - 別案は「その案なら走るはずの SQL / 処理」を同じデータに対して走らせる
///   - 索引の形が変わる案（C）は、メモリ上に別の索引を建てて比べる
/// という形にしてある。判断材料を出すためだけのもので、採用はまだしていない。
///
/// 測る対象は `CardSearchDao.search` の trigram 経路。
/// 実測で全体の 70〜90% が `_resolveCardNumbers` の
/// `SELECT * FROM cards`（1,708 行）だった（docs/UI技術検証メモ.md §4-1）。
///
/// ```bash
/// flutter build windows --profile -t spike/main_search_variants.dart
/// SPIKE_AUTOEXIT=1 ./build/windows/x64/runner/Profile/loveca_ui.exe
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
// ★Flutter の Card ウィジェットと名前がぶつかるので別名で入れる。
import 'package:loveca_core/loveca_core.dart' as core;
import 'package:loveca_db/loveca_db.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import 'common/metrics.dart';
import 'common/spike_db.dart';

void main() => runApp(const VariantsApp());

class VariantsApp extends StatelessWidget {
  const VariantsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / search variants',
        theme: ThemeData(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const VariantsPage(),
      );
}

/// 計測に使う語。trigram 経路（3 文字以上）だけを対象にする。
/// ヒット件数の幅を持たせて、件数依存があるかも見る。
const _queries = <String>[
  'ドロー', // 7 種
  'スクール', // 18 種
  'ハート', // 150 種
  'ブレード', // 254 種
  'ライブ', // 500 種以上
  'アクティブ状態', // 10 種
];

class VariantsPage extends StatefulWidget {
  const VariantsPage({super.key});

  @override
  State<VariantsPage> createState() => _VariantsPageState();
}

class _VariantsPageState extends State<VariantsPage> {
  final StringBuffer _report = StringBuffer();
  final List<String> _log = [];
  String _status = '起動中…';

  void _note(String line) {
    _log.add(line);
    stdout.writeln('[variants] $line');
  }

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  static int _median(List<int> xs) {
    if (xs.isEmpty) return 0;
    final s = [...xs]..sort();
    return s[s.length ~/ 2];
  }

  static String _ms(int us) => (us / 1000).toStringAsFixed(2);

  Future<void> _run() async {
    final opened = await openSpikeDatabase();
    final db = opened.db;
    if (opened.importError != null) {
      setState(() => _status = '★${opened.importError}');
      return;
    }

    final cards = await CardDao(db).cardsByNumber();
    setState(() => _status = '${cards.length} 種');

    _report
      ..writeln('# 検索コスト改善案の比較（実装はしていない）')
      ..writeln()
      ..writeln(environmentHeading())
      ..writeln()
      ..writeln('カード ${cards.length} 種。'
          'trigram 経路のみを対象とする。各値は 7 回の中央値。')
      ..writeln();

    await _checkFoldCollisions(cards);
    await _measureOnRealDb(db, cards);
    _measureIndexShapes(cards);

    writeSpikeReport('06_search_variants', _report.toString());
    if (spikeAutoExit) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
    setState(() => _status = '完了');
  }

  // ---------------------------------------------------------------------------
  // 前提の確認: fold は cardNumber 上で単射か
  // ---------------------------------------------------------------------------

  /// ★`_resolveCardNumbers` は `{fold(cardNumber): cardNumber}` を作る★
  /// 2 つの cardNumber が同じ値へ畳まれると、**片方が黙って消える**。
  /// 案 A / B もこの写像に乗るので、成立の前提として先に確かめる。
  Future<void> _checkFoldCollisions(Map<String, core.Card> cards) async {
    final byFolded = <String, List<String>>{};
    for (final n in cards.keys) {
      (byFolded[fold(n)] ??= []).add(n);
    }
    final collisions =
        byFolded.entries.where((e) => e.value.length > 1).toList();

    _report
      ..writeln('## 前提: `fold` は cardNumber 上で単射か')
      ..writeln()
      ..writeln('`_resolveCardNumbers` は `{fold(cardNumber): cardNumber}` を作るため、'
          '衝突すると片方が黙って消える。')
      ..writeln()
      ..writeln('- cardNumber ${cards.length} 種 → 折りたたみ後 ${byFolded.length} 種')
      ..writeln('- **衝突 ${collisions.length} 件**');
    for (final c in collisions.take(10)) {
      _report.writeln('  - `${c.key}` ← ${c.value.join(" / ")}');
    }
    _report.writeln();
    _note('fold 衝突: ${collisions.length} 件');
  }

  // ---------------------------------------------------------------------------
  // 実 DB 上での内訳と、各案の復元コスト
  // ---------------------------------------------------------------------------

  Future<void> _measureOnRealDb(
    LovecaDatabase db,
    Map<String, core.Card> cards,
  ) async {
    const reps = 7;

    // 案 A が持つことになる写像。起動時に 1 度だけ作る想定。
    final buildSw = Stopwatch()..start();
    final foldedToRaw = {for (final n in cards.keys) fold(n): n};
    buildSw.stop();

    _report
      ..writeln('## 実 DB 上の内訳（drift 経由・別 isolate。本番と同じ経路）')
      ..writeln()
      ..writeln('| 語 | ヒット | FTS の MATCH | 現行の復元'
          '（`SELECT * FROM cards`） | 案A 写像引き | 案B `IN (…)` 引き |')
      ..writeln('|---|---:|---:|---:|---:|---:|');

    final ftsAll = <int>[];
    final nowAll = <int>[];
    final aAll = <int>[];
    final bAll = <int>[];

    for (final q in _queries) {
      final folded = fold(q);
      final fts = <int>[];
      final now = <int>[];
      final a = <int>[];
      final b = <int>[];
      var hits = 0;
      List<String> foldedHits = const [];

      for (var i = 0; i < reps; i++) {
        // --- FTS の MATCH だけ ---
        final sw1 = Stopwatch()..start();
        final rows = await db.customSelect(
          'SELECT card_number FROM card_search WHERE card_search MATCH ? '
          'ORDER BY rank LIMIT ?',
          variables: [
            Variable<String>('"${folded.replaceAll('"', '""')}"'),
            Variable<int>(2000),
          ],
        ).get();
        sw1.stop();
        fts.add(sw1.elapsedMicroseconds);
        foldedHits = [for (final r in rows) r.read<String>('card_number')];
        hits = foldedHits.length;

        // --- 現行: cards を全件読んで写像を作り直す ---
        final sw2 = Stopwatch()..start();
        final all = await db.select(db.cards).get();
        final map = {for (final c in all) fold(c.cardNumber): c.cardNumber};
        final resolvedNow = [
          for (final f in foldedHits)
            if (map[f] != null) map[f]!,
        ];
        sw2.stop();
        now.add(sw2.elapsedMicroseconds);

        // --- 案A: 起動時に作った写像を引くだけ ---
        final sw3 = Stopwatch()..start();
        final resolvedA = [
          for (final f in foldedHits)
            if (foldedToRaw[f] != null) foldedToRaw[f]!,
        ];
        sw3.stop();
        a.add(sw3.elapsedMicroseconds);

        // --- 案B: ヒットした分だけ DB へ引きに行く ---
        // ★折りたたみ済み列がまだ無いので、主キー（card_number）への
        //   IN 引きを代理とする。索引を使う点・件数が同じ点で形は同じ。
        final sw4 = Stopwatch()..start();
        if (resolvedNow.isNotEmpty) {
          final placeholders = List.filled(resolvedNow.length, '?').join(',');
          await db.customSelect(
            'SELECT card_number FROM cards WHERE card_number IN ($placeholders)',
            variables: [for (final n in resolvedNow) Variable<String>(n)],
          ).get();
        }
        sw4.stop();
        b.add(sw4.elapsedMicroseconds);

        if (i == 0 && resolvedA.length != resolvedNow.length) {
          _note('★案A と現行で件数が違う: $q');
        }
      }

      ftsAll.add(_median(fts));
      nowAll.add(_median(now));
      aAll.add(_median(a));
      bAll.add(_median(b));

      _report.writeln('| $q | $hits | ${_ms(_median(fts))} ms | '
          '${_ms(_median(now))} ms | ${_ms(_median(a))} ms | '
          '${_ms(_median(b))} ms |');
      _note('$q: hits=$hits fts=${_ms(_median(fts))} '
          'now=${_ms(_median(now))} A=${_ms(_median(a))} B=${_ms(_median(b))}');
    }

    final fts = _median(ftsAll);
    final now = _median(nowAll);
    final a = _median(aAll);
    final b = _median(bAll);

    _report
      ..writeln()
      ..writeln('### 合計の見込み（MATCH + 復元）')
      ..writeln()
      ..writeln('| | 復元の中央値 | 検索 1 回の合計 | 現行比 |')
      ..writeln('|---|---:|---:|---:|')
      ..writeln('| 現行 | ${_ms(now)} ms | **${_ms(fts + now)} ms** | — |')
      ..writeln('| 案A 写像を保持 | ${_ms(a)} ms | **${_ms(fts + a)} ms** | '
          '${((fts + a) / (fts + now) * 100).toStringAsFixed(0)}% |')
      ..writeln('| 案B 折りたたみ列 + `IN` | ${_ms(b)} ms | '
          '**${_ms(fts + b)} ms** | '
          '${((fts + b) / (fts + now) * 100).toStringAsFixed(0)}% |')
      ..writeln('| 案C 索引に生値を持つ | 0（復元が要らない） | '
          '**${_ms(fts)} ms** | '
          '${(fts / (fts + now) * 100).toStringAsFixed(0)}% |')
      ..writeln()
      ..writeln('案A の写像を起動時に 1 度作るコスト: '
          '**${_ms(buildSw.elapsedMicroseconds)} ms**'
          '（`cards` の全件読みは取り込み後に 1 度だけ必要）')
      ..writeln();
  }

  // ---------------------------------------------------------------------------
  // 索引の形の比較（案C の代償）
  // ---------------------------------------------------------------------------

  /// 現行の索引と、生の cardNumber を `UNINDEXED` で足した索引を
  /// それぞれメモリ上に建て、大きさと MATCH の速さを比べる。
  void _measureIndexShapes(Map<String, core.Card> cards) {
    final list = cards.values.toList();

    ({int bytes, int buildUs, int matchUs}) build({required bool withRaw}) {
      final db = raw.sqlite3.openInMemory();
      try {
        final cols = withRaw
            ? 'card_number, name, effect, group_names, unit_names, '
                'card_number_raw UNINDEXED'
            : 'card_number, name, effect, group_names, unit_names';
        db.execute(
          "CREATE VIRTUAL TABLE s USING fts5($cols, tokenize = 'trigram')",
        );
        final ph = withRaw ? '?, ?, ?, ?, ?, ?' : '?, ?, ?, ?, ?';
        final stmt = db.prepare('INSERT INTO s VALUES ($ph)');

        final sw = Stopwatch()..start();
        db.execute('BEGIN');
        for (final c in list) {
          final values = <Object?>[
            fold(c.cardNumber),
            fold(c.name),
            fold(c.effectText),
            foldJoin(c.groupNames),
            foldJoin(c.unitNames),
            if (withRaw) c.cardNumber,
          ];
          stmt.execute(values);
        }
        db.execute('COMMIT');
        sw.stop();
        stmt.close();

        final pageCount =
            db.select('PRAGMA page_count').first.values.first! as int;
        final pageSize =
            db.select('PRAGMA page_size').first.values.first! as int;

        // MATCH の速さ
        final times = <int>[];
        for (final q in _queries) {
          final folded = fold(q).replaceAll('"', '""');
          for (var i = 0; i < 7; i++) {
            final t = Stopwatch()..start();
            db.select(
              'SELECT ${withRaw ? "card_number_raw" : "card_number"} FROM s '
              'WHERE s MATCH ? ORDER BY rank LIMIT 2000',
              ['"$folded"'],
            );
            t.stop();
            times.add(t.elapsedMicroseconds);
          }
        }

        return (
          bytes: pageCount * pageSize,
          buildUs: sw.elapsedMicroseconds,
          matchUs: _median(times),
        );
      } finally {
        db.close();
      }
    }

    final current = build(withRaw: false);
    final withRaw = build(withRaw: true);

    _report
      ..writeln('## 索引の形の比較（案C の代償）')
      ..writeln()
      ..writeln('同じ 1,708 種からメモリ上に索引を建てて比べた。'
          '`UNINDEXED` 列は trigram のトークンを作らないので、'
          '増えるのは保存分だけになるはず——を実測で確かめる。')
      ..writeln()
      ..writeln('| 索引 | 大きさ | 構築 | MATCH（中央値） |')
      ..writeln('|---|---:|---:|---:|')
      ..writeln('| 現行（5 列） | '
          '${(current.bytes / 1024 / 1024).toStringAsFixed(2)} MiB | '
          '${_ms(current.buildUs)} ms | ${_ms(current.matchUs)} ms |')
      ..writeln('| 案C（+ `card_number_raw UNINDEXED`） | '
          '${(withRaw.bytes / 1024 / 1024).toStringAsFixed(2)} MiB | '
          '${_ms(withRaw.buildUs)} ms | ${_ms(withRaw.matchUs)} ms |')
      ..writeln('| 差 | '
          '**+${((withRaw.bytes - current.bytes) / 1024).toStringAsFixed(0)} KiB '
          '(+${((withRaw.bytes / current.bytes - 1) * 100).toStringAsFixed(1)}%)** | '
          '+${_ms(withRaw.buildUs - current.buildUs)} ms | '
          '${withRaw.matchUs >= current.matchUs ? "+" : ""}'
          '${_ms(withRaw.matchUs - current.matchUs)} ms |')
      ..writeln();
    _note('索引: 現行 ${(current.bytes / 1024 / 1024).toStringAsFixed(2)} MiB / '
        '案C ${(withRaw.bytes / 1024 / 1024).toStringAsFixed(2)} MiB');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('spike / search variants — $_status')),
        body: Container(
          color: Colors.black87,
          padding: const EdgeInsets.all(8),
          child: ListView(
            reverse: true,
            children: [
              for (final line in _log.reversed)
                Text(line,
                    style: const TextStyle(
                        color: Colors.greenAccent, fontSize: 12)),
            ],
          ),
        ),
      );
}
