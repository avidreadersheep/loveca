/// drift のテーブル定義.
///
/// ★列挙は `textEnum` で名前を保存する★
/// `intEnum` は Dart 側の宣言順に依存するため、`HeartColor` に色が 1 つ挿入されただけで
/// 既存行の意味が静かにずれる。名前で持てばその事故が起きない。
library;

import 'package:drift/drift.dart';
import 'package:loveca_core/loveca_core.dart';

import 'enums.dart';

/// 単一行テーブル（`rule_configs` / `master_states`）の行 ID。
///
/// ★INSERT で必ず明示すること★
/// `INTEGER NOT NULL PRIMARY KEY` は SQLite では rowid の別名になるため、
/// 列を省略すると `DEFAULT 0` ではなく**自動採番**が入る。
/// 単一行のつもりが 2 行目・3 行目が生まれ、`WHERE id = 0` が何も返さなくなる。
const int singletonRowId = 0;

// ---------------------------------------------------------------------------
// カードマスタ
// ---------------------------------------------------------------------------

/// ルール上のカード。**cardNumber をキーとする**（総合ルール 6.1.1.2）。
///
/// ★刷りの属性をこのテーブルに置かないこと★
/// `isParallel` は刷り単位であって cardNumber 単位ではない（CLAUDE.md §5-(4)）。
/// 同じカードが複数商品に再録されると通常刷りが複数になるため、
/// ここに「パラレルかどうか」の列を作ると実データを表現できなくなる。
/// 実測で非パラレル刷りを 2 つ以上持つ cardNumber が 19 件ある。
@DataClassName('CardRow')
class Cards extends Table {
  TextColumn get cardNumber => text()();
  TextColumn get name => text()();
  TextColumn get cardType => textEnum<CardType>()();
  TextColumn get effectText => text().withDefault(const Constant(''))();

  /// メンバーのみ（2.6）。
  IntColumn get cost => integer().nullable()();

  /// メンバーのみ（2.8）。★8.3.10 の集計対象は「アクティブ状態のメンバー」のみ。
  IntColumn get bladeCount => integer().nullable()();

  /// ライブのみ（2.10）。
  IntColumn get score => integer().nullable()();

  IntColumn get heartTotal => integer().withDefault(const Constant(0))();
  IntColumn get requiredHeartTotal => integer().withDefault(const Constant(0))();

  /// 決定 D14: ブレード数 + ハート数。検索・ソート用の派生値。
  IntColumn get stats => integer().nullable()();

  /// 公式から消えても既存デッキを壊さないため保持する。
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// ★2 文字以下の検索語のための折りたたみ済み連結テキスト★
  /// trigram は 3 文字未満だと**エラーにならず静かに 0 件**を返すため、
  /// 短い語はこの列への `LIKE` に切り替える。
  /// 中身は `fold()` を通した cardNumber + name + effect + groups + units。
  TextColumn get searchBlob => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {cardNumber};
}

