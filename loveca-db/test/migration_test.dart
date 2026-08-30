/// 移行機構（`MigrationStrategy.onUpgrade`）の検証.
///
/// ★★ なぜこのテストが要るのか ★★
/// 決定 D49 で `schemaVersion` を 2 へ上げ `onUpgrade` を新設したが、
/// **それが呼ばれる経路はどこでも一度も実行されていなかった**
/// （`ルール整合性チェック_v1.06.md` D-6）。
///
/// | 経路 | 走るもの |
/// |---|---|
/// | ほかの全テスト | インメモリの**新規** DB → `onCreate` のみ |
/// | アプリの初回起動 | 新規 DB → `onCreate` のみ |
/// | アプリの 2 回目以降 | 版が同じ → **何も走らない** |
///
/// `rebuildAll()`（`onUpgrade` の中身）は `card_search_test.dart` で固定済みだが、
/// **`onUpgrade` から `rebuildAll()` が呼ばれること**は別問題である。
/// 移行が壊れていると気づくのは「新版を配ったあと・利用者の端末で」であり、
/// そのとき壊れうるのは**作り直せない `decks`**（決定 D11 / D35）。
///
/// ★★ ファイル DB が要る ★★
/// インメモリは閉じると消えるので「閉じて開き直す」ができない。
/// `openFileExecutor` は `native.dart` が「テストと使い捨ての検証向け」と定めている口。
library;

import 'dart:io';

// ★`Variable` だけが要る。drift の `isNotNull` は SQL 式ビルダで、
//   matcher の同名と衝突するので隠す。
import 'package:drift/drift.dart' show Variable;
import 'package:loveca_core/loveca_core.dart';
import 'package:loveca_db/loveca_db.dart';
import 'package:loveca_db/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

// ---------------------------------------------------------------------------
// v1 のスキーマ（★歴史的な値。凍結する）
// ---------------------------------------------------------------------------

/// 決定 D49 以前（`schemaVersion` 1）の `card_search`。
///
/// ★★ 現在の [cardSearchColumns] から導出しないこと ★★
/// 「今の定義から `card_number_raw` を引いたもの」として書くと、
/// **将来また列を足したときに v1 の定義も一緒に動き、テストが黙って無意味になる。**
/// 決定 D51 が言う「テストの無いものは静かに腐る」と同じ型の失敗である。
/// これは歴史的事実なので、直書きして凍結する。
const List<String> _v1CardSearchColumns = [
  'card_number',
  'name',
  'effect',
  'group_names',
  'unit_names',
];

/// 同上。v2 との差は `card_number_raw UNINDEXED` が**無い**ことだけ。
const String _createV1CardSearchTable = '''
CREATE VIRTUAL TABLE card_search USING fts5(
  card_number,
  name,
  effect,
  group_names,
  unit_names,
  tokenize = 'trigram'
)''';

/// `schemaVersion` 3 以前（決定 D65 / D99 以前）の `deck_entries`。
///
/// ★★ 現在の定義から導出しないこと ★★
/// [_v1CardSearchColumns] と同じ理由である。「今の定義から `ord` を引いたもの」と
/// して書くと、**将来また列を足したときに v2 の定義も一緒に動き、
/// テストが黙って無意味になる。** 歴史的事実なので直書きして凍結する。
///
/// ★drift が実際に吐いた DDL から `"ord" INTEGER NOT NULL DEFAULT 0, ` を
/// 取り除いたもの（2026-08-27 に実測して写した）。
const String _createV2DeckEntriesTable = '''
CREATE TABLE "deck_entries" (
  "deck_id" TEXT NOT NULL REFERENCES decks (deck_id) ON DELETE CASCADE,
  "printing_id" TEXT NOT NULL,
  "count" INTEGER NOT NULL,
  PRIMARY KEY ("deck_id", "printing_id")
)''';

const String _createV2DeckEntriesIndex =
    'CREATE INDEX idx_deck_entries_printing ON deck_entries (printing_id)';

/// `deck_entries` から `ord` を落として v2 の形に戻す。
///
/// ★★ `ALTER TABLE ... DROP COLUMN` を使わない ★★
/// SQLite 3.35+ なら使えるが、それは**現在の形から 1 列を引く**書き方であり、
/// 将来 v4 が別の列を足したとき**その列は残ったまま**になる。
/// 上の凍結した DDL で建て直せば、残るのは常に「凍結した v2 の形」である。
Future<void> _rewindDeckEntriesToV2(LovecaDatabase db) async {
  // ★外部キーが有効なままだと DROP TABLE で decks 側の参照が壊れる。
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.customStatement('ALTER TABLE deck_entries RENAME TO deck_entries_v3');
  await db.customStatement(_createV2DeckEntriesTable);
  await db.customStatement(
    'INSERT INTO deck_entries (deck_id, printing_id, count) '
    // ★★ ord で並べて写す ★★
    //   v2 の行には順序が無いが、**rowid の順は残る。**
    //   保存時の並びのまま写すと「移行前から規則順だった」ことになり、
    //   backfill が何もしなくても通ってしまう。
    //   ここは**保存時の並び**（= v2 の byId が返していた printing_id 昇順ではなく
    //   `save` が書いた順）を再現するのが正しい —— v2 の rowid はそれである。
    'SELECT deck_id, printing_id, count FROM deck_entries_v3 ORDER BY rowid',
  );
  await db.customStatement('DROP TABLE deck_entries_v3');
  await db.customStatement(_createV2DeckEntriesIndex);
  await db.customStatement('PRAGMA foreign_keys = ON');
}

