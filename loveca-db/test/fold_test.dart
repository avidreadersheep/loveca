/// 検索用の表記ゆれ折りたたみの検証（決定 D40）.
library;

import 'package:loveca_db/loveca_db.dart';
import 'package:test/test.dart';

void main() {
  group('全角半角のゆれを吸収する', () {
    // ★実データのユニット名は全角半角が混在している★
    //   CYaRon！(全角) / CatChu!(半角) / 5yncri5e!(半角) / みらくらぱーく！(全角)
    test('全角 ASCII と半角 ASCII が同じ結果になる', () {
      expect(fold('CYaRon！'), fold('CYaRon!'));
      expect(fold('みらくらぱーく！'), fold('みらくらぱーく!'));
      expect(fold('ＡＢＣ１２３'), 'abc123');
    });

    test('実データで NFKC が触る 22 文字をすべて畳む', () {
      const source = '：！＋１＆（）２６［］３？５４９＊～８－０µ';
      const expected = ':!+1&()26[]3?549*~8-0μ';
      expect(fold(source), expected);
    });

    test('全角空白を半角にする', () {
      expect(fold('あ　い'), 'あ い');
    });
  });

  group('ギリシャ文字（グループ名 μ\'s）', () {
    test('MICRO SIGN を GREEK SMALL MU に寄せる', () {
      expect(fold('µ\'s'), 'μ\'s');
    });

    test('GREEK CAPITAL MU も小文字化で同じところに来る', () {
      expect(fold('Μ\'s'), 'μ\'s');
      expect(fold('µ\'s'), fold('Μ\'s'));
    });
  });

  group('半角カナ', () {
    test('全角カナに寄せる', () {
      expect(fold('ﾌﾞﾚｰﾄﾞ'), 'ブレード');
      expect(fold('ﾗｲﾌﾞ'), 'ライブ');
    });

    test('半濁点を合成する', () {
      expect(fold('ﾊﾟﾌｫｰﾏﾝｽ'), 'パフォーマンス');
    });

    test('合成先の無い濁点は単独の記号にする', () {
      expect(fold('ｱﾞ'), 'ア゛');
    });
  });

  group('★冪等 fold(fold(x)) == fold(x)', () {
    const samples = [
      'CYaRon！',
      'みらくらぱーく！',
      'ＡＢＣ１２３',
      'µ\'s',
      'Μ\'s',
      'ﾌﾞﾚｰﾄﾞ',
      'ﾊﾟﾌｫｰﾏﾝｽ',
      'ｱﾞ',
      '：！＋１＆（）２６［］３？５４９＊～８－０',
      '【ライブ開始時】自分のデッキの上からカードを1枚見る。',
      'あ　い',
      '',
      'PL!N-bp1-034-PE＋',
      '5yncri5e!',
      'A・ZU・NA',
    ];

    for (final s in samples) {
      test('${s.isEmpty ? '(空文字列)' : s} が冪等', () {
        final once = fold(s);
        expect(fold(once), once);
        // 3 回目まで見て、周期 2 で振動する実装を弾く。
        expect(fold(fold(once)), once);
      });
    }
  });

  group('★適用順に依存しない', () {
    // 全角大文字は「全角畳み→小文字化」でも「小文字化→全角畳み」でも同じ。
    test('全角大文字 Ａ はどちらの順でも a', () {
      expect(fold('Ａ'), 'a');
      expect(fold('ａ'), 'a');
      expect(fold('A'), 'a');
    });

    // µ の Unicode 小文字写像は自身なので toLowerCase は恒等。
    test('MICRO SIGN の小文字化は恒等なので順序が効かない', () {
      expect('µ'.toLowerCase(), 'µ');
      expect(fold('µ'), 'μ');
    });
  });

  group('trigram の下限', () {
    test('3 文字以上は trigram で引ける', () {
      expect(isTrigramSearchable(fold('ライブ')), isTrue);
      expect(isTrigramSearchable(fold('ブレード')), isTrue);
    });

    // ★2 文字以下は MATCH がエラーにならず静かに 0 件を返す★
    //   実測: 花帆 は trigram 0 件 / LIKE 35 件。呼び出し側で LIKE に切り替える。
    test('2 文字以下は trigram で引けない', () {
      expect(isTrigramSearchable(fold('花帆')), isFalse);
      expect(isTrigramSearchable(fold('侑')), isFalse);
      expect(isTrigramSearchable(fold('')), isFalse);
    });

    test('文字数は符号位置で数える', () {
      // サロゲートペア 2 文字 = 4 code unit。code unit で数えると誤判定する。
      const surrogates = '\u{20BB7}\u{20BB7}';
      expect(surrogates.length, 4);
      expect(isTrigramSearchable(surrogates), isFalse);
    });
  });

  group('foldJoin', () {
    test('空の断片を落として畳む', () {
      expect(foldJoin(['CYaRon！', '', 'Liella!']), 'cyaron!\nliella!');
    });
  });
}
