/// 設定の読み書き（決定 D60 / `docs/UI設計メモ.md` §4-6(5)）.
///
/// ★★ 「壊れていたら既定に戻したうえで警告を出す」を固定する ★★
/// 黙って既定に戻すと「設定したのに効かない」が原因不明のまま残る。
/// 設計メモにその規則を書いたのに、M1 では `recoveredFrom` を作っただけで
/// 誰も読んでいなかった（D-6 と同じ型の穴）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;
  late File file;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_settings_test');
    file = File(p.join(tmp.path, 'settings.json'));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  AppSettingsStore store() => AppSettingsStore(file);

  group('読み込み', () {
    test('★存在しないのは異常ではない。既定を返し、警告も出さない', () async {
      final load = await store().load();

      expect(load.settings.distDir, isNull);
      expect(load.settings.showParallel, isTrue);
      // ★初回起動なので「復旧した」とは言わない。言うと毎回警告が出る。
      expect(load.wasRecovered, isFalse);
    });

    test('書いたものが読める（往復）', () async {
      const written = AppSettings(distDir: r'C:\dist', showParallel: false);
      await store().save(written);

      final load = await store().load();

      expect(load.wasRecovered, isFalse);
      expect(load.settings.distDir, r'C:\dist');
      expect(load.settings.showParallel, isFalse);
    });

    test('未知のキーがあっても壊れない', () async {
      file.writeAsStringSync(
        jsonEncode({'distDir': '/x', 'showParallel': true, 'future': 1}),
      );

      final load = await store().load();

      expect(load.wasRecovered, isFalse);
      expect(load.settings.distDir, '/x');
    });
  });

  group('★★ 壊れていたら既定に戻し、理由を返す ★★', () {
    test('JSON として壊れている', () async {
      file.writeAsStringSync('{ this is not json');

      final load = await store().load();

      expect(load.settings.distDir, isNull);
      expect(load.settings.showParallel, isTrue);
      // ★★ ここが要点。黙って既定に戻さない ★★
      expect(load.wasRecovered, isTrue);
      expect(load.recoveredFrom, isNotNull);
    });

    test('JSON だが最上位が Map ではない', () async {
      file.writeAsStringSync(jsonEncode([1, 2, 3]));

      final load = await store().load();

      expect(load.wasRecovered, isTrue);
      expect('${load.recoveredFrom}', contains('Map'));
    });

    test('値の型が違う', () async {
      file.writeAsStringSync(jsonEncode({'distDir': 42}));

      final load = await store().load();

      expect(load.wasRecovered, isTrue);
      expect(load.settings.distDir, isNull);
    });

    test('空ファイル', () async {
      file.writeAsStringSync('');

      final load = await store().load();

      expect(load.wasRecovered, isTrue);
    });
  });

  group('★ 書き込みの原子性', () {
    test('一時ファイルを残さない', () async {
      await store().save(const AppSettings(distDir: '/a'));

      final left = tmp.listSync().map((e) => p.basename(e.path)).toList();
      expect(left, ['settings.json']);
    });

    test('★上書きで前の内容が壊れない（途中の欠けた状態を残さない）', () async {
      await store().save(const AppSettings(distDir: '/first'));
      await store().save(const AppSettings(distDir: '/second'));

      final load = await store().load();
      expect(load.wasRecovered, isFalse);
      expect(load.settings.distDir, '/second');
    });

    test('親ディレクトリが無くても作る', () async {
      final nested = File(p.join(tmp.path, 'a', 'b', 'settings.json'));
      await AppSettingsStore(nested).save(const AppSettings(distDir: '/x'));

      expect(nested.existsSync(), isTrue);
    });
  });
}
