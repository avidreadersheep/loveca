/// 配信ファイルの取得手段がバイナリを運べること
/// （決定 **D121-1** ＝ 画-5 / `docs/同期設計メモ.md` §32-6 の 6）.
///
/// ★★ なぜ要るか ★★
/// 画像を配るには **バイト列** が要る。文字列しか返せないと WebP を通せない。
/// ★★壊れ方は 2 通りある。混ぜないこと（実測）★★ ——
///   (1) `dart:io` の `readAsString` は **投げる**（`FileSystemException`）。
///   (2) `allowMalformed` を許すと置換文字（U+FFFD）に化け、**元に戻せない**。
/// ★どちらも下で実際に見る。★「取得手段が壊す」ので、ここで見る。
///
/// ★★ 対を「UTF-8 にできないバイト列」で置く ★★
/// テキストで往復させると、文字列に畳んでも差が出ないので
/// **文字列経由の実装でも通ってしまう**（`ルール整合性チェック_v1.06.md` **D-27**）。
/// → ★不正なバイト列をわざと使う。
///
/// ★この commit は取り込み層を 1 行も変えていない。★運べるようにしただけである。
library;

import 'dart:convert';
import 'dart:io';

import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

/// ★UTF-8 として復号できないバイト列。
///
/// ★0xFF / 0xFE は UTF-8 の先頭バイトとして不正で、
///   `utf8.decode` は既定で例外を投げ、`allowMalformed` なら置換文字になる。
///   ★WebP の実物も 4 バイト目以降にこの手のバイトを普通に含む。
const _binary = <int>[0x52, 0x49, 0x46, 0x46, 0xFF, 0xFE, 0x00, 0x80, 0xC0];

void main() {
  group('★★ MapMasterFileSource がバイト列を運ぶ（決定 D121-1）★★', () {
    test('★バイト列で置いたものはそのまま返る', () {
      final source = MapMasterFileSource(
        const {},
        binaries: const {'images/thumb/aaaa.webp': _binary},
      );
      expect(source.readBytes('images/thumb/aaaa.webp'), completion(_binary));
    });

    test('★★ 対: そのバイト列は文字列を通すと壊れる ★★', () {
      // ★これがこの commit の存在理由そのものである。
      //   ★通した結果が元に戻らないことを **実際に見る** ——
      //   見ないと「バイト列で運ぶ必要がある」が主張のままになる。
      expect(() => utf8.decode(_binary), throwsA(anything));
      final lossy = utf8.decode(_binary, allowMalformed: true);
      expect(utf8.encode(lossy), isNot(_binary),
          reason: '置換文字に化けると元に戻せない');
    });

    test('★対: テキストで置いたものは UTF-8 のバイト列として返る', () {
      final source = MapMasterFileSource(const {'cards/BP01.json': '{"a":1}'});
      expect(
        source.readBytes('cards/BP01.json'),
        completion(utf8.encode('{"a":1}')),
      );
    });

    test('★対: read は今までどおり文字列を返す', () {
      final source = MapMasterFileSource(const {'cards/BP01.json': '{"a":1}'});
      expect(source.read('cards/BP01.json'), completion('{"a":1}'));
    });

    test('★バイト列のほうが優先される（同じ path に両方あるとき）', () {
      // ★片方しか見ない実装だと、どちらを見ているか分からない。
      final source = MapMasterFileSource(
        const {'x': 'テキスト'},
        binaries: const {'x': _binary},
      );
      expect(source.readBytes('x'), completion(_binary));
      expect(source.read('x'), completion('テキスト'));
    });

    test('★readBytes も読んだ path を記録する', () {
      final source = MapMasterFileSource(
        const {'t': 'text'},
        binaries: const {'b': _binary},
      );
      return Future(() async {
        await source.readBytes('b');
        await source.read('t');
        expect(source.readPaths, ['b', 't']);
      });
    });

    test('★対: 無い path は readBytes でも投げる', () {
      final source = MapMasterFileSource(const {});
      expect(source.readBytes('images/thumb/none.webp'), throwsStateError);
    });
  });

  group('★★ LocalDirectoryMasterFileSource がバイト列を運ぶ ★★', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('loveca-src-');
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('★★ 実ファイルのバイト列が 1 バイトも変わらずに戻る ★★', () async {
      final file = File('${dir.path}/images/thumb/aaaa.webp')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_binary);
      expect(file.existsSync(), isTrue);

      final source = LocalDirectoryMasterFileSource(dir);
      expect(await source.readBytes('images/thumb/aaaa.webp'), _binary);
    });

    test('★★ 対: 同じファイルを read で読むと落ちる ★★', () async {
      File('${dir.path}/images/thumb/aaaa.webp')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_binary);

      final source = LocalDirectoryMasterFileSource(dir);
      // ★★実測で分かったこと★★ —— `readAsString` は黙って置換文字にせず、
      //   ★`FileSystemException` を投げる（既定は allowMalformed: false）。
      //   ★最初この test は「置換文字に化ける」と書いていて落ちた。
      //   ★★壊れ方が違う。★「黙って壊れる」ではなく「読めない」である。★★
      await expectLater(
        source.read('images/thumb/aaaa.webp'),
        throwsA(isA<FileSystemException>()),
        reason: 'テキスト経路では画像が読めない。だから readBytes を足した',
      );
      // ★対: バイト列なら読める（同じファイル・同じ source）。
      expect(await source.readBytes('images/thumb/aaaa.webp'), _binary);
    });

    test('★対: テキストは read でも readBytes でも同じ中身になる', () async {
      File('${dir.path}/cards/BP01.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{"a":1}');

      final source = LocalDirectoryMasterFileSource(dir);
      expect(await source.read('cards/BP01.json'), '{"a":1}');
      expect(await source.readBytes('cards/BP01.json'), utf8.encode('{"a":1}'));
    });

    test('★readBytes も読んだ path を記録する', () async {
      File('${dir.path}/cards/BP01.json')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('{}');
      final source = LocalDirectoryMasterFileSource(dir);
      await source.readBytes('cards/BP01.json');
      expect(source.readPaths, ['cards/BP01.json']);
    });
  });
}
