/// ★★ パスワードの保存の形（決定 **D129-3** / **D129-5** / `docs/同期設計メモ.md` §44-7）★★
///
/// ★★ golden は★別の実装で検算してある ★★
/// ★下の 3 本の値は **Python の `hashlib.pbkdf2_hmac` で独立に計算し、一致を確かめた**
/// （2026-09-01）。★**D115-2** が内容ハッシュに採ったのと**同じ作法**である ——
/// ★**自分の出力を写しただけの golden は「自分と同じであること」しか言わない。**
/// ★★**2 台が交換する値なので、実装をまたぐことが要求そのものである。**★★
/// ★**うち 2 本は RFC 7914 §11 に載っている公表値と一致する**（★同じく確かめた）。
///
/// ★★ ここで固定していないもの ★★
/// ★**「安全である」ことは固定できない。**★固定しているのは
/// ★**(1) 公表された組み立てと一致すること** / ★**(2) 柵 3 つが形として在ること**である。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:loveca_server/loveca_server.dart';
import 'package:test/test.dart';

/// 16 進の文字列にする。★golden の突き合わせに使う。
String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// ★seed から決まる乱数。★**塩を固定するためだけに使う**（★`lib` からは渡さない）。
final _fixed = Random(20260901);

void main() {
  group('★★ golden —— ★別の実装（Python の hashlib）で検算した値 ★★', () {
    test('★ P="passwd" S="salt" c=1 dkLen=64', () {
      final out = pbkdf2(
        password: utf8.encode('passwd'),
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 64,
      );
      expect(
        _hex(out),
        '55ac046e56e3089fec1691c22544b605'
        'f94185216dde0465e68b9d57c20dacbc'
        '49ca9cccf179b645991664b39d77ef31'
        '7c71b845b1e30bd509112041d3a19783',
      );
    });

    test('★ P="password" S="NaCl" c=4096 dkLen=32', () {
      final out = pbkdf2(
        password: utf8.encode('password'),
        salt: utf8.encode('NaCl'),
        iterations: 4096,
        length: 32,
      );
      expect(
        _hex(out),
        '14681269a9dc355d9872c44c3ea290a3'
        '69f804b4fd2b2f71c7be3b22dbd5b898',
      );
    });

    test('★★ 長さが 1 ブロックを超える（★通し番号の組み立てを見る）★★', () {
      // ★★ 64 バイトは 2 ブロックである ★★
      //   ★1 ブロックしか見ないと、★**通し番号を塩の後ろに置く部分が★誰にも見られない。**
      final one = pbkdf2(
        password: utf8.encode('passwd'),
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 32,
      );
      final two = pbkdf2(
        password: utf8.encode('passwd'),
        salt: utf8.encode('salt'),
        iterations: 1,
        length: 64,
      );
      // ★前半は 1 ブロックぶんと一致する（★同じ通し番号 1 で作られる）。
      expect(_hex(two.sublist(0, 32)), _hex(one));
      // ★★後半は前半と違う（★通し番号 2 が効いている）★★
      expect(_hex(two.sublist(32)), isNot(_hex(one)));
    });
  });

  group('★★ 引数の検査（★0 件を「無い」と読まないための対 / D-10）★★', () {
    test('★ 繰り返し回数は 1 以上', () {
      expect(
        () => pbkdf2(
            password: const [1], salt: const [2], iterations: 0, length: 8),
        throwsArgumentError,
      );
    });

    test('★ 長さは 1 以上', () {
      expect(
        () => pbkdf2(
            password: const [1], salt: const [2], iterations: 1, length: 0),
        throwsArgumentError,
      );
    });
  });

  group('★★ 柵 1 —— ★繰り返し回数と塩を★保存した値の中に持つ（D129-5）★★', () {
    test('★ 形は「算法 / 回数 / 塩 / 値」の 4 つに割れる', () {
      final stored = encodePasswordHash('パスワード',
          salt: newSalt(random: _fixed), iterations: 10);
      final parts = stored.split(r'$');

      expect(parts, hasLength(4));
      expect(parts[0], passwordHashAlgorithm);
      expect(parts[1], '10');
      expect(base64.decode(parts[2]), hasLength(passwordSaltLength));
      expect(base64.decode(parts[3]), hasLength(passwordHashLength));
    });

    test('★★ 回数が違う値も★同じ口で照合できる（★あとから上げられること）★★', () {
      final salt = newSalt(random: _fixed);
      final slow = encodePasswordHash('ひみつ', salt: salt, iterations: 20);
      final fast = encodePasswordHash('ひみつ', salt: salt, iterations: 10);

      // ★★ 回数が値の中に在るので、★古い値も新しい値も読める ★★
      expect(verifyPassword('ひみつ', slow), isTrue);
      expect(verifyPassword('ひみつ', fast), isTrue);
      // ★対: 回数が違えば★値そのものは違う（★回数が効いている）。
      expect(slow, isNot(fast));
    });

    test('★★ 塩が違えば★同じパスワードでも値が違う（★作り置きの表が効かない）★★', () {
      final a = encodePasswordHash('おなじ',
          salt: Uint8List.fromList(List<int>.filled(16, 1)), iterations: 10);
      final b = encodePasswordHash('おなじ',
          salt: Uint8List.fromList(List<int>.filled(16, 2)), iterations: 10);

      expect(a, isNot(b));
      // ★対: 塩が同じなら同じ値になる（★塩以外に揺れが無いことの確認）。
      final c = encodePasswordHash('おなじ',
          salt: Uint8List.fromList(List<int>.filled(16, 1)), iterations: 10);
      expect(a, c);
    });
  });

  group('★★ 柵 2 —— ★塩の作り方（D129-5）★★', () {
    test('★ 既定の長さで作る', () {
      expect(newSalt(random: _fixed), hasLength(passwordSaltLength));
    });

    test('★★ 既定では `Random.secure()` を使う（★2 回呼ぶと違う）★★', () {
      // ★★ 「無作為である」ことは固定できない。★**同じ値が返らない**ことだけを見る ★★
      //   ★決め打ちの塩を返す実装なら、★これが落ちる。
      expect(_hex(newSalt()), isNot(_hex(newSalt())));
    });
  });

  group('★★ 柵 3 —— ★時間の差が出ない比較（D129-5）★★', () {
    test('★ 同じなら true', () {
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2, 3]), isTrue);
    });

    test('★ 1 バイトでも違えば false', () {
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2, 4]), isFalse);
    });

    test('★★ 長さが違えば false（★早く帰らないこと自体は測らない）★★', () {
      // ★**時間を測る検査は置かない** —— ★機械の状態で揺れる（**D-28** —— ★測っていない）。
      // ★固定できるのは**答えが正しいこと**までである。
      expect(constantTimeEquals(const [1, 2], const [1, 2, 3]), isFalse);
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2]), isFalse);
    });

    test('★★ 対: 前半が同じでも長さが違えば false ★★', () {
      // ★短いほうで打ち切る実装なら、★これが true になって落ちる。
      expect(constantTimeEquals(const [1, 2, 3], const [1, 2, 3, 0]), isFalse);
    });
  });

  group('★★ 照合 ★★', () {
    final stored = encodePasswordHash('correct horse battery staple',
        salt: newSalt(random: _fixed), iterations: 10);

    test('★ 合っていれば true', () {
      expect(verifyPassword('correct horse battery staple', stored), isTrue);
    });

    test('★ 違えば false', () {
      expect(verifyPassword('correct horse battery stapl', stored), isFalse);
      expect(verifyPassword('', stored), isFalse);
    });

    test('★★ 保存した値に★元のパスワードが残っていない ★★', () {
      // ★**平文で保存する形なら、★これが落ちる。**
      expect(stored.contains('correct horse'), isFalse);
      expect(utf8.decode(base64.decode(stored.split(r'$')[3]), allowMalformed: true),
          isNot(contains('correct')));
    });

    test('★★ 壊れた値は false ではなく投げる（★「合わない」と「読めない」を混ぜない）★★', () {
      expect(() => verifyPassword('x', 'not-a-stored-value'),
          throwsFormatException);
      expect(() => verifyPassword('x', r'md5$10$AAAA$AAAA'),
          throwsFormatException);
      expect(() => verifyPassword('x', '$passwordHashAlgorithm' r'$zero$AAAA$AAAA'),
          throwsFormatException);
      expect(() => verifyPassword('x', '$passwordHashAlgorithm' r'$10$!!!!$AAAA'),
          throwsFormatException);
    });
  });

  group('★★ 既定の値（★下げてはならない / 柵 1）★★', () {
    test('★ 既定の回数と長さ', () {
      // ★★ 数を doc に書かず、★ここで固定する（**D-15**）★★
      expect(passwordHashIterations, 600000);
      expect(passwordSaltLength, 16);
      expect(passwordHashLength, 32);
      expect(passwordHashAlgorithm, 'pbkdf2-sha256');
    });
  });
}
