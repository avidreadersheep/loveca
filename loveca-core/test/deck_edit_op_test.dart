/// デッキ編集の操作の語彙（決定 D110-1 / `lib/src/sync/deck_edit_op.dart`）.
///
/// ★★ この版で固定するのは「語彙」だけである ★★
/// 引数も、書く時点も、未知キーの方針も**決まっていない**（`docs/同期設計メモ.md` §17-9-2）。
/// → ★**それらを固定するテストを書かない。**書くと決めたことになる。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

void main() {
  group('★ キーは永続化と同期の字面である', () {
    test('★★ 重複が無い（★同じキーが 2 つあると読み戻せない）★★', () {
      final keys = DeckEditOpKind.values.map((k) => k.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('★ 空のキーが無い', () {
      for (final kind in DeckEditOpKind.values) {
        expect(kind.key, isNotEmpty, reason: '★$kind のキーが空');
      }
    });

    test('★★ キーは Dart の識別子の写しではない ★★', () {
      // ★★ 陽性対照そのもの ★★
      //   すべて一致していたら「`name` を使えばよい」ことになり、
      //   `key` を別に持つ意味が**この検査からは読み取れない。**
      //   → ★**わざと違えてある 1 件が在ることを固定する**（`deleteDeck` / 記録点のメソッド名）。
      final differing =
          DeckEditOpKind.values.where((k) => k.key != k.name).toList();
      expect(differing, isNotEmpty,
          reason: '★1 件も違わないなら `key` は `name` の写しでしかない');
      expect(differing, contains(DeckEditOpKind.deleteDeck));
      expect(DeckEditOpKind.deleteDeck.key, 'softDelete');
    });

    test('★ 対: 残りは識別子と同じ字面である（★規則が 1 つであることの裏）', () {
      // ★キーの規則は「記録点のメソッド名」であり、9 操作では識別子と一致する。
      //   ★**一致していること自体は偶然ではない**ので、崩れたら気づけるようにする。
      for (final kind in DeckEditOpKind.values) {
        if (kind == DeckEditOpKind.deleteDeck) continue;
        expect(kind.key, kind.name, reason: '★$kind のキーの付け方が変わった');
      }
    });
  });

  group('★ tryFromKey', () {
    test('★ 既知のキーは引ける', () {
      for (final kind in DeckEditOpKind.values) {
        expect(DeckEditOpKind.tryFromKey(kind.key), kind);
      }
    });

    test('★★ 対: 知らないキーは null（★例外を投げない）★★', () {
      // ★★ この対が無いと、上の「引ける」は何でも返す実装でも通る ★★
      expect(DeckEditOpKind.tryFromKey('こんなキーは無い'), isNull);
      expect(DeckEditOpKind.tryFromKey(''), isNull);
      // ★識別子で引いても当たらない（`deleteDeck` はキーではない）。
      expect(DeckEditOpKind.tryFromKey(DeckEditOpKind.deleteDeck.name), isNull);
    });

    test('★ null を返すことは「寛容にする」決定ではない（★方針は記録層 / N-12）', () {
      // ★★ 決めていないことを決めたことにしない ★★
      //   ここで例外を投げる実装に変えたくなったら、先に N-12 を決めること。
      //   この test は「投げない」という**現在の形**を固定しているだけである。
      expect(() => DeckEditOpKind.tryFromKey('未知'), returnsNormally);
    });
  });

  group('★ 語彙の範囲', () {
    test('★★ 削除が語彙に入っている（穴 (c) を塞ぐ先 / 決定 D110-3）★★', () {
      expect(DeckEditOpKind.values, contains(DeckEditOpKind.deleteDeck));
    });

    test('★ 並べ替えが語彙に入っている（★`ord` に答えを持つ操作 / 決定 D99）', () {
      expect(DeckEditOpKind.values, contains(DeckEditOpKind.moveEntry));
      expect(DeckEditOpKind.values, contains(DeckEditOpKind.sortByRule));
    });

    test('★★ 引数の型を 1 つも持たない（★決めていないことを型で決めない）★★', () {
      // ★★ 「無い」ことは走査できない（D-15 (h)）が、ここは列挙の形なので確かめられる ★★
      //   enum の値が持つのは `key` だけである。★引数を足した人はここが落ちる。
      expect(DeckEditOpKind.deleteDeck.key, isA<String>());
      expect(DeckEditOpKind.values.first.toString(), startsWith('DeckEditOpKind.'));
    });
  });
}
