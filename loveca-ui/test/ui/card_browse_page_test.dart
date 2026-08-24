/// R4 の検索まわり（`docs/UI設計メモ.md` §2-6 / 決定 D40 / D44 / D50 / D53）.
///
/// ★★ ここで見るのは「見た目の区別」である ★★
/// 縮退が**実際に起きる**ことは `test/data/card_search_degradation_test.dart`
/// （実 DB）が担保している。ここではフェイクを使い、
///
/// - 打鍵に対して検索が何回走るか（決定 D44）
/// - 3 つの縮退が**別々の行**として読めるか
/// - 失敗が 0 件表示にすり替わらないか（決定 D53）
///
/// を固定する。役割を混ぜない。
library;

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';
import 'package:loveca_ui/src/data/master_catalog.dart';
import 'package:loveca_ui/src/data/search_limit.dart';
import 'package:loveca_ui/src/ui/browse/card_browse_page.dart';

import '../support/fake_card_catalog_repository.dart';
import '../support/fake_deck_repository.dart';
import '../support/pump_app.dart';

final _searchField = find.byKey(const Key('cardSearchField'));

const _rows = [
  CardListRow(
    printingId: 'A-N',
    cardNumber: 'A',
    name: 'カードA',
    cardType: CardType.member,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    cost: 1,
  ),
  CardListRow(
    printingId: 'B-N',
    cardNumber: 'B',
    name: 'カードB',
    cardType: CardType.member,
    expansion: 'bp1',
    rarity: 'N',
    isParallel: false,
    imageHash: '',
    cost: 1,
  ),
];

MasterCatalog _catalog() => MasterCatalog(
      cards: const {
        'A': Card(cardNumber: 'A', name: 'カードA', cardType: CardType.member),
      },
      printings: const {},
      config: RuleConfig.standard,
      rows: _rows,
      dataVersion: 1,
    );

Future<void> _open(
  WidgetTester tester,
  FakeCardCatalogRepository repository, {
  SearchLimitSetting searchLimit = SearchLimitSetting.standard,
}) =>
    pumpInAppScope(
      tester,
      const CardBrowsePage(),
      decks: FakeDeckRepository(),
      cardCatalog: repository,
      catalog: _catalog(),
      searchLimit: searchLimit,
    );

