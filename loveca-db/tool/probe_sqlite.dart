/// 解決された sqlite3 の診断を表示する.
///
/// 検索が動かないときに最初に見る場所。
///
/// ```bash
/// cd loveca-db && dart run tool/probe_sqlite.dart
/// ```
library;

import 'package:loveca_db/native.dart';

void main() {
  final caps = probeSqliteCapabilities();
  print(caps);
  if (!caps.isUsable) {
    print('★要求を満たしていません。FTS5 と trigram が要ります。');
  }
}
