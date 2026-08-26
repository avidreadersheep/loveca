/// ★★ 本番コードのカード番号リテラルが増えないこと（決定 D97）★★
///
/// D97 以前、3 パッケージの `lib/` に**カード番号のハードコードは 0 件**だった。
/// D97 で `AppSettings` の既定値が **1 箇所目**になる。★**例外はこれだけである。**
///
/// ★★ この検査は「手で走らせる grep」では足りない ★★
/// **D-2**（`loveca-core` にリントが 1 つも効いていなかった）が前例で、
/// **走らせる人がいなければ何も検知しない。**だからテストに置く。
///
/// ★★ カード番号そのものをこのファイルに書かない ★★
/// 書くと**この走査自身が許可リストに載らない場所で当たる。**
/// → `AppSettings.defaults.energyFillPrintingId` から**取り出す。**
/// 同じものを 2 箇所に書かないという規約（`ルール整合性チェック_v1.06.md` D-15）に従う。
///
/// ★★ 陽性対照を対で置く ★★
/// 走査器が**実際に当たる**ことを先に確かめる。
/// 正規表現が壊れて 0 件になっていたら、下の「許可リストと一致」は
/// **「無い」ではなく「見えていない」**を意味する（**D-10** の教訓）。
///
/// ★★ 判定は「0 件」ではなく「許可リストと完全一致」★★
/// 0 件では書けない（既定値が 1 件あるため）。**3 件目が増えたら落ちる**形にする。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:path/path.dart' as p;

/// 走査する本番コード。★`test/` と `spike/` は含めない。
/// テストは fixture としてカード番号を持つのが正常で、
/// `spike/` は本実装ではない（**D51**）。
const _libRoots = <String>[
  'lib',
  '../loveca-core/lib',
  '../loveca-db/lib',
];

/// ★許可リスト（ファイル名 → 件数）。
///
/// | ファイル | 何件 | なぜ許すか |
/// |---|---|---|
/// | `app_settings.dart` | 1 | ★**決定 D97 の既定値。**唯一の例外 |
/// | `deck_share_import_dialog.dart` | 1 | ★**入力欄の見本**（`hintText`）。カードを**解決する**用途ではない |
///
/// ★**この 2 つを混ぜて数えないこと。**格が違う。
const _allowed = <String, int>{
  'app_settings.dart': 1,
  'deck_share_import_dialog.dart': 1,
};

/// カード番号らしい文字列。
///
/// 実データの形（`LL-E-002` / `LL-bp1-001` / `PL!N-bp1-034-PE` /
/// `PL!HS-PR-013-PR` / `PL!SP-sd1-003`）から起こしてある。
/// ★先頭を大文字に限るので、日付（`2026-08-25`）や `utf-8` には当たらない。
final _cardNumberLike = RegExp(r'[A-Z][A-Za-z!]*-[A-Za-z0-9]+-[A-Za-z0-9+]+');

/// [source] から**コメントを取り除いた**うえで、文字列リテラルの中身だけを返す。
///
/// ★★ コメントを外すのが要点である ★★
/// `lib/` にはカード番号を**説明として**書いたコメントが 3 件ある
/// （`deck_share.dart` の書式例 / `deck_pane.dart` の幅の根拠 /
/// `card_search_schema.dart` の検索の説明）。
/// **それらは実行されないので数えない。**
List<String> stringLiteralsOf(String source) {
  final out = <String>[];
  final buffer = StringBuffer();
  var i = 0;
  String? quote; // 文字列の中にいるなら、その引用符

  while (i < source.length) {
    final c = source[i];

    if (quote != null) {
      if (c == r'\') {
        // ★エスケープは 2 文字まとめて飛ばす。`\'` で閉じたと誤らないため。
        i += 2;
        continue;
      }
      if (c == quote) {
        out.add(buffer.toString());
        buffer.clear();
        quote = null;
        i++;
        continue;
      }
      // ★改行をまたぐ生の文字列も、そのまま溜めてよい（中身しか見ないため）。
      buffer.write(c);
      i++;
      continue;
    }

    // 行コメント
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    // ブロックコメント
    if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      i++;
      continue;
    }
    i++;
  }
  return out;
}

/// [root] 以下の `.dart` を走査して ファイル名 → 当たった件数 を返す。
Map<String, int> scan(String root) {
  final hits = <String, int>{};
  final dir = Directory(root);
  if (!dir.existsSync()) return hits;
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    var count = 0;
    for (final literal in stringLiteralsOf(entity.readAsStringSync())) {
      count += _cardNumberLike.allMatches(literal).length;
    }
    if (count > 0) hits[p.split(entity.path).last] = count;
  }
  return hits;
}

void main() {
  group('★★ 陽性対照 —— 走査器が実際に当たること ★★', () {
    test('★既定値そのものがカード番号として当たる', () {
      // ★空文字なら下の検査は何も証明しない。
      expect(kDefaultEnergyFillPrintingId, isNotEmpty);
      expect(AppSettings.defaults.energyFillPrintingId,
          kDefaultEnergyFillPrintingId);
      expect(_cardNumberLike.hasMatch(kDefaultEnergyFillPrintingId), isTrue,
          reason: '★正規表現が既定値に当たらないなら、走査は何も見ていない');
    });

    test('★既定値は `app_settings.dart` の文字列リテラルとして在る', () {
      final literals = stringLiteralsOf(
        File(p.join('lib', 'src', 'data', 'app_settings.dart'))
            .readAsStringSync(),
      );

      expect(literals, contains(kDefaultEnergyFillPrintingId));
    });

    test('★★ コメントは数えない（対）★★', () {
      const source = '''
// LL-bp1-001 x4
/// PL!N-bp1-034-PE
/* LL-E-002-SD */
const a = 'LL-E-999-SD';
''';

      final literals = stringLiteralsOf(source);

      // ★当たるのはリテラルの 1 件だけ。コメントの 3 件は消えている。
      expect(literals, ['LL-E-999-SD']);
    });

    test('★★ 日付や `utf-8` には当たらない（誤検知の対）★★', () {
      const source = "const a = '2026-08-25'; const b = 'utf-8';";

      final hits = stringLiteralsOf(source)
          .expand(_cardNumberLike.allMatches)
          .toList();

      expect(hits, isEmpty);
    });
  });

  test('★★ 本番コードのカード番号リテラルは許可リストと完全に一致する ★★', () {
    final found = <String, int>{};
    for (final root in _libRoots) {
      found.addAll(scan(root));
    }

    expect(
      found,
      _allowed,
      reason: '★増えていたら、それは本番コードに 3 件目のカード番号が入ったという意味である。\n'
          '  決定 D97 は「例外は既定値の 1 箇所だけ」と定めている。\n'
          '  種別からの導出（CardType.energy）か、利用者設定に置くこと。',
    );
  });

  test('★対: 走査した根が 3 つとも実在する', () {
    // ★根の綴りを間違えると `scan` は静かに空を返し、上の検査が通ってしまう。
    for (final root in _libRoots) {
      expect(Directory(root).existsSync(), isTrue, reason: '$root が無い');
    }
  });
}
