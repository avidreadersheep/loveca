/// デッキの内容ハッシュ（**N-18** / 決定 **D115-1** / **D115-2** /
/// `lib/src/sync/deck_content_hash.dart`）.
///
/// ★★ この版で固定するのは「1 個の値を作ること」だけである ★★
/// 衝突判定（候補 L / **D111-2**）も、器（**D114-1**）も、送受信も無い。
/// → ★**それらを固定するテストを書かない。**書くと決めたことになる。
///
/// ★★ golden は別の実装で検算してある（2026-09-01）★★
/// 下の 2 つの値は Python の `hashlib.sha256` で**独立に計算して一致を確かめた。**
/// ★**自分の出力を写しただけの golden は「自分と同じであること」しか言わない。**
/// ★2 台が交換する値なので、★**実装をまたいで同じであることが要求そのものである。**
library;

import 'package:crypto/crypto.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

final _base = Deck(
  deckId: 'deck-hash-base',
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

void main() {
  group('★★ golden —— 別の実装で検算した値 ★★', () {
    test('★★ 中身のあるデッキ ★★', () {
      // ★正規化された表現は
      //   `loveca.deck.content/19:なまえ6:めも+2:AB2;2:t16:タグ2;2:AB1:41:C2:12`（75 バイト）。
      //   ★その UTF-8 バイト列の SHA-256 を Python の `hashlib` で計算した値である。
      final deck = Deck(
        deckId: 'ハッシュに入らない',
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
        lastDeviceId: 'ハッシュに入らない',
        masterDataVersion: 9,
      );
      expect(
        deckContentHash(deck),
        'sha256:d641275b071254b58a1571bd21e3a22534409492fa181025cffd946ed4e52153',
      );
    });

    test('★ 5 フィールドが全部空のデッキ', () {
      // ★正規化された表現は `loveca.deck.content/10:0:-0;0;`（30 バイト）。
      //   ★`-` は `coverPrintingId` が null であることを表す。
      final deck = Deck(
        deckId: 'ハッシュに入らない',
        name: '',
        entries: const [],
        memo: '',
        tags: const [],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      expect(
        deckContentHash(deck),
        'sha256:5418e34baddb1a6411952e924390bbabf9486088b3ddb1f1dc4716752f97f718',
      );
    });
  });

  group('★ 字面', () {
    test('★ 接頭辞がつく（★どの関数で畳んだかを値が名乗る）', () {
      expect(deckContentHash(_base), startsWith(deckContentHashPrefix));
      expect(deckContentHashPrefix, 'sha256:');
    });

    test('★ 接頭辞を除くと 64 桁の小文字 16 進である', () {
      final hex = deckContentHash(_base).substring(deckContentHashPrefix.length);
      expect(hex, hasLength(64));
      expect(hex, matches(RegExp(r'^[0-9a-f]{64}$')));
    });
  });

  group('★★ 固定した表現の上に畳んでいる（★2 か所で組み立て直していない）★★', () {
    test('★★ 入力は canonicalDeckContentBytes そのものである ★★', () {
      // ★★ ここが 2 か所になった時点で「2 台が同じ値を出す」保証が消える ★★
      //   ★**関係を直に見る。**下の「別のインスタンスでも同じ」では見えない ——
      //   ★`Deck` から直に組み立て直す実装でも、★5 フィールドが同じなら同じ値になるので
      //   ★**通ってしまう**（★実測で確かめた / **D-27**）。
      expect(
        deckContentHash(_base),
        '$deckContentHashPrefix'
        '${sha256.convert(canonicalDeckContentBytes(_base))}',
      );
    });

    test('★ 別のインスタンスでも、5 フィールドが同じなら同じ値', () {
      final twin = Deck(
        deckId: 'まったく別の deckId',
        name: _base.name,
        entries: _base.entries,
        memo: _base.memo,
        tags: _base.tags,
        coverPrintingId: _base.coverPrintingId,
        createdAt: DateTime.utc(1999),
        updatedAt: DateTime.utc(1999),
        revision: 999,
        lastDeviceId: 'まったく別の端末',
        masterDataVersion: 999,
      );
      expect(deckContentHash(twin), deckContentHash(_base));
    });

    test('★ 同じ Deck からは何度呼んでも同じ値が出る', () {
      expect(deckContentHash(_base), deckContentHash(_base));
    });
  });

  group('★★ 内容が違えば値が違う（★候補 L の「落とす」段が働く条件）★★', () {
    test('name を変えると値が変わる', () {
      expect(deckContentHash(_base.copyWith(name: '別の名前')),
          isNot(deckContentHash(_base)));
    });

    test('枚数を変えると値が変わる', () {
      expect(
          deckContentHash(_base.copyWith(entries: const [
            DeckEntry(printingId: 'PL!N-bp1-034-PE', count: 3),
            DeckEntry(printingId: 'LL-E-002-SD', count: 12),
          ])),
          isNot(deckContentHash(_base)));
    });

    test('★ 並べ替えただけでも値が変わる（決定 D99）', () {
      expect(
          deckContentHash(
              _base.copyWith(entries: _base.entries.reversed.toList())),
          isNot(deckContentHash(_base)));
    });
  });

  group('★★ 対: 保存のたびに動く量は入らない（決定 D111-4 の柵）★★', () {
    // ★★ ここが落ちると候補 L が G に退化する ★★
    //   `updatedAt` / `revision` / `lastDeviceId` が入ると、
    //   **保存のたびに必ず値が変わる**ので「内容が一致するものを落とす」段が
    //   1 度も働かない（**D111-2** / **D111-4**）。
    test('updatedAt を変えても値が変わらない', () {
      expect(deckContentHash(_base.copyWith(updatedAt: DateTime.utc(2030))),
          deckContentHash(_base));
    });

    test('revision を変えても値が変わらない', () {
      expect(deckContentHash(_base.copyWith(revision: 999)),
          deckContentHash(_base));
    });

    test('lastDeviceId を変えても値が変わらない', () {
      expect(deckContentHash(_base.copyWith(lastDeviceId: 'device-2')),
          deckContentHash(_base));
    });

    test('★★ deletedAt を変えても値が変わらない（決定 D116-12）★★', () {
      // ★★ 削除は内容ハッシュに 1 ビットも現れない ★★
      //   ★これは欠陥ではなく **D111-4** の帰結である。
      //   ★削除を見る手段はログ 1 つだけである（**D116-12**）。
      expect(
          deckContentHash(_base.copyWith(deletedAt: DateTime.utc(2026, 9, 1))),
          deckContentHash(_base));
    });
  });
}
