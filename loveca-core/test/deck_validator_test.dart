import 'package:loveca_core/loveca_core.dart';
import 'package:test/test.dart';

/// テスト用のカードマスタを作る。
/// 同一 cardNumber に複数の printing (パラレル) がぶら下がる構造を再現する。
({Map<String, Card> cards, Map<String, Printing> printings}) _master() {
  final cards = <String, Card>{};
  final printings = <String, Printing>{};

  void add(String number, CardType type, List<String> rarities) {
    cards[number] = Card(
      cardNumber: number,
      name: number,
      cardType: type,
      cost: type == CardType.member ? 4 : null,
      bladeCount: type == CardType.member ? 2 : null,
      score: type == CardType.live ? 2 : null,
    );
    for (final rarity in rarities) {
      final id = '$number-$rarity';
      printings[id] = Printing(
        printingId: id,
        cardNumber: number,
        expansion: 'BP01',
        rarity: rarity,
        isParallel: rarity != 'R',
      );
    }
  }

  // メンバー 12 種 (うち 1 種はパラレルあり)
  for (var i = 1; i <= 12; i++) {
    final number = 'PL!N-bp1-${i.toString().padLeft(3, '0')}';
    add(number, CardType.member, i == 1 ? ['R', 'R+', 'SEC'] : ['R']);
  }
  // ライブ 3 種
  for (var i = 25; i <= 27; i++) {
    add('PL!N-bp1-${i.toString().padLeft(3, '0')}', CardType.live, ['L']);
  }
  // エネルギー 3 種
  for (var i = 30; i <= 32; i++) {
    add('PL!N-bp1-${i.toString().padLeft(3, '0')}', CardType.energy, ['LLE']);
  }

  return (cards: cards, printings: printings);
}