/// `schemaVersion` 4 が足した `deck_edit_ops` を落として v3 の形に戻す。
///
/// ★★ ここは列ではなく**表**を落とす ★★
/// v3 の `deck_edit_ops` は「無い」のが正しい形なので、凍結すべき DDL が存在しない
/// （[_createV2DeckEntriesTable] のように写しておく相手が無い）。
///
/// ★★ `ALTER TABLE ... DROP COLUMN` を使わないという取り決めはここでも生きている ★★
/// [_rewindDeckEntriesToV2] が書いているとおり、DROP COLUMN は
/// **現在の形から 1 つ引く**書き方なので、次の版が別の列を足すとそれが残る。
/// 表ごと落とす書き方には同じ弱点が無い —— 落ちるのは常に**この表の全部**である。
///
/// ★★ これが無いと移行が黙って空振りする（2026-08-30 に実測）★★
/// drift の `Migrator.createTable` は **`CREATE TABLE IF NOT EXISTS`** を吐く
/// （`drift/lib/src/runtime/query_builder/migration.dart:319`。★実読）。
/// → 巻き戻しでこの表を落とさないと、`from < 4` の枝は**例外も出さずに何もしない。**
/// [_rewindToV1] の doc が予告していた「★より悪い場合は黙って通って
/// **移行を一度も検証しないテストになる**」がまさにこれである。
///
/// ★★ 実測した対（★数を丸めない / **D-15 (j)**）★★
/// この呼び出しを外して走らせると、★**落ちるのは
/// 「前提: 巻き戻した DB は v3 の形」の 1 件だけ**で、
/// **群の残りは 1 件も落ちない**（表は `createAll` が作った版がそのまま在るため）。
/// → ★**この 1 件がこの群の要石である。**「まず前提を見る」を外形だけ真似て
///   中身を弱めると、群ごと無言で無意味になる。
///
/// ★`IF EXISTS` を付けない。★この表は常に在るはずで、無ければ巻き戻しの側が壊れている。
/// 黙って通すと上の空振りに戻る。
Future<void> _dropDeckEditOpsTable(LovecaDatabase db) async {
  await db.customStatement('DROP TABLE deck_edit_ops');
}

// ---------------------------------------------------------------------------
// v1 の DB を作る
// ---------------------------------------------------------------------------

/// v2 で作った DB を v1 相当へ巻き戻す。
///
/// ★★ 2026-08-27: 上の注記が言っていた「そのとき」が来た（決定 D65 / D99）★★
/// `schemaVersion` 3 が **`deck_entries` に `ord` を足した**ので、
/// **v1 / v2 と v3 で実テーブルが同一ではなくなった。**
/// → [_rewindDeckEntriesToV2] を足し、`deck_entries` の v2 の定義を**凍結**した。
/// ★**注記どおりに手当てした。**手法を黙って流用していない。
///
/// ★★ この手法が正しい条件（v3 版）★★
/// **v1 / v2 と v3 の実テーブルの差が、下で巻き戻している分に尽きること。**
/// いまの差は `deck_entries.ord` の 1 列だけである。
///
/// ★**次に実テーブルを動かす移行を入れたら、また巻き戻しを足すこと。**
/// 足さないと `ALTER TABLE ... ADD COLUMN` が
/// **「duplicate column name」で落ちる**か、より悪い場合は黙って通って
/// **移行を一度も検証しないテストになる。**
///
/// ★★ 2026-08-30: その「次」が来た（決定 **D110-1** / `schemaVersion` 4）★★
/// `deck_edit_ops` を足したので [_dropDeckEditOpsTable] を足した。
/// ★★**そして「より悪い場合」のほうが起きる版だった**★★ ——
/// 列ではなく表なので `ADD COLUMN` の重複では落ちず、drift の
/// `CREATE TABLE IF NOT EXISTS` が**黙って通す**（[_dropDeckEditOpsTable] の doc）。
/// ★**実測した内訳はそちらに書いた**（★落ちるのは前提の 1 件だけである）。
///
/// ★別案を採らなかった理由（`ルール整合性チェック_v1.06.md` D-6 の解消記録）
/// - 生 SQL で v1 を全部書く … 実テーブルは同一なので複製しても何も検証しない
/// - drift の `SchemaVerifier` … ★**drift は `card_search` を知らない。**
///   `customStatement` で作る仮想テーブルは `allSchemaEntities` に載らず
///   スキーマ比較の対象外なので、**v1↔v2 の唯一の差分が見えない。**
Future<void> _rewindToV1(LovecaDatabase db) async {
  await db.customStatement('DROP TABLE IF EXISTS card_search');
  await db.customStatement(_createV1CardSearchTable);

  // v1 の索引を、当時と同じ内容で埋め直す。
  // ★v1 は「折りたたんだ cardNumber」しか持たない（生の表記の保管列が無い）。
  //   これが D49 が解消した弱点そのものである。
  final rows = await db
      .customSelect('SELECT card_number, name, effect_text FROM cards')
      .get();
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

  final placeholders = List.filled(_v1CardSearchColumns.length, '?').join(', ');
  for (final r in rows) {
    final number = r.read<String>('card_number');
    await db.customInsert(
      'INSERT INTO card_search (${_v1CardSearchColumns.join(', ')}) '
      'VALUES ($placeholders)',
      variables: [
        Variable<String>(fold(number)),
        Variable<String>(fold(r.read<String>('name'))),
        Variable<String>(fold(r.read<String>('effect_text'))),
        Variable<String>(foldJoin(groups[number] ?? const [])),
        Variable<String>(foldJoin(units[number] ?? const [])),
      ],
    );
  }

  // ★v1 にも `ord` は無い（決定 D65 / D99 は v3）。
  await _rewindDeckEntriesToV2(db);
  // ★v1 にも `deck_edit_ops` は無い（決定 D110-1 は v4）。
  await _dropDeckEditOpsTable(db);

  // ★drift の native 実装は `user_version` プラグマで版を判定する
  //   （`drift/lib/native.dart`「This uses the `user_version` sqlite3 pragma」）。
  //   ここを 1 にして開き直すと `onUpgrade(1, 3)` が走る。
  await db.customStatement('PRAGMA user_version = 1');
}

