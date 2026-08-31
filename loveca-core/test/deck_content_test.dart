/// 内容ハッシュの入力の正規化された表現（決定 **D115-3** / `lib/src/sync/deck_content.dart`）.
///
/// ★★ この版で固定するのは「表現」だけである ★★
/// ハッシュは 1 バイトも作らない（★コミット 12）。★衝突判定も解決も無い。
/// → ★**それらを固定するテストを書かない。**書くと決めたことになる。
///
/// ★★ 対を置いたら、対象を壊して対が落ちることを実測する（**D-27**）★★
/// この群の対は 3 種類ある ——
/// (1) ★**掴む 5 フィールド**が入ること / (2) ★**掴まない 7 フィールド**が入らないこと /
/// (3) ★**長さ前置が無い実装なら作れる衝突**が作れないこと。
/// ★実測した内訳は `CLAUDE.md` §3 に置いた。
library;

import 'dart:convert';

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

/// 比べやすくするための土台。★5 フィールドは全部「空でない」値を持たせる。
final _base = Deck(
  deckId: 'deck-content-base',
  name: 'ベースのデッキ',
  entries: const [
    DeckEntry(printingId: 'PL!N-bp1-034-PE', count: 4),
    DeckEntry(printingId: 'LL-E-002-SD', count: 12),
  ],
  memo: 'めも',
  tags: const ['タグA', 'タグB'],
  coverPrintingId: 'PL!N-bp1-034-PE',
  createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  updatedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
  revision: 7,
  lastDeviceId: 'device-1',
  masterDataVersion: 2,
);

String _text(Deck deck) => utf8.decode(canonicalDeckContentBytes(deck));

