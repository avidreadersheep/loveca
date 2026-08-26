/// ★★ エネルギーデッキ 0 枚の補完（決定 D96 / D97）★★
///
/// ★★ ここで固定するのは「撃ち分け」である ★★
/// 補完できなかった理由は 3 つあり、**原因も次の一手も違う**（決定 D97-5）。
/// `printings[id] == null` の 1 段で済ませると、
/// **cardNumber ごと無い**のと**その刷りだけ無い**のを取り違える。
/// ★`LL-E-002` は **D68 が開示対象にした 19 種**の 1 つ（非パラレル刷りが 2 件）なので、
/// 「cardNumber は在るのに printingId だけ落ちる」は**実際に起こりうる形**である。
///
/// ★★ 「補う」だけを見ると、常に補う実装でも通る ★★
/// 補わない側（5 通り）を必ず対で置く。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_ui/src/data/app_settings.dart';
import 'package:loveca_ui/src/data/energy_fill.dart';

/// 実データと同じ形のエネルギー（★全フィールドが空 / 567 種すべてこの形）。
Card _energyCard(String cardNumber) => Card(
      cardNumber: cardNumber,
      name: 'エネルギーカード',
      cardType: CardType.energy,
    );

Card _memberCard(String cardNumber) => Card(
      cardNumber: cardNumber,
      name: 'メンバー',
      cardType: CardType.member,
    );

Printing _printing(String printingId, String cardNumber) => Printing(
      printingId: printingId,
      cardNumber: cardNumber,
      expansion: 'X',
      rarity: 'SD',
      isParallel: false,
    );

const _config = RuleConfig();

/// 引ける状態を組む。★既定値そのものは使わず、テスト用の番号で組む。
({Map<String, Card> cards, Map<String, Printing> printings}) _catalog({
  bool energy = true,
}) {
  const number = 'ZZ-E-001';
  const id = 'ZZ-E-001-SD';
  return (
    cards: {number: energy ? _energyCard(number) : _memberCard(number)},
    printings: {id: _printing(id, number)},
  );
}

EnergyFillPlan _plan({
  required int energyCount,
  required String? printingId,
  bool energy = true,
  Map<String, Card>? cards,
  Map<String, Printing>? printings,
}) {
  final c = _catalog(energy: energy);
  return planEnergyFill(
    energyCount: energyCount,
    printingId: printingId,
    cards: cards ?? c.cards,
    printings: printings ?? c.printings,
    config: _config,
  );
}

