/// ★★ 試験用の証明書の柵（決定 **D131-7** / **D131-2** / `docs/同期設計メモ.md` §48-11）★★
///
/// ★★ 見張るのは 2 つ。★見ているものが違う（**D-27**）★★
///
/// | 何 | 何を止めるか |
/// |---|---|
/// | ★**試験用の証明書が★`lib` から参照されない** | ★★**本番で使われること**★★ —— ★秘密鍵がこのリポジトリに在る |
/// | ★**`lib` に★素の待ち受け（`HttpServer.bind`）が無い** | ★★**素の HTTP へ落ちること**★★（**D131-2** / **D129-6**） |
///
/// ★★ 字面を広げすぎない（**D-37 の裏**）★★
/// ★`bind(` は★**`bindSecure(` を含まない**（★対で固定した）。
/// ★**広げると `bindSecure` 自身が当たり、★★柵が常に落ちる★★。**
library;

import 'dart:io';

import 'package:test/test.dart';

const _libRoot = 'lib';

/// ★字面をそのまま探す正規表現。
///
/// ★★ `RegExp.escape` は★★文字列を返す★★（★正規表現ではない）★★
/// ★**そのまま [Pattern] として渡すと★★逃がした逆スラッシュごと★字面で探す★★ことになり、
/// ★★何にも当たらない★★。**★**最初はそう書いており、★★下の「対」が捕まえた★★**
/// （**D-27** —— ★対を置いたら対象を壊して落ちることを実測する。★**この回は★★対が★本命の空振りを見つけた★★**）。
RegExp _literal(String text) => RegExp(RegExp.escape(text));

/// ★試験用の証明書のファイル名（★片方だけでも参照されたら落とす）。
const _fixtureNames = <String>[
  'localhost-TEST-ONLY.cert.pem',
  'localhost-TEST-ONLY.key.pem',
];

/// [root] 以下の `.dart` を走査し、★**ファイル名 → 当たった数**を返す。
Map<String, int> scanDart(String root, Pattern pattern) {
  final hits = <String, int>{};
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final count = pattern.allMatches(entity.readAsStringSync()).length;
    if (count > 0) hits[entity.path.replaceAll(r'\', '/')] = count;
  }
  return hits;
}

void main() {
  group('★★ 前提 —— ★★試験用の証明書が実在する（**D-10**）★★', () {
    test('★ 2 つとも在る', () {
      // ★★ 無ければ下の「0 件」は何も証明しない ★★
      for (final name in _fixtureNames) {
        expect(File('test/fixtures/tls/$name').existsSync(), isTrue,
            reason: '★$name');
      }
    });

    test('★★ 読み方を書いた README が在る ★★', () {
      // ★★ 「本番で使ってはならない」がどこにも書いていない状態を作らない ★★
      final readme = File('test/fixtures/tls/README.md');

      expect(readme.existsSync(), isTrue);
      expect(readme.readAsStringSync(), contains('本番で使ってはならない'));
    });
  });

  group('★★ 柵 —— ★★試験用の証明書は `lib` から参照されない（**D131-7**）★★', () {
    test('★★ 陽性対照: 走査が当たること ★★', () {
      // ★★ 合成のソースで当たることを見る（★0 件は何も証明しない / **D-10**）★★
      for (final name in _fixtureNames) {
        expect(_literal(name).allMatches("const p = '$name';").length, 1);
      }
    });

    test('★★ `lib` に 1 件も無い ★★', () {
      for (final name in _fixtureNames) {
        expect(scanDart(_libRoot, _literal(name)), isEmpty,
            reason: '★$name —— ★★参照されたら本番で使われうる★★');
      }
    });

    test('★★ 対: `test` には在る（★上が「どこにも無い」で通らないこと）★★', () {
      // ★★ これが無いと、★★走査の根を間違えていても★上が通る★★ ★★
      for (final name in _fixtureNames) {
        expect(scanDart('test', _literal(name)), isNotEmpty, reason: '★$name');
      }
    });
  });

  group('★★ 柵 —— ★★`lib` に素の待ち受けが無い（**D131-2**）★★', () {
    test('★★ 陽性対照: `bind(` は `bindSecure(` を含まない（**D-37 の裏**）★★', () {
      // ★★ 広げると `bindSecure` 自身が当たり、★柵が常に落ちる ★★
      final bare = RegExp(r'HttpServer\.bind\(');

      expect(bare.hasMatch('await HttpServer.bind(a, 0);'), isTrue);
      expect(bare.hasMatch('await HttpServer.bindSecure(a, 0, c);'), isFalse);
    });

    test('★★ `lib` に `HttpServer.bind(` が 1 件も無い ★★', () {
      expect(scanDart(_libRoot, RegExp(r'HttpServer\.bind\(')), isEmpty,
          reason: '★★素の HTTP に載せると、★保存をどれだけ固くしても意味が無い★★'
              '（決定 **D129-6**）');
    });

    test('★★ 対: `bindSecure(` は `lib` に在る（★上が「待ち受けが無い」で通らないこと）★★', () {
      // ★★ これが無いと、★★待ち受けを丸ごと消しても★上が通る★★ ★★
      expect(scanDart(_libRoot, RegExp(r'HttpServer\.bindSecure\(')), isNotEmpty);
    });
  });
}
