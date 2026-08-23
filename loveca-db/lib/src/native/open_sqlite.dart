/// ネイティブ sqlite3 の調達と能力検査.
///
/// ★ネイティブライブラリの調達方法★
/// `sqlite3` 3.x はビルドフック（native assets）で SQLite 本体を自前調達する。
/// システムの `sqlite3.dll` / `libsqlite3.so` に依存しないため、
/// **FTS5 の有無が実行環境ごとに変わる問題が構造的に起きない。**
/// （Windows 11 には素の `sqlite3.dll` が無く `winsqlite3.dll` しか無いため、
///   従来方式ではここが環境依存の落とし穴になっていた）
library;

import 'package:sqlite3/sqlite3.dart';

/// 解決されたライブラリの診断情報。
class SqliteCapabilities {
  const SqliteCapabilities({
    required this.version,
    required this.hasFts5,
    required this.hasTrigram,
  });

  final String version;
  final bool hasFts5;

  /// trigram トークナイザ。SQLite 3.34.0 以降。
  final bool hasTrigram;

  bool get isUsable => hasFts5 && hasTrigram;

  @override
  String toString() => 'SQLite $version (fts5: $hasFts5, trigram: $hasTrigram)';
}

/// 解決された sqlite3 が本パッケージの要求を満たすか調べる。
SqliteCapabilities probeSqliteCapabilities() {
  final db = sqlite3.openInMemory();
  try {
    var hasFts5 = false;
    var hasTrigram = false;
    try {
      db.execute('CREATE VIRTUAL TABLE _probe USING fts5(x)');
      hasFts5 = true;
      db.execute('DROP TABLE _probe');
    } on SqliteException catch (_) {
      // FTS5 非搭載ビルド。
    }
    if (hasFts5) {
      try {
        db.execute(
          "CREATE VIRTUAL TABLE _probe3 USING fts5(x, tokenize = 'trigram')",
        );
        hasTrigram = true;
        db.execute('DROP TABLE _probe3');
      } on SqliteException catch (_) {
        // SQLite 3.34.0 未満。
      }
    }
    return SqliteCapabilities(
      version: sqlite3.version.libVersion,
      hasFts5: hasFts5,
      hasTrigram: hasTrigram,
    );
  } finally {
    db.close();
  }
}

/// 要求を満たさないネイティブライブラリを掴んでいたら、原因が分かる形で落とす。
///
/// ★黙って検索機能だけ壊れた状態で動き続けさせない★
/// FTS5 が無いビルドだと `card_search` の作成時に落ちるが、
/// そこで初めて気づくとエラーがスキーマ移行の中に埋もれる。
void assertSqliteCapabilities() {
  final caps = probeSqliteCapabilities();
  if (caps.isUsable) return;
  throw StateError(
    '解決された sqlite3 が要求を満たしていません: $caps\n'
    'FTS5 と trigram トークナイザ（SQLite 3.34.0 以降）が要ります。',
  );
}
