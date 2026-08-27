/// デッキの並びの規則（決定 D99）のテスト.
///
/// ★★ 投入順と期待順が食い違うフィクスチャで測る ★★
/// 一致するデータで測ると、`compareDeckOrder` が**常に 0 を返す実装**（no-op）でも
/// 全部通ってしまう。`sort` は入力順を保つからである。
/// → **各テストの冒頭で「投入順 ≠ 期待順」を先に検査する**（下の [_expectScrambled]）。
///   これが陽性対照であり、フィクスチャを整列済みに直した人はここで落ちる。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// フィクスチャ
// ---------------------------------------------------------------------------

/// 並びに要る値だけを持つ表。★実データの形は `loveca-ui` 側で見る（役割を混ぜない）。
const _keys = <String, DeckOrderKey>{
  // メンバー（cost 降順）。★同値 2 枚を含む
  'M-hi': DeckOrderKey(cardType: CardType.member, cost: 9),
  'M-mid-b': DeckOrderKey(cardType: CardType.member, cost: 4),
  'M-mid-a': DeckOrderKey(cardType: CardType.member, cost: 4),
  'M-lo': DeckOrderKey(cardType: CardType.member, cost: 2),
  'M-null': DeckOrderKey(cardType: CardType.member),
  // ライブ（score 降順）
  'L-hi': DeckOrderKey(cardType: CardType.live, score: 9),
  'L-mid': DeckOrderKey(cardType: CardType.live, score: 5),
  'L-lo': DeckOrderKey(cardType: CardType.live, score: 0),
  'L-null': DeckOrderKey(cardType: CardType.live),
  // エネルギー（軸が無い。printingId 昇順だけが効く）
  'E-a': DeckOrderKey(cardType: CardType.energy),
  'E-b': DeckOrderKey(cardType: CardType.energy),
  'E-c': DeckOrderKey(cardType: CardType.energy),
  // ★マスタに無い刷り（決定 D35）。表に載せない
};

DeckOrderKey _keyOf(String printingId) =>
    _keys[printingId] ?? DeckOrderKey.unknown;

List<DeckEntry> _entries(List<String> ids) =>
    [for (final id in ids) DeckEntry(printingId: id, count: 1)];

List<String> _ids(List<DeckEntry> entries) =>
    [for (final e in entries) e.printingId];

/// ★★ 陽性対照 ★★
/// 投入順が期待順と同じなら、比較器が何もしなくても通る。
/// フィクスチャがその形になっていないことを**先に**確かめる。
void _expectScrambled(List<String> input, List<String> expected) {
  expect(
    input,
    isNot(equals(expected)),
    reason: '投入順が期待順と同じでは、比較器が no-op でもこのテストは通る。'
        'フィクスチャを崩すこと（決定 D99 のテストの作法）',
  );
}

void _expectOrder(List<String> input, List<String> expected) {
  _expectScrambled(input, expected);
  expect(_ids(sortedByDeckOrder(_entries(input), _keyOf)), equals(expected));
}

