/// ネイティブ sqlite3 が本パッケージの要求を満たすかの検査.
///
/// ★FTS5 と trigram トークナイザは検索の前提条件★
/// 無いビルドを掴むと `card_search` の作成で初めて落ち、
/// エラーがスキーマ移行の中に埋もれる。ここで先に露見させる。
library;

import 'package:loveca_db/native.dart';
import 'package:test/test.dart';

void main() {
  test('sqlite3 が解決でき、バージョンが取れる', () {
    final caps = probeSqliteCapabilities();
    printOnFailure('$caps');
    expect(caps.version, isNotEmpty);
  });

  test('FTS5 が使える', () {
    expect(probeSqliteCapabilities().hasFts5, isTrue);
  });

  test('trigram トークナイザが使える (SQLite 3.34.0 以降)', () {
    expect(probeSqliteCapabilities().hasTrigram, isTrue);
  });

  test('assertSqliteCapabilities が通る', () {
    expect(assertSqliteCapabilities, returnsNormally);
  });
}