void main() {
  group('★ 表現そのもの', () {
    test('★ 版タグが先頭に在る', () {
      expect(_text(_base), startsWith(canonicalDeckContentVersion));
    });

    test('★★ 表現そのものを 1 バイト残らず固定する（決定 D115-3）★★', () {
      // ★★ この 1 件がこの群の要石である ★★
      //   **D115-3** が要求しているのは「★表現を★固定すること」であって、
      //   「★衝突しにくいこと」ではない。★下の個別の対は**なぜその形なのか**を
      //   書き残すためのもので、★**形を決めているのはこの golden である。**
      //
      // ★★ ここを黙って書き換えないこと ★★
      //   書き換えると、保存済みの基準ハッシュ（器 / **D114-1**）が全部意味を失う。
      //   ★変えるときは [canonicalDeckContentVersion] を上げ、器の作り直しと同時に行う。
      final deck = Deck(
        deckId: 'golden に入らない',
        name: 'なまえ',
        entries: const [
          DeckEntry(printingId: 'AB', count: 4),
          DeckEntry(printingId: 'C', count: 12),
        ],
        memo: 'めも',
        tags: const ['t1', 'タグ'],
        coverPrintingId: 'AB',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        revision: 3,
        lastDeviceId: 'golden に入らない',
        masterDataVersion: 9,
      );

      expect(
        _text(deck),
        'loveca.deck.content/1'
        '9:なまえ' // name（★日本語 3 文字 = 9 バイト）
        '6:めも' // memo
        '+2:AB' // coverPrintingId（★`+` は「在る」/ `-` は null）
        '2;2:t16:タグ' // tags（★件数 2 → 値 2 つ）
        '2;2:AB1:41:C2:12', // entries（★件数 2 → 刷り番号と枚数を交互に）
      );
      expect(canonicalDeckContentBytes(deck), hasLength(75));
    });

    test('★ 枚数も長さ前置つきで書く（★規則を 1 つに保つ）', () {
      // ★★ 落とすと衝突が作れるが、対を組めなかった ★★
      //   枚数は十進の数字列で、後続は必ず「桁数 + `:`」である。
      //   ★衝突を作るには**21 桁の枚数**が要り、int の範囲を超える（★実測で 0 件）。
      //   → ★**形を直に見る。**上の golden も同じ位置を見ている。
      final deck = _base.copyWith(
          tags: const [],
          entries: const [DeckEntry(printingId: 'AB', count: 4)]);
      expect(_text(deck), contains('2:AB1:4'));
    });

    test('★ 同じ Deck からは何度呼んでも同じバイト列が出る', () {
      expect(canonicalDeckContentBytes(_base),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('★★ 別のインスタンスでも、5 フィールドが同じなら同じ ★★', () {
      // ★★ 「同じ内容」の定義そのものである ★★
      //   ここが同一性（`identical`）に依存していたら、2 台で一致しようがない。
      final twin = Deck(
        deckId: 'まったく別の deckId',
        name: _base.name,
        entries: _base.entries
            .map((e) => DeckEntry(printingId: e.printingId, count: e.count))
            .toList(),
        memo: _base.memo,
        tags: [..._base.tags],
        coverPrintingId: _base.coverPrintingId,
        createdAt: DateTime.utc(1999),
        updatedAt: DateTime.utc(1999),
        revision: 999,
        lastDeviceId: 'まったく別の端末',
        masterDataVersion: 999,
      );
      expect(canonicalDeckContentBytes(twin),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('★★ UTF-8 である（日本語がそのバイト列になる）★★', () {
      // ★★ 「端末をまたいで安定」の下半分である ★★
      //   表現が文字列で止まっていると、バイトに落とす段が端末ごとに違いうる。
      final deck = _base.copyWith(name: 'あ', memo: '', tags: const []);
      final bytes = canonicalDeckContentBytes(deck);
      expect(bytes, containsAllInOrder(utf8.encode('3:あ')));
      // ★対: 3 は文字数ではなくバイト数である。
      expect(_text(deck), isNot(contains('1:あ')));
    });
  });

  group('★★ 掴む 5 フィールド（決定 D111-4）★★', () {
    test('name を変えると表現が変わる', () {
      expect(canonicalDeckContentBytes(_base.copyWith(name: '別の名前')),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('memo を変えると表現が変わる', () {
      expect(canonicalDeckContentBytes(_base.copyWith(memo: '別のめも')),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('coverPrintingId を変えると表現が変わる', () {
      expect(
          canonicalDeckContentBytes(
              _base.copyWith(coverPrintingId: 'LL-E-002-SD')),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('tags を変えると表現が変わる', () {
      expect(canonicalDeckContentBytes(_base.copyWith(tags: const ['タグA'])),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('枚数を変えると表現が変わる', () {
      expect(
          canonicalDeckContentBytes(_base.copyWith(entries: const [
            DeckEntry(printingId: 'PL!N-bp1-034-PE', count: 3),
            DeckEntry(printingId: 'LL-E-002-SD', count: 12),
          ])),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('★★ 並べ替えただけでも表現が変わる（決定 D99）★★', () {
      // ★★ 並びは保存される（`deck_entries.ord`）★★
      //   ここで並べ替えを畳むと、「並べ替えただけの変更」が黙って消える。
      //   `DeckDraft.isDirtyAgainst` は並びを見るので、**画面と食い違う。**
      final reversed = _base.copyWith(entries: _base.entries.reversed.toList());
      expect(canonicalDeckContentBytes(reversed),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('★ tags の並びも見る', () {
      final reversed = _base.copyWith(tags: _base.tags.reversed.toList());
      expect(canonicalDeckContentBytes(reversed),
          isNot(canonicalDeckContentBytes(_base)));
    });

    test('★★ 文字列を 1 文字も畳まない —— 大小 ★★', () {
      // ★★ 折りたたみは検索用シャドウ列の中だけの話である（決定 D40）★★
      //   ここで畳むと、**画面が「変更あり」と言うのにハッシュが一致する**
      //   状態が作れる（`DeckDraft.isDirtyAgainst` は畳まない / **D111-4**）。
      expect(canonicalDeckContentBytes(_base.copyWith(name: 'abc')),
          isNot(canonicalDeckContentBytes(_base.copyWith(name: 'ABC'))));
    });

    test('★★ 文字列を 1 文字も畳まない —— 全角半角 ★★', () {
      // ★実データに表記ゆれが在る（`CLAUDE.md` §5-(5)）。★寄せるのは正規化層の仕事で、
      //   ここではない。★寄せると「直したのに同期で戻る」が作れる。
      expect(canonicalDeckContentBytes(_base.copyWith(name: 'ａ')),
          isNot(canonicalDeckContentBytes(_base.copyWith(name: 'a'))));
    });

    test('★ coverPrintingId の null と空文字は別の表現になる', () {
      // ★`copyWith` は null で「据え置き」なので、明示コンストラクタで作る。
      Deck withCover(String? cover) => Deck(
            deckId: _base.deckId,
            name: _base.name,
            entries: _base.entries,
            memo: _base.memo,
            tags: _base.tags,
            coverPrintingId: cover,
            createdAt: _base.createdAt,
            updatedAt: _base.updatedAt,
          );
      expect(canonicalDeckContentBytes(withCover(null)),
          isNot(canonicalDeckContentBytes(withCover(''))));
    });
  });

  group('★★ 掴まない 7 フィールド（★対。★これが無いと D111-4 の柵を見ていない）★★',
      () {
    // ★★ `Deck.toJson()` を素直に使うと、この群が丸ごと落ちる ★★
    //   保存のたびに `updatedAt` / `revision` が動くので、候補 L の
    //   「内容が一致するものを落とす」段が 1 度も働かなくなる（**D111-4**）。
    test('deckId は入らない', () {
      final other = Deck(
        deckId: 'まったく別の deckId',
        name: _base.name,
        entries: _base.entries,
        memo: _base.memo,
        tags: _base.tags,
        coverPrintingId: _base.coverPrintingId,
        createdAt: _base.createdAt,
        updatedAt: _base.updatedAt,
        revision: _base.revision,
        lastDeviceId: _base.lastDeviceId,
        masterDataVersion: _base.masterDataVersion,
      );
      expect(canonicalDeckContentBytes(other),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('createdAt / masterDataVersion は入らない', () {
      final other = Deck(
        deckId: _base.deckId,
        name: _base.name,
        entries: _base.entries,
        memo: _base.memo,
        tags: _base.tags,
        coverPrintingId: _base.coverPrintingId,
        createdAt: DateTime.utc(1999, 12, 31),
        updatedAt: _base.updatedAt,
        revision: _base.revision,
        lastDeviceId: _base.lastDeviceId,
        masterDataVersion: 12345,
      );
      expect(canonicalDeckContentBytes(other),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('updatedAt は入らない', () {
      expect(
          canonicalDeckContentBytes(
              _base.copyWith(updatedAt: DateTime.utc(2030))),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('revision は入らない', () {
      expect(canonicalDeckContentBytes(_base.copyWith(revision: 999)),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('lastDeviceId は入らない', () {
      expect(
          canonicalDeckContentBytes(_base.copyWith(lastDeviceId: 'device-2')),
          equals(canonicalDeckContentBytes(_base)));
    });

    test('★★ deletedAt は入らない（決定 D116-12。★削除はここに 1 ビットも現れない）★★',
        () {
      // ★★ これは欠陥ではなく D111-4 の帰結である ★★
      //   「削除を見る手段はログ 1 つだけである」（**D116-12** / **D111-4**）。
      //   ★**論理削除だけが起きたデッキは、この関数の出力が 1 バイトも変わらない。**
      //   ★読む側（`deck_conflict.dart`）がこの性質を知っていなければならない。
      expect(
          canonicalDeckContentBytes(
              _base.copyWith(deletedAt: DateTime.utc(2026, 9, 1))),
          equals(canonicalDeckContentBytes(_base)));
    });
  });

  group('★★ 柵 2: 区切り文字だけの連結では作れる衝突（決定 D115-3）★★', () {
    // ★★ この群が長さ前置と件数前置そのものを見ている ★★
    //   ★`name` / `memo` / `tags` は自由文であり、利用者が区切りを中に入れられる。
    //
    // ★★ 「区切り 1 文字」を決め打ちにしない ★★
    //   最初の版は境界に**空白**を入れており、★NUL で連結する実装には当たらなかった
    //   （★実測で 2 件しか落ちなかった / **D-27**）。
    //   → ★**区切りの候補を並べ、境界ごとに全部当てる。**
    //   ★制御文字は字面で書かず符号位置から作る（**D-38**）。
    final separators = <String>[
      ' ',
      '|',
      ':',
      ';',
      '-',
      '+',
      '/',
      String.fromCharCode(0), // NUL（`DeckDraft._orderedCounts` が使う区切り）
      String.fromCharCode(9), // タブ
      String.fromCharCode(10), // 改行
    ];

    /// [sep] を境界に入れた 2 つが同じ表現にならないことを見る。
    void expectNoCollision(String label, Deck a, Deck b, String sep) {
      expect(canonicalDeckContentBytes(a), isNot(canonicalDeckContentBytes(b)),
          reason: '★$label / 符号位置 ${sep.codeUnitAt(0)} の区切りで衝突が作れる');
    }

    test('★★ 隣り合う値の境界を、どの区切りでもまたげない ★★', () {
      for (final sep in separators) {
        // name | memo
        expectNoCollision(
          'name|memo',
          _base.copyWith(name: 'あ', memo: 'い', tags: const []),
          _base.copyWith(name: 'あ$sepい', memo: '', tags: const []),
          sep,
        );
        // memo | coverPrintingId
        expectNoCollision(
          'memo|cover',
          _base.copyWith(memo: 'あ', coverPrintingId: 'い', tags: const []),
          _base.copyWith(memo: 'あ$sepい', coverPrintingId: '', tags: const []),
          sep,
        );
        // tags[0] | tags[1]
        expectNoCollision(
          'tags|tags',
          _base.copyWith(tags: ['あ', 'い']),
          _base.copyWith(tags: ['あ$sepい']),
          sep,
        );
        // tags の末尾 | entries[0].printingId
        expectNoCollision(
          'tags|printingId',
          _base.copyWith(tags: ['あ'], entries: const [
            DeckEntry(printingId: 'い', count: 1),
          ]),
          _base.copyWith(tags: ['あ$sepい'], entries: const [
            DeckEntry(printingId: '', count: 1),
          ]),
          sep,
        );
        // printingId | count
        expectNoCollision(
          'printingId|count',
          _base.copyWith(tags: const [], entries: const [
            DeckEntry(printingId: 'A', count: 1),
          ]),
          _base.copyWith(tags: const [], entries: [
            DeckEntry(printingId: 'A${sep}1', count: 1),
          ]),
          sep,
        );
        // entries[0].count | entries[1].printingId
        expectNoCollision(
          'count|printingId',
          _base.copyWith(tags: const [], entries: const [
            DeckEntry(printingId: 'A', count: 1),
            DeckEntry(printingId: 'B', count: 2),
          ]),
          _base.copyWith(tags: const [], entries: [
            DeckEntry(printingId: 'A', count: 1),
            DeckEntry(printingId: '${sep}B', count: 2),
          ]),
          sep,
        );
      }
    });

    test('★★ 件数の前置が要る —— 列と列の境目は長さ前置では割れない ★★', () {
      // ★★ 長さ前置だけでは足りない位置がある ★★
      //   `entries` は 1 件につき 2 つの値（刷り番号・枚数）を書く。
      //   → ★**タグ 2 つと、エントリ 1 件は、値の並びとしては同じ形になる。**
      //   ★件数を先に置くことで、どこまでが tags でどこからが entries かが定まる。
      //
      // ★最初の版は `['']` と `[]` を比べており、★これは長さ前置だけで割れる。
      //   ★**件数の前置を落としても 0 件しか落ちなかった**（★実測 / **D-27**）。
      final a = _base.copyWith(tags: const ['X', '5'], entries: const []);
      final b = _base.copyWith(tags: const [], entries: const [
        DeckEntry(printingId: 'X', count: 5),
      ]);
      expect(canonicalDeckContentBytes(a), isNot(canonicalDeckContentBytes(b)));
    });

    test('★ 対: 空の列と、空文字 1 つの列も分かれる', () {
      // ★上とは別の位置である。★こちらは長さ前置だけでも割れる（★弱い対だと明記する）。
      final a = _base.copyWith(tags: const []);
      final b = _base.copyWith(tags: const ['']);
      expect(canonicalDeckContentBytes(a), isNot(canonicalDeckContentBytes(b)));
    });

    test('★ 値そのものが長さ前置の形をしていても壊れない', () {
      // ★`"2:ab"` のような値を入れても、外側の長さ前置が先に来るので混ざらない。
      final a = _base.copyWith(name: '2:ab', memo: '');
      final b = _base.copyWith(name: '', memo: '2:ab');
      expect(canonicalDeckContentBytes(a), isNot(canonicalDeckContentBytes(b)));
    });
  });
}
