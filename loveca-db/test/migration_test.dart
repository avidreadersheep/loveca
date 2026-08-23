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

// ---------------------------------------------------------------------------
// v1 の DB を作る
// ---------------------------------------------------------------------------

/// v2 で作った DB を v1 相当へ巻き戻す。
///
/// ★★ この手法が正しい条件 ★★
/// **v1 と v2 で実テーブル（16 個）が完全に同一であること。**
/// 決定 D49 が変えたのは仮想テーブル `card_search` の 1 列だけなので、
/// 「v2 が作った実テーブル」は「v1 が作る実テーブル」とスキーマ上同一である。
///
/// ★**次に実テーブルを動かす移行を入れたら、この手法は使えなくなる。**
/// そのときは v1 の実テーブル定義そのものを凍結して持つ必要がある。
/// **この注記を読まずに流用しないこと。**
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

  // ★drift の native 実装は `user_version` プラグマで版を判定する
  //   （`drift/lib/native.dart`「This uses the `user_version` sqlite3 pragma」）。
  //   ここを 1 にして開き直すと `onUpgrade(1, 2)` が走る。
  await db.customStatement('PRAGMA user_version = 1');
}

Future<int> _userVersion(LovecaDatabase db) async {
  final row = await db.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
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

  group('★ v1 を v2 で開くと onUpgrade が走る（決定 D49 / D-6）', () {
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

    test('user_version が 2 になる', () async {
      // ★★ これ単独では移行の中身が走った証拠にならない ★★
      // drift は `onUpgrade` が何もしなくても版を上げる。実際、
      // `onUpgrade` の中身を空にして走らせる実験（2026-08-24）では
      // **この test だけは通った。** 落ちたのは「索引が v2 の形になる」
      // 「trigram 経路で引ける」「返る cardNumber が保存表記」の 3 つである。
      // → 移行が働いたことを言えるのはそれらであって、この test ではない。
      expect(await _userVersion(db), 2);
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
      expect(await _userVersion(first), 2);
      // 移行後に番兵を入れる。次に rebuildAll が走れば消える。
      await _insertSentinel(first);
      await first.close();

      // 2 回目: 版が同じなので何も走らないはず。
      final second = LovecaDatabase(openFileExecutor(dbPath));
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();

      expect(await _userVersion(second), 2);
      expect(
        await _sentinelSurvives(second),
        isTrue,
        reason: '★索引が建て直された＝毎起動で移行が走っている',
      );
    });
  });
}
