/// 検索と絞り込みの合成（決定 D40 / D44 / D48 / D50 / D53）.
///
/// ★★ 縮退が「実際に起きる」ことはここでは確かめない ★★
/// それは `test/data/card_search_degradation_test.dart`（実 DB）の仕事。
/// ここで見るのは**合成の規則**（検索 ∩ 絞り込み・空語・結果の追い越し）で、
/// フェイクで足りる。役割を混ぜない。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/state/card_browse_store.dart';
import 'package:loveca_ui/src/state/search_degradation.dart';
import 'package:loveca_ui/src/state/store.dart';

import '../support/fake_card_catalog_repository.dart';

CardListRow _row(String cardNumber, String printingId,
        {String expansion = 'bp1', bool isParallel = false}) =>
    CardListRow(
      printingId: printingId,
      cardNumber: cardNumber,
      name: cardNumber,
      cardType: CardType.member,
      expansion: expansion,
      rarity: 'N',
      isParallel: isParallel,
      imageHash: '',
      cost: 1,
    );

/// A は刷り 2 つ（通常 + パラレル）、B と C は 1 つずつ。
final _rows = [
  _row('A', 'A-N'),
  _row('A', 'A-P', isParallel: true),
  _row('B', 'B-N', expansion: 'bp2'),
  _row('C', 'C-N'),
];

CardBrowseStore _store(
  FakeCardCatalogRepository repository, {
  SearchLimitSetting searchLimit = SearchLimitSetting.standard,
}) =>
    CardBrowseStore(
      rows: _rows,
      catalog: repository,
      searchLimit: searchLimit,
    );

List<String> _printingIds(CardBrowseState state) => switch (state.visible) {
      Ready<List<CardListRow>>(:final value) =>
        [for (final r in value) r.printingId],
      _ => throw StateError('Ready ではない: ${state.visible}'),
    };

