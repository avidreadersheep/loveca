/// 取り込みへの配線 —— ★★端末へ写すか（★§32-6 の **8** の 3 / 決定 **D149-3**）★★
///
/// ★★ この群が固定しているもの ★★
/// ★**`MasterRepository.import` が★★受け取った口を★取り込み層まで通すこと★★** ／
/// ★★**ローカルの dist から取り込むときは★写さないこと**★★（★★渡さないことが答えである★★）。
///
/// ★★ 「モバイルで画像が出るようになった」と読まないこと ★★
/// ★**写す経路を呼ぶ側が★★1 行も無い★★**（★§32-6 の 8 の 4 は口だけ / ★5 は未着手）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:loveca_ui/src/data/app_database.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/dist_locator.dart';
import 'package:loveca_ui/src/data/master_repository.dart';
import 'package:path/path.dart' as p;

final _t0 = DateTime.utc(2026, 9, 2, 12);

/// ★UTF-8 として復号できないバイト列（★WebP の実物と同じ性質）。
const _webp = <int>[0x52, 0x49, 0x46, 0x46, 0xFF, 0xFE, 0x00, 0x80];

void main() {
  late Directory tmp;
  late Directory dist;
  late LovecaDatabase db;
  late MasterRepository master;

  /// カード 0 件 ＋ 画像 1 件の最小の配信物を書く。
  void writeDist() {
    Directory(p.join(dist.path, 'images', 'thumb')).createSync(recursive: true);
    File(p.join(dist.path, 'images', 'thumb', 'a.webp'))
        .writeAsBytesSync(_webp);

    final imageManifest = jsonEncode({
      'dataVersion': 0,
      'files': [
        {'path': 'images/thumb/a.webp', 'hash': 'sha256:img', 'bytes': _webp.length},
      ],
    });
    File(p.join(dist.path, 'image_manifest.json'))
        .writeAsStringSync(imageManifest);
    File(p.join(dist.path, 'manifest.json'))
        .writeAsStringSync('{"dataVersion": 1, "files": []}');
    File(p.join(dist.path, 'version.json')).writeAsStringSync(jsonEncode({
      'dataVersion': 1,
      'minAppVersion': '0.0.0',
      'imageManifestPath': '/data/image_manifest.json',
      'imageManifestHash': 'sha256:i',
    }));
  }

  Future<MasterImportOutcome> runImport({MasterImageSink? imageSink}) =>
      master.import(
        location: DistLocation(
          directory: dist,
          searched: const [],
          source: DistSource.settings,
        ),
        appVersion: '1.0.0',
        settings: const AppSettings(),
        now: _t0,
        imageSink: imageSink,
      );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('loveca_image_wiring_test');
    dist = Directory(p.join(tmp.path, 'dist'))..createSync(recursive: true);
    db = await openAppDatabase(File(p.join(tmp.path, 'loveca.db')));
    master = MasterRepository(db);
    writeDist();
  });

  tearDown(() async {
    try {
      await db.close();
    } on Object catch (_) {
      // ★後始末であって検査ではない。
    }
    tmp.deleteSync(recursive: true);
  });

  group('★★ 口を通す（★決定 D149-3）★★', () {
    test('★★ 渡した口に★配るバイト列がそのまま届く ★★', () async {
      final device = Directory(p.join(tmp.path, 'device'));
      final sink = LocalDirectoryMasterImageSink(device);

      await runImport(imageSink: sink);

      expect(sink.writtenPaths, ['images/thumb/a.webp']);
      expect(
        File(p.join(device.path, 'images', 'thumb', 'a.webp'))
            .readAsBytesSync(),
        _webp,
        reason: '★★文字列に畳んでいない（**D121-2** の柵）★★',
      );
    });

    test('★★ 渡さなければ★1 枚も書かない（★★これが今日の経路である★★）★★', () async {
      final device = Directory(p.join(tmp.path, 'device'));

      await runImport();

      expect(device.existsSync(), isFalse,
          reason: '★★ローカルの dist から取り込むときは★写さない★★');
    });

    test('★★ 渡さなくても★取り込みそのものは通る（★★止まらない★★）★★', () async {
      final outcome = await runImport();

      expect(outcome.distMissing, isFalse);
      expect(outcome.result, isNotNull);
    });

    test('★★ 柵: ★dist のディレクトリへ 1 バイトも書かない（**D137-4** の柵 2）★★',
        () async {
      final before = dist
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .toList()
        ..sort();

      await runImport(
          imageSink: LocalDirectoryMasterImageSink(
              Directory(p.join(tmp.path, 'device'))));

      final after = dist
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .toList()
        ..sort();
      expect(after, before, reason: '★★配信物は★開発する人の資産である★★');
    });
  });

  group('★★ 画像のマニフェスト —— ★「まだ無い」と「0 枚である」を書き分ける（D121-1）★★', () {
    test('★★ 版が画像のマニフェストを名指さなければ★1 バイトも読まない ★★', () async {
      // ★★ 生成側が `--skip-images` なら★列を書かない（★実装の記録 / §32-6 のレーン 2）★★
      //   ★**読みに行くと★★存在しないファイルで投げる★★**（★取り込み全体が止まる）。
      File(p.join(dist.path, 'version.json'))
          .writeAsStringSync('{"dataVersion": 1, "minAppVersion": "0.0.0"}');
      File(p.join(dist.path, 'image_manifest.json')).deleteSync();

      final device = Directory(p.join(tmp.path, 'device'));
      final sink = LocalDirectoryMasterImageSink(device);
      final outcome = await runImport(imageSink: sink);

      expect(outcome.result, isNotNull, reason: '★★止まらない★★');
      expect(sink.writtenPaths, isEmpty);
    });

    test('★★ 対: ★空のマニフェストなら★0 枚として扱う（★★「まだ無い」ではない★★）★★',
        () async {
      File(p.join(dist.path, 'image_manifest.json'))
          .writeAsStringSync('{"files": []}');

      final device = Directory(p.join(tmp.path, 'device'));
      final sink = LocalDirectoryMasterImageSink(device);
      final outcome = await runImport(imageSink: sink);

      expect(outcome.result, isNotNull);
      expect(sink.writtenPaths, isEmpty);
    });
  });

  group('★★ 走査 —— ★起動ゲートは★写す口を組み立てない（★決定 D149-3）★★', () {
    test('★★ `boot_steps.dart` に★写す口の構築が 1 つも無い ★★', () {
      // ★★ 「今日は使わない引数」ではない。★★渡さないことが答えである★★ ★★
      //   ★**ローカルの dist から取り込む経路では★画像は既に読み先（段 1）に在る**ので、
      //     ★★写すと 571 MB を二重に持つ★★（★§59-4 の 理由 3）。
      final source =
          File('lib/src/boot/boot_steps.dart').readAsStringSync();

      expect(source.contains('LocalDirectoryMasterImageSink'), isFalse);
    });

    test('★★ 対: ★この走査は★字面を実際に見分ける（★陽性対照）★★', () {
      const synthetic =
          'imageSink: LocalDirectoryMasterImageSink(handle.paths.cardImagesDir),';
      expect(synthetic.contains('LocalDirectoryMasterImageSink'), isTrue);
    });
  });
}
