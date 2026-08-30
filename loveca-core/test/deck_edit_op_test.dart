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

  group('★ 記録 1 件（DeckEditOpRecord / §17-9-7 の commit 4）', () {
    final at = DateTime.utc(2026, 8, 30, 12, 34, 56);

    test('★ kind と at がそのまま読める', () {
      const kind = DeckEditOpKind.moveEntry;
      final DeckEditOpRecord record = (kind: kind, at: at);
      expect(record.kind, kind);
      expect(record.at, at);
    });

    test('★★ 形が型である —— フィールドを足すと別の型になる ★★', () {
      // ★★ これが「引数を足させない」構造の実物である ★★
      //   名前つきクラスならフィールドを 1 行足すだけで増やせる（署名は動かない）。
      //   record は形そのものが型なので、足した瞬間に代入が通らなくなる。
      //   → ★**§17-9-2 の 2 / 4（引数 / `sortByRule` の入れ方）を型で倒さない。**
      final Object exact = (kind: DeckEditOpKind.setName, at: at);
      expect(exact, isA<DeckEditOpRecord>());

      // ★対: 引数を 1 つ足した形は **DeckEditOpRecord ではない**。
      final Object withArgument =
          (kind: DeckEditOpKind.addCard, at: at, printingId: 'PL!HS-bp1-012-N');
      expect(withArgument, isNot(isA<DeckEditOpRecord>()));

      // ★対: 片方だけでも成り立たない（★2 つとも必須である）。
      expect(<Object>[
        (kind: DeckEditOpKind.setName,),
        (at: at,),
      ], everyElement(isNot(isA<DeckEditOpRecord>())));
    });

    test('★ 削除も同じ形で持てる（★記録点は違うが型は 1 つ / D110-3）', () {
      // ★`softDelete` は `DeckDao` が記録し、9 操作は `DeckEditStore` が記録する
      //   （**D110-2** / **D110-3**）が、★**ログの 1 行としては同じ形**である。
      final DeckEditOpRecord record = (kind: DeckEditOpKind.deleteDeck, at: at);
      expect(record.kind.key, 'softDelete');
    });

    test('★★ deckId を持たない（★保存の相手は引数で決まっている）★★', () {
      // ★★ 同じものを 2 か所に持たない（`CLAUDE.md` §3 の規約）★★
      //   `DeckDao.save(deck, ops: ...)` の `deck` と
      //   `DeckDao.softDelete(deckId, at)` の `deckId` が既に相手を決めている。
      //   → ★ここに持たせると食い違いうる。
      final Object withDeckId =
          (kind: DeckEditOpKind.setName, at: at, deckId: 'deck-1');
      expect(withDeckId, isNot(isA<DeckEditOpRecord>()));
    });
  });
}
