/// FTS5(trigram) 検索の検証.
library;

import 'package:loveca_core/loveca_core.dart';
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

  // ★決定 D49 の本質的な利得を固定するテスト★
  // 索引が生の cardNumber を持つようになったことで、
  // 折りたたみ後に衝突する 2 つの cardNumber を取り違えなくなった。
  // 以前は {fold(cardNumber): cardNumber} という写像で元の表記へ戻していたため、
  // 衝突すると片方が黙って消えていた。
  group('★fold が衝突する cardNumber (決定 D49)', () {
    Card synthetic(String cardNumber) => Card(
          cardNumber: cardNumber,
          name: '衝突検証用',
          cardType: CardType.member,
          effectText: 'しょうとつけんしょう',
        );

    // 全角 Ａ と半角 A は fold で同じ値へ畳まれる。
    const fullWidth = 'TEST-bp9-001-Ａ';
    const halfWidth = 'TEST-bp9-001-A';

    test('前提: この 2 つは同じ値へ畳まれる', () {
      expect(fold(fullWidth), fold(halfWidth));
      expect(fullWidth, isNot(halfWidth));
    });

    test('両方が別々に引ける（保存されている表記のまま返る）', () async {
      await search.reindex([synthetic(fullWidth), synthetic(halfWidth)]);

      final result = await search.search('bp9-001');
      expect(result.mode, CardSearchMode.trigram);
      expect(result.cardNumbers, containsAll(<String>[fullWidth, halfWidth]));
    });

    test('片方だけを索引から消せる', () async {
      await search.reindex([synthetic(fullWidth), synthetic(halfWidth)]);
      await search.removeFromIndex([fullWidth]);

      final result = await search.search('bp9-001');
      expect(result.cardNumbers, contains(halfWidth));
      expect(result.cardNumbers, isNot(contains(fullWidth)));
    });

    // ★cards に行が無くても検索が成立する★
    // 復元のために cards を読む必要が無くなったことの裏づけ。
    test('cards に行が無くても索引だけで引ける', () async {
      await search.reindex([synthetic(fullWidth)]);
      expect(await cards.cardByNumber(fullWidth), isNull);

      final result = await search.search('bp9-001');
      expect(result.cardNumbers, contains(fullWidth));
    });
  });

  // ★決定 D50: 上限で切ったことを黙らない★
  // 呼び出し側は件数だけでは切り捨てを判定できない。
  //   - length == limit は「ちょうど limit 件」と区別がつかない（偽陽性）
  // したがって戻り値に旗を立てる。
  group('★結果の上限と切り捨ての通知 (決定 D50)', () {
    test('既定の上限は実データの全カード数を上回る', () {
      expect(CardSearchDao.defaultLimit, greaterThan(1708));
    });

    test('切り捨てが起きなければ truncated は false', () async {
      final result = await search.search('ライブ開始時');
      expect(result.cardNumbers, isNotEmpty);
      expect(result.truncated, isFalse);
    });

    test('trigram 経路で上限を超えると truncated が立つ', () async {
      final full = await search.search('ライブ開始時');
      expect(full.cardNumbers.length, greaterThan(1),
          reason: '上限を試すには 2 件以上ヒットする語が要る');

      final capped = await search.search('ライブ開始時', limit: 1);
      expect(capped.mode, CardSearchMode.trigram);
      expect(capped.cardNumbers, hasLength(1));
      expect(capped.truncated, isTrue);
    });

    test('LIKE 経路でも上限を超えると truncated が立つ', () async {
      final full = await search.search('ラ');
      expect(full.mode, CardSearchMode.likeFallback);
      expect(full.cardNumbers.length, greaterThan(1));

      final capped = await search.search('ラ', limit: 1);
      expect(capped.mode, CardSearchMode.likeFallback);
      expect(capped.cardNumbers, hasLength(1));
      expect(capped.truncated, isTrue);
    });

    test('ちょうど上限と同じ件数なら truncated は立たない', () async {
      final full = await search.search('ライブ開始時');
      final exact = await search.search(
        'ライブ開始時',
        limit: full.cardNumbers.length,
      );
      expect(exact.cardNumbers, hasLength(full.cardNumbers.length));
      expect(exact.truncated, isFalse,
          reason: '件数一致だけでは切り捨てと区別できないので旗で判定する');
    });

    test('切り捨てても返る件数は上限ちょうど', () async {
      final capped = await search.search('ライブ開始時', limit: 2);
      expect(capped.cardNumbers, hasLength(2));
    });
  });

  group('★索引の作り直し（移行の受け皿）', () {
    // `card_search` は cards / card_names からの純粋な派生物なので、
    // 落として建て直せば必ず現在の索引仕様に揃う。
    // MigrationStrategy の onUpgrade がこれを呼ぶ。
    test('rebuildAll で索引が同じ状態に戻る', () async {
      final countBefore = await search.indexedCount();
      final hitBefore = await search.search('ライブ開始時');
      expect(countBefore, greaterThan(0));
      expect(hitBefore.cardNumbers, isNotEmpty);

      await db.customStatement('DROP TABLE card_search');
      await search.rebuildAll();

      expect(await search.indexedCount(), countBefore);
      final hitAfter = await search.search('ライブ開始時');
      expect(hitAfter.cardNumbers, hitBefore.cardNumbers);
    });

    // ★移行がユーザデータに触れないことの証拠★
    // decks は配信物から作り直せない（決定 D11 / D35）。
    test('rebuildAll はデッキに触らない', () async {
      final decks = DeckDao(db);
      await decks.save(Deck(
        deckId: 'a3f1c2d4-0000-4000-8000-0000000000ff',
        name: '移行しても残ること',
        entries: const [],
        createdAt: DateTime.utc(2026, 8, 23),
        updatedAt: DateTime.utc(2026, 8, 23),
      ));

      await search.rebuildAll();

      final after = await decks.byId('a3f1c2d4-0000-4000-8000-0000000000ff');
      expect(after, isNotNull);
      expect(after!.name, '移行しても残ること');
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