/// 検索を確定させる。★デバウンス分を明示的に進める（決定 D44）。
Future<void> _settleSearch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('検索前は全行が出ていて、ヘッダは何も出さない', (tester) async {
    await _open(tester, FakeCardCatalogRepository());

    expect(find.textContaining('の検索結果'), findsNothing);
    expect(find.textContaining('打ち切りました'), findsNothing);
    expect(find.text('条件に合うカードがありません'), findsNothing);
  });

  testWidgets('★連続入力でも検索は 1 回だけ走る（決定 D44）', (tester) async {
    final repository = FakeCardCatalogRepository();
    await _open(tester, repository);

    // 打鍵 120ms 相当。★150ms 未満で刻む（`docs/UI技術検証メモ.md` §4-3）。
    for (final q in ['ラ', 'ライ', 'ライブ']) {
      await tester.enterText(_searchField, q);
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(repository.searchCalls, 0, reason: '打鍵の途中では走らない');

    await _settleSearch(tester);
    expect(repository.searchCalls, 1);
    expect(repository.searchedQueries, ['ライブ']);
  });

  testWidgets('★打ち切りが表示される（決定 D50）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.trigram,
        truncated: true,
      ),
    );
    await _open(tester, repository);

    await tester.enterText(_searchField, 'ライブ');
    await _settleSearch(tester);

    expect(find.textContaining('打ち切りました'), findsOneWidget);
    expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
  });

  testWidgets('★打ち切っていなければ表示されない（出ない側）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.trigram,
      ),
    );
    await _open(tester, repository);

    await tester.enterText(_searchField, 'ライブ');
    await _settleSearch(tester);

    expect(find.textContaining('打ち切りました'), findsNothing);
    expect(find.byIcon(Icons.filter_list_off), findsNothing);
    expect(find.textContaining('の検索結果'), findsOneWidget);
  });

  testWidgets('★上限が上書きされていれば打ち切りの文面に出る（決定 D64）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.trigram,
        truncated: true,
      ),
    );
    await _open(tester, repository, searchLimit: resolveSearchLimit('50'));

    await tester.enterText(_searchField, 'ライブ');
    await _settleSearch(tester);

    // ★誤認（「打ち切りが頻発するアプリだ」）が起きるまさにその瞬間に出す。
    expect(find.textContaining('上限 50 件'), findsOneWidget);
    expect(find.textContaining('LOVECA_SEARCH_LIMIT'), findsOneWidget);
  });

  testWidgets('★2 文字の経路が表示される（決定 D40）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.likeFallback,
      ),
    );
    await _open(tester, repository);

    await tester.enterText(_searchField, '花帆');
    await _settleSearch(tester);

    expect(find.textContaining('部分一致で検索しました'), findsOneWidget);
    expect(find.byIcon(Icons.manage_search), findsOneWidget);
  });

  testWidgets('★trigram 経路では表示されない（出ない側）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A'],
        mode: CardSearchMode.trigram,
      ),
    );
    await _open(tester, repository);

    await tester.enterText(_searchField, '花帆さん');
    await _settleSearch(tester);

    expect(find.textContaining('部分一致で検索しました'), findsNothing);
    expect(find.byIcon(Icons.manage_search), findsNothing);
  });

  testWidgets('★表示できないカードがあれば出る／無ければ出ない（D-8）', (tester) async {
    // 'ZZZ' は一覧に無い cardNumber = 刷りが 1 件も無いカード。
    final repository = FakeCardCatalogRepository()
      ..resultFor = (query, _) => CardSearchResult(
            cardNumbers: query == '孤児あり' ? const ['A', 'ZZZ'] : const ['A'],
            mode: CardSearchMode.trigram,
          );
    await _open(tester, repository);

    await tester.enterText(_searchField, '孤児あり');
    await _settleSearch(tester);
    expect(find.textContaining('表示できません'), findsOneWidget);
    expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);

    await tester.enterText(_searchField, '孤児なし');
    await _settleSearch(tester);
    expect(find.textContaining('表示できません'), findsNothing);
    expect(find.byIcon(Icons.report_problem_outlined), findsNothing);
  });

  testWidgets('★3 つの縮退は別々の行として読める（1 行にまとめない）', (tester) async {
    final repository = FakeCardCatalogRepository(
      result: const CardSearchResult(
        cardNumbers: ['A', 'ZZZ'],
        mode: CardSearchMode.likeFallback,
        truncated: true,
      ),
    );
    await _open(tester, repository);

    await tester.enterText(_searchField, 'ab');
    await _settleSearch(tester);

    // ★原因も対処も違うので、それぞれ独立に読めなければならない。
    expect(find.textContaining('打ち切りました'), findsOneWidget);
    expect(find.textContaining('部分一致で検索しました'), findsOneWidget);
    expect(find.textContaining('表示できません'), findsOneWidget);

    // ★アイコンも別。3 つが同じ見た目だと「なんか出てる」で無視される。
    expect(find.byIcon(Icons.filter_list_off), findsOneWidget);
    expect(find.byIcon(Icons.manage_search), findsOneWidget);
    expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);
  });

  group('★0 件と失敗を見た目で区別する（決定 D53）', () {
    testWidgets('該当なしは「条件に合うカードがありません」', (tester) async {
      final repository = FakeCardCatalogRepository(
        result: const CardSearchResult(
          cardNumbers: [],
          mode: CardSearchMode.trigram,
        ),
      );
      await _open(tester, repository);

      await tester.enterText(_searchField, '該当なし');
      await _settleSearch(tester);

      expect(find.text('条件に合うカードがありません'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.textContaining('0 件 / 全 2 件'), findsOneWidget);
    });

    testWidgets('★失敗はエラー表示になり、0 件表示にすり替わらない', (tester) async {
      final repository = FakeCardCatalogRepository()
        ..failSearch = StateError('DB が読めません');
      await _open(tester, repository);

      await tester.enterText(_searchField, 'ライブ');
      await _settleSearch(tester);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('DB が読めません'), findsOneWidget);
      // ★★ ここが要 ★★
      // 「そのカードは無い」と誤解させないため、0 件の文面を出してはいけない。
      expect(find.text('条件に合うカードがありません'), findsNothing);
    });
  });

  testWidgets('消去ボタンで空に戻す', (tester) async {
    final repository = FakeCardCatalogRepository();
    await _open(tester, repository);

    await tester.enterText(_searchField, 'ライブ');
    await _settleSearch(tester);
    expect(find.textContaining('「ライブ」の検索結果'), findsOneWidget);

    await tester.tap(find.byTooltip('検索語を消す'));
    await _settleSearch(tester);

    expect(find.textContaining('の検索結果'), findsNothing);
    expect(repository.searchedQueries.last, '');
  });
}
