/// ★★ 解決された sqlite3 が★FTS5 / trigram を持つか（★★プラットフォームを問わない★★）★★
///
/// ★★ なぜ `main_probe.dart` では足りないか ★★
/// ★**あちらは★★リポジトリの現物（dist）を読む★★**（`common/spike_db.dart` /
/// `common/paths.dart` が★★ファイルシステムからリポジトリの根を探す★★）。
/// → ★**Windows の開発機でしか走らない。★★Android では★根が無い★★。**
///
/// ★★ この試作が見るのは 1 点だけである ★★
/// ★`loveca_db` の [probeSqliteCapabilities] を呼ぶ。★**現物も dist も 1 バイトも読まない。**
/// → ★★**どのプラットフォームでも★同じ 1 行が出る。**★★
///
/// ★★ 何のために置いたか —— `docs/UI設計メモ.md` §7 の 3 ★★
/// ★**「★FTS5 が無いと `card_search` の作成時点で落ちる」**と★§7 が書いている。
/// ★**確かめたのは Windows だけだった**（`docs/UI技術検証メモ.md` §1-2）。
///
/// ```bash
/// flutter run -d windows       -t spike/main_sqlite_caps.dart
/// flutter run -d emulator-5554 -t spike/main_sqlite_caps.dart
/// ```
///
/// ★★ 自分で終わる —— ★★Android では終わった。★Windows では終わらなかった ★★ ★★
/// ★`--dart-define=SPIKE_AUTOEXIT=1` を渡すと★★出力を書いてから `exit(0)` する★★
/// （★`spike/` の他の試作と同じ作法 / `CLAUDE.md` §3）。
/// ★★**Windows では★2 秒後の `exit(0)` でプロセスが終わらなかった**★★（★実測 —— ★★外から止めた★★）。
/// ★**原因は追っていない**（**D-28** —— ★★測っているのは★終わり方ではない★★）。
/// → ★**Windows で走らせるときは★出力をファイルへ落とし、★★外から止めること★★。**
///
/// ★★ 出力の読み方 ★★
///
/// | プラットフォーム | ★どう読むか |
/// |---|---|
/// | ★Windows | ★**`flutter build windows --debug -t …` して★★exe を直に走らせ、★出力をファイルへ落とす★★** |
/// | ★Android | ★**`flutter build apk --debug -t …` → `adb install -r` → `adb shell am start` → ★★`adb logcat -d`★★** |
///
/// ★★**`flutter run` は使わない**★★ —— ★**この環境では★★返ってこなかった★★**（★実測）。
///
/// ★★ 実測（2026-09-01）★★
///
/// | 何 | ★結果 |
/// |---|---|
/// | ★Windows（x64） | ★`SQLite 3.53.4 (fts5: true, trigram: true) usable=true` |
/// | ★★**Android（エミュレータ / x86_64 / API 36）**★★ | ★★**`SQLite 3.53.4 (fts5: true, trigram: true) usable=true`**★★ |
///
/// ★★**arm64-v8a / armeabi-v7a は★走らせていない**★★（★★APK の中の字面は確かめた★★ ——
/// ★`libsqlite3.so` が 3 ABI とも入り、★`fts5` / `trigram` / `ENABLE_FTS5` の字面が在る）。
/// ★**「Android で動く」と★ABI をまたいで言わない**（**§7-10** —— ★層を書く）。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loveca_db/native.dart';

const bool _autoExit = bool.fromEnvironment('SPIKE_AUTOEXIT');

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final line = _probe();
  // ★★ `print` で書く。★`stdout.writeln` は★★Android の記録に出ない★★（★実測）★★
  //   ★Flutter は `print` を★プラットフォームの記録へ流す（★Android なら logcat の `flutter` タグ）。
  //   ★**最初は `stdout.writeln` で書いた。★★1 行も出なかった★★**（★`adb logcat` で確かめた）。
  // ignore: avoid_print
  print('SQLITE_CAPS $line');

  if (_autoExit) {
    // ★★ 描かずに終わる —— ★測っているのは★★画面ではない★★ ★★
    //   ★**記録が流れきってから終える**（★即座に `exit` すると★★出力が失われうる★★）。
    Future<void>.delayed(const Duration(seconds: 2), () => exit(0));
    return;
  }
  runApp(_CapsApp(line));
}

String _probe() {
  try {
    final caps = probeSqliteCapabilities();
    return '${Platform.operatingSystem} | $caps | usable=${caps.isUsable}';
  } on Object catch (e) {
    // ★★ 投げない —— ★★「解決できなかった」も★測りたい答えである★★ ★★
    return '${Platform.operatingSystem} | 失敗: $e';
  }
}

class _CapsApp extends StatelessWidget {
  const _CapsApp(this.line);

  final String line;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'loveca spike / sqlite caps',
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          appBar: AppBar(title: const Text('sqlite3 の能力')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              line,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
}