/// キャラクター名 / グループ名 / ユニット名。
///
/// ★値は公式の表記のまま保存する（CLAUDE.md §5-(5)）★
/// 全角半角の折りたたみは検索用シャドウ列（`cards.search_blob` と `card_search`）
/// の中だけで行い、この列には一切適用しない（決定 D40）。
@DataClassName('CardNameRow')
@TableIndex(name: 'idx_card_names_lookup', columns: {#kind, #value})
class CardNames extends Table {
  TextColumn get cardNumber =>
      text().references(Cards, #cardNumber, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<CardNameKind>()();

  /// リスト内の位置。`Card` の 3 リストへ順序どおり復元するために要る。
  IntColumn get ord => integer()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {cardNumber, kind, ord};
}

@DataClassName('CardKeywordRow')
@TableIndex(name: 'idx_card_keywords_keyword', columns: {#keyword})
class CardKeywords extends Table {
  TextColumn get cardNumber =>
      text().references(Cards, #cardNumber, onDelete: KeyAction.cascade)();
  IntColumn get ord => integer()();
  TextColumn get keyword => text()();

  @override
  Set<Column<Object>> get primaryKey => {cardNumber, ord};
}

/// ハートの色ごとの件数。
///
/// ★★ 非色アイコン（DRAW / SCORE）はこのテーブルに入らない ★★
/// `color` の型は `HeartColor` であり、`BladeHeartEffect` を入れる余地が無い。
/// 総合ルール 8.3.14 の「ライブ所有ハートに合算する」対象は色だけで、
/// DRAW は 8.3.12.1（ハート合計より**前**にカードを引く）、
/// SCORE は 8.4.2.1（スコア合計に +1）と、処理する時点も対象も違う。
/// 同じ入れ物に同居させ直すと集計で取り違える（A-1 の再発）。
@DataClassName('CardHeartRow')
@TableIndex(name: 'idx_card_hearts_kind_color', columns: {#kind, #color})
class CardHearts extends Table {
  TextColumn get cardNumber =>
      text().references(Cards, #cardNumber, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<HeartKind>()();
  TextColumn get color => textEnum<HeartColor>()();
  IntColumn get count => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cardNumber, kind, color};
}

/// ブレードハートの非色アイコン。
///
/// 実測でいずれも**ライブカードにしか存在しない**（DRAW 59 種 / SCORE 37 種）。
@DataClassName('CardBladeHeartEffectRow')
class CardBladeHeartEffects extends Table {
  TextColumn get cardNumber =>
      text().references(Cards, #cardNumber, onDelete: KeyAction.cascade)();
  TextColumn get effect => textEnum<BladeHeartEffect>()();
  IntColumn get count => integer()();

  @override
  Set<Column<Object>> get primaryKey => {cardNumber, effect};
}

/// 個別の刷り。**printingId をキーとする**（決定 D11）。
@DataClassName('PrintingRow')
@TableIndex(name: 'idx_printings_card_number', columns: {#cardNumber})
@TableIndex(name: 'idx_printings_expansion', columns: {#expansion})
@TableIndex(name: 'idx_printings_is_parallel', columns: {#isParallel})
class Printings extends Table {
  TextColumn get printingId => text()();
  TextColumn get cardNumber =>
      text().references(Cards, #cardNumber, onDelete: KeyAction.cascade)();
  TextColumn get expansion => text().withDefault(const Constant(''))();
  TextColumn get rarity => text().withDefault(const Constant(''))();

  /// ★「cardNumber ごとの代表 1 枚」ではない★
  /// パラレル表示 OFF = `isParallel == false` の刷りを**すべて**表示する。
  BoolColumn get isParallel => boolean().withDefault(const Constant(false))();

  TextColumn get illustrator => text().withDefault(const Constant(''))();

  /// 画像のコンテンツハッシュ。画像キャッシュの無効化キーに使う。
  /// ★公式サイトの `picture` パスから URL を組み立ててはいけない（CLAUDE.md §5-(3)）。
  TextColumn get imageHash => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {printingId};
}

@DataClassName('ProductRow')
class Products extends Table {
  TextColumn get expansionId => text()();
  TextColumn get name => text().withDefault(const Constant(''))();

  /// 公式表記は "2025.02.08" 形式。
  TextColumn get releaseDate => text().withDefault(const Constant(''))();
  TextColumn get slug => text().withDefault(const Constant(''))();
  TextColumn get url => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {expansionId};
}

@DataClassName('FaqRow')
class Faqs extends Table {
  /// 公式の Q 番号。同一 Q&A が複数カードに紐づくため、これが重複排除のキー。
  TextColumn get qaId => text()();
  IntColumn get faqId => integer().withDefault(const Constant(0))();
  TextColumn get question => text().withDefault(const Constant(''))();
  TextColumn get answer => text().withDefault(const Constant(''))();
  TextColumn get registTime => text().withDefault(const Constant(''))();
  TextColumn get updateTime => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {qaId};
}

/// Q&A と刷りの対応。
///
/// ★`Faq.cardNumbers` の中身は cardNumber ではなく printingId★
/// （`loveca_core` の `product.dart` のコメントのとおり）。列名をそれに合わせてある。
///
/// ★`printings` への外部キーにしない★
/// Q&A は未取得の商品の刷りを指しうる。外部キーにすると取り込み順で失敗する。
@DataClassName('FaqPrintingRow')
@TableIndex(name: 'idx_faq_printings_printing', columns: {#printingId})
class FaqPrintings extends Table {
  TextColumn get qaId =>
      text().references(Faqs, #qaId, onDelete: KeyAction.cascade)();
  TextColumn get printingId => text()();

  @override
  Set<Column<Object>> get primaryKey => {qaId, printingId};
}

/// デッキ構築ルール。総合ルール 6.1。単一行（`id = 0`）。
///
/// ★定数にしない★
/// 6.1.2 に「デッキの構築条件に関する常時能力は、上記のデッキ構築条件を置換する
/// 置換効果として適用される」とあり、構築条件を変えるカードが存在しうる。
@DataClassName('RuleConfigRow')
class RuleConfigs extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get mainDeckSize => integer()();
  IntColumn get memberCount => integer()();
  IntColumn get liveCount => integer()();
  IntColumn get energyDeckSize => integer()();
  IntColumn get maxCopiesPerCardNumber => integer()();
  IntColumn get initialHandSize => integer()();
  IntColumn get initialEnergyOnField => integer()();
  IntColumn get liveSlotMax => integer()();
  IntColumn get winCondition => integer()();
  IntColumn get stageAreaCount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// デッキ（総合ルール 6.1）
// ---------------------------------------------------------------------------

/// デッキ。
///
/// ★Phase 4（同期）のための先行対応をそのまま列にしてある★
/// 決定 D100 deckId は UUID / ★決定 D101 revision・updatedAt・deletedAt の 3 つ /
/// 決定 D102 論理削除 / 決定 D11 printingId 単位 / 決定 D35 masterDataVersion。
/// 後付けが極めて高コストなため。
///
/// ★★ 旧番号 P1〜P5 を置き換えた (2026-08-27) ★★
/// ★ここは以前「P2 revision・updatedAt」と書いており deletedAt が落ちていた。
///   決定 D101 は 3 つで 1 組である。
///
/// ★メイン/エネルギーの区分は列に持たない（決定 D41）★
/// `cards.card_type` から導出する。区分を保存すると
/// 「エネルギーカードがメイン区分で記録された行」が作れてしまい、
/// `DeckValidator`（6.1.1.2 / 6.1.1.3）の判定と食い違う経路ができる。
/// 真実は 1 つに保つ。D35 の未知カード表示で区分が要ると分かったら改めて判断する。
@DataClassName('DeckRow')
class Decks extends Table {
  /// ★UUID v4。連番にすると端末間で衝突する（決定 D100）。
  TextColumn get deckId => text()();
  TextColumn get name => text()();
  TextColumn get memo => text().withDefault(const Constant(''))();
  TextColumn get coverPrintingId => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// ★論理削除（決定 D102）。物理削除すると削除が同期で伝播しない。
  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// ★更新のたびに +1（決定 D101）。同期の差分検出に使う。
  IntColumn get revision => integer().withDefault(const Constant(0))();
  TextColumn get lastDeviceId => text().withDefault(const Constant(''))();

  /// ★作成時のカードマスタ版（決定 D35）。未知カード検出に使う（決定 D35）。
  IntColumn get masterDataVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {deckId};
}

@DataClassName('DeckTagRow')
class DeckTags extends Table {
  TextColumn get deckId =>
      text().references(Decks, #deckId, onDelete: KeyAction.cascade)();
  IntColumn get ord => integer()();
  TextColumn get tag => text()();

  @override
  Set<Column<Object>> get primaryKey => {deckId, ord};
}

/// デッキの中身。★保持は printingId 単位（決定 D11）。
///
/// ★★ `printings` への外部キーにしない ★★
/// 決定 D35「カードマスタに存在しない printingId を黙って削除しない」。
/// 外部キー + cascade にすると、配信データから刷りが消えた瞬間に
/// デッキの行が黙って消える。**デッキが静かに壊れる**のがまさに D35 が
/// 禁じている事態であり、ここを FK にしてはいけない。
@DataClassName('DeckEntryRow')
@TableIndex(name: 'idx_deck_entries_printing', columns: {#printingId})
class DeckEntries extends Table {
  TextColumn get deckId =>
      text().references(Decks, #deckId, onDelete: KeyAction.cascade)();
  TextColumn get printingId => text()();
  IntColumn get count => integer()();

  /// デッキの中の並び順（決定 D65 / **D99**）。0 始まりの添字。
  ///
  /// ★★ 主キーに入れない ★★
  /// 「同じ刷りは 1 行」の不変条件は `{deckId, printingId}` が守っている。
  /// `ord` を鍵に入れると、同じ刷りが違う `ord` で 2 行入れられるようになる。
  ///
  /// ★★ 既定値 0 は移行のためである ★★
  /// `schemaVersion` 2 → 3 の `ALTER TABLE ... ADD COLUMN` が NOT NULL 列に
  /// 既定値を要求する。**書き込み時は [DeckDao.save] が必ず添字を明示する**ので、
  /// 既定値が実際に使われるのは移行の一瞬だけである
  /// （直後に backfill が上書きする / `database.dart` の `from < 3` の枝）。
  IntColumn get ord => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {deckId, printingId};
}

/// デッキ編集の**操作の履歴**（決定 **D110-1** / 検出層 = 案 6）。
///
/// ★★ この版は「器」だけである。書き込みは 1 件も無い ★★
/// `docs/同期設計メモ.md` §17-9-7 のコミット 2 に対応する。
/// 記録点（削除 = **D110-3** の C-iv / 9 操作 = **D110-2** の A-i）は
/// **コミット 3 以降**であり、この版では **INSERT する経路がどこにも無い**。
/// ★**「表が空である」ことをテストが固定している**（`migration_test.dart`）。
///
/// ★★ 列は「決まった分」だけ置く ★★
/// §17-9-1 の 1 は最低限を **`deckId` / 操作の種類 / 引数 / 時刻 / 順序** と書いている。
/// そのうち ★**引数だけを落とした**。§17-9-2 の **2**（引数をどこまで持つか）と
/// **4**（`sortByRule` を規則の名前で持つか結果の並びで持つか）が**未決**だからである。
/// ★**4 は (f-3) の軸 B に直結する**（規則で持って再生するとマスタ依存になる / §13-5）。
/// → ★**列を先に作ると「決めた」ことになる。足りなければ v5 で足す。**
///
/// ★★ 時刻だけは後から足せない ★★
/// ほかの列は v5 で足しても既存行に意味のある値を入れられるが、
/// **「その操作がいつ起きたか」は後から復元できない。**
/// **N-16**（ログをいつ捨てるか）が年齢で捨てる規則を選んだ場合、
/// 時刻の無い行は判定できない。→ ★**最低限の 5 つのうち時刻は落とさない。**
///
/// ★★ `decks` への外部キーを張らない（§17-9-1 の 3）★★
/// §17-9-1 は「張っても cascade は起きない（**D102** により物理削除が 0 件）。
/// 張らない理由も張る理由も、いまは無い」と書いている。→ ★**張らないほうを採る。**
/// 理由は 1 つ —— ★**cascade を張ると、ログの寿命が `decks` の行に従属する。**
/// **D110-4** は「ログの寿命が★削除の寿命になる」と定めており、寿命は **N-16** が決める。
/// いま cascade を張ると **N-16 の一部を先取りして決めてしまう**。
/// ★**cascade でない外部キー（RESTRICT）は、起きない物理削除を禁じるだけで何も買わない。**
/// ★`DeckEntries` が `printings` を参照しないのと同じ形である（決定 D35）——
/// **黙って消える経路を作らない。**
///
/// ★★ 索引を今は張らない ★★
/// 読み出す経路がまだ 1 本も無い。**どの索引が要るかは (f-1)**（衝突判定）が
/// 「前回同期の目印より後ろの操作」をどう引くかで決まる（§17-9-6）。
/// ★**クエリが 1 本も書かれていない索引は、テストの無いものと同じで静かに腐る**（決定 D51）。
/// → ★**引く経路と一緒に足す。**行が 0 件のいまは costs も benefits も 0 である。
@DataClassName('DeckEditOpRow')
class DeckEditOps extends Table {
  /// §17-9-1 の 1 が言う「順序」と、同 2 が言う「主キー」を **1 本の単調増加**が兼ねる。
  ///
  /// ★★ 既存の慣習（複合キー）を採らなかった ★★
  /// §17-9-1 の 2 は「既存の慣習は複合キー（`{deckId, ord}` など）。
  /// 単調増加の 1 本にするかは**未決**」と書いている。→ ★**単調増加を採る。**
  ///
  /// | | |
  /// |---|---|
  /// | `{deckId, ord}` | ★**デッキをまたぐ順序が消える。**挿入のたびに `MAX(ord)` を引く |
  /// | ★**単調増加 1 本** | ★**両方引ける** —— 全体順は `ORDER BY id`、デッキ内は `WHERE deck_id = ? ORDER BY id` |
  ///
  /// ★**選ぶ余地を狭めないほうを採った。**§17-9-5 は「前回同期時点の目印を
  /// **ログの位置**で持つか別のスカラで持つか」を**未決**にしており、
  /// 複合キーにすると「ログの位置」という選択肢が先に消える。
  ///
  /// ★★ `AUTOINCREMENT` である（rowid の再利用が起きない）★★
  /// drift の `autoIncrement()` は `INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT` を吐く
  /// （`drift_dev/lib/src/writer/utils/column_constraints.dart:31`。★実読）。
  /// 素の `INTEGER PRIMARY KEY` は削除後に **rowid を使い回す**ので、
  /// **N-16** が古い行を捨てた瞬間に「目印より後ろ」の判定が壊れる。
  IntColumn get id => integer().autoIncrement()();

  /// どのデッキへの操作か。★10 種すべてがデッキ 1 つに対する操作である。
  TextColumn get deckId => text()();

  /// 操作の種類。★**`DeckEditOpKind.key` の字面**を入れる。
  ///
  /// ★★ `textEnum<DeckEditOpKind>()` を使ってはならない ★★
  /// drift の `EnumNameConverter` は **`value.name`（Dart の識別子）**を保存する
  /// （`drift/lib/src/runtime/types/converters.dart:283`。★実読）。
  /// `DeckEditOpKind.deleteDeck` の識別子は `deleteDeck` だが、
  /// ★**キーは `softDelete`（記録点のメソッド名）である** —— **D110-1** が
  /// 「リネームで送信済みのログが意味を失わないように」わざと違えた 1 件である。
  /// → ★`textEnum` にすると**その決定が黙って裏返る。**素の [text] にして
  ///   `DeckEditOpKind.key` を明示で入れる
  ///   （★`test/migration_test.dart` の「kind は key の字面を持つ」が対で見張る）。
  ///
  /// ★★ 未知のキーの扱いはここで決めない ★★
  /// `DeckEditOpKind.tryFromKey` は `null` を返すだけで、例外を投げるかは
  /// **N-12**（版のずれ）と **A-4**（**D-1** の厳格性）の下流である
  /// （`loveca-core/lib/src/sync/deck_edit_op.dart` の library doc の 3）。
  /// → ★**列は字面をそのまま持つ。読み出す層が決める。**
  TextColumn get kind => text()();

  /// ★呼び出し側から渡された時刻。`DateTime.now()` を層の内側で呼ばない。
  /// （`master_files.imported_at` / `DeckDao.softDelete` の `at` と同じ扱い）
  DateTimeColumn get at => dateTime()();
}

// ---------------------------------------------------------------------------
// 取り込み状態
// ---------------------------------------------------------------------------

/// 取り込み済みのマスタの版。単一行（`id = 0`）。
///
/// ★`dataVersion` はマニフェスト内の全ファイルが成功したときにだけ更新する★
/// `planUpdate` は `remoteVersion.dataVersion <= localDataVersion` で `upToDate` を返す
/// （`master_data.dart:234`）。1 ファイル失敗したのにここを上げると、
/// 次回は `upToDate` になって**失敗したファイルが二度と再取得されない**。
@DataClassName('MasterStateRow')
class MasterStates extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  IntColumn get dataVersion => integer().withDefault(const Constant(0))();
  TextColumn get minAppVersion => text().withDefault(const Constant('0.0.0'))();
  TextColumn get manifestHash => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 取り込みに成功したファイルとそのハッシュ。
///
/// これが `planUpdate` の `localFileHashes` になる。
/// ★失敗したファイルの行を作らないことが差分更新の要★
/// 行が無ければ `localHash == null` となり、次回の計画で再取得対象に残る。
@DataClassName('MasterFileRow')
class MasterFiles extends Table {
  TextColumn get path => text()();

  /// "sha256:..." 形式。
  TextColumn get hash => text()();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  IntColumn get cardCount => integer().withDefault(const Constant(0))();

  /// ★呼び出し側から渡された時刻。`DateTime.now()` を層の内側で呼ばない。
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

/// 取り込みの失敗記録（決定 D39）。
///
/// ★主キーを `(path, hash)` にしてある★
/// 配信側が壊れたまま直らないと毎回同じ失敗が起きる。追記型にすると行が無限に増える。
/// path と hash が同じなら決定的に同じ例外になるので、1 行に集約して回数だけ数える。
@DataClassName('ImportIssueRow')
class ImportIssues extends Table {
  TextColumn get path => text()();
  TextColumn get hash => text()();
  TextColumn get kind => textEnum<ImportIssueKind>()();
  TextColumn get message => text()();
  IntColumn get occurrenceCount => integer().withDefault(const Constant(1))();
  DateTimeColumn get firstSeenAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {path, hash};
}
