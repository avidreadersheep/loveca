/// アプリのファイル置き場（決定 D59 / `docs/UI設計メモ.md` §4-6）.
///
/// ★★ `path_provider` に触れてよいのはこのファイルだけ ★★
///
/// `loveca_db` は DB ファイルの置き場所を決めない
/// （`native.dart`「置き場所は呼び出し側が決める。`path_provider` は
/// Flutter 依存なのでこのパッケージからは参照しない」）。決めるのは `loveca-ui` の責務。
///
/// ★★ キャッシュ領域に置かないこと ★★
/// DB は `decks`（**作り直せないユーザデータ** / 決定 D11・D35）と
/// `cards` / `printings` / `card_search`（dist からの派生物で作り直せる）を
/// **同じ 1 ファイル**に持つ。`getApplicationCacheDirectory()` は
/// **OS がいつでも消してよい場所**なので、置くと**デッキが黙って消えうる**。
/// これは A-3（痕跡を残さずデータを落とす）と同じ型の失敗である。
///
/// ★Phase 5 でこのファイルを書き換えずに済む形にしてある（決定 D52 の
/// 「通路を設計で確保する」の実質化）。`getApplicationSupportDirectory()` は
/// Windows / Android / iOS すべてで「アプリが支援ファイルを置いてよい場所」を
/// 返す契約なので、**DB の置き場は差し替え不要**。
/// プラットフォームで変わるのは dist の探し方だけで、そちらは
/// `DistLocator` 抽象に閉じてある。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  const AppPaths(this.supportDir);

  /// `getApplicationSupportDirectory()` が返すディレクトリ。
  final Directory supportDir;

  static Future<AppPaths> resolve() async =>
      AppPaths(await getApplicationSupportDirectory());

  /// ★キャッシュ領域ではない。上の注記を参照。
  File get databaseFile => File(p.join(supportDir.path, 'loveca.db'));

  File get settingsFile => File(p.join(supportDir.path, 'settings.json'));

  @override
  String toString() => 'AppPaths(${supportDir.path})';
}