void main() {
  group('段 1 — 区分順（決定 D99）', () {
    test('メンバー → ライブ → エネルギー → 未知', () {
      _expectOrder(
        ['E-a', 'X-unknown', 'L-hi', 'M-hi'],
        ['M-hi', 'L-hi', 'E-a', 'X-unknown'],
      );
    });

    test('★マスタに無い刷りは末尾に残る（決定 D35: 黙って捨てない）', () {
      final sorted = sortedByDeckOrder(
        _entries(['X-b', 'M-hi', 'X-a', 'E-a']),
        _keyOf,
      );
      // ★消えていないこと。並びより先にこれを見る。
      expect(sorted.length, 4);
      expect(_ids(sorted), ['M-hi', 'E-a', 'X-a', 'X-b']);
    });

    test('★未知どうしは printingId 昇順（段 3 だけが効く）', () {
      _expectOrder(['X-c', 'X-a', 'X-b'], ['X-a', 'X-b', 'X-c']);
    });
  });

  group('段 2 — 区分ごとの軸（決定 D99）', () {
    test('メンバーは cost 降順', () {
      _expectOrder(['M-lo', 'M-mid-a', 'M-hi'], ['M-hi', 'M-mid-a', 'M-lo']);
    });

    test('ライブは score 降順', () {
      _expectOrder(['L-lo', 'L-mid', 'L-hi'], ['L-hi', 'L-mid', 'L-lo']);
    });

    test('★score 0 は null ではない —— 末尾ではなく最小として並ぶ', () {
      // ★実データのライブは score の値域が 0〜9（`docs/UI設計メモ.md` §12-2 事実 2）。
      //   0 を「値が無い」と混同すると、実在する最小値が null と同じ扱いになる。
      _expectOrder(
        ['L-null', 'L-lo', 'L-hi'],
        ['L-hi', 'L-lo', 'L-null'],
      );
    });

    test('★エネルギーには軸が無い —— printingId 昇順だけが効く', () {
      _expectOrder(['E-c', 'E-a', 'E-b'], ['E-a', 'E-b', 'E-c']);
    });

    test('★エネルギーは cost / score を持っていても見ない（区分で軸が決まる）', () {
      // ★実データのエネルギーは全件空だが（§12-2 事実 1）、
      //   「値が無いから並ばない」のではなく「区分に軸が無い」ことを固定する。
      DeckOrderKey keyOf(String id) => switch (id) {
            'E-x' => const DeckOrderKey(
                cardType: CardType.energy, cost: 1, score: 1),
            'E-y' => const DeckOrderKey(
                cardType: CardType.energy, cost: 99, score: 99),
            _ => DeckOrderKey.unknown,
          };
      // cost 降順なら E-y が先。★printingId 昇順なので E-x が先になる。
      expect(
        _ids(sortedByDeckOrder(_entries(['E-y', 'E-x']), keyOf)),
        ['E-x', 'E-y'],
      );
    });
  });

  group('★ null は末尾（決定 D99）', () {
    test('メンバーの cost が null なら末尾', () {
      _expectOrder(
        ['M-null', 'M-lo', 'M-hi'],
        ['M-hi', 'M-lo', 'M-null'],
      );
    });

    test('ライブの score が null なら末尾', () {
      _expectOrder(['L-null', 'L-lo', 'L-hi'], ['L-hi', 'L-lo', 'L-null']);
    });

    test('★対: null が 2 枚あっても printingId 昇順で決まる', () {
      DeckOrderKey keyOf(String id) => const DeckOrderKey(
            cardType: CardType.member,
          );
      expect(
        _ids(sortedByDeckOrder(_entries(['M-z', 'M-a']), keyOf)),
        ['M-a', 'M-z'],
      );
    });

    test('★対: 値がある札は必ず null より前（降順の端に落ちない）', () {
      // ★「null を先頭に置く実装」だと落ちる。
      DeckOrderKey keyOf(String id) => switch (id) {
            // ★名前は昇順で null 側が先。段 3 では救えない配置にしてある。
            'M-a-null' => const DeckOrderKey(cardType: CardType.member),
            'M-z-min' =>
              const DeckOrderKey(cardType: CardType.member, cost: 0),
            _ => DeckOrderKey.unknown,
          };
      expect(
        _ids(sortedByDeckOrder(_entries(['M-a-null', 'M-z-min']), keyOf)),
        ['M-z-min', 'M-a-null'],
      );
    });
  });

  group('段 3 — 副次キー（決定 D99）', () {
    test('cost が同値なら printingId 昇順', () {
      _expectOrder(['M-mid-b', 'M-mid-a'], ['M-mid-a', 'M-mid-b']);
    });

    test('★同じ入力を並べ替えた 2 通りから同じ結果が出る（一意である）', () {
      const ids = ['M-mid-b', 'M-hi', 'M-mid-a', 'M-lo'];
      final a = _ids(sortedByDeckOrder(_entries(ids), _keyOf));
      final b = _ids(sortedByDeckOrder(_entries(ids.reversed.toList()), _keyOf));
      expect(a, equals(b));
      // ★no-op なら a と b は互いに逆順になり、ここで落ちる。
      expect(a, ['M-hi', 'M-mid-a', 'M-mid-b', 'M-lo']);
    });
  });

  group('sortedByDeckOrder', () {
    test('元のリストを変更しない', () {
      final original = _entries(['E-a', 'M-hi']);
      final before = _ids(original);
      sortedByDeckOrder(original, _keyOf);
      expect(_ids(original), equals(before));
    });

    test('★枚数を落とさない（並べ替えであって集約ではない）', () {
      final sorted = sortedByDeckOrder(
        [
          const DeckEntry(printingId: 'M-hi', count: 3),
          const DeckEntry(printingId: 'M-lo', count: 2),
        ],
        _keyOf,
      );
      expect(sorted.map((e) => e.count).toList(), [3, 2]);
    });

    test('全区分を混ぜた通し', () {
      _expectOrder(
        [
          'E-b',
          'L-lo',
          'M-mid-b',
          'X-a',
          'M-hi',
          'L-hi',
          'E-a',
          'M-mid-a',
          'M-null',
          'L-null',
        ],
        [
          'M-hi',
          'M-mid-a',
          'M-mid-b',
          'M-null',
          'L-hi',
          'L-lo',
          'L-null',
          'E-a',
          'E-b',
          'X-a',
        ],
      );
    });
  });

  group('deckOrderInsertionIndex（決定 D99）', () {
    test('規則順に並んだリストの正しい位置に入る', () {
      final list = _entries(['M-hi', 'M-lo', 'L-hi', 'E-a']);
      expect(deckOrderInsertionIndex(list, 'M-mid-a', _keyOf), 1);
      expect(deckOrderInsertionIndex(list, 'L-lo', _keyOf), 3);
      expect(deckOrderInsertionIndex(list, 'E-b', _keyOf), 4);
    });

    test('★先頭に来るべき札は 0', () {
      final list = _entries(['M-lo', 'L-hi']);
      expect(deckOrderInsertionIndex(list, 'M-hi', _keyOf), 0);
    });

    test('★最後に来るべき札は末尾（見つからなければ length）', () {
      final list = _entries(['M-hi', 'L-hi']);
      expect(deckOrderInsertionIndex(list, 'X-a', _keyOf), 2);
    });

    test('空のリストには 0', () {
      expect(deckOrderInsertionIndex(const [], 'M-hi', _keyOf), 0);
    });

    test('★手動順が混ざったリストでは「規則順の正しい位置」とは限らない', () {
      // ★決定 D99 が明記している性質そのものを固定する。
      //   ここが変わったら、決定文のほうも直す必要がある。
      final scrambled = _entries(['M-lo', 'M-hi']); // ★規則順ではない
      // 規則順なら M-mid-a は M-hi の後・M-lo の前（= 添字 1）に来るはずだが、
      // ★このリストでは「自分より後ろに来る最初の札」が M-lo（添字 0）なので 0 になる。
      expect(deckOrderInsertionIndex(scrambled, 'M-mid-a', _keyOf), 0);
    });

    test('★挿入してから並べ替えると規則順になる（挿入位置は最終形を縛らない）', () {
      final scrambled = _entries(['M-lo', 'M-hi']);
      final at = deckOrderInsertionIndex(scrambled, 'M-mid-a', _keyOf);
      final inserted = [...scrambled]
        ..insert(at, const DeckEntry(printingId: 'M-mid-a', count: 1));
      expect(
        _ids(sortedByDeckOrder(inserted, _keyOf)),
        ['M-hi', 'M-mid-a', 'M-lo'],
      );
    });
  });

  group('compareDeckOrder', () {
    test('同じ刷りどうしは 0', () {
      expect(compareDeckOrder('M-hi', 'M-hi', _keyOf), 0);
    });

    test('★向きが逆になる（反対称）', () {
      expect(compareDeckOrder('M-hi', 'M-lo', _keyOf), lessThan(0));
      expect(compareDeckOrder('M-lo', 'M-hi', _keyOf), greaterThan(0));
    });

    test('★推移する（区分をまたいでも）', () {
      expect(compareDeckOrder('M-hi', 'L-hi', _keyOf), lessThan(0));
      expect(compareDeckOrder('L-hi', 'E-a', _keyOf), lessThan(0));
      expect(compareDeckOrder('M-hi', 'E-a', _keyOf), lessThan(0));
    });
  });
}
