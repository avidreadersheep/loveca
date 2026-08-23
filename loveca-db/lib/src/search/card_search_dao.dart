/// カード検索.
///
/// ★索引側とクエリ側の両方に [fold] を通す★
/// 表記ゆれの吸収は検索索引という派生物の中だけで閉じており、
/// `card_names.value` などの保存列は公式の表記のまま（決定 D40 / CLAUDE.md §5-(5)）。
///
/// ★ヒットした行から保存表記の cardNumber をそのまま取る（決定 D49）★
/// 索引に `card_number_raw`（`UNINDEXED`）を持たせてある。
/// 以前は折りたたみ済みの cardNumber を元の表記へ戻すために
/// 毎回 `SELECT * FROM cards`（1,708 行）を走らせており、
/// 実測で trigram 検索の 70〜90% がその復元に費やされていた
/// （10.13ms → 0.74ms / `docs/UI技術検証メモ.md` §9-1）。
///
/// ★採用した理由は速さだけではない★
/// 復元処理そのものが無くなるため、`{fold(cardNumber): cardNumber}` という
/// 写像に依存しなくなる。2 つの cardNumber が同じ値へ畳まれると片方が
/// 黙って消えるという弱点が、構造ごと消える。
///
/// ★却下した案: 写像をメモリに保持する（案A）★
/// 速さは同等（0.76ms）だったが**採らなかった。決め手は性能ではない。**
/// このクラスは `const` で呼び出しごとに生成されるため写像の置き場が無く、
/// どこかに持たせると `CardDao` の書き込み（`replaceExpansion` /
/// `deleteExpansion` / `deleteOrphanCards`）が
/// この写像を無効化するという逆向きの結合が生まれる。
/// **無効化を 1 箇所でも漏らすと「取り込んだ新しいカードが検索で引けない」**
/// という無言の欠落になり、これは A-3（数字なし表記を 59 種で無言に落としていた）
/// と同じ失敗の型である。
/// 速さの問題を直すために A-3 型のリスクを新設するのは筋が悪い。
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
      await _insert(
        cardNumber: card.cardNumber,
        name: card.name,
        effect: card.effectText,
        groupNames: card.groupNames,
        unitNames: card.unitNames,
      );
    }
  }

  /// 索引行を 1 件書く。[reindex] と [rebuildAll] の共通部。
  ///
  /// ★プレースホルダは [cardSearchColumns] の要素数から作る★
  /// `VALUES (?, ?, ?, ?, ?)` と数を直書きすると、列を足したときに
  /// 片方だけ直して静かに壊れる。
  Future<void> _insert({
    required String cardNumber,
    required String name,
    required String effect,
    required List<String> groupNames,
    required List<String> unitNames,
  }) async {
    final placeholders = List.filled(cardSearchColumns.length, '?').join(', ');
    await db.customInsert(
      'INSERT INTO card_search '
      '(${cardSearchColumns.join(', ')}) VALUES ($placeholders)',
      variables: [
        Variable<String>(fold(cardNumber)),
        Variable<String>(fold(name)),
        Variable<String>(fold(effect)),
        Variable<String>(foldJoin(groupNames)),
        Variable<String>(foldJoin(unitNames)),
        // ★ここだけ折りたたまない（決定 D49）。検索結果をそのまま返すための保管列。
        Variable<String>(cardNumber),
      ],
    );
  }

  /// 索引を丸ごと作り直す。
  ///
  /// ★`card_search` は `cards` / `card_names` からの純粋な派生物★
  /// 落として建て直せば必ず現在の索引仕様に揃う。
  /// **ユーザデータ（`decks`）には一切触れない。**
  /// これが `LovecaDatabase.migration` の `onUpgrade` の受け皿になる。
  ///
  /// ★`CardDao` を経由せず生の SQL で読む★
  /// 移行はエンティティの形が変わっても動き続ける必要がある。
  /// `Card` の組み立てに依存させない。
  Future<void> rebuildAll() async {
    await db.customStatement('DROP TABLE IF EXISTS card_search');
    await db.customStatement(createCardSearchTable);

    final rows =
        await db.customSelect('SELECT card_number, name, effect_text '
            'FROM cards ORDER BY card_number').get();
    if (rows.isEmpty) return;

    // グループ名・ユニット名は別テーブルにある。順序は ord のとおりに戻す。
    final nameRows = await db.customSelect(
      "SELECT card_number, kind, value FROM card_names "
      "WHERE kind IN ('group', 'unit') ORDER BY card_number, kind, ord",
    ).get();
    final groups = <String, List<String>>{};
    final units = <String, List<String>>{};
    for (final r in nameRows) {
      final number = r.read<String>('card_number');
      final target = r.read<String>('kind') == 'group' ? groups : units;
      (target[number] ??= []).add(r.read<String>('value'));
    }

    for (final r in rows) {
      final number = r.read<String>('card_number');
      await _insert(
        cardNumber: number,
        name: r.read<String>('name'),
        effect: r.read<String>('effect_text'),
        groupNames: groups[number] ?? const [],
        unitNames: units[number] ?? const [],
      );
    }
  }

  /// ★生の cardNumber で消す（決定 D49）★
  /// 折りたたみ済みの値で消すと、2 つの cardNumber が同じ値へ畳まれたときに
  /// 巻き添えで両方消える。実データでは衝突 0 件（1,708 → 1,708）だが、
  /// これは現時点でそうだというだけで将来の保証ではない。
  Future<void> removeFromIndex(Iterable<String> cardNumbers) async {
    for (final number in cardNumbers) {
      await db.customUpdate(
        'DELETE FROM card_search WHERE $cardSearchRawColumn = ?',
        variables: [Variable<String>(number)],
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
      'SELECT $cardSearchRawColumn FROM card_search WHERE card_search MATCH ? '
      'ORDER BY rank LIMIT ?',
      variables: [
        Variable<String>(_asFts5Phrase(folded)),
        Variable<int>(limit),
      ],
    ).get();

    // ★保存されている表記がそのまま索引に入っている（決定 D49）★
    // cards 側と突き合わせる必要は無い。
    return CardSearchResult(
      cardNumbers:
          rows.map((r) => r.read<String>(cardSearchRawColumn)).toList(),
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