void main() {
  test('検索前は全行が見えている（Loading にしない）', () {
    final store = _store(FakeCardCatalogRepository());
    addTearDown(store.dispose);

    expect(store.value.visible, isA<Ready<List<CardListRow>>>());
    expect(_printingIds(store.value), ['A-N', 'A-P', 'B-N', 'C-N']);
    expect(store.value.hasQuery, isFalse);
  });

  test('★検索は cardNumber を返す。刷りへは呼び出し側が広げる', () async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.trigram,
      ),
    );
    final store = _store(repository);
    addTearDown(store.dispose);

    await store.search('A');

    // ★A は刷りが 2 つある。cardNumber 1 件が刷り 2 件に広がる。
    expect(_printingIds(store.value), ['A-N', 'A-P']);
    expect(store.value.query, 'A');
  });

  test('★空の検索語は「0 件」ではなく「絞り込みなし」', () async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: [],
        mode: CardSearchMode.empty,
      ),
    );
    final store = _store(repository);
    addTearDown(store.dispose);

    await store.search('   ');

    expect(_printingIds(store.value), ['A-N', 'A-P', 'B-N', 'C-N']);
    expect(store.value.degradations, isEmpty);
  });

  test('該当なしは Ready の空リスト（失敗ではない）', () async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: [],
        mode: CardSearchMode.trigram,
      ),
    );
    final store = _store(repository);
    addTearDown(store.dispose);

    await store.search('該当なし');

    expect(store.value.visible, isA<Ready<List<CardListRow>>>());
    expect(_printingIds(store.value), isEmpty);
    expect(store.value.visibleCount, 0);
  });

  group('検索と絞り込みの合成（決定 D48）', () {
    test('検索結果にさらに絞り込みが掛かる', () async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          cardNumbers: ['A', 'C'],
          mode: CardSearchMode.trigram,
        ),
      );
      final store = _store(repository);
      addTearDown(store.dispose);

      await store.search('AC');
      expect(_printingIds(store.value), ['A-N', 'A-P', 'C-N']);

      store.setShowParallel(false);
      expect(_printingIds(store.value), ['A-N', 'C-N']);
    });

    test('★絞り込みを変えても検索は走らない（SQL を再実行しない）', () async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          cardNumbers: ['A'],
          mode: CardSearchMode.trigram,
        ),
      );
      final store = _store(repository);
      addTearDown(store.dispose);

      await store.search('A');
      expect(repository.searchCalls, 1);

      store
        ..setShowParallel(false)
        ..setExpansion('bp1')
        ..clearFilter();

      expect(repository.searchCalls, 1, reason: '絞り込みはメモリ上で行う（決定 D48）');
    });

    test('検索中に絞り込みを変えても Loading のままにする', () async {
      final repository = FakeCardCatalogRepository()
        ..gate = (_) => Future<void>.delayed(const Duration(milliseconds: 5));
      final store = _store(repository);
      addTearDown(store.dispose);

      final pending = store.search('A');
      store.setShowParallel(false);

      expect(store.value.visible, isA<Loading<List<CardListRow>>>(),
          reason: '検索中なのに結果が出ている状態を作らない');
      await pending;
      expect(store.value.visible, isA<Ready<List<CardListRow>>>());
    });
  });

  test('★遅れて届いた古い結果で新しい結果を上書きしない', () async {
    final gates = <String, Completer<void>>{
      'おそい': Completer<void>(),
      'はやい': Completer<void>(),
    };
    // ★カスケードにしない。`=> 式` の直後の `..` は式側に付いてしまう。
    final repository = FakeCardCatalogRepository();
    repository.gate = (query) => gates[query]!.future;
    repository.resultFor = (query, _) => CardSearchResult(
          cardNumbers: [query == 'おそい' ? 'A' : 'C'],
          mode: CardSearchMode.trigram,
        );
    final store = _store(repository);
    addTearDown(store.dispose);

    final slow = store.search('おそい');
    final fast = store.search('はやい');

    // 後から始めたほうが先に返る。
    gates['はやい']!.complete();
    await fast;
    expect(_printingIds(store.value), ['C-N']);

    // ★古いほうが後から返っても上書きしない。
    gates['おそい']!.complete();
    await slow;
    expect(_printingIds(store.value), ['C-N'],
        reason: '打った語と違う結果が出るのは無言の誤りである');
    expect(store.value.query, 'はやい');
  });

  group('縮退（決定 D40 / D50 / D-8）', () {
    test('上限の上書きが打ち切りの表示に載る（決定 D64）', () async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          cardNumbers: ['A'],
          mode: CardSearchMode.trigram,
          truncated: true,
        ),
      );
      final store = _store(repository, searchLimit: resolveSearchLimit('50'));
      addTearDown(store.dispose);

      await store.search('A');

      final truncated =
          store.value.degradations.whereType<SearchTruncated>().single;
      expect(truncated.limit, 50);
      expect(truncated.limitOverridden, isTrue);
      expect(repository.searchedLimits, [50]);
    });

    test('★前の検索の縮退を次の検索へ持ち越さない', () async {
      final repository = FakeCardCatalogRepository()
        ..resultFor = (query, _) => CardSearchResult(
              cardNumbers: const ['A'],
              mode: CardSearchMode.trigram,
              truncated: query == '多い',
            );
      final store = _store(repository);
      addTearDown(store.dispose);

      await store.search('多い');
      expect(store.value.degradations, hasLength(1));

      await store.search('少ない');
      expect(store.value.degradations, isEmpty,
          reason: '前の検索の打ち切りが今の結果として読まれてはいけない');
    });

    test('★3 つの縮退は同時に立ちうる（1 つに畳まない）', () async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          // 'ZZZ' は一覧に無い cardNumber = 刷りが 1 件も無いカード（D-8）。
          cardNumbers: ['A', 'ZZZ'],
          mode: CardSearchMode.likeFallback,
          truncated: true,
        ),
      );
      final store = _store(repository);
      addTearDown(store.dispose);

      await store.search('ab');

      expect(store.value.degradations, hasLength(3));
      expect(store.value.degradations.whereType<SearchTruncated>(), hasLength(1));
      expect(
          store.value.degradations.whereType<SearchLikeFallback>(), hasLength(1));
      expect(store.value.degradations.whereType<SearchMissingCards>().single.count,
          1);
    });

    test('★表示できない件数は絞り込み前の全行に対して数える', () async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          cardNumbers: ['A', 'B'],
          mode: CardSearchMode.trigram,
        ),
      );
      final store = _store(repository);
      addTearDown(store.dispose);

      // B は bp2 にしか無いので、bp1 で絞ると表示から消える。
      store.setExpansion('bp1');
      await store.search('AB');

      expect(_printingIds(store.value), ['A-N', 'A-P']);
      expect(store.value.degradations.whereType<SearchMissingCards>(), isEmpty,
          reason: '絞り込みで消えただけの刷りを「表示できないカード」に化けさせない');
    });
  });

  test('失敗は Failed になり、0 件にすり替わらない（決定 D53）', () async {
    final repository = FakeCardCatalogRepository()
      ..failSearch = StateError('DB が読めません');
    final store = _store(repository);
    addTearDown(store.dispose);

    await store.search('A');

    expect(store.value.visible, isA<Failed<List<CardListRow>>>());
    expect(store.value.visibleCount, isNull);
    expect(store.value.degradations, isEmpty);
  });

  group('★★ 種別を変えてもコストを外さない（`Android UI 決定` §1-4）★★', () {
    // ★★この群は★2026-09-03 に新設した★★ ——
    //   ★**それまで `setCardType` が `maxCost` を外すことに★対が 1 つも無かった**
    //   （★実測: ★★この 1 行を書き換えても★1199 件が全部通った★★ / **D-20** / **D-27**）。

    test('メンバー以外にしてもコストが残る', () {
      final store = _store(FakeCardCatalogRepository());
      addTearDown(store.dispose);

      store.setMaxCost(1);
      store.setCardType(CardType.live);

      // ★★以前はここで null に落ちていた★★。
      expect(store.value.filter.maxCost, 1);
      expect(store.value.filter.cardType, CardType.live);
      expect(store.value.filter.appliesCost, isTrue);
    });

    test('種別を外してもコストが残る', () {
      final store = _store(FakeCardCatalogRepository());
      addTearDown(store.dispose);

      store.setMaxCost(2);
      store.setCardType(CardType.member);
      store.setCardType(null);

      expect(store.value.filter.cardType, isNull);
      expect(store.value.filter.maxCost, 2);
    });

    test('★対: コストそのものは外せる', () {
      final store = _store(FakeCardCatalogRepository());
      addTearDown(store.dispose);

      store.setMaxCost(1);
      store.setMaxCost(null);

      expect(store.value.filter.maxCost, isNull);
    });

    test('★対: `clearFilter` は両方外す', () {
      final store = _store(FakeCardCatalogRepository());
      addTearDown(store.dispose);

      store.setMaxCost(1);
      store.setCardType(CardType.live);
      store.clearFilter();

      expect(store.value.filter.maxCost, isNull);
      expect(store.value.filter.cardType, isNull);
      expect(store.value.filter.isEmpty, isTrue);
    });
  });

  testWidgets('★連続入力でも検索は 1 回だけ走る（決定 D44）', (tester) async {
    final repository = FakeCardCatalogRepository();
    final store = _store(repository);
    addTearDown(store.dispose);

    for (final q in ['ス', 'スク', 'スクー', 'スクール']) {
      store.setQuery(q);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(repository.searchCalls, 0, reason: '打鍵の途中では走らない');

    await tester.pump(const Duration(milliseconds: 150));
    expect(repository.searchCalls, 1);
    expect(repository.searchedQueries, ['スクール']);
  });
}
