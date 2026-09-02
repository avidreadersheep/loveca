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

  /// ★★ 端末に取り込んだカード画像の置き場（★§32-6 の **8** の 1 / 決定 **D149**）★★
  ///
  /// ## ★★ キャッシュ領域に置かない。★理由は DB とは違う ★★
  ///
  /// ★**DB をキャッシュに置かない理由は「★★作り直せないユーザデータが混ざるから★★」である**（★上）。
  /// ★★**画像は★作り直せる。★それでもキャッシュに置かない**★★ ——
  ///   ★**取り込み層は★「取り込み済み」を★★DB に記録する★★**（`master_import_files`）。
  ///   ★**OS が画像だけ消すと、★★記録は残り★実体だけが消える★★** ——
  ///     ★★次の取り込みは★ハッシュが一致するので★1 件も計画しない★★（★実読）。
  ///   → ★**画像が★★痕跡を残さず落ちる★★**（★型は **D-4** / **D-32** と同じ）。
  /// ★★**「消えない」とは書かない**★★（**D-28**）—— ★**利用者が消すことも、★端末が壊れることも在る。**
  ///   ★**書けるのは「★★OS がいつでも消してよい場所には置かない★★」までである。**
  ///
  /// ## ★★ 段 2 の相手そのものである ★★
  ///
  /// ★**読む側は `resolveCardImagesRoot` の★段 2**（`card_image_source.dart`）。
  /// ★**書く側は `LocalDirectoryMasterImageSink`**（`loveca_db` の `native.dart`）。
  /// ★★**dist のディレクトリではない**★★（**D137-4** の柵 2 —— ★★取り込みが dist へ書かない★★）。
  Directory get cardImagesDir => Directory(p.join(supportDir.path, 'images'));

  @override
  String toString() => 'AppPaths(${supportDir.path})';
}