/// v3 で作った DB を v2 相当へ巻き戻す（決定 D65 / D99 の移行だけを見るため）。
///
/// ★`card_search` は v2 の形のままにする。v1 から巻き戻すと
/// **`from < 2` の枝も一緒に走り、どちらの効果か分からなくなる。**
Future<void> _rewindToV2(LovecaDatabase db) async {
  await _rewindDeckEntriesToV2(db);
  await _dropDeckEditOpsTable(db);
  await db.customStatement('PRAGMA user_version = 2');
}

/// v4 で作った DB を v3 相当へ巻き戻す（決定 **D110-1** の移行だけを見るため）。
///
/// ★`card_search` は v2 の形・`deck_entries` は v3 の形（`ord` あり）のままにする。
/// もっと前から巻き戻すと `from < 2` / `from < 3` の枝も一緒に走り、
/// **どの枝の効果か分からなくなる**（[_rewindToV2] と同じ理由）。
///
/// ★★ 落とすのは**この版が足した分だけ**である ★★
/// v5 が別の表を足したら、その表を落とすのは `_rewindToV4`（新設）の役目であって
/// ここではない。★**各段が「自分の版が足したもの」を落とす**形を崩さないこと。
Future<void> _rewindToV3(LovecaDatabase db) async {
  await _dropDeckEditOpsTable(db);
  await db.customStatement('PRAGMA user_version = 3');
}

Future<int> _userVersion(LovecaDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

/// いま在る実テーブルの名前（★`sqlite_` で始まる内部表は除く）。
///
/// ★`sqlite_sequence` を除いてある —— `AUTOINCREMENT` を使う表が 1 つでもあると
/// SQLite が勝手に作る表で、**移行が作ったものではない**（`deck_edit_ops` を
/// 落としても残る）。混ぜると「v3 の形」の判定が SQLite の都合に振り回される。
Future<List<String>> _tableNames(LovecaDatabase db) async {
  final rows = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  ).get();
  return [for (final r in rows) r.read<String>('name')];
}

Future<List<String>> _cardSearchColumnNames(LovecaDatabase db) async {
  final rows = await db.customSelect('PRAGMA table_info(card_search)').get();
  return [for (final r in rows) r.read<String>('name')];
}

/// 索引に「`cards` に対応の無い」行を 1 つ入れる。
///
/// [rebuildAll] は `DROP TABLE` してから `cards` / `card_names` で建て直すため、
/// この行は**移行が走れば必ず消える**。移行が走らなければ残る。
Future<void> _insertSentinel(LovecaDatabase db) async {
  final placeholders = List.filled(cardSearchColumns.length, '?').join(', ');
  await db.customInsert(
    'INSERT INTO card_search (${cardSearchColumns.join(', ')}) '
    'VALUES ($placeholders)',
    variables: [
      for (var i = 0; i < cardSearchColumns.length; i++)
        const Variable<String>(_sentinel),
    ],
  );
}

const String _sentinel = 'ZZZ-sentinel-row';

Future<bool> _sentinelSurvives(LovecaDatabase db) async {
  final row = await db.customSelect(
    'SELECT COUNT(*) AS c FROM card_search WHERE $cardSearchRawColumn = ?',
    variables: [const Variable<String>(_sentinel)],
  ).getSingle();
  return row.read<int>('c') > 0;
}

// ---------------------------------------------------------------------------

