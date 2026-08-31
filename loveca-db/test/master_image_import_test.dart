/// 画像の取り込みと削除の振り分け
/// （決定 **D121-1** ＝ 画-5 / `docs/同期設計メモ.md` §32-6 の 7）.
///
/// ★★ ここが埋めるもの ★★
/// - 事実 い: 取り込みの振り分けは `cards/` と 3 つのメタしか扱わず、
///   画像の path は **未対応** に落ちていた。
/// - 事実 う: 削除の振り分けは `cards/` しか見ず、計画が「消せ」と言っても
///   画像に対しては **何もせずに戻って** いた。
///
/// ★★ 置き場は決めない（門 キ / **N-1**）★★
/// この層が持つのは「どれを取り、どれを消すか」と「バイト列を渡す」までである。
/// ★保存先は呼び出し側が [MasterImageSink] として渡す。
/// ★渡さなければ **今までどおり未対応** に落ちる —— 置き場が決まっていないことで
/// 取り込み全体が止まる形にしない。
library;

import 'dart:convert';

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

final _t0 = DateTime.utc(2026, 8, 31, 12);

/// ★UTF-8 として復号できないバイト列（WebP の実物と同じ性質）。
const _webp = <int>[0x52, 0x49, 0x46, 0x46, 0xFF, 0xFE, 0x00, 0x80];
const _webp2 = <int>[0x52, 0x49, 0x46, 0x46, 0xFF, 0xFE, 0x01, 0x81];

/// 保存先の記録だけを取る。★置き場は決めない（門 キ）。
class _RecordingSink implements MasterImageSink {
  final List<(String, List<int>)> written = [];
  final List<String> deleted = [];

  /// ★書き込みを失敗させる（隔離の検査に使う）。
  Object? failWriteFor;

  @override
  Future<void> write(String path, List<int> bytes) async {
    if (path == failWriteFor) throw StateError('書けません: $path');
    written.add((path, bytes));
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}

/// 最小の配信物。★カードもメタも 0 件でよい（見たいのは画像の経路である）。
class _Dist {
  final Map<String, String> texts = {};
  final Map<String, List<int>> binaries = {};
  final List<ManifestFile> imageFiles = [];

  void image(String path, List<int> bytes, String hash) {
    binaries[path] = bytes;
    imageFiles.removeWhere((f) => f.path == path);
    imageFiles.add(ManifestFile(path: path, hash: hash, bytes: bytes.length));
  }

  void dropImage(String path) {
    binaries.remove(path);
    imageFiles.removeWhere((f) => f.path == path);
  }

  VersionInfo get version => const VersionInfo(
        dataVersion: 2,
        minAppVersion: '0.0.0',
        manifestPath: '/data/manifest.json',
        manifestHash: 'sha256:m',
        imageManifestPath: '/data/image_manifest.json',
        imageManifestHash: 'sha256:i',
      );

  Manifest get manifest => const Manifest(dataVersion: 2, files: []);

  Manifest get imageManifest => Manifest(dataVersion: 0, files: imageFiles);

  MapMasterFileSource get source =>
      MapMasterFileSource(Map.of(texts), binaries: Map.of(binaries));
}

void main() {
  late LovecaDatabase db;
  late MasterImporter importer;
  late MasterStateDao state;

  setUp(() {
    db = LovecaDatabase(openInMemoryExecutor());
    importer = MasterImporter(db);
    state = MasterStateDao(db);
  });
  tearDown(() => db.close());

  /// ★★ `noImageManifest` を **別の引数** にしてある ★★
  ///   最初は `Manifest? imageManifest` に `null` を渡す形にしていたが、
  ///   `imageManifest ?? dist.imageManifest` の `??` が **黙って実物に
  ///   すり替えて** いた。★「マニフェストが無ければ 1 件も消さない」を
  ///   壊しても **1 件も落ちなかった**（実測）。
  ///   → ★対を置いても対象を見ていないことがある（**D-27**）。
  Future<MasterImportResult> run(
    _Dist dist, {
    MasterImageSink? sink,
    Manifest? imageManifest,
    bool noImageManifest = false,
    MapMasterFileSource? source,
  }) =>
      importer.import(
        remoteVersion: dist.version,
        remoteManifest: dist.manifest,
        remoteImageManifest:
            noImageManifest ? null : (imageManifest ?? dist.imageManifest),
        imageSink: sink,
        source: source ?? dist.source,
        appVersion: '1.0.0',
        now: _t0,
      );

  group('★★ 画像が取り込まれる（決定 D121-1 の受け取り側 3／4）★★', () {
    test('★★ バイト列が 1 バイトも変わらずに保存先へ渡る ★★', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      final sink = _RecordingSink();

      final result = await run(dist, sink: sink);

      expect(sink.written, hasLength(1));
      expect(sink.written.single.$1, 'images/thumb/aaaa.webp');
      expect(sink.written.single.$2, _webp);
      expect(result.importedPaths, ['images/thumb/aaaa.webp']);
    });

    test('★★ 対: そのバイト列はテキストにすると元に戻らない ★★', () {
      // ★「バイト列で運んでいる」の対。★文字列経由の実装でも通る検査に
      //   しないための土台である（`ルール整合性チェック_v1.06.md` **D-27**）。
      expect(() => utf8.decode(_webp), throwsA(anything));
    });

    test('★2 回目は取り込まない（ハッシュが同じ）', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());

      final second = _RecordingSink();
      final source = dist.source;
      final result = await run(dist, sink: second, source: source);

      expect(second.written, isEmpty);
      expect(source.readPaths, isEmpty, reason: '読みにも行かない');
      expect(result.skippedPaths, contains('images/thumb/aaaa.webp'));
    });