void main() {
  group('★ cardNumber の切り出し（CLAUDE.md §5-(6)）', () {
    test('★printingId から末尾の 1 段だけを落とす', () {
      expect(cardNumberOfPrinting('ZZ-E-001-SD'), 'ZZ-E-001');
      expect(cardNumberOfPrinting('PL!N-bp1-034-PE'), 'PL!N-bp1-034');
    });

    test('★★ 既定値は cardNumber ではなく printingId である ★★', () {
      // ★これが崩れると、既定値に cardNumber を書いた（= 刷りが決まらない）という意味。
      //   `LL-E-002` に切り出し規則を掛けると `LL-E` になり、そんなカードは実在しない。
      final derived = cardNumberOfPrinting(kDefaultEnergyFillPrintingId);

      expect(derived, isNot(kDefaultEnergyFillPrintingId),
          reason: '★既定値が printingId なら、cardNumber は必ず短くなる');
      expect(derived.split('-'), hasLength(greaterThanOrEqualTo(3)),
          reason: '★実データの cardNumber は 3 段以上（LL-E-002 / LL-bp1-001）');
    });
  });

  group('★ 補う側', () {
    test('0 枚なら 6.1.1.3 の枚数ちょうどを補う', () {
      final plan = _plan(energyCount: 0, printingId: 'ZZ-E-001-SD');

      expect(plan.willFill, isTrue);
      expect(plan.printingId, 'ZZ-E-001-SD');
      // ★定数 12 を書かない（6.1.2 で置換されうる / RuleConfig から取る）。
      expect(plan.count, _config.energyDeckSize);
    });

    test('★★ 適用しても revision と updatedAt が動かない ★★', () {
      // ★`Deck.copyWith` を踏むと revision が +1 され updatedAt が現在時刻になる
      //   （**D-14** の既知の違反箇所）。盤面を開くだけで同期の差分が立つ。
      final base = Deck(
        deckId: 'd',
        name: 'n',
        entries: const [DeckEntry(printingId: 'M-1', count: 1)],
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        revision: 7,
      );

      final filled = applyEnergyFill(
        base,
        _plan(energyCount: 0, printingId: 'ZZ-E-001-SD'),
      );

      expect(filled.revision, 7);
      expect(filled.updatedAt, DateTime.utc(2026, 1, 2));
      expect(filled.deckId, 'd');
      // ★元の中身は残り、エネルギーが 1 件足される。
      expect(filled.entries, hasLength(2));
      expect(filled.entries.first.printingId, 'M-1');
      expect(filled.entries.last.count, _config.energyDeckSize);
    });

    test('★対: 元の Deck を書き換えない', () {
      final base = Deck(
        deckId: 'd',
        name: 'n',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      applyEnergyFill(base, _plan(energyCount: 0, printingId: 'ZZ-E-001-SD'));

      expect(base.entries, isEmpty);
    });
  });

  group('★★ 補わない側 —— 理由を撃ち分ける（決定 D97-5）★★', () {
    test('0 枚でなければ補わない', () {
      final plan = _plan(energyCount: 12, printingId: 'ZZ-E-001-SD');

      expect(plan.willFill, isFalse);
      expect(plan.skip, EnergyFillSkip.notNeeded);
    });

    test('★1 枚でも補わない（「12 枚に足す」ではない）', () {
      // ★総合ルール 6.1.1.3 は「ちょうど」なので、足して 13 枚にはしない。
      expect(_plan(energyCount: 1, printingId: 'ZZ-E-001-SD').skip,
          EnergyFillSkip.notNeeded);
    });

    test('設定が空なら補わない（★異常ではない）', () {
      expect(_plan(energyCount: 0, printingId: null).skip,
          EnergyFillSkip.unset);
      expect(_plan(energyCount: 0, printingId: '').skip, EnergyFillSkip.unset);
    });

    test('★★ cardNumber ごと無い → unknownCardNumber ★★', () {
      final plan = _plan(
        energyCount: 0,
        printingId: 'QQ-E-999-SD',
        cards: const {},
        printings: const {},
      );

      expect(plan.skip, EnergyFillSkip.unknownCardNumber);
      expect(plan.cardNumber, 'QQ-E-999');
    });

    test('★★ cardNumber は在るが、その刷りだけ無い → unknownPrinting ★★', () {
      // ★★ これが D68 の 19 種で起こる形である ★★
      //   刷りだけを見る実装だと、上の枝と区別できずに同じ文面を出してしまう。
      final plan = _plan(
        energyCount: 0,
        // ★カタログに cardNumber は在る（`ZZ-E-001`）が、この刷りは無い。
        printingId: 'ZZ-E-001-PR',
      );

      expect(plan.skip, EnergyFillSkip.unknownPrinting);
      expect(plan.cardNumber, 'ZZ-E-001');
    });

    test('★★ 上の 2 つが本当に別の答えになっている ★★', () {
      // ★同じ「引けない」でも撃ち分けが効いていることを、対にして見る。
      //   片方だけ見ると、常に同じ理由を返す実装でも通る。
      final missingCard = _plan(
        energyCount: 0,
        printingId: 'QQ-E-999-SD',
        cards: const {},
        printings: const {},
      );
      final missingPrinting =
          _plan(energyCount: 0, printingId: 'ZZ-E-001-PR');

      expect(missingCard.skip, isNot(missingPrinting.skip));
    });

    test('★引けるが種別がエネルギーでない → notEnergy', () {
      final plan =
          _plan(energyCount: 0, printingId: 'ZZ-E-001-SD', energy: false);

      expect(plan.skip, EnergyFillSkip.notEnergy);
      expect(plan.cardNumber, 'ZZ-E-001');
    });

    test('★補わないときは Deck が素通りする', () {
      final base = Deck(
        deckId: 'd',
        name: 'n',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(
        applyEnergyFill(base, _plan(energyCount: 0, printingId: null)),
        same(base),
      );
    });
  });
}
