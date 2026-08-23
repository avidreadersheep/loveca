/// Card / Printing と DB 行の相互変換の検証.
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late LovecaDatabase db;
  late CardDao dao;

  setUp(() {
    db = LovecaDatabase(openInMemoryExecutor());
    dao = CardDao(db);
  });
  tearDown(() => db.close());

  Future<void> importAll() async {
    for (final expansion in fixtureExpansions) {
      await dao.replaceExpansion(loadCardSet(expansion));
    }
  }

  group('2 階層 (決定 D11 / CLAUDE.md §5-(4))', () {
    test('同一 cardNumber の非パラレル刷りを 2 件とも取れる', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      await dao.replaceExpansion(loadCardSet('PR'));

      final printings = await dao.printingsOfCard(multiPrintingMember);
      expect(printings, hasLength(2));
      // ★どちらもパラレルではない。「代表 1 枚」は誤りとして廃止済み。
      expect(printings.every((p) => !p.isParallel), isTrue);
      expect(
        printings.map((p) => p.expansion).toSet(),
        {'BP01', 'PR'},
      );
      // カード本体は 1 行に集約される。
      expect(await dao.cardByNumber(multiPrintingMember), isNotNull);
    });

    test('パラレル刷りが混じっても非パラレルだけを全部返せる', () async {
      await importAll();

      final all = await dao.printingsOfCard(multiPrintingWithParallel);
      expect(all, hasLength(3));

      // パラレル表示 OFF = isParallel == false の刷りを「すべて」表示する。
      final normal = all.where((p) => !p.isParallel).toList();
      expect(normal, hasLength(2));
      expect(normal.map((p) => p.expansion).toSet(), {'BP03', 'PR'});
      expect(
        all.singleWhere((p) => p.isParallel).expansion,
        'BP05',
      );
    });

    test('imageHash を保持する (画像キャッシュの無効化キー)', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      final printings = await dao.printingsById();
      expect(printings.values.map((p) => p.imageHash), everyElement(isNotEmpty));
    });
  });

  group('ブレードハートの色と効果アイコン (A-1 の再発防止)', () {
    test('DRAW は bladeHearts に混入せず bladeHeartEffects に入る', () async {
      await importAll();

      final card = (await dao.cardByNumber(drawLive))!;
      expect(card.cardType, CardType.live);
      expect(card.bladeHeartEffects[BladeHeartEffect.draw], isNotNull);
      // ★8.3.14 に合算するのは色だけ。DRAW はここに来てはいけない。
      expect(card.bladeHearts.keys, everyElement(isA<HeartColor>()));
      final rawColors = await db
          .customSelect('SELECT DISTINCT color FROM card_hearts')
          .get();
      expect(
        rawColors.map((r) => r.read<String>('color')).toSet(),
        isNot(contains('draw')),
      );
    });

    test('SCORE も別テーブルに入る', () async {
      await importAll();
      final card = (await dao.cardByNumber(scoreLive))!;
      expect(card.bladeHeartEffects[BladeHeartEffect.score], isNotNull);
      expect(card.bladeHeartEffects.containsKey(BladeHeartEffect.draw), isFalse);
    });

    test('hearts / requiredHearts / bladeHearts が kind で分かれて往復する',
        () async {
      await importAll();
      final source = loadCardSet('BP01');
      for (final original in source.cards) {
        final restored = (await dao.cardByNumber(original.cardNumber))!;
        expect(restored.hearts, original.hearts,
            reason: '${original.cardNumber} の所持ハート');
        expect(restored.requiredHearts, original.requiredHearts,
            reason: '${original.cardNumber} の必要ハート');
        expect(restored.bladeHearts, original.bladeHearts,
            reason: '${original.cardNumber} のブレードハート(色)');
        expect(restored.bladeHeartEffects, original.bladeHeartEffects,
            reason: '${original.cardNumber} のブレードハート(効果)');
      }
    });
  });

  group('Card の往復', () {
    test('BP01 の全カードが値として一致する', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      final source = loadCardSet('BP01');

      for (final original in source.cards) {
        final restored = (await dao.cardByNumber(original.cardNumber))!;
        expect(restored.name, original.name);
        expect(restored.cardType, original.cardType);
        expect(restored.effectText, original.effectText);
        expect(restored.characterNames, original.characterNames);
        expect(restored.groupNames, original.groupNames);
        expect(restored.unitNames, original.unitNames);
        expect(restored.keywords, original.keywords);
        expect(restored.cost, original.cost);
        expect(restored.bladeCount, original.bladeCount);
        expect(restored.score, original.score);
        expect(restored.heartTotal, original.heartTotal);
        expect(restored.requiredHeartTotal, original.requiredHeartTotal);
        expect(restored.stats, original.stats);
        expect(restored.isDeleted, original.isDeleted);
      }
    });

    // ★CLAUDE.md §5-(5): 未知の名前は勝手に変えない（決定 D40）
    test('グループ名・ユニット名は公式の表記のまま保存される', () async {
      await importAll();
      final names = await db
          .customSelect("SELECT DISTINCT value FROM card_names WHERE kind IN "
              "('group', 'unit')")
          .get();
      final values = names.map((r) => r.read<String>('value')).toSet();

      // 全角の ！ が半角に潰されていないこと。
      expect(values, contains('みらくらぱーく！'));
      // MICRO SIGN / GREEK MU の書き換えが保存値に及んでいないこと。
      expect(values, contains("μ's"));
    });

    test('検索用の折りたたみは search_blob の中だけで起きる', () async {
      await importAll();
      final rows = await db
          .customSelect('SELECT search_blob FROM cards '
              "WHERE search_blob LIKE '%みらくらぱーく!%'")
          .get();
      // 索引側は半角に畳まれている。
      expect(rows, isNotEmpty);
    });
  });

  group('replaceExpansion', () {
    test('同じ商品を 2 回入れても重複しない', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      final firstCards = await dao.cardCount();
      final firstPrintings = (await dao.printingsById()).length;

      await dao.replaceExpansion(loadCardSet('BP01'));
      expect(await dao.cardCount(), firstCards);
      expect((await dao.printingsById()).length, firstPrintings);

      final names = await db.select(db.cardNames).get();
      expect(names.map((n) => (n.cardNumber, n.kind, n.ord)).toSet(),
          hasLength(names.length));
    });

    // ★cards は expansion 単位で消さない★
    //   実データでは 102 の cardNumber が複数の商品ファイルに現れる。
    test('商品を消しても他商品から参照されているカードは残る', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      await dao.replaceExpansion(loadCardSet('PR'));

      await dao.deleteExpansion('PR');

      // PR の刷りだけが消え、BP01 の刷りとカード本体は残る。
      final printings = await dao.printingsOfCard(multiPrintingMember);
      expect(printings, hasLength(1));
      expect(printings.single.expansion, 'BP01');
      expect(await dao.cardByNumber(multiPrintingMember), isNotNull);
    });

    test('どこからも参照されなくなったカードだけを掃除できる', () async {
      await dao.replaceExpansion(loadCardSet('BP01'));
      await dao.replaceExpansion(loadCardSet('PR'));
      final before = await dao.cardCount();

      await dao.deleteExpansion('PR');
      await dao.deleteOrphanCards();

      final after = await dao.cardCount();
      expect(after, lessThanOrEqualTo(before));
      // 両方の商品に居るカードは残る。
      expect(await dao.cardByNumber(multiPrintingMember), isNotNull);
    });
  });
}
