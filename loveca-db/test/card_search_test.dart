/// FTS5(trigram) 検索の検証.
library;

import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  late LovecaDatabase db;
  late CardDao cards;
  late CardSearchDao search;

  setUp(() async {
    db = LovecaDatabase(openInMemoryExecutor());
    cards = CardDao(db);
    search = CardSearchDao(db);
    for (final expansion in fixtureExpansions) {
      await cards.replaceExpansion(loadCardSet(expansion));
    }
  });
  tearDown(() => db.close());

  test('索引の件数がカード件数と一致する', () async {
    expect(await search.indexedCount(), await cards.cardCount());
  });

  group('日本語の検索', () {
    test('効果テキストを引ける', () async {
      final result = await search.search('ライブ開始時');
      expect(result.mode, CardSearchMode.trigram);
      expect(result.cardNumbers, isNotEmpty);

      // 返った cardNumber は保存されている表記のまま。
      for (final n in result.cardNumbers) {
        expect(await cards.cardByNumber(n), isNotNull);
      }
    });

    test('カード名を引ける', () async {
      final card = (await cards.cardByNumber(multiPrintingMember))!;
      final result = await search.search(card.name);
      expect(result.cardNumbers, contains(multiPrintingMember));
    });

    test('カード番号の一部で引ける', () async {
      final result = await search.search('bp1-012');
      expect(result.mode, CardSearchMode.trigram);
      expect(result.cardNumbers, contains(multiPrintingMember));
    });

    test('ユニット名で引ける', () async {
      final result = await search.search('みらくらぱーく');
      expect(result.cardNumbers, isNotEmpty);
    });
  });

  group('★表記ゆれ (決定 D40)', () {
    test('全角 ！ と半角 ! が同じ結果を返す', () async {
      final full = await search.search('みらくらぱーく！');
      final half = await search.search('みらくらぱーく!');
      expect(full.cardNumbers, isNotEmpty);
      expect(half.cardNumbers, full.cardNumbers);
    });

    test('MICRO SIGN と GREEK MU が同じ結果を返す', () async {
      final micro = await search.search("µ's");
      final greek = await search.search("μ's");
      expect(micro.cardNumbers, isNotEmpty);
      expect(greek.cardNumbers, micro.cardNumbers);
    });

    test('大文字小文字を区別しない', () async {
      final upper = await search.search('LIELLA');
      final lower = await search.search('liella');
      expect(upper.cardNumbers, isNotEmpty);
      expect(lower.cardNumbers, upper.cardNumbers);
    });
  });

  group('★注釈文 (決定 D38 / 2.12.4)', () {
    test('（）内の文言でも引ける', () async {
      // 実データで最多の注釈文。印刷されている文言で引けないのは偽陰性。
      final annotated = await db
          .customSelect("SELECT card_number FROM cards "
              "WHERE effect_text LIKE '%（%' AND effect_text LIKE '%）%'")
          .get();
      if (annotated.isEmpty) {
        markTestSkipped('ミニ配信物に注釈文を持つカードが入っていない');
        return;
      }
      final number = annotated.first.read<String>('card_number');
      final card = (await cards.cardByNumber(number))!;
      final start = card.effectText.indexOf('（');
      final end = card.effectText.indexOf('）', start);
      final inside = card.effectText.substring(start + 1, end);
      expect(inside.runes.length, greaterThanOrEqualTo(3));

      final result = await search.search(inside.substring(0, 4));
      expect(result.cardNumbers, contains(number));
    });
  });

  group('★2 文字以下の検索語', () {
    // trigram は 3 文字未満だと**エラーにならず静かに 0 件**を返す。
    // 黙って 0 件を返すのは A-3 と同じ失敗の型なので LIKE に切り替える。
    test('2 文字は LIKE 経路に落ちて当たる', () async {
      final card = (await cards.cardByNumber(multiPrintingMember))!;
      final twoChars = String.fromCharCodes(card.name.runes.take(2));

      final result = await search.search(twoChars);
      expect(result.mode, CardSearchMode.likeFallback);
      expect(result.cardNumbers, contains(multiPrintingMember));
    });

    test('1 文字でも当たる', () async {
      final card = (await cards.cardByNumber(multiPrintingMember))!;
      final oneChar = String.fromCharCodes(card.name.runes.take(1));

      final result = await search.search(oneChar);
      expect(result.mode, CardSearchMode.likeFallback);
      expect(result.cardNumbers, contains(multiPrintingMember));
    });

    test('LIKE 経路でも表記ゆれを吸収する', () async {
      // search_blob も fold 済みなので、全角で打っても当たる。
      final result = await search.search('！');
      expect(result.mode, CardSearchMode.likeFallback);
      expect(result.cardNumbers, isNotEmpty);
    });

    test('3 文字以上は trigram 経路を通る', () async {
      final result = await search.search('ライブ');
      expect(result.mode, CardSearchMode.trigram);
    });

    test('空文字列は empty を返す', () async {
      final result = await search.search('   ');
      expect(result.mode, CardSearchMode.empty);
      expect(result.isEmpty, isTrue);
    });
  });

  group('特殊文字', () {
    test('FTS5 の演算子文字を含む語で落ちない', () async {
      for (final q in ['"', 'a"b', 'NEAR(', '*', 'a OR b', '^x']) {
        await expectLater(search.search(q), completes);
      }
    });

    test('LIKE のワイルドカードが素通りしない', () async {
      // % だけで全件返ってしまうと検索として壊れている。
      final result = await search.search('%');
      expect(result.mode, CardSearchMode.likeFallback);
      expect(result.length, lessThan(await cards.cardCount()));
    });
  });

  group('索引の更新', () {
    test('商品を入れ直しても索引が重複しない', () async {
      final before = await search.indexedCount();
      await cards.replaceExpansion(loadCardSet('BP01'));
      expect(await search.indexedCount(), before);
    });

    test('孤児カードを消すと索引からも消える', () async {
      final target = (await cards.cardByNumber(multiPrintingMember))!;
      for (final expansion in fixtureExpansions) {
        await cards.deleteExpansion(expansion);
      }
      await cards.deleteOrphanCards();

      expect(await search.indexedCount(), 0);
      expect((await search.search(target.name)).cardNumbers, isEmpty);
    });
  });
}
