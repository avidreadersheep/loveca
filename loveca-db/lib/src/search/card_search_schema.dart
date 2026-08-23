/// FTS5 検索テーブルの DDL.
///
/// ★drift の Dart テーブル API は仮想テーブルを表現できない★
/// `.drift` ファイル経由にすると `tokenize` オプションのコード生成互換に賭けることになる。
/// `customStatement` で作り `customSelect` で引く形にして、SQL を手元に置く。
///
/// ★外部コンテンツ (`content=`) にしない・トリガも置かない★
/// 書き手が取り込み層しか無いので、同一トランザクションで入れれば整合する。
/// rowid の整合を自前で管理する事故を作らない。
library;

/// 検索対象の列。
///
/// - `card_number` … `bp1-012` のような部分一致で引ける
/// - `name` / `effect` … 本文
/// - `group_names` / `unit_names` … グループ名・ユニット名
///
/// ★`characterNames` は入れない★
/// `name` の部分文字列（`上原歩夢&中須かすみ` の各要素）なので、
/// trigram では重複ヒットにしかならない。
///
/// ★`rarity` / `expansion` は入れない★
/// 完全一致の絞り込みなので `printings` の通常列＋索引で扱う。
///
/// ★`card_number_raw` だけは折りたたまない（決定 D49）★
/// 検索結果をそのまま返すための保管列。`UNINDEXED` なので検索対象にはならない。
///
/// ★`effect` には注釈文（`（）` 内）も含める（決定 D38）★
/// 2.12.4 が定めるのは「注釈文はゲームに影響しない」＝**裁定の射程**であり、
/// 検索は裁定ではなく「印刷されている文字列からカードを見つける」操作。
/// 除外すると印刷された文言で引けない偽陰性が出る。
/// 実測でも該当 44 種・効果テキスト全 81,064 文字中 1,806 文字（2.2%）にすぎない。
const List<String> cardSearchColumns = [
  'card_number',
  'name',
  'effect',
  'group_names',
  'unit_names',
  'card_number_raw',
];

/// ★索引に入れる値が折りたたみ済みでない唯一の列（決定 D49）★
///
/// 検索でヒットした行から**そのまま**保存されている表記の cardNumber を返すためにある。
/// これが無いと、折りたたみ済みの cardNumber を元の表記へ戻すために
/// 毎回 `SELECT * FROM cards`（1,708 行）を走らせることになり、
/// 実測で trigram 検索の 70〜90% がその復元に費やされていた（10.13ms → 0.74ms）。
///
/// ★`UNINDEXED` にすること★
/// トークンを作らせない。作らせると生の表記が検索対象に混ざり、
/// 折りたたみを両側に等しく効かせるという前提（決定 D40）が崩れる。
/// 実測で索引は +24 KiB（+2.6%）、`MATCH` の速さは変わらなかった。
const String cardSearchRawColumn = 'card_number_raw';

/// `card_search` 仮想テーブルの作成 SQL。
///
/// `tokenize = 'trigram'` は SQLite 3.34.0 以降。
/// 既定で ASCII は大文字小文字を区別しない。
/// ★索引側とクエリ側の両方に `fold()` を通すので、trigram 自身の畳み方は
///   正しさに影響しない（両側に等しく効くため）。
const String createCardSearchTable = '''
CREATE VIRTUAL TABLE IF NOT EXISTS card_search USING fts5(
  card_number,
  name,
  effect,
  group_names,
  unit_names,
  card_number_raw UNINDEXED,
  tokenize = 'trigram'
)''';
