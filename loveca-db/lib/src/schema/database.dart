/// drift のデータベース定義.
///
/// ★`QueryExecutor` を受け取るだけにしてある★
/// このファイルは `dart:io` を含まない。DB ファイルの場所やネイティブライブラリの
/// 調達は `package:loveca_db/native.dart` 側の責務。
library;

import 'package:drift/drift.dart';
// ★生成される database.g.dart は part なのでこのファイルの import を使う。
//   textEnum の型 (CardType / HeartColor / BladeHeartEffect / 各 Kind) が
//   生成コードから見えるように、ここで import しておく必要がある。
import 'package:loveca_core/loveca_core.dart';

import '../dao/deck_dao.dart';
import '../search/card_search_dao.dart';
import '../search/card_search_schema.dart';
import 'enums.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Cards,
    CardNames,
    CardKeywords,
    CardHearts,
    CardBladeHeartEffects,
    Printings,
    Products,
    Faqs,
    FaqPrintings,
    RuleConfigs,
    Decks,
    DeckTags,
    DeckEntries,
    DeckEditOps,
    DeckSyncMarks,
    MasterStates,
    MasterFiles,
    ImportIssues,
  ],
)
class LovecaDatabase extends _$LovecaDatabase {
  LovecaDatabase(super.executor);

  /// ★2: 検索索引に `card_number_raw` を足した（決定 D49）。
  /// ★3: `deck_entries` に `ord` を足した（決定 D65 / **D99**）。
  /// ★4: 編集ログの表 `deck_edit_ops` を足した（決定 **D110-1**）。
  /// ★5: 前回同期時点の器 `deck_sync_marks` を足した（決定 **D114-1** / **N-10**）。
  ///
  /// 上げるときは必ず [migration] の `onUpgrade` に対応する手順を足すこと。
  /// 版だけ上げて手順を足さないと、既存の端末が古い形のまま動き続ける。
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // ★仮想テーブルは drift の Dart テーブル API で表現できないので手で作る。
          await customStatement(createCardSearchTable);
        },

        /// ★移行機構（Phase 4 でどのみち要るものの前倒し）★
        ///
        /// これが無いと、スキーマを変えた版を配ったときに
        /// **既存端末のデッキ（ユーザデータ）を捨てるしか手が無くなる。**
        /// `cards` / `printings` / `card_search` は配信物からの派生なので作り直せるが、
        /// `decks` は作り直せない（決定 D11 / D35）。
        ///
        /// ★検索索引の作り直しで済む変更は `rebuildAll` に寄せる★
        /// `card_search` は `cards` / `card_names` からの純粋な派生物なので、
        /// 落として建て直すだけでよく、ユーザデータに触れずに済む。
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v1 -> v2: 索引に `card_number_raw` を足した（決定 D49）。
            //           索引は派生物なので建て直すだけでよい。
            await CardSearchDao(this).rebuildAll();
          }
          if (from < 3) {
            // ★★ v2 -> v3: `deck_entries` に `ord` を足す（決定 D65 / D99）★★
            //
            // ★ここから下は上の枝と格が違う。**ユーザデータに触る移行**である。
            //   `card_search` は `cards` からの純粋な派生物なので落として建て直せるが、
            //   `decks` は作り直せない（決定 D11 / D35）。
            //
            // ★順序が要る: 列を足してからでないと backfill が書き込めない。
            await m.addColumn(deckEntries, deckEntries.ord);
            await DeckDao(this).backfillOrd();
          }
          if (from < 4) {
            // ★★ v3 -> v4: 編集ログの表を作る（決定 **D110-1**）★★
            //
            // ★上の 2 つの枝と格が違う。**既存の行を 1 行も読まず 1 行も書かない。**
            //   `from < 2` は `card_search` を作り直し、`from < 3` は
            //   `deck_entries` の全行に `ord` を書いた。ここは**表を足すだけ**である。
            //
            // ★★ ただし「触らない」は「安全」の意味ではない ★★
            //   `schemaVersion` は上がるので、**既存インストールの DB は必ずここを通る。**
            //   通る以上、`decks` / `deck_entries` が無傷であることは
            //   **測って確かめる**（`test/migration_test.dart` の v3 -> v4 の群）。
            //
            // ★決定 **D109**: 移行は「システムが動かした」側なので
            //   `decks.updatedAt` を動かさない。★動かさないことも上のテストが見る。
            //
            // ★`m.createAll()` ではない —— それは**既存の表も作り直そうとする**。
            //   足した 1 つだけを名指しする。
            await m.createTable(deckEditOps);
          }
          if (from < 5) {
            // ★★ v4 -> v5: 前回同期時点の器を作る（決定 **D114-1** / **N-10**）★★
            //
            // ★`from < 4` と同じ格である。**既存の行を 1 行も読まず 1 行も書かない。**
            //   `decks` / `deck_entries` / `deck_edit_ops` に 1 文字も触れない。
            //
            // ★★ 「触らない」は「安全」の意味ではない ★★
            //   `schemaVersion` は上がるので、**既存インストールの DB は必ずここを通る。**
            //   通る以上、無傷であることは**測って確かめる**
            //   （`test/migration_test.dart` の v4 -> v5 の群）。
            //
            // ★決定 **D109**: 移行は「システムが動かした」側なので
            //   `decks.updatedAt` を動かさない。★動かさないことも上のテストが見る。
            //   ★**D114-4 の 3**（器への書き込みが `decks` を 1 度も触らない）が
            //   この表を選んだ根拠の 1 つであり、**移行の時点から成り立たせる。**
            //
            // ★`m.createAll()` ではない —— それは**既存の表も作り直そうとする**。
            //   足した 1 つだけを名指しする（`from < 4` と同じ）。
            await m.createTable(deckSyncMarks);
          }
        },
        beforeOpen: (details) async {
          // ★外部キーは既定で無効。有効にしないと onDelete: cascade が効かない。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
