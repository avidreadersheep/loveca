/// デッキの保存・区分・検証の検証.
library;

import 'package:drift/drift.dart' show Value;
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// テストは時刻を固定する。`loveca_core` は `DateTime.now()` を持ち込まない方針。
final _t0 = DateTime.utc(2026, 8, 23, 12);

void main() {
  late LovecaDatabase db;
  late CardDao cards;
  late DeckDao decks;

  setUp(() async {
    db = LovecaDatabase(openInMemoryExecutor());
    cards = CardDao(db);
    decks = DeckDao(db);
    for (final expansion in fixtureExpansions) {
      await cards.replaceExpansion(loadCardSet(expansion));
    }
  });
  tearDown(() => db.close());

  /// 種別ごとの cardNumber を（刷りを 1 つ選んで）返す。
  Future<Map<CardType, List<({String cardNumber, String printingId})>>>
      byType() async {
    final all = await cards.cardsByNumber();
    final printings = await cards.printingsById();
    final out = {
      for (final t in CardType.values)
        t: <({String cardNumber, String printingId})>[],
    };
    for (final number in all.keys.toList()..sort()) {
      final p = printings.values
          .where((p) => p.cardNumber == number && !p.isParallel)
          .toList()
        ..sort((a, b) => a.printingId.compareTo(b.printingId));
      if (p.isEmpty) continue;
      out[all[number]!.cardType]!
          .add((cardNumber: number, printingId: p.first.printingId));
    }
    return out;
  }

  Deck deckOf(List<DeckEntry> entries, {String id = 'deck-1'}) => Deck(
        deckId: id,
        name: 'テストデッキ',
        entries: entries,
        createdAt: _t0,
        updatedAt: _t0,
      );

  group('保存と取得', () {
    test('デッキが値として往復する', () async {
      final deck = Deck(
        deckId: 'a3f1c2d4-0000-4000-8000-000000000001',
        name: 'μ\'s 型',
        entries: const [
          DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4),
          DeckEntry(printingId: 'PL!HS-bp1-012-PR', count: 2),
        ],
        memo: 'メモ',
        tags: const ['大会用', '調整中'],
        coverPrintingId: 'PL!HS-bp1-012-N',
        createdAt: _t0,
        updatedAt: _t0.add(const Duration(hours: 1)),
        revision: 7,
        lastDeviceId: 'pc-1',
        masterDataVersion: 2,
      );
      await decks.save(deck);

      final restored = (await decks.byId(deck.deckId))!;
      expect(restored.name, deck.name);
      expect(restored.memo, deck.memo);
      expect(restored.tags, deck.tags);
      expect(restored.coverPrintingId, deck.coverPrintingId);
      expect(restored.createdAt, deck.createdAt);
      expect(restored.updatedAt, deck.updatedAt);
      expect(restored.revision, 7);
      expect(restored.lastDeviceId, 'pc-1');
      expect(restored.masterDataVersion, 2);
      expect(restored.totalCount, 6);
      expect(
        restored.entries.map((e) => (e.printingId, e.count)).toSet(),
        deck.entries.map((e) => (e.printingId, e.count)).toSet(),
      );
    });

    test('保存し直すと中身が入れ替わる', () async {
      await decks.save(deckOf(const [
        DeckEntry(printingId: 'PL!HS-bp1-012-N', count: 4),
      ]));
      await decks.save(deckOf(const [
        DeckEntry(printingId: 'PL!HS-bp1-012-PR', count: 1),
      ]));
      final restored = (await decks.byId('deck-1'))!;
      expect(restored.entries, hasLength(1));
      expect(restored.entries.single.printingId, 'PL!HS-bp1-012-PR');
    });

    // ★決定 D102: 物理削除すると削除が同期で伝播しない。
    test('論理削除は一覧から外れるが行は残る', () async {
      await decks.save(deckOf(const []));
      await decks.softDelete('deck-1', _t0.add(const Duration(days: 1)));

      expect(await decks.all(), isEmpty);
      final withDeleted = await decks.all(includeDeleted: true);
      expect(withDeleted, hasLength(1));
      expect(withDeleted.single.isDeleted, isTrue);
      expect(withDeleted.single.deletedAt, isNotNull);
    });
  });

  group('★区分は cardType から導出する (決定 D41)', () {
    test('メンバー / ライブ / エネルギーに分かれる', () async {
      final t = await byType();
      final deck = deckOf([
        DeckEntry(printingId: t[CardType.member]!.first.printingId, count: 4),
        DeckEntry(printingId: t[CardType.live]!.first.printingId, count: 2),
        DeckEntry(printingId: t[CardType.energy]!.first.printingId, count: 12),
      ]);

      final sections = await decks.sections(deck);
      expect(sections.memberCount, 4);
      expect(sections.liveCount, 2);
      expect(sections.energyCount, 12);
      // メインデッキ = メンバー + ライブ（6.1.1.1）
      expect(sections.main, hasLength(2));
      expect(sections.hasUnknownCards, isFalse);
    });

    // ★決定 D35: 黙って削除しない。
    test('マスタに無い printingId は unknown に集まり、行も消えない', () async {
      final deck = deckOf(const [
        DeckEntry(printingId: 'NOT-A-REAL-PRINTING', count: 3),
      ]);
      await decks.save(deck);

      final sections = await decks.sections((await decks.byId('deck-1'))!);
      expect(sections.hasUnknownCards, isTrue);
      expect(sections.unknownCount, 3);
      expect(sections.members, isEmpty);

      // 保存された行が消えていないこと。
      expect((await decks.byId('deck-1'))!.entries, hasLength(1));
    });

    test('カードマスタを消してもデッキの行は残る', () async {
      final t = await byType();
      final printingId = t[CardType.member]!.first.printingId;
      await decks.save(deckOf([DeckEntry(printingId: printingId, count: 4)]));

      for (final expansion in fixtureExpansions) {
        await cards.deleteExpansion(expansion);
      }
      await cards.deleteOrphanCards();

      // ★deck_entries を printings への外部キーにしていないので消えない。
      final restored = (await decks.byId('deck-1'))!;
      expect(restored.entries, hasLength(1));
      final sections = await decks.sections(restored);
      expect(sections.hasUnknownCards, isTrue);
    });
  });

  group('★4 枚制限はメインデッキのみ (6.1.1.2 / 6.1.1.3)', () {
    test('エネルギーは同一 cardNumber を 12 枚入れられる', () async {
      final t = await byType();
      final energy = t[CardType.energy]!.first;
      final members = t[CardType.member]!.take(12).toList();
      final lives = t[CardType.live]!.take(6).toList();

      final deck = deckOf([
        for (final m in members) DeckEntry(printingId: m.printingId, count: 4),
        for (final l in lives) DeckEntry(printingId: l.printingId, count: 2),
        DeckEntry(printingId: energy.printingId, count: 12),
      ]);

      final result = await decks.validate(deck);
      expect(result.memberCount, 48);
      expect(result.liveCount, 12);
      expect(result.energyCount, 12);
      // ★エネルギー 12 枚で tooManyCopies が出ないこと。
      expect(
        result.issues.where((i) => i.code == DeckIssueCode.tooManyCopies),
        isEmpty,
      );
      expect(result.isValid, isTrue);
    });

    test('メンバーの同一 cardNumber 5 枚は違反になる', () async {
      final t = await byType();
      final member = t[CardType.member]!.first;
      final deck = deckOf([DeckEntry(printingId: member.printingId, count: 5)]);

      final result = await decks.validate(deck);
      final tooMany = result.issues
          .where((i) => i.code == DeckIssueCode.tooManyCopies)
          .toList();
      expect(tooMany, hasLength(1));
      expect(tooMany.single.cardNumber, member.cardNumber);
      expect(tooMany.single.actual, 5);
    });

    // ★異なる刷り（パラレル違い）でも cardNumber が同じなら合算される。
    test('パラレル違いも合算して 4 枚制限にかかる', () async {
      final printings = await cards.printingsById();
      final variants = printings.values
          .where((p) => p.cardNumber == multiPrintingWithParallel)
          .toList()
        ..sort((a, b) => a.printingId.compareTo(b.printingId));
      expect(variants.length, greaterThanOrEqualTo(2));

      final legal = deckOf([
        DeckEntry(printingId: variants[0].printingId, count: 2),
        DeckEntry(printingId: variants[1].printingId, count: 2),
      ]);
      expect(
        (await decks.validate(legal))
            .issues
            .where((i) => i.code == DeckIssueCode.tooManyCopies),
        isEmpty,
      );

      final illegal = deckOf([
        DeckEntry(printingId: variants[0].printingId, count: 3),
        DeckEntry(printingId: variants[1].printingId, count: 2),
      ]);
      final issues = (await decks.validate(illegal))
          .issues
          .where((i) => i.code == DeckIssueCode.tooManyCopies)
          .toList();
      expect(issues, hasLength(1));
      expect(issues.single.actual, 5);
    });

    test('canAdd がエネルギーとメインで違う判定になる', () async {
      final t = await byType();
      final member = t[CardType.member]!.first;
      final energy = t[CardType.energy]!.first;

      final memberFull =
          deckOf([DeckEntry(printingId: member.printingId, count: 4)]);
      expect(await decks.canAdd(memberFull, member.printingId), isFalse);

      final energyFour =
          deckOf([DeckEntry(printingId: energy.printingId, count: 4)]);
      // ★エネルギーに 4 枚制限は無い。12 枚上限にだけかかる。
      expect(await decks.canAdd(energyFour, energy.printingId), isTrue);

      final energyFull =
          deckOf([DeckEntry(printingId: energy.printingId, count: 12)]);
      expect(await decks.canAdd(energyFull, energy.printingId), isFalse);
    });
  });

  group('構築条件', () {
    test('配信された ruleConfig を使う', () async {
      await db.into(db.ruleConfigs).insertOnConflictUpdate(
            RuleConfigsCompanion.insert(
              id: const Value(singletonRowId),
              mainDeckSize: 60,
              memberCount: 48,
              liveCount: 12,
              energyDeckSize: 12,
              maxCopiesPerCardNumber: 4,
              initialHandSize: 6,
              initialEnergyOnField: 3,
              liveSlotMax: 3,
              winCondition: 3,
              stageAreaCount: 3,
            ),
          );
      final config = await decks.ruleConfig();
      expect(config.memberCount, 48);
      expect(config.maxCopiesPerCardNumber, 4);
    });

    test('未取得なら標準値になる', () async {
      expect(
        (await decks.ruleConfig()).memberCount,
        RuleConfig.standard.memberCount,
      );
    });
  });
}
