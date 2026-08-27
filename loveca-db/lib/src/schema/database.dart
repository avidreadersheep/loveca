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
    MasterStates,
    MasterFiles,
    ImportIssues,
  ],
)
class LovecaDatabase extends _$LovecaDatabase {
  LovecaDatabase(super.executor);

  /// ★2: 検索索引に `card_number_raw` を足した（決定 D49）。
  /// ★3: `deck_entries` に `ord` を足した（決定 D65 / **D99**）。
  ///
  /// 上げるときは必ず [migration] の `onUpgrade` に対応する手順を足すこと。
  /// 版だけ上げて手順を足さないと、既存の端末が古い形のまま動き続ける。
  @override
  int get schemaVersion => 3;

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
        },
        beforeOpen: (details) async {
          // ★外部キーは既定で無効。有効にしないと onDelete: cascade が効かない。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
