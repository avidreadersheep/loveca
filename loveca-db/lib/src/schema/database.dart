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
    MasterStates,
    MasterFiles,
    ImportIssues,
  ],
)
class LovecaDatabase extends _$LovecaDatabase {
  LovecaDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // ★仮想テーブルは drift の Dart テーブル API で表現できないので手で作る。
          await customStatement(createCardSearchTable);
        },
        beforeOpen: (details) async {
          // ★外部キーは既定で無効。有効にしないと onDelete: cascade が効かない。
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
