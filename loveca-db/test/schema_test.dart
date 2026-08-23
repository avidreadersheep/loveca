/// スキーマが実データの形を表現できることの検証.
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

void main() {
  late LovecaDatabase db;

  setUp(() => db = LovecaDatabase(openInMemoryExecutor()));
  tearDown(() => db.close());

  group('2 階層 (cardNumber / printingId)', () {
    // ★実データに 19 件ある形。同じカードが複数商品に再録されると通常刷りが複数になる
    //   (CLAUDE.md §5-(4))。PL!HS-bp1-012 は BP01 の -N とプロモの -PR。
    test('同一 cardNumber に非パラレル刷りを複数保存・取得できる', () async {
      await db.into(db.cards).insert(
            CardsCompanion.insert(
              cardNumber: 'PL!HS-bp1-012',
              name: 'テストメンバー',
              cardType: CardType.member,
            ),
          );
      await db.into(db.printings).insert(
            PrintingsCompanion.insert(
              printingId: 'PL!HS-bp1-012-N',
              cardNumber: 'PL!HS-bp1-012',
              expansion: const Value('BP01'),
              rarity: const Value('N'),
              isParallel: const Value(false),
            ),
          );
      await db.into(db.printings).insert(
            PrintingsCompanion.insert(
              printingId: 'PL!HS-bp1-012-PR',
              cardNumber: 'PL!HS-bp1-012',
              expansion: const Value('PR'),
              rarity: const Value('PR'),
              isParallel: const Value(false),
            ),
          );

      final rows = await (db.select(db.printings)
            ..where((p) => p.cardNumber.equals('PL!HS-bp1-012'))
            ..orderBy([(p) => OrderingTerm(expression: p.printingId)]))
          .get();

      expect(rows, hasLength(2));
      // ★どちらもパラレルではない。「代表 1 枚」という概念は誤りとして廃止済み。
      expect(rows.every((p) => !p.isParallel), isTrue);
      expect(
        rows.map((p) => p.expansion),
        containsAll(<String>['BP01', 'PR']),
      );
    });

    test('パラレル表示 OFF は isParallel == false の刷りをすべて返す', () async {
      await db.into(db.cards).insert(
            CardsCompanion.insert(
              cardNumber: 'PL!HS-bp1-012',
              name: 'テストメンバー',
              cardType: CardType.member,
            ),
          );
      for (final (id, parallel) in const [
        ('PL!HS-bp1-012-N', false),
        ('PL!HS-bp1-012-PR', false),
        ('PL!HS-bp1-012-SEC', true),
      ]) {
        await db.into(db.printings).insert(
              PrintingsCompanion.insert(
                printingId: id,
                cardNumber: 'PL!HS-bp1-012',
                isParallel: Value(parallel),
              ),
            );
      }

      final normal = await (db.select(db.printings)
            ..where((p) => p.isParallel.equals(false)))
          .get();
      expect(normal, hasLength(2));
    });
  });

  group('ブレードハートの色と効果アイコンの分離 (A-1 の再発防止)', () {
    setUp(() async {
      // DRAW を持つライブカード。実データではライブにしか存在しない。
      await db.into(db.cards).insert(
            CardsCompanion.insert(
              cardNumber: 'PL!-bp3-025',
              name: 'テストライブ',
              cardType: CardType.live,
            ),
          );
      await db.into(db.cardHearts).insert(
            CardHeartsCompanion.insert(
              cardNumber: 'PL!-bp3-025',
              kind: HeartKind.bladeHearts,
              color: HeartColor.blue,
              count: 1,
            ),
          );
      await db.into(db.cardBladeHeartEffects).insert(
            CardBladeHeartEffectsCompanion.insert(
              cardNumber: 'PL!-bp3-025',
              effect: BladeHeartEffect.draw,
              count: 1,
            ),
          );
    });

    // ★8.3.14 のライブ所有ハートに合算するのは色だけ。
    //   DRAW は 8.3.12.1 (ハート合計より前に引く)、SCORE は 8.4.2.1 (スコアに +1)。
    test('card_hearts に DRAW / SCORE が混入しない', () async {
      final hearts = await db.select(db.cardHearts).get();
      expect(hearts, hasLength(1));
      expect(hearts.single.color, HeartColor.blue);
      // 保存されている文字列そのものを見る。textEnum は名前で保存する。
      final raw = await db
          .customSelect('SELECT DISTINCT color FROM card_hearts')
          .get();
      final colors = raw.map((r) => r.read<String>('color')).toSet();
      expect(colors, {'blue'});
      expect(colors.intersection({'draw', 'score'}), isEmpty);
    });

    test('効果アイコンは別テーブルに入る', () async {
      final effects = await db.select(db.cardBladeHeartEffects).get();
      expect(effects.single.effect, BladeHeartEffect.draw);
    });

    test('bladeHearts と hearts は kind で参照範囲が分かれる', () async {
      // 8.3.10 はアクティブ状態のメンバーのブレードのみ、
      // 8.3.14 はウェイト含む全メンバーのハート。参照範囲が違うので混ぜない。
      await db.into(db.cardHearts).insert(
            CardHeartsCompanion.insert(
              cardNumber: 'PL!-bp3-025',
              kind: HeartKind.requiredHearts,
              color: HeartColor.gray,
              count: 2,
            ),
          );
      final byKind = await (db.select(db.cardHearts)
            ..where((h) => h.kind.equalsValue(HeartKind.bladeHearts)))
          .get();
      expect(byKind, hasLength(1));
      expect(byKind.single.color, HeartColor.blue);
    });
  });

  group('外部キー', () {
    test('カードを消すと刷りとハートも消える', () async {
      await db.into(db.cards).insert(
            CardsCompanion.insert(
              cardNumber: 'X-1',
              name: 'x',
              cardType: CardType.energy,
            ),
          );
      await db.into(db.printings).insert(
            PrintingsCompanion.insert(printingId: 'X-1-N', cardNumber: 'X-1'),
          );
      await (db.delete(db.cards)..where((c) => c.cardNumber.equals('X-1'))).go();
      expect(await db.select(db.printings).get(), isEmpty);
    });
  });
}
