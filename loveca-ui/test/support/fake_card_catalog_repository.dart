/// ウィジェットテスト用の `CardCatalogRepository` 差し替え.
///
/// ★★ 縮退が「実際に起きる」ことは実 DB のテストが担保する ★★
/// `test/data/card_search_degradation_test.dart` が `limit` を下げて本当に打ち切り、
/// 2 文字で本当に `likeFallback` へ落ち、`deleteExpansion` で本当に孤児を作る。
/// **フェイクが `truncated: true` を返すだけのテストは配線しか見ていない**
/// （D-10:「0 件は『無い』と『見えていない』の区別がつかない」）。
///
/// ここでフェイクを使うのは**画面の振る舞い**（デバウンス回数・見た目の区別）を
/// 見るためであって、縮退が起きる条件を検証するためではない。役割を混ぜない。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_ui/src/data/card_catalog_repository.dart';
import 'package:loveca_ui/src/data/card_list_row.dart';

const CardSearchResult emptyTrigramResult = CardSearchResult(
  cardNumbers: [],
  mode: CardSearchMode.trigram,
);

class FakeCardCatalogRepository implements CardCatalogRepository {
  FakeCardCatalogRepository({this.result = emptyTrigramResult});

  /// 返す結果。テストごとに差し替える。
  CardSearchResult result;

  /// ★語ごとに返し分けたいとき。null なら [result] を返す。
  CardSearchResult Function(String query, int limit)? resultFor;

  /// ★呼ばれた回数。デバウンスの確認に使う（決定 D44）。
  int searchCalls = 0;

  /// 呼ばれたときの引数。
  final List<String> searchedQueries = [];
  final List<int> searchedLimits = [];

  /// 投げさせたい失敗。★リポジトリは例外を握らないので、Store まで届くはず。
  Object? failSearch;

  /// ★完了を保留したいとき（結果の順序が入れ替わる状況を作るため）。
  Future<void> Function(String query)? gate;

  @override
  Future<CardSearchResult> search(String query, {required int limit}) async {
    searchCalls++;
    searchedQueries.add(query);
    searchedLimits.add(limit);
    if (gate case final g?) await g(query);
    if (failSearch case final error?) throw error;
    return resultFor?.call(query, limit) ?? result;
  }

  // --- 以下は起動ゲートの段 4 が使うだけで、画面のテストでは通らない。 ---

  @override
  Future<List<CardListRow>> loadListRows() =>
      throw UnimplementedError('画面のテストでは使わない');

  @override
  Future<List<String>> expansions() =>
      throw UnimplementedError('画面のテストでは使わない');

  @override
  Future<Map<String, Card>> cardsByNumber() =>
      throw UnimplementedError('画面のテストでは使わない');

  @override
  Future<Map<String, Printing>> printingsById() =>
      throw UnimplementedError('画面のテストでは使わない');
}
