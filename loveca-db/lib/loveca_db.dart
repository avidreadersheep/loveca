/// loveca_db — ラブカ シミュレーターのローカル DB 層.
///
/// ★このライブラリは `dart:io` を含まない★
/// DB ファイルの場所とネイティブ sqlite3 の調達は
/// `package:loveca_db/native.dart` 側の責務。
/// Phase 5 で Web / WASM 経路を足すときは、そちらを差し替えれば済む。
library;

export 'src/dao/card_dao.dart';
export 'src/dao/deck_dao.dart';
export 'src/dao/deck_sync_mark_dao.dart';
export 'src/dao/master_state_dao.dart';
export 'src/dao/sync_identity_dao.dart';
export 'src/import/master_file_source.dart';
export 'src/import/master_image_sink.dart';
export 'src/import/master_importer.dart';
export 'src/schema/database.dart';
export 'src/schema/enums.dart';
export 'src/schema/tables.dart';
export 'src/search/card_search_dao.dart';
export 'src/search/card_search_schema.dart';
export 'src/search/fold.dart';