Deck _deck(List<DeckEntry> entries) => Deck(
      deckId: '00000000-0000-4000-8000-000000000000',
      name: 'test',
      entries: entries,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// 合法なデッキ: メンバー 48 / ライブ 12 / エネルギー 12
Deck _legalDeck() => _deck([
      for (var i = 1; i <= 12; i++)
        DeckEntry(printingId: 'PL!N-bp1-${i.toString().padLeft(3, '0')}-R', count: 4),
      for (var i = 25; i <= 27; i++)
        DeckEntry(printingId: 'PL!N-bp1-${i.toString().padLeft(3, '0')}-L', count: 4),
      for (var i = 30; i <= 32; i++)
        DeckEntry(printingId: 'PL!N-bp1-${i.toString().padLeft(3, '0')}-LLE', count: 4),
    ]);

void main() {
  final master = _master();
  final validator =
      DeckValidator(cards: master.cards, printings: master.printings);

  test('合法なデッキが通る (総合ルール 6.1.1)', () {
    final result = validator.validate(_legalDeck());
    expect(result.isValid, isTrue, reason: result.issues.join('\n'));
    expect(result.memberCount, 48);
    expect(result.liveCount, 12);
    expect(result.energyCount, 12);
  });

  test('★パラレル違いでも cardNumber 単位で合算される (6.1.1.2)', () {
    // 同じ cardNumber の R / R+ / SEC を 2+2+1 = 5 枚
    final deck = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-001-R', count: 2),
      const DeckEntry(printingId: 'PL!N-bp1-001-R+', count: 2),
      const DeckEntry(printingId: 'PL!N-bp1-001-SEC', count: 1),
    ]);
    final result = validator.validate(deck);
    final tooMany =
        result.issues.where((i) => i.code == DeckIssueCode.tooManyCopies);
    expect(tooMany, isNotEmpty,
        reason: 'パラレルを別カード扱いすると 4 枚制限をすり抜けてしまう');
    expect(tooMany.first.actual, 5);
    expect(tooMany.first.cardNumber, 'PL!N-bp1-001');
  });

  test('同一 cardNumber の内訳合計がちょうど 4 枚なら通る (決定 D11)', () {
    final entries = _legalDeck().entries.toList()
      ..removeWhere((e) => e.printingId == 'PL!N-bp1-001-R')
      ..addAll(const [
        DeckEntry(printingId: 'PL!N-bp1-001-R', count: 2),
        DeckEntry(printingId: 'PL!N-bp1-001-R+', count: 1),
        DeckEntry(printingId: 'PL!N-bp1-001-SEC', count: 1),
      ]);
    final result = validator.validate(_deck(entries));
    expect(result.isValid, isTrue, reason: result.issues.join('\n'));
  });

  test('★エネルギーは同じカード12枚でも合法 (6.1.1.2 はメインデッキのみ)', () {
    final entries = _legalDeck().entries.toList()
      ..removeWhere((e) => e.printingId.startsWith('PL!N-bp1-03'))
      ..add(const DeckEntry(printingId: 'PL!N-bp1-030-LLE', count: 12));
    final result = validator.validate(_deck(entries));
    expect(result.isValid, isTrue, reason: result.issues.join('\n'));
    expect(result.energyCount, 12);
  });

  test('エネルギーデッキが13枚だと不合格', () {
    final entries = _legalDeck().entries.toList()
      ..removeWhere((e) => e.printingId.startsWith('PL!N-bp1-03'))
      ..add(const DeckEntry(printingId: 'PL!N-bp1-030-LLE', count: 13));
    final result = validator.validate(_deck(entries));
    expect(
      result.issues.where((i) => i.code == DeckIssueCode.energyCountMismatch),
      isNotEmpty,
    );
  });

  test('canAdd: エネルギーは4枚超でも追加でき、12枚で止まる', () {
    final eight = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-030-LLE', count: 8),
    ]);
    expect(validator.canAdd(eight, 'PL!N-bp1-030-LLE'), isTrue,
        reason: 'エネルギーに4枚制限は無い');

    final full = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-030-LLE', count: 12),
    ]);
    expect(validator.canAdd(full, 'PL!N-bp1-030-LLE'), isFalse,
        reason: 'エネルギーデッキ全体の12枚上限は超えられない');
  });

  test('メンバーが 47 枚だと不合格 (「ちょうど」判定)', () {
    final entries = _legalDeck().entries.toList();
    final idx = entries.indexWhere((e) => e.printingId == 'PL!N-bp1-001-R');
    entries[idx] = entries[idx].copyWith(count: 3);
    final result = validator.validate(_deck(entries));
    expect(
      result.issues.where((i) => i.code == DeckIssueCode.memberCountMismatch),
      isNotEmpty,
    );
  });

  test('メンバーが 49 枚でも不合格 (過剰も検出する)', () {
    final entries = _legalDeck().entries.toList()
      ..add(const DeckEntry(printingId: 'PL!N-bp1-002-R', count: 1));
    final result = validator.validate(_deck(entries));
    expect(
      result.issues.where((i) => i.code == DeckIssueCode.memberCountMismatch),
      isNotEmpty,
    );
  });

  test('★未知の printingId は削除せず検出する (決定 D35)', () {
    final entries = _legalDeck().entries.toList()
      ..add(const DeckEntry(printingId: 'PL!N-bp9-999-R', count: 1));
    final result = validator.validate(_deck(entries));
    expect(result.hasUnknownCards, isTrue);
    expect(result.unknownPrintingIds, contains('PL!N-bp9-999-R'));
    // 未知カードがあってもデッキ自体は保持されること
    expect(_deck(entries).entries.length, entries.length);
  });

  test('canAdd が 4 枚到達で false になる', () {
    final deck = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-001-R', count: 3),
    ]);
    expect(validator.canAdd(deck, 'PL!N-bp1-001-R+'), isTrue);

    final full = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-001-R', count: 4),
    ]);
    expect(validator.canAdd(full, 'PL!N-bp1-001-R+'), isFalse,
        reason: 'パラレル違いでも同一 cardNumber なので追加できない');
  });

  test('共有形式は cardNumber + 枚数に落ちる (STEP4 M44)', () {
    final deck = _deck([
      const DeckEntry(printingId: 'PL!N-bp1-001-R', count: 2),
      const DeckEntry(printingId: 'PL!N-bp1-001-SEC', count: 2),
    ]);
    final shared = deck.toShareFormat(master.printings);
    expect(shared, {'PL!N-bp1-001': 4});
  });

  test('copyWith で revision が増える (同期の差分検出 P2)', () {
    final deck = _legalDeck();
    final updated = deck.copyWith(name: 'renamed');
    expect(updated.revision, deck.revision + 1);
    expect(updated.deckId, deck.deckId, reason: 'deckId は不変');
  });
}
