/// カード検索.
///
/// ★索引側とクエリ側の両方に [fold] を通す★
/// 表記ゆれの吸収は検索索引という派生物の中だけで閉じており、
/// `card_names.value` などの保存列は公式の表記のまま（決定 D40 / CLAUDE.md §5-(5)）。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import '../schema/database.dart';
import 'card_search_schema.dart';
import 'fold.dart';

/// どの経路で引いたか。
///
/// ★UI に出せるようにしてある★
/// trigram が使えず `LIKE` に落ちたことを利用者が知れないと、
/// 「なぜか件数が違う」が原因不明のまま残る。
enum CardSearchMode {
  /// FTS5 の trigram 索引。
  trigram,

  /// ★2 文字以下の語のための全走査★
  /// trigram は 3 文字未満だと**エラーにならず静かに 0 件**を返す
  /// （実測: `花帆` は trigram 0 件 / `LIKE` 35 件）。
  /// 黙って 0 件を返すのは A-3 と同じ失敗の型なので、必ず切り替える。
  likeFallback,

  /// 検索語が空。
  empty,
}

class CardSearchResult {
  const CardSearchResult({required this.cardNumbers, required this.mode});

  final List<String> cardNumbers;
  final CardSearchMode mode;

  bool get isEmpty => cardNumbers.isEmpty;
  int get length => cardNumbers.length;
}

class CardSearchDao {
  const CardSearchDao(this.db);

  final LovecaDatabase db;

  // -------------------------------------------------------------------------
  // 索引の更新
  // -------------------------------------------------------------------------

  /// 指定した cardNumber の索引行を作り直す。
  ///
  /// 取り込みと**同じトランザクション**で呼ぶこと。別トランザクションにすると、
  /// 途中で失敗したときに本体と索引がずれる。
  Future<void> reindex(Iterable<Card> cards) async {
    final numbers = cards.map((c) => c.cardNumber).toList();
    if (numbers.isEmpty) return;

    await removeFromIndex(numbers);
    for (final card in cards) {
      await db.customInsert(
        'INSERT INTO card_search '
        '(${cardSearchColumns.join(', ')}) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable<String>(fold(card.cardNumber)),
          Variable<String>(fold(card.name)),
          Variable<String>(fold(card.effectText)),
          Variable<String>(foldJoin(card.groupNames)),
          Variable<String>(foldJoin(card.unitNames)),
        ],
      );
    }
  }

  Future<void> removeFromIndex(Iterable<String> cardNumbers) async {
    for (final number in cardNumbers) {
      await db.customUpdate(
        'DELETE FROM card_search WHERE card_number = ?',
        variables: [Variable<String>(fold(number))],
      );
    }
  }

  /// 索引を空にする。
  Future<void> clearIndex() =>
      db.customUpdate('DELETE FROM card_search');

  Future<int> indexedCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM card_search')
        .getSingle();
    return row.read<int>('c');
  }

  // -------------------------------------------------------------------------
  // 検索
  // -------------------------------------------------------------------------

  /// カード名 / 効果テキスト / グループ名 / ユニット名 / カード番号を横断して引く。
  ///
  /// 戻り値は cardNumber の一覧。刷りへの展開は呼び出し側で行う
  /// （パラレル表示の ON/OFF は刷り単位の判断なので検索の責務ではない）。
  Future<CardSearchResult> search(String query, {int limit = 500}) async {
    final folded = fold(query.trim());
    if (folded.isEmpty) {
      return const CardSearchResult(
        cardNumbers: [],
        mode: CardSearchMode.empty,
      );
    }

    if (!isTrigramSearchable(folded)) return _likeFallback(folded, limit);

    final rows = await db.customSelect(
      'SELECT card_number FROM card_search WHERE card_search MATCH ? '
      'ORDER BY rank LIMIT ?',
      variables: [
        Variable<String>(_asFts5Phrase(folded)),
        Variable<int>(limit),
      ],
    ).get();

    // ★索引には fold 済みの cardNumber が入っている★
    // 元の表記へ戻すため cards 側と突き合わせる。
    return CardSearchResult(
      cardNumbers: await _resolveCardNumbers(
        rows.map((r) => r.read<String>('card_number')).toList(),
      ),
      mode: CardSearchMode.trigram,
    );
  }

  Future<CardSearchResult> _likeFallback(String folded, int limit) async {
    final rows = await db.customSelect(
      r"SELECT card_number FROM cards WHERE search_blob LIKE ? ESCAPE '\' "
      'ORDER BY card_number LIMIT ?',
      variables: [
        Variable<String>('%${_escapeLike(folded)}%'),
        Variable<int>(limit),
      ],
      readsFrom: {db.cards},
    ).get();

    return CardSearchResult(
      cardNumbers: rows.map((r) => r.read<String>('card_number')).toList(),
      mode: CardSearchMode.likeFallback,
    );
  }

  /// 折りたたみ済みの cardNumber を、保存されている表記へ戻す。
  Future<List<String>> _resolveCardNumbers(List<String> foldedNumbers) async {
    if (foldedNumbers.isEmpty) return const [];
    final all = await db.select(db.cards).get();
    final byFolded = {for (final c in all) fold(c.cardNumber): c.cardNumber};
    return [
      for (final f in foldedNumbers)
        if (byFolded[f] != null) byFolded[f]!,
    ];
  }

  /// FTS5 のフレーズ検索用に引用する。
  ///
  /// trigram では引用された文字列が部分一致として扱われ、
  /// `*` や `-` などの演算子も literal になる。
  static String _asFts5Phrase(String folded) =>
      '"${folded.replaceAll('"', '""')}"';

  static String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
