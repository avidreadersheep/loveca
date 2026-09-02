/// 端末の領域へ画像を書く（★§32-6 の **8** の 2 / 決定 **D149-4**）.
///
/// ★★ この群が固定しているもの ★★
/// ★**根の下にしか書かない**（★2 段の柵 / **D134-7** / §60 と同じ形）／
/// ★**一時ファイルへ書いて置き換える**／ ★**無いものを消しても投げない**（★契約）。
///
/// ★★ 置き場は 1 バイトも見ない ★★
/// ★**根は★呼び出し側が渡す。★★この class は「どこが正しい置き場か」を知らない★★。**
library;

import 'dart:io';

import 'package:loveca_db/native.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late LocalDirectoryMasterImageSink sink;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_image_sink_test');
    sink = LocalDirectoryMasterImageSink(tmp);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  File at(String rel) => File(p.joinAll([tmp.path, ...p.posix.split(rel)]));

  group('★★ 書く ★★', () {
    test('★ 根の下に書く（★中間のディレクトリも作る）', () async {
      await sink.write('images/thumb/abc.webp', const [1, 2, 3]);

      expect(at('images/thumb/abc.webp').readAsBytesSync(), [1, 2, 3]);
      expect(sink.writtenPaths, ['images/thumb/abc.webp']);
    });

    test('★★ バイト列をそのまま書く（★★文字列に畳まない★★ / D121-2 の柵）★★', () async {
      // ★★ UTF-8 として復号できないバイト列を通す ★★
      const bytes = [0xFF, 0xD8, 0x00, 0x80];
      await sink.write('images/thumb/a.webp', bytes);

      expect(at('images/thumb/a.webp').readAsBytesSync(), bytes);
    });

    test('★★ 一時ファイルを残さない（★書いて置き換える）★★', () async {
      await sink.write('images/thumb/a.webp', const [1]);

      final leftovers = tmp
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });

    test('★ 同じ path を 2 度書くと★あとの中身になる', () async {
      await sink.write('images/thumb/a.webp', const [1]);
      await sink.write('images/thumb/a.webp', const [2]);

      expect(at('images/thumb/a.webp').readAsBytesSync(), [2]);
    });
  });

  group('★★ 柵 —— ★根の外へ書かない（★★2 段★★ / **D134-7** / §60）★★', () {
    test('★★ 上へ抜ける path は★投げる（★★黙って捨てない★★）★★', () async {
      await expectLater(
        () => sink.write('../outside.webp', const [1]),
        throwsA(isA<ArgumentError>()),
      );
      expect(sink.writtenPaths, isEmpty);
    });

    test('★ 段の途中に `..` が在っても投げる', () async {
      await expectLater(
        () => sink.write('images/../../outside.webp', const [1]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('★ 空の path は投げる', () async {
      await expectLater(
          () => sink.write('', const [1]), throwsA(isA<ArgumentError>()));
    });

    test('★★ 区切りが 2 つ続く path は★★畳まれる。★投げない★★（★実測）★★', () async {
      // ★★ 書いた断定が 1 つ偽だった（**D-15 (j)** —— ★★走らせて分かった。★出す前である★★）★★
      //   ★**「空の段も投げる」と書いたが、★★`p.posix.split` が★空の段を落とす★★**
      //     （★2026-09-02 実測: ★`split('images//a.webp')` は `[images, a.webp]`）。
      //   ★**害は無い** —— ★**読む側は★★マニフェストの字面を組み立てに使わない★★**
      //     （`CardImageSource` は `{根}/{段}/{ハッシュ}.webp` を自分で組む / ★実読）。
      //   ★**消す側も★同じ字面を通すので★★同じ所を指す★★**（★下の群）。
      await sink.write('images//a.webp', const [1]);

      expect(at('images/a.webp').readAsBytesSync(), [1]);
      expect(sink.writtenPaths, ['images//a.webp'],
          reason: '★★記録は★渡された字面のままである★★');
    });

    test('★★ ドライブを含む段も投げる（★Windows）★★', () async {
      await expectLater(() => sink.write('C:/outside.webp', const [1]),
          throwsA(isA<ArgumentError>()));
    });

    test('★★ 逆斜線を含む段も投げる ★★', () async {
      final withBackslash = 'images${String.fromCharCode(92)}a.webp';
      await expectLater(() => sink.write(withBackslash, const [1]),
          throwsA(isA<ArgumentError>()));
    });

    test('★★ 対: ★根の中なら書ける（★★陽性対照★★）★★', () async {
      await sink.write('images/thumb/a.webp', const [1]);
      expect(at('images/thumb/a.webp').existsSync(), isTrue);
    });

    test('★★ 段ごとの判定そのもの（★★純粋関数で見る★★）★★', () {
      bool safe(List<String> s) =>
          LocalDirectoryMasterImageSink.isSafeImageSegments(s);

      expect(safe(const []), isFalse);
      expect(safe(const ['']), isFalse);
      expect(safe(const ['.']), isFalse);
      expect(safe(const ['..']), isFalse);
      expect(safe(const ['C:']), isFalse);
      expect(safe(const ['a/b']), isFalse);
      expect(safe(['a${String.fromCharCode(92)}b']), isFalse);
      expect(safe(const ['images', 'thumb', 'a.webp']), isTrue);
    });
  });

  group('★★ 消す ★★', () {
    test('★ 在れば消す', () async {
      await sink.write('images/thumb/a.webp', const [1]);
      await sink.delete('images/thumb/a.webp');

      expect(at('images/thumb/a.webp').existsSync(), isFalse);
      expect(sink.deletedPaths, ['images/thumb/a.webp']);
    });

    test('★★ 無ければ黙って戻る（★★契約★★ —— ★投げない）★★', () async {
      await sink.delete('images/thumb/nope.webp');
      expect(sink.deletedPaths, ['images/thumb/nope.webp']);
    });

    test('★★ 根の外を指す path も★黙って戻る（★★1 バイトも消さない★★）★★', () async {
      final outside = File(p.join(tmp.parent.path, 'loveca_sink_outside.txt'))
        ..writeAsStringSync('のこる');
      addTearDown(() {
        if (outside.existsSync()) outside.deleteSync();
      });

      await sink.delete('../loveca_sink_outside.txt');

      expect(outside.existsSync(), isTrue);
      expect(sink.deletedPaths, isEmpty);
    });
  });
}