    test('★対: ハッシュが変われば取り込み直す', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());

      dist.image('images/thumb/aaaa.webp', _webp2, 'sha256:2');
      final second = _RecordingSink();
      await run(dist, sink: second);

      expect(second.written.single.$2, _webp2);
    });
  });

  group('★★ 画像が消される（事実 う）★★', () {
    test('★配信側から消えた画像は保存先からも消える', () async {
      final dist = _Dist()
        ..image('images/thumb/aaaa.webp', _webp, 'sha256:1')
        ..image('images/thumb/bbbb.webp', _webp2, 'sha256:2');
      await run(dist, sink: _RecordingSink());

      dist.dropImage('images/thumb/bbbb.webp');
      final sink = _RecordingSink();
      final result = await run(dist, sink: sink);

      expect(sink.deleted, ['images/thumb/bbbb.webp']);
      expect(result.deletedPaths, ['images/thumb/bbbb.webp']);
      // ★対: 残っているほうは消さない。
      expect(sink.deleted, isNot(contains('images/thumb/aaaa.webp')));
    });

    test('★消したら記録も消える（次回また取り込める）', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());
      dist.dropImage('images/thumb/aaaa.webp');
      await run(dist, sink: _RecordingSink());

      dist.image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      final third = _RecordingSink();
      await run(dist, sink: third);
      expect(third.written, hasLength(1));
    });
  });

  group('★★ 「まだ無い」と「0 枚である」を混ぜない ★★', () {
    test('★★ マニフェストが無ければ 1 件も消さない ★★', () async {
      // ★★これがこの commit で最も危ない経路である★★ ——
      //   空として扱うと「取り込み済みの画像を全部消せ」という計画になる。
      //   ★生成側は `--skip-images` のとき **書かない**（列も出さない）ので、
      //   この状態は実際に作れる。
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());

      final sink = _RecordingSink();
      final result = await run(dist, sink: sink, noImageManifest: true);

      expect(sink.deleted, isEmpty);
      expect(result.deletedPaths, isEmpty);
      expect(sink.written, isEmpty);
    });

    test('★対: 空のマニフェストなら消す（★宣言が「0 枚」である）', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());

      final sink = _RecordingSink();
      await run(dist,
          sink: sink, imageManifest: const Manifest(dataVersion: 0, files: []));

      expect(sink.deleted, ['images/thumb/aaaa.webp'],
          reason: '「0 枚である」と宣言されたなら消す。「まだ無い」とは別である');
    });
  });

  group('★★ 保存先が無ければ今までどおり（門 キ / N-1）★★', () {
    test('★未対応として扱い、取り込み全体は止まらない', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      final result = await run(dist);

      expect(result.decision, UpdateDecision.update);
      expect(result.unhandledPaths, isEmpty,
          reason: '計画そのものを立てないので「未対応」にも数えない');
      expect(result.importedPaths, isEmpty);
      expect(result.deletedPaths, isEmpty);
    });

    test('★対: 保存先を渡せば取り込む（同じ配信物・同じ呼び出し）', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      final sink = _RecordingSink();
      final result = await run(dist, sink: sink);
      expect(result.importedPaths, ['images/thumb/aaaa.webp']);
      expect(sink.written, hasLength(1));
    });
  });

  group('★★ 1 枚の失敗で全体を止めない（決定 D39 と同じ隔離）★★', () {
    test('★読めない画像は失敗として記録され、ハッシュは残らない', () async {
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      // ★配信物からバイト列だけ抜く（マニフェストには残す）。
      final source = MapMasterFileSource(const {});
      final sink = _RecordingSink();

      final result = await run(dist, sink: sink, source: source);

      expect(result.failedPaths, ['images/thumb/aaaa.webp']);
      expect(sink.written, isEmpty);
      expect(await state.outstandingImportIssueCount(), 1);
      // ★対: ハッシュを記録していないので次回も計画に残る。
      final retry = _RecordingSink();
      await run(dist, sink: retry);
      expect(retry.written, hasLength(1));
    });

    test('★書けない画像も同じ形で隔離される', () async {
      final dist = _Dist()
        ..image('images/thumb/aaaa.webp', _webp, 'sha256:1')
        ..image('images/thumb/bbbb.webp', _webp2, 'sha256:2');
      final sink = _RecordingSink()..failWriteFor = 'images/thumb/aaaa.webp';

      final result = await run(dist, sink: sink);

      expect(result.failedPaths, ['images/thumb/aaaa.webp']);
      // ★対: もう 1 枚は取り込まれている（1 枚で全体を止めない）。
      expect(result.importedPaths, ['images/thumb/bbbb.webp']);
    });
  });

  group('★★ カードの計画に画像を混ぜない ★★', () {
    test('★★ カードのマニフェストの削除計画が画像を巻き込まない ★★', () async {
      // ★★仕込まないと踏む★★ —— `planUpdate` の削除計画は
      //   「カードのマニフェストに無いローカルの path」なので、
      //   画像の記録をそのまま渡すと **画像が全部消える**。
      final dist = _Dist()..image('images/thumb/aaaa.webp', _webp, 'sha256:1');
      await run(dist, sink: _RecordingSink());

      final sink = _RecordingSink();
      final result = await run(dist, sink: sink);

      expect(result.deletedPaths, isEmpty);
      expect(sink.deleted, isEmpty);
    });
  });
}
