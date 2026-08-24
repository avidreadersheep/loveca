/// カードの読み出し（決定 D55）.
///
/// ★★ UI はここより下（DAO / drift）を直接呼ばない ★★
/// 理由は 3 つ（`docs/UI設計メモ.md` §4-1）。
/// 1. `DeckDao.validate` / `canAdd` は呼ぶたび全件実体化する（40〜60ms）
/// 2. 決定 D48 が要求する投影クエリが `loveca_db` の公開 API に無い
/// 3. `drift` の型が UI に漏れると Phase 5 の Web / WASM 経路で UI ごと巻き込む
///
/// ★このクラスが返すのは `loveca_core` の型と UI 用の投影型だけ。
/// `drift` の型を返さない。
library;

import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

import 'card_list_row.dart';
import 'repository_exception.dart';

class CardCatalogRepository {
  const CardCatalogRepository(this._db);

  final LovecaDatabase _db;

  /// 一覧の投影（決定 D48）。**表示と絞り込みに要る列だけ**を引く。
  ///
  /// ★`CardDao.cardsByNumber()` を使わない。あれは `DeckValidator` に渡すための
  /// もので、一覧表示には重い（実測 40〜60ms 対 11〜15ms）。
  Future<List<CardListRow>> loadListRows() =>
      guardRepository('cardCatalog.loadListRows', () async {
        final rows = await _db.customSelect(
          'SELECT p.printing_id, p.card_number, p.expansion, p.rarity, '
          'p.is_parallel, p.image_hash, '
          'c.name, c.card_type, c.cost '
          'FROM printings p JOIN cards c ON c.card_number = p.card_number '
          'ORDER BY p.expansion, p.printing_id',
          readsFrom: {_db.printings, _db.cards},
        ).get();

        return [
          for (final r in rows)
            CardListRow(
              printingId: r.read<String>('printing_id'),
              cardNumber: r.read<String>('card_number'),
              name: r.read<String>('name'),
              // ★drift の textEnum は enum の name を保存する
              //   （`loveca-db/lib/src/schema/tables.dart` の注記）。
              //   境界でここ 1 回だけ enum へ直す。未知なら投げる——握らない。
              cardType: CardType.values.byName(r.read<String>('card_type')),
              expansion: r.read<String>('expansion'),
              rarity: r.read<String>('rarity'),
              isParallel: r.read<int>('is_parallel') != 0,
              imageHash: r.read<String>('image_hash'),
              cost: r.readNullable<int>('cost'),
            ),
        ];
      });

  /// 絞り込みに使える商品の一覧。
  Future<List<String>> expansions() =>
      guardRepository('cardCatalog.expansions', () async {
        final rows = await _db.customSelect(
          'SELECT DISTINCT expansion FROM printings ORDER BY expansion',
          readsFrom: {_db.printings},
        ).get();
        return [for (final r in rows) r.read<String>('expansion')];
      });

  /// 検索（決定 D40 / D50 / M3）。
  ///
  /// ★★ 戻り値は cardNumber であって刷りではない ★★
  /// 刷りへの展開は呼び出し側の責務（`card_search_dao.dart:212-215`）。
  /// パラレル表示の ON/OFF は刷り単位の判断なので検索の責務ではない。
  /// 展開の実測は 0.00〜0.13ms（`docs/UI技術検証メモ.md` §4-2）で、設計上の考慮は要らない。
  ///
  /// ★★ 縮退（`truncated` / `mode`）をそのまま通す ★★
  /// ここで畳むと「成功したが不完全」が「成功」と区別できなくなる
  /// （`docs/UI設計メモ.md` §3-4(3)）。`CardSearchResult` は drift の型ではない値型なので
  /// UI へ出してよい（`MasterRepository` が `MasterImportResult` を出しているのと同じ扱い）。
  ///
  /// ★[limit] に既定値を持たせない。既定 2000（決定 D50）が 2 箇所に散ると、
  /// どちらが効いているのか追えなくなる。供給元は `AppEnvironment.searchLimit` 1 つ。
  Future<CardSearchResult> search(String query, {required int limit}) =>
      guardRepository(
        'cardCatalog.search',
        () => CardSearchDao(_db).search(query, limit: limit),
      );

  /// `DeckValidator` に渡す材料（決定 D55）。**起動ゲートで 1 回だけ呼ぶ。**
  Future<Map<String, Card>> cardsByNumber() =>
      guardRepository('cardCatalog.cardsByNumber', () => CardDao(_db).cardsByNumber());

  /// 同上。
  Future<Map<String, Printing>> printingsById() =>
      guardRepository('cardCatalog.printingsById', () => CardDao(_db).printingsById());
}
