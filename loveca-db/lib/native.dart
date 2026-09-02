/// ネイティブ（デスクトップ / モバイル）向けのエントリポイント.
///
/// ★`dart:io` に触れるのはこのエントリの下だけ★
/// `package:loveca_db/loveca_db.dart` 側（スキーマ・DAO・取り込み層）は
/// `QueryExecutor` を受け取るだけで、`dart:io` を一切含まない。
/// Phase 5 で Web / WASM 経路を足すときに、そちらを差し替えるだけで済む形にしてある。
library;

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

export 'src/native/local_dir_image_sink.dart';
export 'src/native/local_dir_source.dart';
export 'src/native/open_sqlite.dart'
    show SqliteCapabilities, assertSqliteCapabilities, probeSqliteCapabilities;

/// メモリ上の DB を開く。テストと使い捨ての検証用。
QueryExecutor openInMemoryExecutor({bool logStatements = false}) =>
    NativeDatabase.memory(logStatements: logStatements);

/// ファイル上の DB を開く。
///
/// 置き場所は呼び出し側が決める。`path_provider` は Flutter 依存なので
/// このパッケージからは参照しない（アプリ側が解決してパスを渡す）。
QueryExecutor openFileExecutor(String path, {bool logStatements = false}) =>
    NativeDatabase(File(path), logStatements: logStatements);
