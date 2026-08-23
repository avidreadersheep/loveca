/// 一覧表示のための行データ.
///
/// ★表示に要る列だけを引く経路と、既存 DAO で全件を実体化する経路を
///   両方持たせてある★ どちらのコストで Phase 2 後半を設計するかの判断材料。
///
/// 一覧の単位は**刷り（printing）**であって cardNumber ではない。
/// パラレル表示 OFF は `isParallel == false` の刷りを「すべて」出す
/// （CLAUDE.md §5-(4)）。代表 1 枚に畳む概念は誤りとして廃止済み。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';

/// グリッドのセル 1 つ分。
class CardGridRow {
  const CardGridRow({
    required this.printingId,
    required this.cardNumber,
    required this.name,
    required this.cardType,
    required this.expansion,
    required this.rarity,
    required this.isParallel,
    required this.imageHash,
    required this.cost,
  });

  final String printingId;
  final String cardNumber;
  final String name;
  final String cardType;
  final String expansion;
  final String rarity;
  final bool isParallel;
  final String imageHash;
  final int? cost;
}

/// 取得経路。どちらのコストかを測るために切り替えられるようにしてある。
enum GridLoadStrategy {
  /// 表示に要る列だけの JOIN。
  leanJoin,

  /// 既存 DAO で `Card` / `Printing` を全件実体化してから組み立てる。
  daoFull,
}

class CardGridLoadResult {
  const CardGridLoadResult({
    required this.rows,
    required this.strategy,
    required this.millis,
  });

  final List<CardGridRow> rows;
  final GridLoadStrategy strategy;
  final int millis;
}

/// 絞り込み条件。
class CardGridFilter {
  const CardGridFilter({
    this.expansion,
    this.maxCost,
    this.showParallel = true,
  });

  final String? expansion;
  final int? maxCost;

  /// ★false のとき `isParallel == false` の刷りを「すべて」残す。
  ///   cardNumber ごとに 1 枚へ畳まない（CLAUDE.md §5-(4)）。
  final bool showParallel;

  bool get isEmpty => expansion == null && maxCost == null && showParallel;

  bool matches(CardGridRow r) {
    if (!showParallel && r.isParallel) return false;
    if (expansion != null && r.expansion != expansion) return false;
    if (maxCost != null && (r.cost == null || r.cost! > maxCost!)) return false;
    return true;
  }

  /// SQL の WHERE 句と変数。`leanJoin` の再クエリで使う。
  (String, List<Object?>) toSql() {
    final where = <String>[];
    final vars = <Object?>[];
    if (!showParallel) where.add('p.is_parallel = 0');
    if (expansion != null) {
      where.add('p.expansion = ?');
      vars.add(expansion);
    }
    if (maxCost != null) {
      where.add('c.cost IS NOT NULL AND c.cost <= ?');
      vars.add(maxCost);
    }
    return (where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}', vars);
  }
}

class CardGridRepository {
  CardGridRepository(this.db);

  final LovecaDatabase db;

  static const _selectColumns = 'p.printing_id AS printing_id, '
      'p.card_number AS card_number, p.expansion AS expansion, '
      'p.rarity AS rarity, p.is_parallel AS is_parallel, '
      'p.image_hash AS image_hash, c.name AS name, '
      'c.card_type AS card_type, c.cost AS cost';

  static const _from = 'FROM printings p '
      'JOIN cards c ON c.card_number = p.card_number';

  static const _order = 'ORDER BY p.expansion, p.printing_id';

  Future<CardGridLoadResult> load(
    GridLoadStrategy strategy, {
    CardGridFilter filter = const CardGridFilter(),
  }) async {
    final sw = Stopwatch()..start();
    final rows = switch (strategy) {
      GridLoadStrategy.leanJoin => await _leanJoin(filter),
      GridLoadStrategy.daoFull => await _daoFull(filter),
    };
    sw.stop();
    return CardGridLoadResult(
      rows: rows,
      strategy: strategy,
      millis: sw.elapsedMilliseconds,
    );
  }

  Future<List<CardGridRow>> _leanJoin(CardGridFilter filter) async {
    final (where, vars) = filter.toSql();
    final result = await db.customSelect(
      'SELECT $_selectColumns $_from $where $_order',
      variables: [for (final v in vars) if (v is int) Variable<int>(v) else Variable<String>(v! as String)],
      readsFrom: {db.printings, db.cards},
    ).get();

    return [
      for (final r in result)
        CardGridRow(
          printingId: r.read<String>('printing_id'),
          cardNumber: r.read<String>('card_number'),
          name: r.read<String>('name'),
          cardType: r.read<String>('card_type'),
          expansion: r.read<String>('expansion'),
          rarity: r.read<String>('rarity'),
          isParallel: r.read<int>('is_parallel') != 0,
          imageHash: r.read<String>('image_hash'),
          cost: r.readNullable<int>('cost'),
        ),
    ];
  }

  /// 既存 DAO 経由。`Card` 1,708 個と `Printing` 2,527 個を実体化する。
  Future<List<CardGridRow>> _daoFull(CardGridFilter filter) async {
    final dao = CardDao(db);
    final cards = await dao.cardsByNumber();
    final printings = await dao.printingsById();

    final rows = <CardGridRow>[];
    for (final p in printings.values) {
      final Card? card = cards[p.cardNumber];
      if (card == null) continue;
      final row = CardGridRow(
        printingId: p.printingId,
        cardNumber: p.cardNumber,
        name: card.name,
        cardType: card.cardType.name,
        expansion: p.expansion,
        rarity: p.rarity,
        isParallel: p.isParallel,
        imageHash: p.imageHash,
        cost: card.cost,
      );
      if (filter.matches(row)) rows.add(row);
    }
    rows.sort((a, b) {
      final e = a.expansion.compareTo(b.expansion);
      return e != 0 ? e : a.printingId.compareTo(b.printingId);
    });
    return rows;
  }

  /// 絞り込みに使える商品の一覧。
  Future<List<String>> expansions() async {
    final rows = await db
        .customSelect('SELECT DISTINCT expansion FROM printings '
            'ORDER BY expansion')
        .get();
    return [for (final r in rows) r.read<String>('expansion')];
  }
}