void main() {
  late Directory tmp;
  late String dbPath;

  /// 移行前に作っておくユーザデータ（決定 D11 / D35）。
  final deck = Deck(
    deckId: 'deck-migration-test',
    name: '移行で消えないことを確かめるデッキ',
    entries: const [
      DeckEntry(printingId: '$multiPrintingMember-N', count: 4),
      DeckEntry(printingId: '$multiPrintingWithParallel-N', count: 2),
    ],
    memo: 'このメモも残ること',
    tags: const ['タグA', 'タグB'],
    coverPrintingId: '$multiPrintingMember-N',
    createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    updatedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    revision: 7,
    lastDeviceId: 'test-device',
    masterDataVersion: 1,
  );

  /// v1 の DB をファイル上に用意する。
  Future<void> buildV1Database() async {
    final db = LovecaDatabase(openFileExecutor(dbPath));
    for (final expansion in fixtureExpansions) {
      await CardDao(db).replaceExpansion(loadCardSet(expansion));
    }
    await DeckDao(db).save(deck);
    await _rewindToV1(db);
    await db.close();
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('loveca_migration_test');
    dbPath = '${tmp.path}/loveca.db';
  });

  // ★失敗したテストが DB を掴んだままだと削除に失敗する。
  //   ここで投げると**本当の失敗理由が削除エラーに埋もれる**ので握る。
  //   握ってよいのは後始末だけで、検証結果は握らない。
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException catch (_) {
      // 一時ディレクトリの残骸は OS に任せる。
    }
  });

  test('★前提: 巻き戻した DB は v1 の形（5 列 / user_version 1）', () async {
    await buildV1Database();

    // ★drift で開くと移行が走ってしまうので、素の sqlite3 で覗く。
    final raw = sqlite3.open(dbPath);
    addTearDown(raw.close);

    final columns = raw
        .select('PRAGMA table_info(card_search)')
        .map((r) => r['name'] as String)
        .toList();
    expect(columns, _v1CardSearchColumns);
    expect(columns, isNot(contains(cardSearchRawColumn)));

    expect(raw.select('PRAGMA user_version').first['user_version'], 1);
  });

  group('★ v1 を最新版で開くと onUpgrade が走る（決定 D49 / D-6）', () {
    late LovecaDatabase db;

    setUp(() async {
      await buildV1Database();
      db = LovecaDatabase(openFileExecutor(dbPath));
      // ★最初のクエリで onCreate / onUpgrade / beforeOpen が走る。
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() => db.close());

    test('索引が v2 の形になる（card_number_raw が生える）', () async {
      expect(await _cardSearchColumnNames(db), cardSearchColumns);
      expect(await _cardSearchColumnNames(db), contains(cardSearchRawColumn));
    });

    test('user_version が 4 になる', () async {
      // ★★ これ単独では移行の中身が走った証拠にならない ★★
      // drift は `onUpgrade` が何もしなくても版を上げる。実際、
      // `onUpgrade` の中身を空にして走らせる実験（2026-08-24）では
      // **この test だけは通った。** 落ちたのは「索引が v2 の形になる」
      // 「trigram 経路で引ける」「返る cardNumber が保存表記」の 3 つである。
      // → 移行が働いたことを言えるのはそれらであって、この test ではない。
      //
      // ★2026-08-27: v1 から開くと `from < 2` と `from < 3` の両方が走るので
      //   着地は 3 である（決定 D65 / D99）。
      // ★2026-08-30: `from < 4` が足されたので着地は 4 になった（決定 D110-1）。
      expect(await _userVersion(db), 4);
    });

    test('★ deck_edit_ops も生える（3 つの枝が順に走る / 決定 D110-1）', () async {
      // ★★ 上の test が「版が上がったこと」しか言えないことの受け ★★
      //   v1 から開くと `from < 2` / `from < 3` / `from < 4` の 3 つが走る。
      //   ★**最後の枝まで到達したこと**を、着地した版ではなく**表の有無**で見る。
      expect(await _tableNames(db), contains('deck_edit_ops'));
    });

    test('★★ decks が保存される（決定 D49 の主張の検証）★★', () async {
      // D49:「案C の移行は card_search を落として建て直すだけで、
      //       ユーザデータ（decks）に一切触れない」
      final restored = await DeckDao(db).byId(deck.deckId);

      expect(restored, isNotNull);
      expect(restored!.name, deck.name);
      expect(restored.memo, deck.memo);
      expect(restored.tags, deck.tags);
      expect(restored.coverPrintingId, deck.coverPrintingId);
      expect(restored.revision, deck.revision);
      expect(restored.lastDeviceId, deck.lastDeviceId);
      expect(restored.masterDataVersion, deck.masterDataVersion);
      expect(restored.createdAt, deck.createdAt);
      expect(restored.updatedAt, deck.updatedAt);

      // 入っていた刷りと枚数がそのまま。
      final byPrinting = {
        for (final e in restored.entries) e.printingId: e.count,
      };
      expect(byPrinting, {
        for (final e in deck.entries) e.printingId: e.count,
      });
    });

    test('cards / printings も消えない', () async {
      final cards = CardDao(db);
      expect(await cards.cardCount(), greaterThan(0));
      expect(await cards.cardByNumber(multiPrintingMember), isNotNull);
      expect(await cards.printingsOfCard(multiPrintingMember), isNotEmpty);
    });

    group('★ 索引が再構築され検索が動く', () {
      test('索引の件数がカード件数と一致する', () async {
        expect(await CardSearchDao(db).indexedCount(),
            await CardDao(db).cardCount());
      });

      test('trigram 経路で引ける', () async {
        final result = await CardSearchDao(db).search('ライブ開始時');
        expect(result.mode, CardSearchMode.trigram);
        expect(result.cardNumbers, isNotEmpty);
      });

      test('★返る cardNumber が保存表記（fold 済みでない）', () async {
        // v1 の索引は折りたたんだ cardNumber しか持たなかった。
        // 移行で card_number_raw が生え、保存表記が返るようになる（D49）。
        final result = await CardSearchDao(db).search('bp1-012');

        expect(result.cardNumbers, contains(multiPrintingMember));
        for (final number in result.cardNumbers) {
          expect(await CardDao(db).cardByNumber(number), isNotNull,
              reason: '$number が cards に無い＝保存表記で返っていない');
        }
      });
    });
  });

  // =========================================================================
  // v2 -> v3: deck_entries.ord（決定 D65 / D99）
  // =========================================================================

  /// ★★ 保存時の並びは「規則順でも printingId 昇順でもない」★★
  /// 移行前から規則順で入っていると、**backfill が何もしなくても通る。**
  /// ここは 3 つの並びを互いに違えてある（下の前提テストが機械で見張る）。
  final scrambledDeck = Deck(
    deckId: 'deck-ord-migration',
    name: 'ord の backfill を確かめるデッキ',
    entries: const [
      DeckEntry(printingId: 'PL!HS-bp1-019-L', count: 1), // ライブ score 1
      DeckEntry(printingId: 'LL-E-002-SD', count: 3), // エネルギー
      DeckEntry(printingId: 'PL!HS-bp1-007-R', count: 4), // メンバー cost 2
      DeckEntry(printingId: 'ZZZ-unknown-999-X', count: 1), // ★マスタに無い
      DeckEntry(printingId: 'LL-bp1-001-R+', count: 1), // メンバー cost 20
      DeckEntry(printingId: 'PL!-bp3-021-L', count: 1), // ライブ score 6
      DeckEntry(printingId: 'PL!HS-bp1-005-P', count: 2), // メンバー cost 9
      DeckEntry(printingId: 'PL!HS-bp1-021-L', count: 1), // ライブ score 4
    ],
    createdAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
    updatedAt: DateTime.utc(2026, 2, 3, 4, 5, 6),
    revision: 3,
  );

  /// 決定 D99 の規則順（区分順 → cost/score 降順 → printingId 昇順）。
  const expectedRuleOrder = [
    'LL-bp1-001-R+', // メンバー 20
    'PL!HS-bp1-005-P', // メンバー 9
    'PL!HS-bp1-007-R', // メンバー 2
    'PL!-bp3-021-L', // ライブ 6
    'PL!HS-bp1-021-L', // ライブ 4
    'PL!HS-bp1-019-L', // ライブ 1
    'LL-E-002-SD', // エネルギー
    'ZZZ-unknown-999-X', // ★未知は末尾（決定 D35）
  ];

  /// v2 の DB をファイル上に用意する（`card_search` は v2 のまま）。
  Future<void> buildV2Database() async {
    final db = LovecaDatabase(openFileExecutor(dbPath));
    for (final expansion in fixtureExpansions) {
      await CardDao(db).replaceExpansion(loadCardSet(expansion));
    }
    await DeckDao(db).save(deck);
    await DeckDao(db).save(scrambledDeck);
    await _rewindToV2(db);
    await db.close();
  }

  group('★★ v2 -> v3: ord の backfill（決定 D65 / D99）★★', () {
    test('★前提: 保存順 / 規則順 / printingId 昇順 は 3 つとも違う', () {
      // ★★ これが陽性対照の土台である ★★
      // どれか 2 つが一致していると、backfill が何もしなくても
      // 下のテストが通ってしまう。
      final saved = [for (final e in scrambledDeck.entries) e.printingId];
      final ascending = [...saved]..sort();

      expect(saved, isNot(equals(expectedRuleOrder)),
          reason: '保存順が規則順と同じでは backfill を検証できない');
      expect(ascending, isNot(equals(expectedRuleOrder)),
          reason: 'printingId 昇順が規則順と同じでは D99 の分を検証できない');
      expect(saved, isNot(equals(ascending)));
    });

    test('★前提: 巻き戻した DB は v2 の形（ord が無い / user_version 2）', () async {
      await buildV2Database();

      // ★drift で開くと移行が走ってしまうので、素の sqlite3 で覗く。
      final raw = sqlite3.open(dbPath);
      addTearDown(raw.close);

      final columns = raw
          .select('PRAGMA table_info(deck_entries)')
          .map((r) => r['name'] as String)
          .toList();
      expect(columns, ['deck_id', 'printing_id', 'count']);
      expect(columns, isNot(contains('ord')));
      expect(raw.select('PRAGMA user_version').first['user_version'], 2);

      // ★索引も戻っていること（巻き戻しが index を落としたままだと、
      //   移行後の形が本番と違うのに気づけない）。
      final indexes = raw
          .select("SELECT name FROM sqlite_master WHERE type='index' "
              "AND tbl_name='deck_entries'")
          .map((r) => r['name'] as String)
          .toList();
      expect(indexes, contains('idx_deck_entries_printing'));
    });

    group('v2 を最新版で開く', () {
      late LovecaDatabase db;

      setUp(() async {
        await buildV2Database();
        db = LovecaDatabase(openFileExecutor(dbPath));
        await db.customSelect('SELECT 1').get();
      });

      tearDown(() => db.close());

      test('ord 列が生える / user_version が 4 になる', () async {
        final columns = await db
            .customSelect('PRAGMA table_info(deck_entries)')
            .get()
            .then((rows) => [for (final r in rows) r.read<String>('name')]);
        expect(columns, contains('ord'));
        // ★2026-08-30: v2 から開くと `from < 3` と `from < 4` の両方が走るので
        //   着地は 4 である（決定 D110-1）。**この群が見ているのは `ord` のほう**で、
        //   版はその副産物にすぎない（上の「これ単独では証拠にならない」と同じ）。
        expect(await _userVersion(db), 4);
      });

      test('★★ backfill が規則順で ord を書く（決定 D99）★★', () async {
        // ★backfill が走らなければ ord は全件 0 のままで、
        //   ORDER BY ord は挿入順（= 保存順）を返す。前提テストにより
        //   保存順 ≠ 規則順 なので、ここが落ちる。
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);
        expect(
          [for (final e in restored!.entries) e.printingId],
          equals(expectedRuleOrder),
        );
      });

      test('★ ord は 0 から連番（デッキごとに振り直す）', () async {
        final ords = await db
            .customSelect(
              'SELECT ord FROM deck_entries WHERE deck_id = ? ORDER BY ord',
              variables: [Variable<String>(scrambledDeck.deckId)],
            )
            .get()
            .then((rows) => [for (final r in rows) r.read<int>('ord')]);
        expect(ords, [0, 1, 2, 3, 4, 5, 6, 7]);
      });

      test('★ もう 1 つのデッキも 0 から始まる（deck ごとに独立）', () async {
        final ords = await db
            .customSelect(
              'SELECT ord FROM deck_entries WHERE deck_id = ? ORDER BY ord',
              variables: [Variable<String>(deck.deckId)],
            )
            .get()
            .then((rows) => [for (final r in rows) r.read<int>('ord')]);
        expect(ords, [0, 1]);
      });

      test('★★ decks が残る（ユーザデータに触る移行 / 決定 D65）★★', () async {
        // ★D49 の移行（索引の建て直し）と違い、これは deck_entries そのものを
        //   触る移行である。**中身が消えていないこと**を別に見る。
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);

        expect(restored, isNotNull);
        expect(restored!.name, scrambledDeck.name);
        expect(restored.revision, scrambledDeck.revision);
        expect(restored.createdAt, scrambledDeck.createdAt);
        expect(
          {for (final e in restored.entries) e.printingId: e.count},
          {for (final e in scrambledDeck.entries) e.printingId: e.count},
        );
      });

      test('★ マスタに無い刷りも消えない（決定 D35）', () async {
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);
        expect(
          [for (final e in restored!.entries) e.printingId],
          contains('ZZZ-unknown-999-X'),
        );
      });

      test('★★ all と byId が同じ並びを返す（D-11 の経路差の解消）★★', () async {
        // ★★ 「互いに一致する」だけでは足りない ★★
        //   ORDER BY を両方から落としても、たまたま一致しうる。
        //   **両方が規則順であること**を見る。
        final viaAll = (await DeckDao(db).all())
            .firstWhere((d) => d.deckId == scrambledDeck.deckId);
        final viaById = await DeckDao(db).byId(scrambledDeck.deckId);

        expect([for (final e in viaAll.entries) e.printingId],
            equals(expectedRuleOrder));
        expect([for (final e in viaById!.entries) e.printingId],
            equals(expectedRuleOrder));
      });

      test('★ 保存し直すと画面の並びがそのまま入る（save が添字を書く）', () async {
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);
        // ★規則順とは違う並びに手で組み替える。
        final reordered = [...restored!.entries.reversed];
        await DeckDao(db).save(
          Deck(
            deckId: restored.deckId,
            name: restored.name,
            entries: reordered,
            memo: restored.memo,
            tags: restored.tags,
            coverPrintingId: restored.coverPrintingId,
            createdAt: restored.createdAt,
            updatedAt: restored.updatedAt,
            revision: restored.revision + 1,
            lastDeviceId: restored.lastDeviceId,
            masterDataVersion: restored.masterDataVersion,
          ),
        );

        final again = await DeckDao(db).byId(scrambledDeck.deckId);
        expect([for (final e in again!.entries) e.printingId],
            equals(expectedRuleOrder.reversed.toList()));
        // ★対: 規則順に戻っていないこと（save が並びを書いている証拠）。
        expect([for (final e in again.entries) e.printingId],
            isNot(equals(expectedRuleOrder)));
      });
    });

    test('★ 2 回目に開いても backfill は走らない（手動順を踏み潰さない）', () async {
      // ★★ ここが v2 -> v3 で最も怖い誤りである ★★
      //   毎起動で backfill が走ると、**利用者が並べ替えた順が毎回消える。**
      await buildV2Database();

      final first = LovecaDatabase(openFileExecutor(dbPath));
      await first.customSelect('SELECT 1').get();
      final restored = await DeckDao(first).byId(scrambledDeck.deckId);
      await DeckDao(first).save(
        Deck(
          deckId: restored!.deckId,
          name: restored.name,
          entries: [...restored.entries.reversed],
          createdAt: restored.createdAt,
          updatedAt: restored.updatedAt,
        ),
      );
      await first.close();

      final second = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      final again = await DeckDao(second).byId(scrambledDeck.deckId);
      expect([for (final e in again!.entries) e.printingId],
          equals(expectedRuleOrder.reversed.toList()),
          reason: '★毎起動で backfill が走り、手動の並びが消えている');
    });

    test('★ マスタが空でも落ちない（全件が未知 = printingId 昇順）', () async {
      // ★★ カードを取り込む前に古い DB を開く経路の受け ★★
      //   cards / printings が空なら全件が「マスタに無い刷り」になり
      //   （決定 D35）、段 3 だけが効く。**移行前の並びと同じ**なので
      //   その端末では見た目が変わらない。
      final build = LovecaDatabase(openFileExecutor(dbPath));
      await DeckDao(build).save(scrambledDeck); // ★カードを 1 枚も入れない
      await _rewindToV2(build);
      await build.close();

      final db = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      final restored = await DeckDao(db).byId(scrambledDeck.deckId);
      expect(
        [for (final e in restored!.entries) e.printingId],
        equals([for (final e in scrambledDeck.entries) e.printingId]..sort()),
      );
    });
  });


  // =========================================================================
  // v3 -> v4: deck_edit_ops（決定 D110-1 / 編集ログの表）
  // =========================================================================

  /// v3 の DB をファイル上に用意する（`card_search` は v2 / `deck_entries` は v3）。
  ///
  /// ★**規則順ではない並び**（`scrambledDeck` の保存順）のまま v3 に置く。
  /// これが下の「並びが 1 つも動かない」の陽性対照になる ——
  /// もし `from < 4` の枝が `deck_entries` に触って backfill を巻き添えにすると、
  /// 並びが**規則順へ飛ぶ**ので落ちる。
  Future<void> buildV3Database() async {
    final db = LovecaDatabase(openFileExecutor(dbPath));
    for (final expansion in fixtureExpansions) {
      await CardDao(db).replaceExpansion(loadCardSet(expansion));
    }
    await DeckDao(db).save(deck);
    await DeckDao(db).save(scrambledDeck);
    await _rewindToV3(db);
    await db.close();
  }

  /// v3 に保存した時点の並び（= `save` が書いた添字の順 = `scrambledDeck` の順）。
  final savedOrder = [for (final e in scrambledDeck.entries) e.printingId];

  group('★★ v3 -> v4: 編集ログの表（決定 D110-1）★★', () {
    test('★前提: 保存順は規則順ではない（下の陽性対照の土台）', () {
      // ★★ これが無いと「並びが動かない」が何も証明しない ★★
      //   保存順が最初から規則順なら、移行が backfill を巻き添えにしても
      //   並びは変わらず、下のテストは通ってしまう。
      expect(savedOrder, isNot(equals(expectedRuleOrder)));
    });

    test('★前提: 巻き戻した DB は v3 の形（deck_edit_ops が無い / user_version 3）',
        () async {
      // ★★ この群の要石である（2026-08-30 に実測）★★
      //   drift の `createTable` は `CREATE TABLE IF NOT EXISTS` なので、
      //   巻き戻しが `deck_edit_ops` を落とし損ねると `from < 4` は**空振りする**。
      //   そのとき落ちるのは**この 1 件だけ**で、群の残りは 1 件も落ちない。
      //   → ★**ここを弱めると群ごと無言で無意味になる**（`_dropDeckEditOpsTable` の doc）。
      await buildV3Database();

      // ★drift で開くと移行が走ってしまうので、素の sqlite3 で覗く。
      final raw = sqlite3.open(dbPath);
      addTearDown(raw.close);

      final tables = raw
          .select("SELECT name FROM sqlite_master WHERE type='table' "
              "AND name NOT LIKE 'sqlite_%' ORDER BY name")
          .map((r) => r['name'] as String)
          .toList();
      expect(tables, isNot(contains('deck_edit_ops')));
      // ★対: v3 に在るはずの表は残っていること（巻き戻しが行き過ぎていない）。
      expect(tables, contains('decks'));
      expect(tables, contains('deck_entries'));

      expect(raw.select('PRAGMA user_version').first['user_version'], 3);

      // ★v3 の `deck_entries` は `ord` を持つ（ここまで巻き戻していない）。
      final columns = raw
          .select('PRAGMA table_info(deck_entries)')
          .map((r) => r['name'] as String)
          .toList();
      expect(columns, contains('ord'));
    });

    group('v3 を最新版で開く', () {
      late LovecaDatabase db;

      setUp(() async {
        await buildV3Database();
        db = LovecaDatabase(openFileExecutor(dbPath));
        await db.customSelect('SELECT 1').get();
      });

      tearDown(() => db.close());

      test('deck_edit_ops が生える / user_version が 4 になる', () async {
        expect(await _tableNames(db), contains('deck_edit_ops'));
        expect(await _userVersion(db), 4);
      });

      test('★★ 列は 4 つだけ（引数の列を作っていない / 決定 D110-1）★★', () async {
        // ★★ 「決めていないことを型で決めない」ことの機械的な受け ★★
        //   `docs/同期設計メモ.md` §17-9-1 の 1 は最低限を
        //   **deckId / 操作の種類 / 引数 / 時刻 / 順序** と書いているが、
        //   §17-9-2 の 2（引数をどこまで持つか）と 4（`sortByRule` の入れ方）が**未決**。
        //   → ★**引数の列を作らない。**作れば決めたことになる。
        //   ★この期待値が増えたら「引数を決めた」はずである。**黙って増やさないこと。**
        final columns = await db
            .customSelect('PRAGMA table_info(deck_edit_ops)')
            .get()
            .then((rows) => [for (final r in rows) r.read<String>('name')]);
        expect(columns, ['id', 'deck_id', 'kind', 'at']);
      });

      test('★ id は AUTOINCREMENT（rowid を使い回さない / N-16 の前提）', () async {
        // ★★ 素の INTEGER PRIMARY KEY との差はここでしか出ない ★★
        //   素の rowid は「いま在る行の最大 + 1」なので、**末尾を消すと番号が戻る。**
        //   N-16（ログをいつ捨てるか）が古い行を捨てた瞬間に
        //   「目印より後ろ」の判定が壊れる。
        Future<int> insertOne() {
          return db.into(db.deckEditOps).insert(
                DeckEditOpsCompanion.insert(
                  deckId: 'deck-autoincrement',
                  kind: DeckEditOpKind.setName.key,
                  at: DateTime.utc(2026, 8, 30),
                ),
              );
        }

        final first = await insertOne();
        final second = await insertOne();
        expect(second, greaterThan(first));

        await (db.delete(db.deckEditOps)..where((t) => t.id.equals(second)))
            .go();

        final third = await insertOne();
        expect(third, greaterThan(second),
            reason: '★rowid が使い回された = AUTOINCREMENT になっていない');
      });

      test('★★ 新表は空である（この版に書き込む経路は 1 本も無い）★★', () async {
        expect(await db.select(db.deckEditOps).get(), isEmpty);
      });

      test('★★ 対: 空でない状態は作れる（上が「作れないから空」ではないこと）★★',
          () async {
        // ★★ D-10 —— 0 件は「無い」と「見えていない」の区別がつかない ★★
        //   表そのものが壊れていても「空」は通る。**入れられることを見る。**
        await db.into(db.deckEditOps).insert(
              DeckEditOpsCompanion.insert(
                deckId: scrambledDeck.deckId,
                kind: DeckEditOpKind.moveEntry.key,
                at: DateTime.utc(2026, 8, 30, 12, 34, 56),
              ),
            );

        final rows = await db.select(db.deckEditOps).get();
        expect(rows, hasLength(1));
        expect(rows.single.deckId, scrambledDeck.deckId);
        expect(rows.single.kind, DeckEditOpKind.moveEntry.key);
        expect(rows.single.at.toUtc(), DateTime.utc(2026, 8, 30, 12, 34, 56));
      });

      test('★★ kind は key の字面を持つ（Dart の識別子ではない / 決定 D110-1）★★',
          () async {
        // ★★ `textEnum<DeckEditOpKind>()` にすると黙って裏返る ★★
        //   drift の `EnumNameConverter` は **`value.name`（識別子）**を保存する
        //   （`drift/lib/src/runtime/types/converters.dart:283`）。
        //   `deleteDeck` の識別子は `deleteDeck` だが、**キーは `softDelete`** である
        //   —— リネームで送信済みのログが意味を失わないよう、わざと違えてある。
        await db.into(db.deckEditOps).insert(
              DeckEditOpsCompanion.insert(
                deckId: scrambledDeck.deckId,
                kind: DeckEditOpKind.deleteDeck.key,
                at: DateTime.utc(2026, 8, 30),
              ),
            );

        // ★drift を介さず生の字面を見る（型変換に隠れないように）。
        final raw = await db
            .customSelect('SELECT kind FROM deck_edit_ops')
            .getSingle()
            .then((r) => r.read<String>('kind'));
        expect(raw, 'softDelete');

        // ★対: 識別子とは違うこと。ここが一致し始めたら key の規則が壊れている。
        expect(raw, isNot(DeckEditOpKind.deleteDeck.name));
      });

      test('★★ decks が残る（§17-9-1 の 4「ユーザデータに触らない」の検証）★★',
          () async {
        // ★★ 「触らない」を「安全」と読み替えない ★★
        //   表を作るだけの枝でも `schemaVersion` は上がり、
        //   **既存インストールの DB は必ずここを通る。**通る以上、測る。
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);

        expect(restored, isNotNull);
        expect(restored!.name, scrambledDeck.name);
        expect(restored.memo, scrambledDeck.memo);
        expect(restored.tags, scrambledDeck.tags);
        expect(restored.coverPrintingId, scrambledDeck.coverPrintingId);
        expect(restored.createdAt, scrambledDeck.createdAt);
        expect(
          {for (final e in restored.entries) e.printingId: e.count},
          {for (final e in scrambledDeck.entries) e.printingId: e.count},
        );
      });

      test('★★ 並び（ord）が 1 つも動かない ★★', () async {
        // ★★ 陽性対照つき ★★
        //   `from < 4` の枝が `deck_entries` に触れば、**規則順へ飛ぶ**
        //   （backfill を巻き添えにした場合）。上の前提テストが
        //   「保存順 ≠ 規則順」を見張っているので、この対が効く。
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);
        expect([for (final e in restored!.entries) e.printingId],
            equals(savedOrder));
        expect([for (final e in restored.entries) e.printingId],
            isNot(equals(expectedRuleOrder)),
            reason: '★規則順へ飛んだ = この枝が backfill を巻き添えにしている');
      });

      test('★★ 決定 D109: updatedAt / revision が動かない（移行はシステム）★★',
          () async {
        // ★決定 D109-1:「更新」の日付を動かすかは**変更の主体**で決める。
        //   移行はシステムが動かした側なので**動かさない**（D109-2 の事例 1）。
        //   ★`revision` には D109 が及ばない（D109-5 の 1）が、
        //     **この枝は 1 行も書かない**ので、どちらも動かないことをまとめて見る。
        final restored = await DeckDao(db).byId(scrambledDeck.deckId);
        expect(restored!.updatedAt, scrambledDeck.updatedAt);
        expect(restored.revision, scrambledDeck.revision);
        expect(restored.deletedAt, isNull);
      });
    });

    test('★ 2 回目に開いても表は作り直されない（入れた行が消えない）', () async {
      // ★★ v2 -> v3 の「2 回目に backfill は走らない」と同じ形 ★★
      //   drift の `createTable` は `CREATE TABLE IF NOT EXISTS` なので
      //   **走っても例外は出ない。**行が消えるかどうかでしか観測できない。
      await buildV3Database();

      final first = LovecaDatabase(openFileExecutor(dbPath));
      await first.customSelect('SELECT 1').get();
      await first.into(first.deckEditOps).insert(
            DeckEditOpsCompanion.insert(
              deckId: scrambledDeck.deckId,
              kind: DeckEditOpKind.addCard.key,
              at: DateTime.utc(2026, 8, 30),
            ),
          );
      await first.close();

      final second = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      expect(await second.select(second.deckEditOps).get(), hasLength(1),
          reason: '★毎起動で表が作り直されている');
    });
  });

  group('★ 移行が過剰に走らないこと', () {
    test('★前提: rebuildAll は破壊的である（下の番兵方式が依拠する）', () async {
      // ★★ この前提が崩れたら下のテストは無意味になる ★★
      // 番兵方式は「rebuildAll が DROP TABLE してから建て直す」ことに依存している
      // （`card_search_dao.dart` の `rebuildAll`）。
      // もし将来 rebuildAll が「既存行を残して差分更新する」実装に変わると、
      // 番兵は生き残り、下のテストは**通り続けるが何も検証しなくなる。**
      //
      // その依存を黙って抱えないよう、前提そのものをここで固定する。
      // ★この test が落ちたら、下の「2 回目は onUpgrade が走らない」を
      //   別の観測手段に作り直すこと。番兵を消して済ませないこと。
      await buildV1Database();
      final db = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      await _insertSentinel(db);
      expect(await _sentinelSurvives(db), isTrue,
          reason: '番兵が入っていない。テストの前提が壊れている');

      await CardSearchDao(db).rebuildAll();

      expect(await _sentinelSurvives(db), isFalse,
          reason: '★rebuildAll が破壊的でなくなった。番兵方式は使えない');
    });

    test('2 回目に開いても onUpgrade は走らない', () async {
      await buildV1Database();

      // 1 回目: 移行が走る。
      final first = LovecaDatabase(openFileExecutor(dbPath));
      await first.customSelect('SELECT 1').get();
      expect(await _userVersion(first), 4);
      // 移行後に番兵を入れる。次に rebuildAll が走れば消える。
      await _insertSentinel(first);
      await first.close();

      // 2 回目: 版が同じなので何も走らないはず。
      final second = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      expect(await _userVersion(second), 4);
      expect(
        await _sentinelSurvives(second),
        isTrue,
        reason: '★索引が建て直された＝毎起動で移行が走っている',
      );
    });
  });
}
